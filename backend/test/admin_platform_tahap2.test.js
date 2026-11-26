const test = require('node:test');
const assert = require('node:assert/strict');
const db = require('../src/config/db');

const ADMIN_ID = '11111111-1111-4111-8111-111111111111';
const USER_ID = '22222222-2222-4222-8222-222222222222';

let auditLogsWritten = [];
let settingHistoryWritten = [];

const fakeQuery = async (sql, params = []) => {
  const norm = sql.replace(/\s+/g, ' ');

  if (norm.includes('INSERT INTO audit_logs')) {
    const row = {
      id: 'aud-test-01',
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
      name: 'Nakal Organizer',
      email: 'nakal@example.com',
      role: 'organizer',
      disabled_at: params[0],
    }];
  }

  if (norm.includes('SELECT') && norm.includes('FROM audit_logs')) {
    if (norm.includes('COUNT(*)')) {
      return [{ total: auditLogsWritten.length }];
    }
    return auditLogsWritten;
  }

  if (norm.includes('INSERT INTO platform_settings')) {
    return [{
      key: params[0],
      value: JSON.parse(params[1]),
      updated_at: new Date(),
    }];
  }

  if (norm.includes('INSERT INTO platform_setting_history')) {
    settingHistoryWritten.push({
      key: params[0],
      oldValue: params[1],
      newValue: params[2],
      changedById: params[3],
      reason: params[4],
    });
    return [];
  }

  if (norm.includes('FROM platform_settings WHERE key = $1')) {
    return [{ key: params[0], value: 5.0, updated_at: new Date() }];
  }

  if (norm.includes('FROM platform_settings ORDER BY key')) {
    return [
      { key: 'ticketCommissionRate', value: 5.0, updated_at: new Date() },
      { key: 'fixedServiceFee', value: 2500, updated_at: new Date() },
    ];
  }

  if (norm.includes('FROM platform_setting_history')) {
    return [];
  }

  if (norm.includes('FROM events GROUP BY status')) {
    return [
      { status: 'PUBLISHED', count: '10' },
      { status: 'PENDING_REVIEW', count: '3' },
      { status: 'SUSPENDED', count: '1' },
    ];
  }

  if (norm.includes('COUNT(DISTINCT created_by)')) {
    return [{ count: '5' }];
  }

  if (norm.includes('FROM event_orders')) {
    return [{ count: '25' }];
  }

  if (norm.includes('FROM tickets')) {
    return [{ count: '40' }];
  }

  if (norm.includes('FROM attendees')) {
    return [{ count: '40' }];
  }

  if (norm.includes('FROM check_ins')) {
    return [{ count: '15' }];
  }

  if (norm.includes('platform_transactions') && norm.includes('SUM(gross_amount)')) {
    return [{
      gross_amount: '5000000',
      commission_amount: '250000',
      service_fee: '62500',
      platform_revenue: '312500',
      organizer_net_amount: '4687500',
    }];
  }

  if (norm.includes('DATE_TRUNC')) {
    return [];
  }

  if (norm.includes('FROM subscriptions s')) {
    if (norm.includes('COUNT(*)')) return [{ total: 1 }];
    return [{
      id: 'sub-01',
      organizer_id: USER_ID,
      organizer_name: 'Tech Org',
      organizer_email: 'tech@example.com',
      plan_id: 'plan-01',
      plan_name: 'Professional',
      status: 'active',
      billing_interval: 'monthly',
      starts_at: new Date(),
      ends_at: new Date(),
      auto_renew: true,
      created_at: new Date(),
    }];
  }

  if (norm.includes('moderate_event')) {
    return [{ moderate_event: params[0] }];
  }

  if (norm.includes('FROM events e LEFT JOIN event_categories')) {
    return [{
      id: params[0],
      title: 'Event Moderated',
      status: 'SUSPENDED',
      event_format: 'VENUE',
      category_name: 'Music',
    }];
  }

  return [];
};

db.query = fakeQuery;
db.getOne = async (sql, params = []) => (await fakeQuery(sql, params))[0] || null;

const { updateAccountStatus } = require('../src/controllers/adminController');
const { listAuditLogs } = require('../src/controllers/auditLogController');
const { listPlatformSettings, updatePlatformSetting } = require('../src/controllers/platformSettingsController');
const { getAdminOverview } = require('../src/controllers/adminOverviewController');
const { listAdminSubscriptions } = require('../src/controllers/subscriptionController');
const { moderateEvent } = require('../src/controllers/eventMetricsController');

const createRes = () => {
  const res = { statusCode: 200, body: null };
  res.status = (code) => { res.statusCode = code; return res; };
  res.json = (body) => { res.body = body; return res; };
  return res;
};

test('updateAccountStatus: menolak suspend akun tanpa alasan atau alasan kurang dari 5 karakter (400)', async () => {
  const reqNoReason = {
    user: { id: ADMIN_ID, role: 'admin', email: 'admin@example.com' },
    params: { id: USER_ID },
    body: { disabled: true },
  };
  const res = createRes();

  await assert.rejects(
    async () => {
      await updateAccountStatus(reqNoReason, res);
    },
    (err) => {
      assert.equal(res.statusCode, 400);
      assert.match(err.message, /alasan penangguhan akun wajib diisi minimal 5 karakter/i);
      return true;
    }
  );

  const reqShortReason = {
    user: { id: ADMIN_ID, role: 'admin', email: 'admin@example.com' },
    params: { id: USER_ID },
    body: { disabled: true, reason: 'bad' },
  };
  await assert.rejects(
    async () => {
      await updateAccountStatus(reqShortReason, res);
    },
    (err) => {
      assert.equal(res.statusCode, 400);
      return true;
    }
  );
});

test('updateAccountStatus: suspend valid mencatat audit log dengan action SUSPEND_ACCOUNT dan reason', async () => {
  auditLogsWritten = [];
  const req = {
    user: { id: ADMIN_ID, role: 'admin', email: 'admin@example.com' },
    params: { id: USER_ID },
    body: { disabled: true, reason: 'Pelanggaran duplikasi tiket berulang' },
  };
  const res = createRes();

  await updateAccountStatus(req, res);

  assert.equal(res.statusCode, 200);
  assert.equal(res.body.success, true);
  assert.ok(res.body.user.disabled_at, 'disabled_at harus terisi');

  assert.equal(auditLogsWritten.length, 1);
  assert.equal(auditLogsWritten[0].action, 'SUSPEND_ACCOUNT');
  assert.equal(auditLogsWritten[0].entity_type, 'ACCOUNT');
  assert.equal(auditLogsWritten[0].entity_id, USER_ID);
  assert.equal(auditLogsWritten[0].reason, 'Pelanggaran duplikasi tiket berulang');
});

test('updatePlatformSetting: update setting mencatat history dan audit log', async () => {
  auditLogsWritten = [];
  settingHistoryWritten = [];
  const req = {
    user: { id: ADMIN_ID, role: 'admin', email: 'admin@example.com' },
    params: { key: 'ticketCommissionRate' },
    body: { value: 7.5, reason: 'Penyesuaian kuartal baru' },
  };
  const res = createRes();

  await updatePlatformSetting(req, res);

  assert.equal(res.statusCode, 200);
  assert.equal(res.body.success, true);

  assert.equal(settingHistoryWritten.length, 1);
  assert.equal(settingHistoryWritten[0].key, 'ticketCommissionRate');
  assert.equal(settingHistoryWritten[0].reason, 'Penyesuaian kuartal baru');

  assert.equal(auditLogsWritten.length, 1);
  assert.equal(auditLogsWritten[0].action, 'UPDATE_SETTING');
  assert.equal(auditLogsWritten[0].entity_id, 'ticketCommissionRate');
});

test('getAdminOverview: mengembalikan metrik event, pengguna, dan finansial dari database', async () => {
  const req = {
    user: { id: ADMIN_ID, role: 'admin' },
    query: {},
  };
  const res = createRes();

  await getAdminOverview(req, res);

  assert.equal(res.statusCode, 200);
  assert.equal(res.body.success, true);

  const overview = res.body.overview;
  assert.equal(overview.events.total, 14);
  assert.equal(overview.events.published, 10);
  assert.equal(overview.events.suspended, 1);
  assert.equal(overview.active_organizers, 5);
  assert.equal(overview.total_orders, 25);
  assert.equal(overview.financials.gross_amount, 5000000);
  assert.equal(overview.financials.platform_revenue, 312500);

  // Kontrak yang dibaca konsol Admin Flutter
  // (`PlatformRevenueSummary.fromOverview`). Bila key ini berubah, dashboard
  // akan kembali menampilkan nol/angka contoh tanpa error — karena itu bentuk
  // respons dijaga di sini.
  assert.equal(typeof overview.tickets_sold, 'number');
  assert.equal(typeof overview.total_participants, 'number');
  assert.equal(typeof overview.total_check_ins, 'number');
  assert.ok('pending_review' in overview.events);
  assert.ok('rejected' in overview.events);
  assert.ok('draft' in overview.events);
  assert.ok(Array.isArray(overview.trends));
  assert.equal(typeof overview.financials.commission_amount, 'number');
});

test('listAdminSubscriptions: mengembalikan daftar langganan platform', async () => {
  const req = {
    user: { id: ADMIN_ID, role: 'admin' },
    query: {},
  };
  const res = createRes();

  await listAdminSubscriptions(req, res);

  assert.equal(res.statusCode, 200);
  assert.equal(res.body.success, true);
  assert.equal(res.body.subscriptions.length, 1);
  assert.equal(res.body.subscriptions[0].plan_name, 'Professional');
});

test('moderateEvent: suspend event mencatat audit log SUSPEND_EVENT', async () => {
  auditLogsWritten = [];
  const req = {
    user: { id: ADMIN_ID, role: 'admin', email: 'admin@example.com' },
    params: { id: 'evt-test-01' },
    body: { status: 'SUSPENDED', note: 'Indikasi penipuan' },
  };
  const res = createRes();

  await moderateEvent(req, res);

  assert.equal(res.statusCode, 200);
  assert.equal(res.body.success, true);
  assert.equal(auditLogsWritten.length, 1);
  assert.equal(auditLogsWritten[0].action, 'SUSPEND_EVENT');
  assert.equal(auditLogsWritten[0].entity_type, 'EVENT');
  assert.equal(auditLogsWritten[0].reason, 'Indikasi penipuan');
});
