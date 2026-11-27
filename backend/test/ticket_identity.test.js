/**
 * Regresi ID publik tiket & nama file e-tiket.
 *
 * Tidak memerlukan database: yang diuji adalah format ID, keunikan kandidat,
 * sanitasi nama file, dan perilaku "tiket lama dirapikan sekali". Untuk itu
 * `config/db` diganti stub di `require.cache` sehingga `getOne` dapat dikontrol
 * tanpa menyentuh database sungguhan.
 */
process.env.NODE_ENV = 'test';
process.env.DATABASE_URL = 'postgresql://tester:secret@127.0.0.1:5432/e_ticket_test';
process.env.JWT_SECRET = 'test-only-jwt-secret';
process.env.TICKET_TOKEN_SECRET = 'test-only-ticket-token-secret';

const test = require('node:test');
const assert = require('node:assert/strict');

const DB_PATH = require.resolve('../src/config/db');
const SERVICE_PATH = require.resolve('../src/services/ticketCodeService');

/**
 * Muat ulang `ticketCodeService` dengan `config/db` palsu.
 *
 * @param {{row?: object|null, updateResult?: object|null, failCode?: string}} scenario
 *   `row` = hasil SELECT tiket; `updateResult` = hasil UPDATE (undefined berarti
 *   sukses dengan kode kandidat); `failCode` = kode error yang dilempar UPDATE.
 * @returns {{service: object, calls: Array<{sql: string, params: Array}>}}
 */
const loadServiceWithStubDb = (scenario) => {
  const calls = [];
  const stub = {
    getOne: async (sql, params) => {
      calls.push({ sql, params });
      if (sql.startsWith('UPDATE')) {
        if (scenario.failCode) {
          const error = new Error('simulasi kegagalan database');
          error.code = scenario.failCode;
          throw error;
        }
        return scenario.updateResult === undefined
          ? { ticket_code: params[0] }
          : scenario.updateResult;
      }
      return scenario.row ?? null;
    },
    query: async (sql, params) => {
      calls.push({ sql, params });
      return scenario.listRows ?? [];
    },
    pool: { connect: async () => { throw new Error('pool tidak dipakai'); } },
  };

  const cached = require.cache[DB_PATH];
  require.cache[DB_PATH] = {
    id: DB_PATH,
    filename: DB_PATH,
    loaded: true,
    exports: stub,
    children: [],
    paths: [],
  };
  delete require.cache[SERVICE_PATH];
  try {
    return { service: require(SERVICE_PATH), calls };
  } finally {
    delete require.cache[SERVICE_PATH];
    if (cached) require.cache[DB_PATH] = cached;
    else delete require.cache[DB_PATH];
  }
};

const tickets = require('../src/services/ticketCodeService');
const filename = require('../src/utils/ticketFilename');

test('ID publik memakai prefix ETK- dan 6 karakter tanpa I/L/O/U', () => {
  assert.equal(tickets.PUBLIC_TICKET_ID_PREFIX, 'ETK-');
  for (let index = 0; index < 200; index += 1) {
    const id = tickets.generatePublicTicketId();
    assert.match(id, /^ETK-[0-9A-HJKMNP-TV-Z]{6}$/);
    assert.ok(!/[ILOU]/.test(id.slice(4)), `karakter mudah tertukar pada ${id}`);
  }
});

test('ID publik yang dihasilkan tersebar merata tanpa pengulangan sistematis', () => {
  const seen = new Set();
  const samples = 5000;
  for (let index = 0; index < samples; index += 1) {
    seen.add(tickets.generatePublicTicketId());
  }
  // Ruang ID 32^6 ≈ 1,07 miliar. Tabrakan bersifat acak (birthday problem):
  // peluang satu tabrakan pada 5000 sampel ≈ 1,2% sehingga TIDAK boleh
  // dijadikan kegagalan mutlak (dulu flaky). Yang diperiksa adalah entropi:
  // generator rusak (mis. hanya beberapa nilai) akan menghasilkan ribuan
  // duplikat, jauh di atas batas ini.
  const duplicates = samples - seen.size;
  assert.ok(
    duplicates <= 2,
    `duplikat ${duplicates} dari ${samples} sampel (batas acak 2)`,
  );
  // Semua nilai tetap berformat ID publik yang sah.
  for (const id of seen) {
    assert.match(id, /^ETK-[0-9A-HJKMNP-TV-Z]{6}$/);
  }
});

test('deteksi format ID publik dan kode lama database', () => {
  assert.equal(tickets.isPublicTicketId('ETK-7K4P9Q'), true);
  assert.equal(tickets.isPublicTicketId('ETK-7K4P9I'), false, 'I tidak dipakai');
  assert.equal(tickets.isPublicTicketId('TKT-TEST-001'), false);
  assert.equal(tickets.isLegacyTicketCode(`TKT-${'a'.repeat(32)}`), true);
  assert.equal(tickets.isLegacyTicketCode('TKT-TEST-001'), false);
  assert.equal(tickets.isLegacyTicketCode('ETK-7K4P9Q'), false);
});

test('tiket yang sudah berformat ETK- tidak diubah (idempotent)', async () => {
  const { service, calls } = loadServiceWithStubDb({
    row: { id: 'ticket-1', ticket_code: 'ETK-7K4P9Q' },
  });
  const code = await service.ensurePublicTicketCode('ticket-1');
  assert.equal(code, 'ETK-7K4P9Q');
  assert.equal(calls.filter((call) => call.sql.startsWith('UPDATE')).length, 0);
});

test('tiket lama dirapikan sekali dan kode lama dipakai sebagai guard', async () => {
  const legacy = `TKT-${'b'.repeat(32)}`;
  const { service, calls } = loadServiceWithStubDb({
    row: { id: 'ticket-2', ticket_code: legacy },
  });
  const code = await service.ensurePublicTicketCode('ticket-2');
  assert.match(code, /^ETK-[0-9A-HJKMNP-TV-Z]{6}$/);
  const update = calls.find((call) => call.sql.startsWith('UPDATE'));
  assert.ok(update, 'UPDATE dijalankan untuk kode lama');
  assert.equal(update.params[2], legacy,
    'guard memakai kode lama agar perubahan pihak lain tidak tertimpa');
});

test('kode lama dipertahankan bila semua kandidat bentrok (tiket tetap valid)', async () => {
  const legacy = `TKT-${'c'.repeat(32)}`;
  const { service, calls } = loadServiceWithStubDb({
    row: { id: 'ticket-3', ticket_code: legacy },
    failCode: '23505',
  });
  const code = await service.ensurePublicTicketCode('ticket-3');
  assert.equal(code, legacy, 'kode tiket tidak boleh dikosongkan/dihapus');
  assert.ok(calls.filter((call) => call.sql.startsWith('UPDATE')).length > 1,
    'kandidat diulang sebelum menyerah');
});

test('tiket tidak ditemukan mengembalikan null', async () => {
  const { service } = loadServiceWithStubDb({ row: null });
  assert.equal(await service.ensurePublicTicketCode('tidak-ada'), null);
  assert.equal(await service.ensurePublicTicketCode(null), null);
});

test('backfill hanya menyentuh tiket yang belum berformat ETK-', async () => {
  const legacy = `TKT-${'d'.repeat(32)}`;
  // Baris pertama sudah benar (tidak boleh diubah), baris kedua kode lama.
  const { service, calls } = loadServiceWithStubDb({
    row: { id: 'ticket-legacy', ticket_code: legacy },
    listRows: [
      { id: 'ticket-ok', ticket_code: 'ETK-ABC123' },
      { id: 'ticket-legacy', ticket_code: legacy },
    ],
  });
  const result = await service.backfillPublicTicketCodes();
  assert.equal(result.processed, 2);
  // SELECT backfill memakai pola format ETK- sehingga tiket yang sudah benar
  // tidak pernah ikut terpilih pada database sungguhan.
  const select = calls.find((call) => call.sql.includes('FROM tickets'));
  assert.match(select.sql, /ticket_code !~ '\^ETK-/);
  assert.equal(select.params.length, 0, 'tanpa limit tidak mengirim parameter');
});

test('backfill menghormati batas jumlah tiket per jalan', async () => {
  const { service, calls } = loadServiceWithStubDb({ listRows: [] });
  await service.backfillPublicTicketCodes({ limit: 25 });
  const select = calls.find((call) => call.sql.includes('FROM tickets'));
  assert.match(select.sql, /LIMIT \$1/);
  assert.deepEqual(select.params, [25]);
});


test('nama file lampiran memakai format E-TIKET Nama Peserta.pdf', () => {
  const cases = [
    ['Aziz', 'E-TIKET Aziz.pdf'],
    ['Budi Santoso', 'E-TIKET Budi Santoso.pdf'],
    ['Muhammad Rizky Pratama Putra', 'E-TIKET Muhammad Rizky Pratama Putra.pdf'],
    ['  Spasi   Berlebih  ', 'E-TIKET Spasi Berlebih.pdf'],
    ['Nama/Anak:Uji?', 'E-TIKET Nama Anak Uji.pdf'],
    ['Nama\tBaris\nBaru', 'E-TIKET Nama Baris Baru.pdf'],
    ['', 'E-TIKET Peserta.pdf'],
    [null, 'E-TIKET Peserta.pdf'],
  ];
  for (const [input, expected] of cases) {
    assert.equal(filename.ticketPdfFilename(input), expected);
  }
  // Tidak boleh memakai underscore/tanda hubung sebagai pemisah atau prefix lain.
  const sample = filename.ticketPdfFilename('Aziz Azman Faza');
  assert.ok(!sample.includes('_'));
  assert.ok(!/^ticket[-_]/i.test(sample));
  assert.ok(sample.endsWith('.pdf'));
});

test('Content-Disposition menyertakan filename ASCII dan filename* UTF-8', () => {
  const header = filename.pdfContentDisposition('Zoë Álvarez');
  assert.match(header, /^attachment; /);
  assert.match(header, /filename="E-TIKET Zo[eE] Alvarez\.pdf"/);
  assert.match(header, /filename\*=UTF-8''E-TIKET%20Zo%C3%AB%20%C3%81lvarez\.pdf/);
  assert.match(filename.pdfContentDisposition('Aziz Azman Faza'),
    /filename="E-TIKET Aziz Azman Faza\.pdf"/);
});
