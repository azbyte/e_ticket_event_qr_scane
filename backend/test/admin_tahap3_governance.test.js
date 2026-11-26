const test = require('node:test');
const assert = require('node:assert/strict');
const db = require('../src/config/db');

const ADMIN_USER = {
  id: '00000000-0000-4000-8000-000000000001',
  role: 'admin',
  name: 'Super Admin',
  email: 'admin@event.local',
};

const TARGET_USER_ID = '00000000-0000-4000-8000-000000000099';

let auditLogsWritten = [];
let settingHistoryWritten = [];

const fakeQuery = async (sql, params = []) => {
  const norm = sql.replace(/\s+/g, ' ');

  if (norm.includes('INSERT INTO audit_logs')) {
    const row = {
      id: 'aud-tahap3-01',
      actor_id: params[0],
      actor_name: params[1],
      actor_role: params[2],
      action: params[3],
      entity_type: params[4],
      entity_id: params[5],
      reason: params[6],
      details: params[7],
      metadata: params[8] ? JSON.parse(params[8]) : null,
      created_at: new Date(),
    };
    auditLogsWritten.push(row);
    return [row];
  }

  if (norm.includes('UPDATE profiles SET disabled_at')) {
    return [{
      id: params[1],
      name: 'Budi Test',
      email: 'budi@test.com',
      role: 'organizer',
      disabled_at: params[0],
    }];
  }

  if (norm.includes('INSERT INTO platform_setting_history')) {
    const entry = {
      key: params[0],
      oldValue: params[1],
      newValue: params[2],
      changedById: params[3],
      reason: params[4],
    };
    settingHistoryWritten.push(entry);
    return [];
  }

  if (norm.includes('FROM platform_settings WHERE key = $1')) {
    return [{ key: params[0], value: 5000, updated_at: new Date() }];
  }

  if (norm.includes('INSERT INTO platform_settings')) {
    return [{
      key: params[0],
      value: JSON.parse(params[1]),
      updated_at: new Date(),
    }];
  }

  return [];
};

db.query = fakeQuery;
db.getOne = async (sql, params = []) => (await fakeQuery(sql, params))[0] || null;

const { updateAccountStatus } = require('../src/controllers/adminController');
const { updatePlatformSetting } = require('../src/controllers/platformSettingsController');

const createRes = () => {
  const res = { statusCode: 200, body: null };
  res.status = (code) => { res.statusCode = code; return res; };
  res.json = (body) => { res.body = body; return res; };
  return res;
};

test('adminTahap3Governance: suspend akun tanpa alasan ditolak 400', async () => {
  const req = {
    user: ADMIN_USER,
    params: { id: TARGET_USER_ID },
    body: {
      disabled: true,
      reason: '', // Kosong -> ditolak
    },
  };
  const res = createRes();

  await assert.rejects(
    async () => {
      await updateAccountStatus(req, res);
    },
    (err) => {
      assert.equal(res.statusCode, 400);
      assert.match(err.message, /alasan penangguhan akun wajib diisi minimal 5 karakter/i);
      return true;
    }
  );
});

test('adminTahap3Governance: suspend akun dengan alasan valid berhasil dan menulis audit log', async () => {
  auditLogsWritten = [];
  const req = {
    user: ADMIN_USER,
    params: { id: TARGET_USER_ID },
    body: {
      disabled: true,
      reason: 'Investigasi indikasi kecurangan tiket event',
    },
  };
  const res = createRes();

  await updateAccountStatus(req, res);

  assert.equal(res.statusCode, 200);
  assert.equal(res.body.success, true);
  assert.equal(auditLogsWritten.length, 1);
  assert.equal(auditLogsWritten[0].action, 'SUSPEND_ACCOUNT');
  assert.match(auditLogsWritten[0].reason, /Investigasi indikasi/);
});

test('adminTahap3Governance: perubahan setting komisi/fee terlindungi audit dan histori', async () => {
  auditLogsWritten = [];
  settingHistoryWritten = [];
  const req = {
    user: ADMIN_USER,
    params: { key: 'fixed_service_fee' },
    body: {
      value: 5000,
      reason: 'Penetapan nilai Rp 5.000 sesuai keputusan produk C-01',
    },
  };
  const res = createRes();

  await updatePlatformSetting(req, res);

  assert.equal(res.statusCode, 200);
  assert.equal(res.body.success, true);
  assert.equal(settingHistoryWritten.length, 1);
  assert.equal(auditLogsWritten.length, 1);
  assert.equal(auditLogsWritten[0].action, 'UPDATE_SETTING');
});
