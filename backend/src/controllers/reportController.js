const asyncHandler = require('express-async-handler');
const { createHash, randomBytes } = require('node:crypto');
const { query, getOne } = require('../config/db');

const VALID_STATUSES = new Set(['OPEN', 'IN_PROGRESS', 'WAITING_FOR_USER', 'RESOLVED', 'CLOSED']);
const VALID_PRIORITIES = new Set(['LOW', 'MEDIUM', 'HIGH', 'URGENT']);
const VALID_CATEGORIES = new Set([
  'EVENT', 'PAYMENT', 'E_TICKET', 'REGISTRATION', 'ACCOUNT',
  'SUBSCRIPTION', 'TRANSACTION', 'SCANNER', 'OTHER',
]);

const generateTicketNumber = () => `RPT-${Date.now()}-${randomBytes(4).toString('hex')}`;
const generateStatusToken = () => createHash('sha256').update(randomBytes(32).toString('base64url')).digest('hex');

const findReportForUser = async (identifier, user) => {
  const report = await getOne(
    `SELECT * FROM support_reports
     WHERE id::text = $1 OR ticket_number = $1
     LIMIT 1`,
    [String(identifier)]
  );
  if (!report) return null;
  const canView = user.role === 'admin'
    || report.reporter_id === user.id
    || report.assigned_to_id === user.id;
  return canView ? report : null;
};

const assertCanManageReport = (report, user) => {
  if (user.role === 'admin') return;
  if (report.assigned_to_id === user.id) return;
  const err = new Error('Anda tidak memiliki akses untuk mengubah laporan ini');
  err.statusCode = 403;
  throw err;
};

const addReportActivity = async ({ reportId, user, visibility, action, message }) => {
  await query(
    `INSERT INTO support_report_activities
       (id, report_id, author_id, author_name, visibility, action, message, created_at)
     VALUES (gen_random_uuid(), $1, $2, $3, $4, $5, $6, NOW())`,
    [reportId, user.id, user.name || user.email, visibility, action, message]
  );
};

const listReports = asyncHandler(async (req, res) => {
  const user = req.user;
  if (!user) {
    res.status(401);
    throw new Error('Authentication required');
  }

  const where = [];
  const params = [];
  let paramIndex = 1;
  const add = (cond, val) => { where.push(cond); params.push(val); paramIndex += 1; };

  if (user.role !== 'admin') {
    add(`reporter_id = $${paramIndex}`, user.id);
  }
  if (req.query.status) {
    const s = String(req.query.status).toUpperCase();
    if (!VALID_STATUSES.has(s)) {
      res.status(400);
      throw new Error('Status tidak valid');
    }
    add(`status = $${paramIndex}`, s);
  }
  if (req.query.category) {
    const c = String(req.query.category).toUpperCase();
    if (!VALID_CATEGORIES.has(c)) {
      res.status(400);
      throw new Error('Kategori tidak valid');
    }
    add(`category = $${paramIndex}`, c);
  }
  if (req.query.priority) {
    const p = String(req.query.priority).toUpperCase();
    if (!VALID_PRIORITIES.has(p)) {
      res.status(400);
      throw new Error('Prioritas tidak valid');
    }
    add(`priority = $${paramIndex}`, p);
  }
  if (req.query.search) {
    const q = `%${String(req.query.search).trim()}%`;
    add(`(subject ILIKE $${paramIndex} OR ticket_number ILIKE $${paramIndex} OR description ILIKE $${paramIndex})`, q);
  }
  const querySql = `SELECT id, ticket_number, status_token_hash, reporter_id, assigned_to_id, order_id,
            contact_email, order_reference, category, subject, description, status,
            priority, created_at, updated_at, resolved_at
           FROM support_reports ${where.length ? `WHERE ${where.join(' AND ')}` : ''} ORDER BY created_at DESC`;
  const rows = await query(querySql, params);

  res.json({ success: true, count: rows.length, reports: rows, data: rows });
});

const createReport = asyncHandler(async (req, res) => {
  const { contact_email, category, subject, description, order_reference } = req.body;
  const user = req.user;

  if (!category || !VALID_CATEGORIES.has(String(category).toUpperCase())) {
    res.status(400);
    throw new Error('Kategori tidak valid');
  }
  if (!subject || String(subject).trim().length === 0) {
    res.status(400);
    throw new Error('Subjek laporan diperlukan');
  }
  if (!description || String(description).trim().length === 0) {
    res.status(400);
    throw new Error('Deskripsi laporan diperlukan');
  }
  const priority = String(req.body.priority || 'MEDIUM').toUpperCase();
  if (!VALID_PRIORITIES.has(priority)) {
    res.status(400);
    throw new Error('Prioritas tidak valid');
  }

  const inserted = await query(
    `INSERT INTO support_reports
       (id, ticket_number, status_token_hash, reporter_id, contact_email, order_reference,
        category, subject, description, priority, status)
     VALUES (gen_random_uuid(), $1, $2, $3, $4, $5, $6, $7, $8, $9, 'OPEN')
     RETURNING *`,
    [
      generateTicketNumber(),
      generateStatusToken(),
      user.id,
      contact_email || user.email || null,
      order_reference || null,
      String(category).toUpperCase(),
      String(subject).trim(),
      String(description).trim(),
      priority,
    ]
  );
  const report = inserted[0];
  await addReportActivity({
    reportId: report.id,
    user,
    visibility: 'PUBLIC',
    action: 'Laporan Dibuat',
    message: 'Laporan dukungan berhasil dibuat',
  });

  res.status(201).json({ success: true, report, data: report });
});
const getReport = asyncHandler(async (req, res) => {
  const user = req.user;
  const report = await findReportForUser(req.params.id, user);
  if (!report) {
    res.status(404);
    throw new Error('Laporan tidak ditemukan');
  }
  const canSeeInternal = user.role === 'admin' || report.assigned_to_id === user.id;
  const activities = await query(
    `SELECT id, report_id, author_id, author_name, visibility, action, message, created_at
     FROM support_report_activities
     WHERE report_id = $1 ${canSeeInternal ? '' : "AND visibility = 'PUBLIC'"}
     ORDER BY created_at ASC`,
    [report.id]
  );
  res.json({ success: true, report, activities, data: report });
});

const updateReportStatus = asyncHandler(async (req, res) => {
  const user = req.user;
  const s = String(req.body.status || '').toUpperCase();
  if (!VALID_STATUSES.has(s)) {
    res.status(400);
    throw new Error('Status tidak valid');
  }
  const report = await findReportForUser(req.params.id, user);
  if (!report) {
    res.status(404);
    throw new Error('Laporan tidak ditemukan');
  }
  assertCanManageReport(report, user);

  const resolvedAt = ['RESOLVED', 'CLOSED'].includes(s) ? new Date().toISOString() : null;
  const updated = await query(
    `UPDATE support_reports
     SET status = $1,
         resolved_at = $2,
         updated_at = NOW()
     WHERE id = $3
     RETURNING *`,
    [s, resolvedAt, report.id]
  );
  const next = updated[0];
  await addReportActivity({
    reportId: report.id,
    user,
    visibility: 'PUBLIC',
    action: 'Status Diubah',
    message: String(req.body.note || `Status diubah menjadi ${s}`).trim(),
  });
  res.json({ success: true, report: next, data: next });
});

const updateReportPriority = asyncHandler(async (req, res) => {
  const user = req.user;
  const p = String(req.body.priority || '').toUpperCase();
  if (!VALID_PRIORITIES.has(p)) {
    res.status(400);
    throw new Error('Prioritas tidak valid');
  }
  const report = await findReportForUser(req.params.id, user);
  if (!report) {
    res.status(404);
    throw new Error('Laporan tidak ditemukan');
  }
  assertCanManageReport(report, user);
  const updated = await query(
    `UPDATE support_reports SET priority = $1, updated_at = NOW() WHERE id = $2 RETURNING *`,
    [p, report.id]
  );
  const next = updated[0];
  await addReportActivity({
    reportId: report.id,
    user,
    visibility: 'PUBLIC',
    action: 'Prioritas Diubah',
    message: `Prioritas diubah menjadi ${p}`,
  });
  res.json({ success: true, report: next, data: next });
});

const addReply = asyncHandler(async (req, res) => {
  const user = req.user;
  const { message, sender_name } = req.body;
  if (!message || String(message).trim().length === 0) {
    res.status(400);
    throw new Error('Pesan balasan diperlukan');
  }
  const report = await findReportForUser(req.params.id, user);
  if (!report) {
    res.status(404);
    throw new Error('Laporan tidak ditemukan');
  }

  await addReportActivity({
    reportId: report.id,
    user,
    visibility: 'PUBLIC',
    action: 'Balasan Terkirim',
    message: String(message).trim(),
  });
  await query('UPDATE support_reports SET updated_at = NOW() WHERE id = $1', [report.id]);
  res.json({ success: true, message: 'Balasan terkirim', author_name: sender_name || user.name || user.email });
});

const addInternalNote = asyncHandler(async (req, res) => {
  const user = req.user;
  const { note } = req.body;
  if (!note || String(note).trim().length === 0) {
    res.status(400);
    throw new Error('Catatan internal diperlukan');
  }
  const report = await findReportForUser(req.params.id, user);
  if (!report) {
    res.status(404);
    throw new Error('Laporan tidak ditemukan');
  }
  assertCanManageReport(report, user);

  await addReportActivity({
    reportId: report.id,
    user,
    visibility: 'INTERNAL',
    action: 'Catatan Internal Ditambahkan',
    message: String(note).trim(),
  });
  await query('UPDATE support_reports SET updated_at = NOW() WHERE id = $1', [report.id]);
  res.json({ success: true, message: 'Catatan internal ditambahkan' });
});

module.exports = {
  listReports,
  createReport,
  getReport,
  updateReportStatus,
  updateReportPriority,
  addReply,
  addInternalNote,
};
