/**
 * Uji end-to-end alur nyata terhadap backend + database (bukan mock).
 *
 * Skenario: registrasi Organizer, buat event + kategori + form dinamis,
 * akses publik tanpa login, desain tiket (template/upload), pendaftaran guest,
 * pembayaran simulasi, penerbitan tiket, dan PDF tiket.
 *
 * Jalankan: npm run test:registration-flow
 *
 * Prasyarat: backend berjalan (dialek API pada PORT default 5000) dan
 * `SIMULATED_PAYMENTS_ENABLED=true` untuk menguji event berbayar.
 */
const BASE = process.env.VERIFY_API_URL || 'http://127.0.0.1:5000';
const stamp = Date.now();

const request = async (
  method, path, { token, orderToken, body, expectJson = true } = {},
) => {
  const response = await fetch(`${BASE}${path}`, {
    method,
    headers: {
      ...(body ? { 'Content-Type': 'application/json' } : {}),
      ...(token ? { Authorization: `Bearer ${token}` } : {}),
      ...(orderToken ? { 'X-Order-Access-Token': orderToken } : {}),
    },
    body: body ? JSON.stringify(body) : undefined,
  });  const buffer = Buffer.from(await response.arrayBuffer());
  const text = buffer.toString('utf8');
  let json = null;
  if (expectJson) {
    try { json = JSON.parse(text); } catch (_e) { json = null; }
  }
  return { status: response.status, json, text, buffer, headers: response.headers };
};

const results = [];
const check = (name, passed, detail = '') => {
  results.push({ name, passed, detail });
  console.log(`${passed ? 'PASS' : 'FAIL'}  ${name}${detail ? ` :: ${detail}` : ''}`);
};

module.exports = { request, check, results, stamp, BASE };

if (require.main === module) {
  const { run } = require('./e2e-registration-scenarios');
  run().catch((error) => {
    console.error('E2E gagal:', error);
    process.exitCode = 1;
  });
}
