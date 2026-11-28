/**
 * Penyimpanan konfigurasi tata letak tiket (mode `layout_only`) pada controller
 * desain tiket.
 *
 * Menguji jalur nyata `PUT /api/events/:id/ticket-design` tanpa database: lapisan
 * `config/db` dan `eventController.getEventForOwner` diganti stub di
 * `require.cache`, sehingga yang diperiksa adalah SQL dan payload yang benar-benar
 * dikirim controller.
 */
process.env.NODE_ENV = 'test';
process.env.DATABASE_URL = 'postgresql://tester:secret@127.0.0.1:5432/e_ticket_test';
process.env.JWT_SECRET = 'test-only-jwt-secret';
process.env.TICKET_TOKEN_SECRET = 'test-only-ticket-token-secret';

const test = require('node:test');
const assert = require('node:assert/strict');

const dbPath = require.resolve('../src/config/db');
const eventControllerPath = require.resolve('../src/controllers/eventController');
const controllerPath = require.resolve('../src/controllers/ticketDesignController');

const state = { calls: [], event: null };

const resetState = (overrides = {}) => {
  Object.assign(state, { calls: [], event: null }, overrides);
};

require.cache[dbPath] = {
  id: dbPath,
  filename: dbPath,
  loaded: true,
  exports: {
    query: async (sql, params) => {
      state.calls.push({ sql, params });
      return [];
    },
    getOne: async (sql, params) => {
      state.calls.push({ sql, params });
      return null;
    },
    pool: { end: async () => {} },
  },
};

require.cache[eventControllerPath] = {
  id: eventControllerPath,
  filename: eventControllerPath,
  loaded: true,
  exports: {
    getEventForOwner: async () => state.event,
  },
};

const controller = require(controllerPath);

/** Response palsu: mencatat status/JSON dan menangkap error asyncHandler. */
const createResponse = () => {
  const res = {
    statusCode: 200,
    body: null,
    status(code) {
      this.statusCode = code;
      return this;
    },
    json(payload) {
      this.body = payload;
      return this;
    },
  };
  return res;
};

const callSave = async (body) => {
  const req = {
    params: { eventId: 'evt-1' },
    body,
    user: { id: 'u-1', role: 'organizer' },
    // `absoluteUrl` memakai req.protocol/req.get('host').
    protocol: 'http',
    get: () => 'localhost:5000',
  };
  const res = createResponse();
  let error = null;
  await controller.saveTicketDesign(req, res, (err) => { error = err; });
  return { res, error };
};

const previousDesign = {
  source: 'upload',
  template: 'custom',
  file_path: '/media/ticket-designs/evt-1/desain.png',
  content_type: 'image/png',
  orientation: 'landscape',
  width: 1684,
  height: 1188,
  layout: {
    version: 2,
    panel_split: 0.558,
    text_width: 0.6,
    title: { x: 0.0445, y: 0.0286, font_size: 50, bold: true },
    ticket_id: { x: 0.0445, y: 0.147, font_size: 30, bold: false },
    instruction: { x: 0.0445, y: 0.2165, font_size: 30, bold: false },
    qr: { x: 0.0595, y: 0.326, size: 0.4231 },
  },
};

test('layout_only menyimpan tata letak tanpa mengunggah ulang desain', async () => {
  resetState({
    event: { id: 'evt-1', ticket_design: previousDesign, ticket_design_orientation: 'landscape' },
  });
  const { res, error } = await callSave({
    scope: 'event',
    layout_only: true,
    layout: {
      ...previousDesign.layout,
      qr: { x: 0.55, y: 0.55, size: 0.25 },
    },
  });
  assert.equal(error, null);
  assert.equal(res.statusCode, 200);
  assert.equal(res.body.success, true);

  // SQL hanya memperbarui kolom desain (orientasi tidak diubah).
  const updates = state.calls.filter((call) => /UPDATE events/.test(call.sql));
  assert.equal(updates.length, 1);
  assert.ok(!/ticket_design_orientation/.test(updates[0].sql),
    'orientasi tidak ikut ditulis pada mode layout_only');
  const stored = JSON.parse(updates[0].params[0]);
  assert.deepEqual(stored.layout.qr, { x: 0.55, y: 0.55, size: 0.25 });
  assert.equal(stored.file_path, previousDesign.file_path, 'file desain dipertahankan');
  assert.equal(stored.orientation, 'landscape');
  assert.equal(stored.layout.title.font_size, 50, 'ukuran judul dipertahankan');
  // `qr` cermin pada respons tetap sinkron dengan `layout.qr`.
  assert.deepEqual(res.body.design.qr, { x: 0.55, y: 0.55, size: 0.25 });
});

test('layout_only tetap dapat disimpan walau belum ada desain tersimpan', async () => {
  resetState({ event: { id: 'evt-1', ticket_design: null, ticket_design_orientation: null } });
  const { res, error } = await callSave({
    scope: 'event',
    layout_only: true,
    layout: {
      qr: { x: 0.3, y: 0.45, size: 0.3 },
      title: { x: 0.06, y: 0.06, font_size: 40, bold: true },
    },
  });
  assert.equal(error, null);
  assert.equal(res.statusCode, 200);
  const stored = JSON.parse(
    state.calls.find((call) => /UPDATE events/.test(call.sql)).params[0],
  );
  // Tiket default sistem memakai tata letak yang sama, jadi konfigurasi tetap
  // tersimpan tanpa berkas gambar.
  assert.equal(stored.file_path, null);
  assert.equal(stored.layout.qr.x, 0.3);
  assert.equal(stored.layout.title.font_size, 40);
  // Elemen yang tidak dikirim memakai default orientasi sistem.
  assert.equal(stored.layout.instruction.font_size, 30);
});

test('layout_only dengan QR yang menutupi tulisan ditolak', async () => {
  resetState({
    event: { id: 'evt-1', ticket_design: previousDesign, ticket_design_orientation: 'landscape' },
  });
  const { res, error } = await callSave({
    scope: 'event',
    layout_only: true,
    layout: {
      ...previousDesign.layout,
      qr: { x: 0.05, y: 0.15, size: 0.55 },
    },
  });
  assert.equal(res.statusCode, 400);
  assert.match(error.message, /QR Code menutupi/);
  assert.equal(state.calls.filter((call) => /UPDATE events/.test(call.sql)).length, 0,
    'tidak ada penulisan saat validasi gagal');
});

test('layout_only dengan ukuran QR di luar rentang ditolak', async () => {
  resetState({
    event: { id: 'evt-1', ticket_design: previousDesign, ticket_design_orientation: 'landscape' },
  });
  const { res, error } = await callSave({
    scope: 'event',
    layout_only: true,
    layout: { ...previousDesign.layout, qr: { x: 0.2, y: 0.2, size: 0.95 } },
  });
  assert.equal(res.statusCode, 400);
  assert.match(error.message, /Ukuran QR/);
});

test('layout_only memakai default untuk nilai yang tidak dikirim', async () => {
  resetState({
    event: { id: 'evt-1', ticket_design: previousDesign, ticket_design_orientation: 'landscape' },
  });
  const { res, error } = await callSave({
    scope: 'event',
    layout_only: true,
    layout: { qr: { x: 0.3 } },
  });
  assert.equal(error, null);
  assert.equal(res.statusCode, 200);
  const stored = JSON.parse(
    state.calls.find((call) => /UPDATE events/.test(call.sql)).params[0],
  );
  assert.equal(stored.layout.qr.x, 0.3);
  assert.ok(stored.layout.qr.y > 0 && stored.layout.qr.y < 1);
  assert.ok(stored.layout.qr.size >= 0.15 && stored.layout.qr.size <= 0.6);
});
