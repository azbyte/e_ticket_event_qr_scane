const test = require('node:test');
const assert = require('node:assert/strict');

// Unit test murni: koneksi database tidak pernah dipakai. Variabel ini hanya
// memenuhi validasi startup `config/env.js` sehingga `require` controller tidak
// berhenti dengan "Missing required environment variables".
process.env.NODE_ENV = 'test';
process.env.DATABASE_URL = 'postgresql://tester:secret@127.0.0.1:5432/e_ticket_test';
process.env.JWT_SECRET = 'test-only-jwt-secret';
process.env.TICKET_TOKEN_SECRET = 'test-only-ticket-token-secret';

const db = require('../src/config/db');

const EVENT_ID = '11111111-1111-4111-8111-111111111111';
const OWNER_ID = '22222222-2222-4222-8222-222222222222';
const STAFF_EXPORT_ID = '33333333-3333-4333-8333-333333333333';
const STAFF_NO_EXPORT_ID = '44444444-4444-4444-8444-444444444444';

const fakeQuery = async (sql, params = []) => {
  const norm = sql.replace(/\s+/g, ' ');

  if (norm.includes('FROM events WHERE id = $1')) {
    if (params[0] === EVENT_ID) {
      return [{ id: EVENT_ID, created_by: OWNER_ID, status: 'PUBLISHED' }];
    }
    return [];
  }

  if (norm.includes('FROM event_members WHERE event_id = $1 AND user_id = $2')) {
    if (params[1] === STAFF_EXPORT_ID) {
      return [{ id: 'mem-exp-01', event_id: EVENT_ID, user_id: STAFF_EXPORT_ID }];
    }
    if (params[1] === STAFF_NO_EXPORT_ID) {
      return [{ id: 'mem-exp-02', event_id: EVENT_ID, user_id: STAFF_NO_EXPORT_ID }];
    }
    return [];
  }

  if (norm.includes('FROM event_member_permissions WHERE event_member_id = $1')) {
    if (params[0] === 'mem-exp-01') {
      return [{ permission: 'EXPORT_PARTICIPANTS' }];
    }
    return [{ permission: 'VIEW_PARTICIPANTS' }];
  }

  if (norm.includes('event_attendees') || norm.includes('FROM attendees a')) {
    return [
      {
        attendee_id: 'att-01',
        attendee_order_item_id: 'oi-01',
        attendee_name: '=1+1 Dangerous Name', // Test formula injection
        attendee_email: '@danger@example.com', // Test formula injection
        attendee_phone: '081234567890',
        organization: 'Komunitas Tech',
        custom_fields: {},
        ticket_type_name: 'VIP Pass, Special', // Test comma escaping
        ticket_id: 'tkt-01',
        ticket_code: 'TK-001',
        ticket_status: 'active',
        purchased_at: new Date('2026-10-01T10:00:00Z'),
        used_at: null,
        checked_in_at: null,
        order_id: 'ord-01',
        order_number: 'ORD-101',
        order_status: 'PAID',
        payment_status: 'PAID',
      },
      {
        attendee_id: 'att-02',
        attendee_order_item_id: 'oi-02',
        attendee_name: 'Dewi "Star" Lestari', // Test quote escaping
        attendee_email: 'dewi@example.com',
        attendee_phone: '081234567891',
        organization: null,
        custom_fields: {},
        ticket_type_name: 'Regular Pass',
        ticket_id: 'tkt-02',
        ticket_code: 'TK-002',
        ticket_status: 'active',
        purchased_at: new Date('2026-10-02T10:00:00Z'),
        used_at: null,
        checked_in_at: null,
        order_id: 'ord-02',
        order_number: 'ORD-102',
        order_status: 'PAID',
        payment_status: 'PAID',
      },
    ];
  }

  return [];
};

db.query = fakeQuery;
db.getOne = async (sql, params = []) => (await fakeQuery(sql, params))[0] || null;

const { exportEventAttendeesCsv } = require('../src/controllers/checkInController');

const createRes = () => {
  const res = { statusCode: 200, headers: {}, sentData: null };
  res.status = (code) => { res.statusCode = code; return res; };
  res.setHeader = (name, value) => { res.headers[name] = value; return res; };
  res.send = (data) => { res.sentData = data; return res; };
  return res;
};

test('exportEventAttendeesCsv (K3): staff tanpa EXPORT_PARTICIPANTS ditolak dengan 403', async () => {
  const req = {
    user: { id: STAFF_NO_EXPORT_ID, role: 'staff' },
    params: { id: EVENT_ID },
  };
  const res = createRes();

  await assert.rejects(
    async () => {
      await exportEventAttendeesCsv(req, res);
    },
    (err) => {
      assert.equal(err.statusCode, 403);
      assert.match(err.message, /permission/i);
      return true;
    }
  );
});

test('exportEventAttendeesCsv (K2 & K5): format CSV benar, mencegah formula injection dan escaping koma/kutip', async () => {
  const req = {
    user: { id: OWNER_ID, role: 'organizer' },
    params: { id: EVENT_ID },
  };
  const res = createRes();

  await exportEventAttendeesCsv(req, res);

  assert.equal(res.statusCode, 200);
  assert.equal(res.headers['Content-Type'], 'text/csv; charset=utf-8');
  assert.match(res.headers['Content-Disposition'], /attachment; filename="attendees-/);

  const csv = res.sentData;
  assert.ok(csv, 'Data CSV harus dikirim');

  const lines = csv.split(/\r?\n/);
  // Header
  assert.equal(lines[0], 'ID,Nama,Email,No_HP,Kategori_Tiket,Kode_Tiket,No_Pesanan,Metode,Status_Tiket,Status_Pembayaran,CheckIn,Waktu_CheckIn');

  // Baris 1: Formula injection '=1+1' harus diawali tanda kutip satu "'"
  assert.ok(lines[1].includes("'=1+1 Dangerous Name"), 'Karakter formula = harus di-escape dengan tanda kutip');
  assert.ok(lines[1].includes("'@danger@example.com"), 'Karakter formula @ harus di-escape dengan tanda kutip');
  // Kategori tiket dengan koma 'VIP Pass, Special' harus dibungkus double quotes
  assert.ok(lines[1].includes('"VIP Pass, Special"'), 'Field dengan koma harus dibungkus quotes');

  // Baris 2: Dewi "Star" Lestari harus di-escape menjadi "Dewi ""Star"" Lestari"
  assert.ok(lines[2].includes('"Dewi ""Star"" Lestari"'), 'Tanda kutip internal harus digandakan');
});
