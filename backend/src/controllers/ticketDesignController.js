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
 * Desain efektif = desain tersimpan (bila ada) atau placeholder orientasi.
 * Orientasi selalu dikirim agar Store/UI dapat menampilkan pilihan aktif
 * walau Organizer belum mengunggah file desain.
 */
const presentDesign = (req, raw, orientationFallback) => {
  const normalized = design.normalizeDesign(raw);
  const orientation = design.orientationOrDefault(
    normalized?.orientation || orientationFallback,
  );
  if (!normalized) {
    return {
      file_path: null,
      content_type: null,
      source: 'none',
      template: 'default',
      orientation,
      width: null,
      height: null,
      qr: design.DEFAULT_QR_BY_ORIENTATION[orientation],
      info: design.DEFAULT_INFO_BY_ORIENTATION[orientation],
      url: null,
    };
  }
  return {
    ...normalized,
    orientation,
    url: absoluteUrl(req, normalized.file_path),
  };
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
      qr: design.DEFAULT_QR_BY_ORIENTATION[eventOrientation],
      info: design.DEFAULT_INFO_BY_ORIENTATION[eventOrientation],
      qr_by_orientation: design.DEFAULT_QR_BY_ORIENTATION,
      info_by_orientation: design.DEFAULT_INFO_BY_ORIENTATION,
      spec: design.ORIENTATION_SPEC,
    },
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
    || (typeof req.body?.image_base64 !== 'string' && req.body?.orientation != null);

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
      qr: design.DEFAULT_QR_BY_ORIENTATION[orientation],
      info: design.DEFAULT_INFO_BY_ORIENTATION[orientation],
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
        url: stored.file_path ? absoluteUrl(req, stored.file_path) : null,
      },
    });
  }

  const { errors, value } = design.validateUploadPayload(req.body);
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
    qr: value.qr,
    info: value.info,
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
    design: { ...stored, url: absoluteUrl(req, stored.file_path) },
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
