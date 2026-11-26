/* eslint-disable no-console */
// Live end-to-end verification against the real PostgreSQL database.
require('dotenv').config();
const { Pool } = require('pg');

const API = process.env.API_BASE || 'http://127.0.0.1:5000/api';
const pool = new Pool({ connectionString: process.env.DATABASE_URL });

const results = [];
function record(name, pass, detail = '') {
  results.push({ name, pass, detail });
  console.log(`${pass ? 'PASS' : 'FAIL'}  ${name}${detail ? '  — ' + detail : ''}`);
}

async function api(path, { method = 'POST', body, token } = {}) {
  const res = await fetch(API + path, {
    method,
    headers: {
      'Content-Type': 'application/json',
      ...(token ? { Authorization: `Bearer ${token}` } : {}),
    },
    body: body ? JSON.stringify(body) : undefined,
  });
  let data = null;
  try { data = JSON.parse(await res.text()); } catch { data = null; }
  return { status: res.status, data };
}
async function main() {
  const adminPw = process.env.ADMIN_PASSWORD;
  const stamp = Date.now();
  const orgEmail = `organizer.e2e.${stamp}@example.com`;
  const orgPw = 'rahasiaOrg123';

  // ---------- A. LOGIN ----------
  const adminOk = await api('/auth/login', { body: { email: 'admin@eticket.local', password: adminPw } });
  record('A1. login admin (akun DB, password benar) → 200 + role admin',
    adminOk.status === 200 && adminOk.data?.user?.role === 'admin', `status=${adminOk.status}`);

  const adminToken = adminOk.data?.token;
  record('A2. token JWT diterbitkan', Boolean(adminToken));

  if (adminToken) {
    const me = await api('/auth/me', { method: 'GET', token: adminToken });
    record('A3. GET /auth/me dengan token → 200 + identitas admin',
      me.status === 200 && me.data?.user?.email === 'admin@eticket.local', `status=${me.status}`);
  }

  const adminByUsername = await api('/auth/login', { body: { username: 'admin', password: adminPw } });
  record('A4. login pakai username (bukan email) → 200',
    adminByUsername.status === 200 && adminByUsername.data?.user?.role === 'admin', `status=${adminByUsername.status}`);

  const wrongPw = await api('/auth/login', { body: { email: 'admin@eticket.local', password: 'salah-sekali' } });
  record('A5. login password salah → 401', wrongPw.status === 401, `status=${wrongPw.status}`);

  const unknown = await api('/auth/login', { body: { email: 'tidak.ada@example.com', password: 'apapun123' } });
  record('A6. login email tidak terdaftar → 401', unknown.status === 401, `status=${unknown.status}`);

  const noAuth = await api('/auth/me', { method: 'GET' });
  record('A7. akses /auth/me tanpa token → 401', noAuth.status === 401, `status=${noAuth.status}`);



  // ---------- B. REGISTRASI ORGANIZER ----------
  const reg = await api('/auth/register', {
    body: { name: 'Organizer E2E', email: orgEmail, password: orgPw },
  });
  record('B1. registrasi organizer valid → 201 + token',
    reg.status === 201 && Boolean(reg.data?.token), `status=${reg.status}`);
  record('B2. role akun baru = organizer', reg.data?.user?.role === 'organizer');
  record('B3. respons menyertakan organizer_profile_id', Boolean(reg.data?.user?.organizer_profile_id));

  const userId = reg.data?.user?.id;

  const userRow = (await pool.query(
    'select id, email, name, role, username, password_hash from profiles where email = $1', [orgEmail]
  )).rows[0];
  record('B4. akun tersimpan di tabel profiles', Boolean(userRow));
  record('B5. password tersimpan sebagai hash bcrypt, bukan plaintext',
    Boolean(userRow?.password_hash) && /^\$2[aby]\$/.test(userRow.password_hash) && userRow.password_hash !== orgPw,
    userRow ? `${userRow.password_hash.slice(0, 7)}... len=${userRow.password_hash.length}` : '');

  const orgRow = (await pool.query(
    'select id, user_id, contact_name from organizer_profiles where user_id = $1', [userId]
  )).rows[0];
  record('B6. profil organizer dibuat di organizer_profiles', Boolean(orgRow));
  record('B7. relasi organizer_profiles.user_id -> profiles.id benar',
    orgRow?.user_id === userId, `org.user_id=${orgRow?.user_id}`);
  record('B8. organizer_profile_id di respons = baris DB', reg.data?.user?.organizer_profile_id === orgRow?.id);

  const newLogin = await api('/auth/login', { body: { email: orgEmail, password: orgPw } });
  record('B9. akun organizer baru dapat login -> 200 + role organizer',
    newLogin.status === 200 && newLogin.data?.user?.role === 'organizer', `status=${newLogin.status}`);

  if (newLogin.data?.token) {
    const prof = await api('/organizer/profile', { method: 'GET', token: newLogin.data.token });
    record('B10. organizer dapat mengakses /organizer/profile -> 200',
      prof.status === 200, `status=${prof.status}`);
    const adminArea = await api('/admin/overview', { method: 'GET', token: newLogin.data.token });
    record('B11. organizer DITOLAK dari area admin (-> 403)',
      adminArea.status === 403, `status=${adminArea.status}`);
  }

  // ---------- Duplikasi & validasi ----------
  const dup = await api('/auth/register', { body: { name: 'Dup', email: orgEmail, password: orgPw } });
  record('B12. registrasi email duplikat -> 400', dup.status === 400, `status=${dup.status}`);

  const dupCount = (await pool.query('select count(*)::int c from profiles where email = $1', [orgEmail])).rows[0].c;
  record('B13. duplikat tidak menambah baris profiles', dupCount === 1, `count=${dupCount}`);

  const invalidBodies = [
    ['tanpa email', { name: 'X', password: 'rahasia123' }],
    ['tanpa password', { name: 'X', email: `a.${stamp}@example.com` }],
    ['tanpa nama', { email: `b.${stamp}@example.com`, password: 'rahasia123' }],
    ['email invalid', { name: 'X', email: 'bukan-email', password: 'rahasia123' }],
    ['password pendek', { name: 'X', email: `c.${stamp}@example.com`, password: '123' }],
  ];
  for (const [label, body] of invalidBodies) {
    const r = await api('/auth/register', { body });
    record(`B14. registrasi ${label} -> 400`, r.status === 400, `status=${r.status}`);
  }

  const partial = (await pool.query(
    'select count(*)::int c from profiles where email = any($1::text[])',
    [[`a.${stamp}@example.com`, `b.${stamp}@example.com`, `c.${stamp}@example.com`]]
  )).rows[0].c;
  record('B15. registrasi gagal tidak meninggalkan data parsial', partial === 0, `rows=${partial}`);

  // ---------- C. KONSISTENSI DATABASE ----------
  const orphans = (await pool.query(
    `select count(*)::int c from profiles p
      left join organizer_profiles op on op.user_id = p.id
      where p.role = 'organizer' and op.id is null`
  )).rows[0].c;
  record('C1. tidak ada akun organizer tanpa profil organizer', orphans === 0, `orphans=${orphans}`);
  // ---------- D. INTEGRASI BROWSER (CORS + web app) ----------
  const ORIGIN = process.env.WEB_ORIGIN || 'http://127.0.0.1:3100';
  try {
    const pre = await fetch(API + '/auth/login', {
      method: 'OPTIONS',
      headers: {
        Origin: ORIGIN,
        'Access-Control-Request-Method': 'POST',
        'Access-Control-Request-Headers': 'content-type',
      },
    });
    record('D1. preflight CORS dari origin web -> 2xx + allow-origin cocok',
      pre.status >= 200 && pre.status < 300 && pre.headers.get('access-control-allow-origin') === ORIGIN,
      `status=${pre.status} allow-origin=${pre.headers.get('access-control-allow-origin')}`);
  } catch (e) {
    record('D1. preflight CORS dari origin web', false, e.message);
  }

  try {
    const web = await fetch(ORIGIN + '/');
    const html = await web.text();
    record('D2. aplikasi web Flutter dapat diakses di origin',
      web.status === 200 && html.includes('flutter'), `status=${web.status}`);
  } catch (e) {
    record('D2. aplikasi web Flutter dapat diakses di origin', false, e.message);
  }

  try {
    const browserLogin = await fetch(API + '/auth/login', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', Origin: ORIGIN },
      body: JSON.stringify({ email: orgEmail, password: orgPw }),
    });
    const body = await browserLogin.json();
    record('D3. login dari browser (dengan Origin) -> 200 + token',
      browserLogin.status === 200 && Boolean(body.token),
      `status=${browserLogin.status}`);
  } catch (e) {
    record('D3. login dari browser (dengan Origin)', false, e.message);
  }


  // ---------- RINGKASAN ----------
  const failed = results.filter((r) => !r.pass);
  console.log(`\n===== ${results.length - failed.length}/${results.length} PASS, ${failed.length} FAIL =====`);
  if (failed.length) {
    failed.forEach((f) => console.log('FAILED:', f.name, f.detail));
    process.exitCode = 1;
  }
  console.log('E2E_ORG_EMAIL=' + orgEmail);
}

main()
  .catch((e) => { console.error('E2E ERROR:', e.message); process.exitCode = 1; })
  .finally(() => pool.end());

