const asyncHandler = require('express-async-handler');
const { query, getOne } = require('../config/db');
const { getEventForOwner } = require('./eventController');
const design = require('../services/ticketDesignService');
const logger = require('../utils/logger');

/**
 * Desain tiket Organizer (PRD §5).
 *
 * Semua endpoint di sini hanya untuk pemilik event atau Admin. Endpoint tiket
 * publik (QR/PDF peserta) berada di `ticketController`, sehingga desain tidak
 * pernah membuka akses ke data internal Organizer.
 */

const absoluteUrl = (req, filePath) => {
  if (!filePath) return null;
  return `${req.protocol}://${req.get('host')}${filePath}`;
};

const loadTicketType = async (eventId, ticketTypeId) => {
  if (!ticketTypeId) return null;
  return getOne(
    'SELECT id, event_id, name, ticket_design, ticket_design_orientation '
    + 'FROM ticket_types WHERE id = $1 AND event_id = $2',
    [ticketTypeId, eventId],
  );
};

/**
 * Data teks nyata untuk menghitung kotak elemen saat memvalidasi tata letak.
 *
 * Judul memakai nama event sebenarnya dan ID tiket contoh berformat sama dengan
 * ID asli (`ETK-XXXXXXX`), sehingga tumpang tindih yang dilaporkan editor sama
 * dengan yang akan terjadi pada tiket peserta.
 */
const layoutValidationTexts = (event) => {
  const title = design.layoutSpec.ticketTitle(event?.title || 'Nama Event');
  return {
    title,
    ticketId: design.layoutSpec.ticketIdLine('ETK-0000000'),
    instruction: design.layoutSpec.EXCHANGE_INSTRUCTION,
  };
};

/**
 * Desain efektif = desain tersimpan (bila ada) atau konfigurasi default.
 * Orientasi & tata letak selalu dikirim agar Store/UI dapat menampilkan posisi
 * elemen yang BENAR-BENAR dipakai saat tiket dirender, walau Organizer belum
 * mengunggah berkas desain.
 */
const presentDesign = (req, raw, orientationFallback) => {
  const normalized = design.normalizeDesign(raw);
  const orientation = design.orientationOrDefault(
    normalized?.orientation || orientationFallback,
  );
  const layout = normalized?.layout
    || design.layoutSpec.defaultLayoutFor(orientation);
  const base = {
    file_path: normalized?.file_path ?? null,
    content_type: normalized?.content_type ?? null,
    source: normalized ? normalized.source : 'none',
    template: normalized ? normalized.template : 'default',
    orientation,
    width: normalized?.width ?? null,
    height: normalized?.height ?? null,
    layout,
    qr: { ...layout.qr },
    updated_at: normalized?.updated_at ?? null,
    url: normalized?.file_path ? absoluteUrl(req, normalized.file_path) : null,
    // True bila konfigurasi berasal dari unggahan Organizer (bukan default).
    is_custom: Boolean(normalized?.file_path),
  };
  return base;
};

const getEventTicketDesign = asyncHandler(async (req, res) => {
  const event = await getEventForOwner(req.params.eventId, req.user);
  const ticketTypes = await query(
    'SELECT id, name, ticket_design, ticket_design_orientation '
    + 'FROM ticket_types WHERE event_id = $1 ORDER BY name ASC',
    [event.id],
  );
  // Orientasi event: kolom eksplisit -> JSON desain -> default sistem.
  const eventOrientation = design.orientationOrDefault(
    event.ticket_design_orientation
      || design.designOrientationOf(event.ticket_design),
  );
  res.json({
    success: true,
    event_design: presentDesign(req, event.ticket_design, eventOrientation),
    event_orientation: eventOrientation,
    ticket_types: ticketTypes.map((row) => {
      // Kategori yang belum diatur mewarisi orientasi event.
      const typeOrientation = design.orientationOrDefault(
        row.ticket_design_orientation
          || design.designOrientationOf(row.ticket_design)
          || eventOrientation,
      );
      return {
        id: row.id,
        name: row.name,
        orientation: typeOrientation,
        is_orientation_explicit: Boolean(
          row.ticket_design_orientation || design.designOrientationOf(row.ticket_design),
        ),
        design: presentDesign(req, row.ticket_design, typeOrientation),
      };
    }),
    orientations: design.ORIENTATIONS,
    default_orientation: design.DEFAULT_ORIENTATION,
    default_layout: {
      layout: design.layoutSpec.DEFAULT_LAYOUT_BY_ORIENTATION[eventOrientation],
      qr: design.DEFAULT_QR_BY_ORIENTATION[eventOrientation],
      layout_by_orientation: design.layoutSpec.DEFAULT_LAYOUT_BY_ORIENTATION,
      qr_by_orientation: design.DEFAULT_QR_BY_ORIENTATION,
      spec: design.ORIENTATION_SPEC,
      canvas: design.layoutSpec.CANVAS,
      limits: design.layoutSpec.LIMITS,
      colors: design.layoutSpec.DEFAULT_COLORS,
    },
    // Teks contoh dipakai editor untuk pratinjau (bukan data peserta nyata).
    preview_texts: layoutValidationTexts(event),
    fonts: design.ticketFonts.resolveFontFiles(),
  });
});

const saveTicketDesign = asyncHandler(async (req, res) => {
  const event = await getEventForOwner(req.params.eventId, req.user);
  const scope = String(req.body?.scope || 'event').toLowerCase();
  if (!['event', 'ticket_type'].includes(scope)) {
    res.status(400);
    throw new Error('Scope desain harus "event" atau "ticket_type".');
  }

  let ticketType = null;
  if (scope === 'ticket_type') {
    ticketType = await loadTicketType(event.id, req.body?.ticket_type_id);
    if (!ticketType) {
      res.status(404);
      throw new Error('Kategori tiket tidak ditemukan pada event ini.');
    }
  }

  const previousRaw = scope === 'event' ? event.ticket_design : ticketType.ticket_design;
  const previous = design.normalizeDesign(previousRaw);
  const previousOrientation = design.orientationOrDefault(
    previous?.orientation
      || (scope === 'event' ? event.ticket_design_orientation
        : ticketType.ticket_design_orientation),
  );

  // Simpan orientasi saja (tanpa mengunggah file) diperbolehkan: Organizer
  // memilih orientasi sebelum mengunggah desain.
  const onlyOrientation = req.body?.orientation_only === true
    || (typeof req.body?.image_base64 !== 'string' && req.body?.orientation != null
      && req.body?.layout == null && req.body?.qr == null);

  if (onlyOrientation) {
    const orientation = design.normalizeOrientation(req.body?.orientation);
    if (!orientation) {
      res.status(400);
      throw new Error('Orientasi desain tiket harus "landscape" atau "portrait".');
    }
    // Desain lama hanya dipertahankan bila orientasinya sama. Bila berbeda,
    // file lama dilepas (dan dihapus) agar tiket tidak memakai gambar dengan
    // rasio yang salah — yang akan terpotong/diregangkan saat dirender.
    const keepFile = previous && previous.orientation === orientation;
    const stored = {
      source: keepFile ? previous.source : 'template',
      template: keepFile ? previous.template : 'default',
      ...(keepFile ? { file_path: previous.file_path, content_type: previous.content_type } : {}),
      orientation,
      // Tata letak kembali ke default orientasi baru; nilai default dijamin
      // valid sehingga tidak perlu validasi tumpang tindih.
      layout: design.layoutSpec.defaultLayoutFor(orientation),
      updated_at: new Date().toISOString(),
    };
    const removedFile = previous?.file_path && !keepFile ? previous.file_path : null;

    if (scope === 'event') {
      await query(
        'UPDATE events SET ticket_design = $1::jsonb, ticket_design_orientation = $2 '
        + 'WHERE id = $3',
        [JSON.stringify(stored), orientation, event.id],
      );
    } else {
      await query(
        'UPDATE ticket_types SET ticket_design = $1::jsonb, ticket_design_orientation = $2 '
        + 'WHERE id = $3',
        [JSON.stringify(stored), orientation, ticketType.id],
      );
    }
    if (removedFile) {
      await design.removeDesignFile(removedFile).catch((error) => {
        logger.warn('ticket_design_cleanup_failed', { error: error.message });
      });
    }
    logger.info('ticket_design_orientation_saved', {
      eventId: event.id, scope, orientation, designRemoved: Boolean(removedFile),
    });
    return res.json({
      success: true,
      scope,
      ticket_type_id: ticketType?.id ?? null,
      design: {
        ...stored,
        qr: { ...stored.layout.qr },
        url: stored.file_path ? absoluteUrl(req, stored.file_path) : null,
      },
    });
  }

  // Simpan KONFIGURASI TATA LETAK saja (tanpa mengunggah ulang file desain):
  // posisi/ukuran judul, ID tiket, instruksi, dan QR. Berlaku juga saat belum
  // ada berkas desain (Organizer mengatur tata letak pada desain default).
  const layoutOnly = req.body?.layout_only === true || req.body?.qr_only === true
    || (typeof req.body?.image_base64 !== 'string'
      && req.body?.orientation_only !== true
      && req.body?.orientation == null
      && (req.body?.layout != null || req.body?.qr != null));

  if (layoutOnly) {
    const orientation = previousOrientation;
    const { errors, value: layout } = design.validateLayoutPayload(
      req.body?.layout ?? req.body,
      { ...layoutValidationTexts(event), orientation },
    );
    if (errors.length > 0) {
      res.status(400);
      throw new Error(errors.join(' '));
    }
    const stored = design.applyLayoutPlacement(previous, { layout });
    if (scope === 'event') {
      await query(
        'UPDATE events SET ticket_design = $1::jsonb WHERE id = $2',
        [JSON.stringify(stored), event.id],
      );
    } else {
      await query(
        'UPDATE ticket_types SET ticket_design = $1::jsonb WHERE id = $2',
        [JSON.stringify(stored), ticketType.id],
      );
    }
    logger.info('ticket_design_layout_saved', {
      eventId: event.id,
      scope,
      ticketTypeId: ticketType?.id ?? null,
      qr: stored.layout.qr,
      title_size: stored.layout.title.font_size,
    });
    return res.json({
      success: true,
      scope,
      ticket_type_id: ticketType?.id ?? null,
      design: {
        ...stored,
        qr: { ...stored.layout.qr },
        url: absoluteUrl(req, stored.file_path),
      },
    });
  }

  const { errors, value } = design.validateUploadPayload({
    ...req.body,
    title_text: layoutValidationTexts(event).title,
    ticket_id_text: layoutValidationTexts(event).ticketId,
    instruction_text: layoutValidationTexts(event).instruction,
  });
  if (errors.length > 0) {
    res.status(400);
    throw new Error(errors.join(' '));
  }
  // Desain lama pada orientasi berbeda tidak dapat dipakai ulang: rasio file
  // akan berbeda dengan kanvas, sehingga akan terpotong/diregangkan.
  const orientationChanged = previousOrientation !== value.orientation;

  const { filePath } = await design.saveDesignImage({
    eventId: event.id,
    buffer: value.buffer,
    contentType: value.contentType,
  });

  const stored = {
    source: 'upload',
    template: typeof req.body?.template === 'string' ? req.body.template : 'custom',
    file_path: filePath,
    content_type: value.contentType,
    orientation: value.orientation,
    width: value.width,
    height: value.height,
    layout: value.layout,
    updated_at: new Date().toISOString(),
  };

  if (scope === 'event') {
    await query(
      'UPDATE events SET ticket_design = $1::jsonb, ticket_design_orientation = $2 '
      + 'WHERE id = $3',
      [JSON.stringify(stored), value.orientation, event.id],
    );
  } else {
    await query(
      'UPDATE ticket_types SET ticket_design = $1::jsonb, ticket_design_orientation = $2 '
      + 'WHERE id = $3',
      [JSON.stringify(stored), value.orientation, ticketType.id],
    );
  }

  // File lama dihapus setelah referensi baru tersimpan agar tidak ada desain
  // yang menunjuk file hilang bila penyimpanan gagal.
  if (previous?.file_path && previous.file_path !== filePath) {
    await design.removeDesignFile(previous.file_path).catch((error) => {
      logger.warn('ticket_design_cleanup_failed', { error: error.message });
    });
  }
  logger.info('ticket_design_saved', {
    eventId: event.id,
    scope,
    ticketTypeId: ticketType?.id ?? null,
    orientation: value.orientation,
    orientationChanged,
  });

  res.json({
    success: true,
    scope,
    ticket_type_id: ticketType?.id ?? null,
    design: {
      ...stored,
      qr: { ...stored.layout.qr },
      url: absoluteUrl(req, stored.file_path),
    },
  });
});

const deleteTicketDesign = asyncHandler(async (req, res) => {
  const event = await getEventForOwner(req.params.eventId, req.user);
  const scope = String(req.query.scope || 'event').toLowerCase();
  if (!['event', 'ticket_type'].includes(scope)) {
    res.status(400);
    throw new Error('Scope desain harus "event" atau "ticket_type".');
  }

  if (scope === 'event') {
    const previous = design.normalizeDesign(event.ticket_design);
    // Reset ke NULL (belum diatur) agar tiket kembali memakai default sistem.
    await query(
      'UPDATE events SET ticket_design = NULL, ticket_design_orientation = NULL WHERE id = $1',
      [event.id],
    );
    if (previous?.file_path) await design.removeDesignFile(previous.file_path);
    return res.json({ success: true, scope, design: null });
  }

  const ticketType = await loadTicketType(event.id, req.query.ticket_type_id);
  if (!ticketType) {
    res.status(404);
    throw new Error('Kategori tiket tidak ditemukan pada event ini.');
  }
  const previous = design.normalizeDesign(ticketType.ticket_design);
  await query(
    'UPDATE ticket_types SET ticket_design = NULL, ticket_design_orientation = NULL WHERE id = $1',
    [ticketType.id],
  );
  if (previous?.file_path) await design.removeDesignFile(previous.file_path);
  return res.json({
    success: true,
    scope,
    ticket_type_id: ticketType.id,
    design: null,
  });
});

/**
 * Unduh template desain tiket.
 *
 * Template bersifat generik (tanpa data Organizer/event), sehingga dapat
 * diakses tanpa login agar tautannya bisa dibuka langsung dari browser/aplikasi.
 * `format=pdf` (default) dan `format=png` memakai ukuran kanvas yang sama
 * dengan tiket final, lengkap dengan penanda posisi QR.
 */
const downloadTemplate = asyncHandler(async (req, res) => {
  const format = String(req.query.format || 'pdf').toLowerCase();
  // Template mengikuti orientasi yang dipilih penyelenggara.
  const orientation = design.normalizeOrientation(req.query.orientation)
    || design.DEFAULT_ORIENTATION;
  const suffix = orientation === 'portrait' ? 'portrait' : 'landscape';

  if (format === 'png') {
    const pngPath = design.templatePathFor('png', orientation);
    if (!pngPath) {
      res.status(503);
      throw new Error('Template PNG belum tersedia di server.');
    }
    res.setHeader('Content-Type', 'image/png');
    res.setHeader(
      'Content-Disposition',
      `attachment; filename="template-desain-tiket-${suffix}.png"`,
    );
    return res.sendFile(pngPath);
  }
  if (format !== 'pdf') {
    res.status(400);
    throw new Error('Format template harus pdf atau png.');
  }

  const buffer = await design.buildTemplatePdf({
    title: 'Template Desain Tiket',
    orientation,
  });
  res.setHeader('Content-Type', 'application/pdf');
  res.setHeader(
    'Content-Disposition',
    `attachment; filename="template-desain-tiket-${suffix}.pdf"`,
  );
  return res.status(200).send(buffer);
});

module.exports = {
  getEventTicketDesign,
  saveTicketDesign,
  deleteTicketDesign,
  downloadTemplate,
  presentDesign,
};
