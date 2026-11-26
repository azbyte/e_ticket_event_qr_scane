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

const presentDesign = (req, raw) => {
  const normalized = design.normalizeDesign(raw);
  if (!normalized) return null;
  return { ...normalized, url: absoluteUrl(req, normalized.file_path) };
};

const loadTicketType = async (eventId, ticketTypeId) => {
  if (!ticketTypeId) return null;
  return getOne(
    'SELECT id, event_id, name, ticket_design FROM ticket_types WHERE id = $1 AND event_id = $2',
    [ticketTypeId, eventId],
  );
};

const getEventTicketDesign = asyncHandler(async (req, res) => {
  const event = await getEventForOwner(req.params.eventId, req.user);
  const ticketTypes = await query(
    'SELECT id, name, ticket_design FROM ticket_types WHERE event_id = $1 ORDER BY name ASC',
    [event.id],
  );
  res.json({
    success: true,
    event_design: presentDesign(req, event.ticket_design),
    ticket_types: ticketTypes.map((row) => ({
      id: row.id,
      name: row.name,
      design: presentDesign(req, row.ticket_design),
    })),
    default_layout: {
      qr: design.DEFAULT_QR,
      info: design.DEFAULT_INFO,
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

  const { errors, value } = design.validateUploadPayload(req.body);
  if (errors.length > 0) {
    res.status(400);
    throw new Error(errors.join(' '));
  }

  const { filePath } = await design.saveDesignImage({
    eventId: event.id,
    buffer: value.buffer,
    contentType: value.contentType,
  });

  const previousRaw = scope === 'event' ? event.ticket_design : ticketType.ticket_design;
  const previous = design.normalizeDesign(previousRaw);
  const stored = {
    source: 'upload',
    template: typeof req.body?.template === 'string' ? req.body.template : 'custom',
    file_path: filePath,
    content_type: value.contentType,
    qr: value.qr,
    info: value.info,
    updated_at: new Date().toISOString(),
  };

  if (scope === 'event') {
    await query('UPDATE events SET ticket_design = $1::jsonb WHERE id = $2', [
      JSON.stringify(stored),
      event.id,
    ]);
  } else {
    await query('UPDATE ticket_types SET ticket_design = $1::jsonb WHERE id = $2', [
      JSON.stringify(stored),
      ticketType.id,
    ]);
  }

  // File lama dihapus setelah referensi baru tersimpan agar tidak ada desain
  // yang menunjuk file hilang bila penyimpanan gagal.
  if (previous?.file_path && previous.file_path !== filePath) {
    await design.removeDesignFile(previous.file_path).catch((error) => {
      logger.warn('ticket_design_cleanup_failed', { error: error.message });
    });
  }

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
    await query('UPDATE events SET ticket_design = NULL WHERE id = $1', [event.id]);
    if (previous?.file_path) await design.removeDesignFile(previous.file_path);
    return res.json({ success: true, scope, design: null });
  }

  const ticketType = await loadTicketType(event.id, req.query.ticket_type_id);
  if (!ticketType) {
    res.status(404);
    throw new Error('Kategori tiket tidak ditemukan pada event ini.');
  }
  const previous = design.normalizeDesign(ticketType.ticket_design);
  await query('UPDATE ticket_types SET ticket_design = NULL WHERE id = $1', [
    ticketType.id,
  ]);
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

  if (format === 'png') {
    const pngPath = design.templatePathFor('png');
    if (!pngPath) {
      res.status(503);
      throw new Error('Template PNG belum tersedia di server.');
    }
    res.setHeader('Content-Type', 'image/png');
    res.setHeader(
      'Content-Disposition',
      'attachment; filename="template-desain-tiket.png"',
    );
    return res.sendFile(pngPath);
  }
  if (format !== 'pdf') {
    res.status(400);
    throw new Error('Format template harus pdf atau png.');
  }

  const buffer = await design.buildTemplatePdf({
    title: 'Template Desain Tiket',
  });
  res.setHeader('Content-Type', 'application/pdf');
  res.setHeader(
    'Content-Disposition',
    'attachment; filename="template-desain-tiket.pdf"',
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
