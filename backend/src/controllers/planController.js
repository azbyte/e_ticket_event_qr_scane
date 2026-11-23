const asyncHandler = require('express-async-handler');
const { query, getOne, pool } = require('../config/db');
const { writeAuditLog } = require('../utils/auditLog');

const PLAN_STATUSES = new Set(['ACTIVE', 'INACTIVE', 'ARCHIVED']);

const toPlanDto = (row, features = []) => ({
  id: row.id,
  name: row.name,
  description: row.description,
  status: String(row.status).toLowerCase(),
  is_free: row.is_free,
  price_monthly: row.price_monthly === null ? null : Number(row.price_monthly),
  price_yearly: row.price_yearly === null ? null : Number(row.price_yearly),
  max_active_events: row.max_active_events,
  max_tickets_per_event: row.max_tickets_per_event,
  max_staff_per_event: row.max_staff_per_event,
  features: Object.fromEntries(features.map((f) => [f.key, f.value])),
  created_at: row.created_at,
  updated_at: row.updated_at,
});

const loadFeaturesByPlan = async (planIds) => {
  if (planIds.length === 0) return {};
  const rows = await query(
    'SELECT plan_id, key, value FROM plan_features WHERE plan_id = ANY($1::uuid[]) ORDER BY key',
    [planIds]
  );
  const map = {};
  for (const row of rows) {
    if (!map[row.plan_id]) map[row.plan_id] = [];
    map[row.plan_id].push(row);
  }
  return map;
};

const listPlans = asyncHandler(async (req, res) => {
  const rows = await query(
    "SELECT * FROM plans WHERE status = 'ACTIVE' ORDER BY price_monthly NULLS FIRST, name"
  );
  const features = await loadFeaturesByPlan(rows.map((r) => r.id));
  res.json({
    success: true,

    count: rows.length,
    plans: rows.map((row) => toPlanDto(row, features[row.id] || [])),
  });
});

const listAllPlans = asyncHandler(async (req, res) => {
  const status = req.query.status ? String(req.query.status).toUpperCase() : null;
  if (status && !PLAN_STATUSES.has(status)) {
    res.status(400);
    throw new Error('Status paket tidak valid');
  }
  const rows = status
    ? await query('SELECT * FROM plans WHERE status = $1 ORDER BY name', [status])
    : await query('SELECT * FROM plans ORDER BY name');
  const features = await loadFeaturesByPlan(rows.map((r) => r.id));
  res.json({
    success: true,
    count: rows.length,
    plans: rows.map((row) => toPlanDto(row, features[row.id] || [])),
  });
});

const getPlan = asyncHandler(async (req, res) => {
  const row = await getOne('SELECT * FROM plans WHERE id = $1', [req.params.id]);
  if (!row) {
    res.status(404);
    throw new Error('Paket tidak ditemukan');
  }
  const features = await loadFeaturesByPlan([row.id]);
  res.json({ success: true, plan: toPlanDto(row, features[row.id] || []) });
});

const validatePlanPayload = (body, { partial = false } = {}) => {
  const errors = [];
  const has = (field) => body[field] !== undefined;

  if (!partial || has('name')) {
    if (typeof body.name !== 'string' || body.name.trim().length < 2) {
      errors.push('Nama paket wajib diisi minimal 2 karakter');
    }
  }
  if (has('status') && !PLAN_STATUSES.has(String(body.status).toUpperCase())) {
    errors.push('Status paket tidak valid');
  }
  for (const field of ['priceMonthly', 'priceYearly']) {
    if (has(field) && body[field] !== null
      && (!Number.isFinite(Number(body[field])) || Number(body[field]) < 0)) {
      errors.push(`${field} harus berupa angka >= 0`);
    }
  }
  for (const field of ['maxActiveEvents', 'maxTicketsPerEvent', 'maxStaffPerEvent']) {
    if (has(field) && body[field] !== null
      && (!Number.isInteger(Number(body[field])) || Number(body[field]) < 1)) {
      errors.push(`${field} harus berupa bilangan bulat >= 1 atau null`);
    }
  }
  if (has('features') && body.features !== null
    && (typeof body.features !== 'object' || Array.isArray(body.features))) {
    errors.push('features harus berupa objek key-value');
  }
  return errors;
};


const syncFeatures = async (client, planId, features) => {
  await client.query('DELETE FROM plan_features WHERE plan_id = $1', [planId]);
  for (const [key, value] of Object.entries(features || {})) {
    await client.query(
      `INSERT INTO plan_features (id, plan_id, key, value, created_at)
       VALUES (gen_random_uuid(), $1, $2, $3::jsonb, NOW())`,
      [planId, String(key).slice(0, 100), JSON.stringify(value)]
    );
  }
};
const createPlan = asyncHandler(async (req, res) => {
  const errors = validatePlanPayload(req.body);
  if (errors.length) {
    res.status(400);
    throw new Error(errors.join('; '));
  }
  const duplicate = await getOne('SELECT id FROM plans WHERE name = $1', [req.body.name.trim()]);
  if (duplicate) {
    res.status(409);
    throw new Error('Nama paket sudah digunakan');
  }

  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    const inserted = await client.query(
      `INSERT INTO plans
         (id, name, description, status, is_free, price_monthly, price_yearly,
          max_active_events, max_tickets_per_event, max_staff_per_event, created_at, updated_at)
       VALUES (gen_random_uuid(), $1, $2, $3, $4, $5, $6, $7, $8, $9, NOW(), NOW())
       RETURNING *`,
      [
        req.body.name.trim(),
        req.body.description || null,
        String(req.body.status || 'ACTIVE').toUpperCase(),
        Boolean(req.body.isFree),
        req.body.priceMonthly === undefined ? null : req.body.priceMonthly,
        req.body.priceYearly === undefined ? null : req.body.priceYearly,
        req.body.maxActiveEvents === undefined ? null : req.body.maxActiveEvents,
        req.body.maxTicketsPerEvent === undefined ? null : req.body.maxTicketsPerEvent,
        req.body.maxStaffPerEvent === undefined ? null : req.body.maxStaffPerEvent,
      ]
    );
    const planId = inserted.rows[0].id;
    await syncFeatures(client, planId, req.body.features);
    await client.query('COMMIT');
    await writeAuditLog({
      actor: req.user,
      action: 'CREATE_PACKAGE',
      entityType: 'PACKAGE',
      entityId: planId,
      details: `Package created: ${req.body.name}`,
      metadata: { planId, name: req.body.name },
    });
    const features = await loadFeaturesByPlan([planId]);
    res.status(201).json({
      success: true,
      plan: toPlanDto(inserted.rows[0], features[planId] || []),
    });
  } catch (error) {
    try { await client.query('ROLLBACK'); } catch (_) { /* sudah berakhir */ }
    throw error;
  } finally {
    client.release();
  }
});

const PLAN_COLUMNS = [
  ['name', 'name', (v) => v.trim()],
  ['description', 'description', (v) => v],
  ['status', 'status', (v) => String(v).toUpperCase()],
  ['isFree', 'is_free', Boolean],
  ['priceMonthly', 'price_monthly', (v) => v],
  ['priceYearly', 'price_yearly', (v) => v],
  ['maxActiveEvents', 'max_active_events', (v) => v],
  ['maxTicketsPerEvent', 'max_tickets_per_event', (v) => v],
  ['maxStaffPerEvent', 'max_staff_per_event', (v) => v],
];

const updatePlan = asyncHandler(async (req, res) => {
  const existing = await getOne('SELECT * FROM plans WHERE id = $1', [req.params.id]);
  if (!existing) {
    res.status(404);
    throw new Error('Paket tidak ditemukan');
  }
  const errors = validatePlanPayload(req.body, { partial: true });
  if (errors.length) {
    res.status(400);
    throw new Error(errors.join('; '));
  }
  if (req.body.name && req.body.name.trim() !== existing.name) {
    const duplicate = await getOne('SELECT id FROM plans WHERE name = $1 AND id <> $2', [
      req.body.name.trim(), existing.id,
    ]);
    if (duplicate) {
      res.status(409);
      throw new Error('Nama paket sudah digunakan');
    }
  }

  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    const setParts = [];
    const params = [];
    let index = 1;
    for (const [field, column, transform] of PLAN_COLUMNS) {
      if (req.body[field] === undefined) continue;
      setParts.push(`${column} = $${index}`);
      params.push(transform(req.body[field]));
      index += 1;
    }
    if (setParts.length > 0) {
      setParts.push('updated_at = NOW()');
      params.push(existing.id);
      await client.query(`UPDATE plans SET ${setParts.join(', ')} WHERE id = $${index}`, params);
    }
    if (req.body.features !== undefined) {
      await syncFeatures(client, existing.id, req.body.features);
    }
    await client.query('COMMIT');
    await writeAuditLog({
      actor: req.user,
      action: 'UPDATE_PACKAGE',
      entityType: 'PACKAGE',
      entityId: existing.id,
      details: `Package updated: ${existing.name}`,
      metadata: { planId: existing.id, updates: req.body },
    });
  } catch (error) {
    try { await client.query('ROLLBACK'); } catch (_) { /* sudah berakhir */ }
    throw error;
  } finally {
    client.release();
  }

  const row = await getOne('SELECT * FROM plans WHERE id = $1', [existing.id]);
  const features = await loadFeaturesByPlan([row.id]);
  res.json({ success: true, plan: toPlanDto(row, features[row.id] || []) });
});

const deletePlan = asyncHandler(async (req, res) => {
  const existing = await getOne('SELECT id FROM plans WHERE id = $1', [req.params.id]);
  if (!existing) {
    res.status(404);

    throw new Error('Paket tidak ditemukan');
  }
  const used = await getOne('SELECT id FROM subscriptions WHERE plan_id = $1 LIMIT 1', [existing.id]);
  if (used) {
    res.status(409);
    throw new Error('Paket sedang dipakai langganan; ubah status menjadi INACTIVE/ARCHIVED');
  }
  await query('DELETE FROM plans WHERE id = $1', [existing.id]);
  res.json({ success: true, message: 'Paket dihapus' });
});


module.exports = {
  validatePlanPayload,
  toPlanDto,
  listPlans,
  listAllPlans,
  getPlan,
  createPlan,
  updatePlan,
  deletePlan,
};

