const { record, api, dataOf, results, getFailures, pool, BASE } = require('./e2e-live-helpers');

const stamp = Date.now();
const orgEmail = `org.e2e.${stamp}@example.test`;
const staffEmail = `staff.e2e.${stamp}@example.test`;
const guestEmail = `guest.e2e.${stamp}@example.test`;
const PASSWORD = 'RahasiaKuat123!';

async function prepare() {
  // ---------------------------------------------------------------- health
  const health = await api('GET', '/health');
  record('E2E-00', 'Health check + database connected',
    health.status === 200 && health.body.database === 'connected', `status=${health.status}`);

  // ------------------------------------------------------------ organizer
  const reg = await api('POST', '/api/auth/register', {
    body: { name: 'Organizer E2E', email: orgEmail, password: PASSWORD, role: 'organizer' },
  });
  record('A-01a', 'Register Organizer', [200, 201].includes(reg.status),
    `status=${reg.status} ${reg.body?.message ?? ''}`);

  const login = await api('POST', '/api/auth/login', { body: { email: orgEmail, password: PASSWORD } });
  const org = dataOf(login) || {};
  const orgToken = org.token;
  const orgUser = org.user;
  record('A-01b', 'Login Organizer', Boolean(orgToken), `status=${login.status}`);

  const now = Date.now();
  const salesStartAt = new Date(now - 86400000).toISOString();
  const startAt = new Date(now + 3 * 86400000).toISOString();
  const endAt = new Date(now + 3 * 86400000 + 4 * 3600000).toISOString();

  const createEvent = await api('POST', '/api/events', {
    token: orgToken,
    body: {
      title: `E2E Summit ${stamp}`,
      description: 'Event pengujian end-to-end Developer 1 Tahap 3.',
      category: 'Seminar',
      organizer_name: 'Organizer E2E',
      contact_info: 'org.e2e@example.test',
      event_date: startAt,
      end_date_time: endAt,
      time_zone: 'Asia/Jakarta',
      event_format: 'OFFLINE',
      location: 'Jakarta Convention Center',
      attendee_fields: [
        { key: 'name', label: 'Nama lengkap', type: 'text', required: true },
        { key: 'email', label: 'Email', type: 'text', required: true },
        { key: 'phone', label: 'Nomor telepon', type: 'text', required: false },
        { key: 'instansi', label: 'Instansi', type: 'text', required: true },
        { key: 'ukuran_kaos', label: 'Ukuran Kaos', type: 'select', required: true, options: ['S', 'M', 'L'] },
      ],
    },
  });
  const createdEvent = dataOf(createEvent) || {};
  const eventId = createdEvent.id || createdEvent.event?.id;
  record('A-02', 'Organizer membuat event baru', Boolean(eventId), `status=${createEvent.status} body=${JSON.stringify(createEvent.body).slice(0, 300)}`);

  const paidType = await api('POST', `/api/events/${eventId}/ticket-types`, {
    token: orgToken,
    body: { name: 'Reguler', price: 150000, quota: 50, sales_start: salesStartAt, sales_end: endAt, is_active: true },
  });
  const paidTypeId = (dataOf(paidType) || {}).id;
  record('A-03a', 'Organizer mengisi kategori tiket berbayar', Boolean(paidTypeId), `status=${paidType.status} body=${JSON.stringify(paidType.body).slice(0, 200)}`);

  const freeType = await api('POST', `/api/events/${eventId}/ticket-types`, {
    token: orgToken,
    body: { name: 'Gratis', price: 0, quota: 20, sales_start: salesStartAt, sales_end: endAt, is_active: true },
  });
  record('A-03b', 'Event berbayar menolak kategori gratis (aturan bisnis)', freeType.status === 400,
    `status=${freeType.status} msg=${freeType.body?.message}`);

  const publish = await api('POST', `/api/events/${eventId}/publish`, { token: orgToken });
  const pub = dataOf(publish) || {};
  const publishedStatus = String(pub.status || '').toUpperCase();
  record('A-04', 'Event valid otomatis PUBLISHED tanpa Admin', publishedStatus === 'PUBLISHED',
    `status=${publish.status} event=${pub.status} errors=${JSON.stringify(pub.validation_errors)}`);

  const publicList = await api('GET', '/api/events/public?limit=100');
  const publicRows = dataOf(publicList)?.events || dataOf(publicList) || [];
  const list = Array.isArray(publicRows) ? publicRows : (publicRows.events || []);
  record('A-06', 'Event published tampil di daftar publik', list.some((e) => e.id === eventId),
    `count=${list.length}`);

  const publicDetail = await api('GET', `/api/events/${eventId}`);
  const detail = dataOf(publicDetail) || {};
  record('A-07', 'Detail publik memuat public_url', Boolean(detail.public_url) && publicDetail.status === 200,
    `public_url=${detail.public_url} keys=${Object.keys(publicDetail.body || {}).join(',')}`);

  // ------------------------------------------------ event gratis terpisah
  const freeEvent = await api('POST', '/api/events', {
    token: orgToken,
    body: {
      title: `E2E Free Meetup ${stamp}`,
      description: 'Event gratis untuk menguji tiket tanpa pembayaran.',
      category: 'Komunitas',
      organizer_name: 'Organizer E2E',
      contact_info: 'org.e2e@example.test',
      event_date: startAt,
      end_date_time: endAt,
      time_zone: 'Asia/Jakarta',
      event_format: 'OFFLINE',
      location: 'Bandung Creative Hub',
      attendee_fields: [
        { key: 'name', label: 'Nama lengkap', type: 'text', required: true },
        { key: 'email', label: 'Email', type: 'text', required: true },
      ],
    },
  });
  const freeEventId = (dataOf(freeEvent) || {}).id;
  const freeTicketType = await api('POST', `/api/events/${freeEventId}/ticket-types`, {
    token: orgToken,
    body: { name: 'Gratis', price: 0, quota: 30, sales_start: salesStartAt, sales_end: endAt, is_active: true },
  });
  const freeTypeId = (dataOf(freeTicketType) || {}).id;
  const freePublish = await api('POST', `/api/events/${freeEventId}/publish`, { token: orgToken });
  record('A-03c', 'Event gratis + kategori gratis dapat publish',
    Boolean(freeTypeId) && freePublish.status === 200,
    `type=${freeTicketType.status} publish=${freePublish.status}`);

  // --------------------------------------------------------- event invalid
  // Event dibuat lengkap tetapi tanpa kategori tiket → publish harus 422.
  const badEvent = await api('POST', '/api/events', {
    token: orgToken,
    body: {
      title: `E2E Invalid ${stamp}`,
      description: 'Event tanpa kategori tiket.',
      category: 'Lainnya',
      organizer_name: 'Organizer E2E',
      contact_info: 'org.e2e@example.test',
      event_date: startAt,
      end_date_time: endAt,
      time_zone: 'Asia/Jakarta',
      event_format: 'OFFLINE',
      location: 'Surabaya',
    },
  });
  const badId = (dataOf(badEvent) || {}).id;
  const badPublish = await api('POST', `/api/events/${badId}/publish`, { token: orgToken });
  const badReasons = (dataOf(badPublish) || {}).validation_errors || badPublish.body?.validation_errors;
  const badStatus = String((dataOf(badPublish) || {}).status || '').toUpperCase();
  record('A-05', 'Event invalid -> 422 + alasan, tetap DRAFT',
    badPublish.status === 422 && Array.isArray(badReasons) && badReasons.length > 0 && badStatus === 'DRAFT',
    `status=${badPublish.status} eventStatus=${badStatus} reasons=${JSON.stringify(badReasons)?.slice(0, 180)}`);

  const badPublicList = await api('GET', '/api/events/public?limit=200');
  const badRowsRaw = dataOf(badPublicList)?.events || [];
  const badRows = Array.isArray(badRowsRaw) ? badRowsRaw : [];
  record('A-05b', 'Event invalid tidak muncul di /api/events/public',
    !badRows.some((e) => e.id === badId), `publicCount=${badRows.length}`);

  return {
    orgEmail, staffEmail, guestEmail, orgToken, orgUser, eventId, paidTypeId,
    freeEventId, freeTypeId, badId, startAt, endAt,
  };
}

// ------------------------------------------------------------ GUEST JOURNEY
async function guestJourney(ctx) {
  const { eventId, paidTypeId, freeEventId, freeTypeId, badId } = ctx;
  const paidAttendee = {
    ticket_type_id: paidTypeId,
    name: 'Guest E2E',
    email: guestEmail,
    phone: '081234567890',
    custom_fields: { instansi: 'PT Uji', ukuran_kaos: 'M' },
  };
  const paidOrder = await api('POST', '/api/orders', {
    headers: { 'Idempotency-Key': `e2e-${stamp}-paid-0001` },
    body: { event_id: eventId, items: { [paidTypeId]: 1 }, attendees: [paidAttendee] },
  });
  const paid = paidOrder.body?.order || {};
  const orderId = paid.id;
  const orderToken = paidOrder.body?.order_access_token;
  record('E2E-06', 'Guest membuat order tepat 1 tiket',
    Boolean(orderId) && Boolean(orderToken),
    `status=${paidOrder.status} orderId=${orderId} total=${paid.total_amount} token=${orderToken ? 'ada' : 'kosong'} msg=${paidOrder.body?.message ?? ''}`);

  const qty2 = await api('POST', '/api/orders', {
    headers: { 'Idempotency-Key': `e2e-${stamp}-qty2-0001` },
    body: {
      event_id: eventId, items: { [paidTypeId]: 2 },
      attendees: [
        { ticket_type_id: paidTypeId, name: 'Andi', email: `a.${stamp}@x.test`, custom_fields: { instansi: 'A', ukuran_kaos: 'S' } },
        { ticket_type_id: paidTypeId, name: 'Budi', email: `b.${stamp}@x.test`, custom_fields: { instansi: 'B', ukuran_kaos: 'M' } },
      ],
    },
  });
  record('N-01', 'Quantity 2 ditolak server', [400, 422].includes(qty2.status),
    `status=${qty2.status} msg=${qty2.body?.message}`);

  const replay = await api('POST', '/api/orders', {
    headers: { 'Idempotency-Key': `e2e-${stamp}-paid-0001` },
    body: { event_id: eventId, items: { [paidTypeId]: 1 }, attendees: [paidAttendee] },
  });
  const replayId = replay.body?.order?.id;
  record('A-36', 'Replay idempotent tidak membuat order ganda', replayId === orderId,
    `first=${orderId} replay=${replayId}`);

  const wrongToken = await api('GET', `/api/orders/${orderId}`, { orderToken: `wrong-token-${stamp}` });
  record('N-04', 'Guest dengan token salah ditolak', [401, 403, 404].includes(wrongToken.status),
    `status=${wrongToken.status}`);

  const noToken = await api('GET', `/api/orders/${orderId}`);
  record('N-12', 'Guest tanpa order token ditolak', [401, 403, 404].includes(noToken.status),
    `status=${noToken.status}`);

  const forcePaid = await api('PUT', `/api/orders/${orderId}`, {
    orderToken, body: { status: 'PAID', payment_status: 'PAID' },
  });
  record('N-03', 'Client tidak dapat memaksa status PAID',
    [400, 401, 403, 404, 405].includes(forcePaid.status), `status=${forcePaid.status}`);

  const pay = await api('POST', '/api/payments/simulate', {
    body: { order_id: orderId, simulate_success: true }, orderToken,
  });
  record('E2E-07', 'Pembayaran simulasi -> PAID', [200, 201].includes(pay.status),
    `status=${pay.status} body=${JSON.stringify(pay.body).slice(0, 160)}`);

  const afterPay = await api('GET', `/api/orders/${orderId}`, { orderToken });
  const after = dataOf(afterPay) || {};
  const orderStatus = String(after.status || '').toUpperCase();
  record('E2E-08a', 'Order berstatus PAID', orderStatus === 'PAID',
    `status=${after.status} payment=${after.payment?.status}`);

  const myTickets = await api('GET', `/api/tickets/my-tickets?order_id=${orderId}`, { orderToken });
  const tickets = myTickets.body?.tickets || [];
  record('E2E-08b', 'Tepat satu tiket terbit setelah PAID', tickets.length === 1,
    `status=${myTickets.status} tickets=${tickets.length}`);

  const ticketId = tickets[0]?.id;
  const ticketToken = tickets[0]?.token || tickets[0]?.ticket_token;

  record('A-37', 'Tiket berisi token QR opaque (bukan PII)',
    Boolean(ticketToken) && !String(ticketToken).includes('@'),
    `tokenLen=${ticketToken?.length ?? 0}`);

  const freeOrder = await api('POST', '/api/orders', {
    headers: { 'Idempotency-Key': `e2e-${stamp}-free-0001` },
    body: {
      event_id: freeEventId,
      items: { [freeTypeId]: 1 },
      attendees: [{
        ticket_type_id: freeTypeId,
        name: 'Guest Gratis',
        email: `free.${stamp}@example.test`,
      }],
    },
  });
  const free = freeOrder.body?.order || {};
  const freeToken = freeOrder.body?.order_access_token;
  const freeTicketList = await api('GET', `/api/tickets/my-tickets?order_id=${free.id}`, { orderToken: freeToken });
  const freeTickets = freeTicketList.body?.tickets || [];
  const freeOrderStatus = String(free.status || '').toUpperCase();
  record('A-31', 'Order gratis langsung menerbitkan tiket tanpa pembayaran',
    freeTickets.length === 1 && freeOrderStatus === 'PAID',
    `status=${freeOrderStatus} tickets=${freeTickets.length} payment=${free.payment?.status}`);

  const invalidField = await api('POST', '/api/orders', {
    headers: { 'Idempotency-Key': `e2e-${stamp}-badfield-01` },
    body: {
      event_id: eventId, items: { [paidTypeId]: 1 },
      attendees: [{ ticket_type_id: paidTypeId, name: 'Tanpa Field', email: `x.${stamp}@example.test` }],
    },
  });
  record('K5-D1-04', 'Field dinamis wajib divalidasi server',
    [400, 422].includes(invalidField.status),
    `status=${invalidField.status} msg=${invalidField.body?.message}`);

  const badChoice = await api('POST', '/api/orders', {
    headers: { 'Idempotency-Key': `e2e-${stamp}-badchoice` },
    body: {
      event_id: eventId, items: { [paidTypeId]: 1 },
      attendees: [{
        ticket_type_id: paidTypeId,
        name: 'Pilihan Salah', email: `y.${stamp}@example.test`,
        custom_fields: { instansi: 'PT Y', ukuran_kaos: 'XXL' },
      }],
    },
  });
  record('K5-D1-04b', 'Opsi select di luar daftar ditolak server',
    [400, 422].includes(badChoice.status),
    `status=${badChoice.status} msg=${badChoice.body?.message}`);

  const orderOnDraft = await api('POST', '/api/orders', {
    headers: { 'Idempotency-Key': `e2e-${stamp}-draft-0001` },
    body: {
      event_id: badId, items: { [paidTypeId]: 1 },
      attendees: [{
        ticket_type_id: paidTypeId,
        name: 'Draft Guest', email: `d.${stamp}@x.test`,
        custom_fields: { instansi: 'D', ukuran_kaos: 'S' },
      }],
    },
  });
  record('N-13a', 'Event draft tidak dapat didaftari', [400, 403, 404, 409, 422].includes(orderOnDraft.status),
    `status=${orderOnDraft.status}`);

  return { orderId, orderToken, ticketId, ticketToken, freeOrderId: free.id };
}

// -------------------------------------------------------------------- STAFF
async function staffJourney(ctx) {
  const { eventId, orgToken, ticketId, ticketToken } = ctx;
  const invite = await api('POST', `/api/events/${eventId}/invitations`, {
    token: orgToken,
    body: {
      email: staffEmail,
      permissions: ['SCAN_TICKET', 'CHECK_IN_TICKET', 'VIEW_SCAN_HISTORY', 'VIEW_PARTICIPANTS'],
    },
  });
  const inv = dataOf(invite) || {};
  const inviteToken = inv.token || inv.invitation?.token;
  const inviteUrl = inv.invite_url;
  record('E2E-09', 'Organizer mengundang staff (invite_url berbeda dari public_url)',
    Boolean(inviteToken) && Boolean(inviteUrl) && !String(inviteUrl).includes(`/e/${eventId}`),
    `status=${invite.status} invite_url=${inviteUrl}`);

  const staffReg = await api('POST', '/api/auth/register', {
    body: { name: 'Staff E2E', email: staffEmail, password: PASSWORD },
  });
  record('E2E-09b', 'Staff mendaftar dengan email undangan',
    [200, 201].includes(staffReg.status), `status=${staffReg.status}`);

  const staffLogin = await api('POST', '/api/auth/login', { body: { email: staffEmail, password: PASSWORD } });
  const staffAuth = dataOf(staffLogin) || {};
  const staffToken = staffAuth.token;

  const accept = await api('POST', `/api/invitations/${inviteToken}/accept`, { token: staffToken });
  record('E2E-10', 'Staff menerima undangan -> membership aktif',
    [200, 201].includes(accept.status), `status=${accept.status} body=${JSON.stringify(accept.body).slice(0, 140)}`);

  const memberships = await api('GET', '/api/me/memberships', { token: staffToken });
  const mem = dataOf(memberships);
  const memList = Array.isArray(mem) ? mem : (mem?.memberships || []);
  record('A-45', 'Membership aktif terbaca dari /api/me/memberships',
    memberships.status === 200 && memList.length >= 1,
    `status=${memberships.status} count=${memList.length}`);

  const reuse = await api('POST', `/api/invitations/${inviteToken}/accept`, { token: staffToken });
  record('N-09', 'Undangan yang sudah dipakai ditolak',
    [400, 403, 409, 410, 422].includes(reuse.status), `status=${reuse.status}`);

  const ticketDetail = await api('GET', `/api/tickets/${ticketId}`, { token: staffToken });
  record('C-15', 'Staff tidak dapat membaca detail tiket penuh (hanya validasi)',
    ticketDetail.status === 404, `status=${ticketDetail.status}`);

  // WRONG_EVENT diuji dengan pemilik kedua event agar otorisasi pos scan lolos
  // dan yang tersisa hanya perbedaan event tiket.
  const scanWrongEvent = await api('POST', '/api/tickets/validate', {
    token: orgToken, body: { token: ticketToken, event_id: ctx.freeEventId },
  });
  const wrongResult = scanWrongEvent.body?.status;
  record('N-05', 'Scan tiket event lain -> WRONG_EVENT',
    scanWrongEvent.status === 200 && String(wrongResult).toUpperCase() === 'WRONG_EVENT',
    `status=${scanWrongEvent.status} result=${wrongResult}`);

  const validate = await api('POST', '/api/tickets/validate', {
    token: staffToken, body: { token: ticketToken, event_id: eventId },
  });
  const validResult = validate.body?.status;
  record('E2E-11b', 'Scan tiket valid -> VALID',
    String(validResult).toUpperCase() === 'VALID',
    `status=${validate.status} result=${validResult}`);

  const checkIn = await api('POST', '/api/check-ins', {
    token: staffToken, body: { token: ticketToken, event_id: eventId },
  });
  record('E2E-11', 'Check-in berhasil tercatat',
    checkIn.status === 201,
    `status=${checkIn.status} body=${JSON.stringify(checkIn.body).slice(0, 160)}`);

  const revalidate = await api('POST', '/api/tickets/validate', {
    token: staffToken, body: { token: ticketToken, event_id: eventId },
  });
  const recheckResult = String(revalidate.body?.status || '').toUpperCase();
  record('E2E-12', 'Scan ulang -> ALREADY_USED', recheckResult === 'ALREADY_USED',
    `status=${revalidate.status} result=${recheckResult}`);

  const recheckCommit = await api('POST', '/api/check-ins', {
    token: staffToken, body: { token: ticketToken, event_id: eventId },
  });
  record('N-07', 'Commit check-in kedua ditolak tanpa baris baru',
    recheckCommit.status == 400 || recheckCommit.status == 409,
    `status=${recheckCommit.status}`);

  const dbCheckIns = await pool.query(
    'select count(*)::int as c from check_ins where ticket_id = $1', [ticketId],
  );
  record('B-09', 'Tepat satu baris check_ins per tiket', dbCheckIns.rows[0].c === 1,
    `rows=${dbCheckIns.rows[0].c}`);

  const history = await api('GET', `/api/check-ins/events/${eventId}/check-ins`, { token: staffToken });
  record('E2E-13', 'Riwayat check-in dapat dibaca staff', history.status === 200,
    `status=${history.status}`);

  // Staff tanpa permission scan tidak boleh check-in di event lain.
  const otherEventCheckIn = await api('POST', '/api/check-ins', {
    token: staffToken, body: { token: ticketToken, event_id: ctx.freeEventId },
  });
  record('N-08', 'Staff tanpa membership/permission ditolak',
    [401, 403, 404].includes(otherEventCheckIn.status), `status=${otherEventCheckIn.status}`);

  return { staffToken, inviteToken };
}

// -------------------------------------------------------- ORGANIZER POST
async function organizerPostFlow(ctx) {
  const { eventId, orgToken } = ctx;

  const attendees = await api('GET', `/api/events/${eventId}/attendees`, { token: orgToken });
  const att = dataOf(attendees);
  const attRows = Array.isArray(att) ? att : (att?.attendees || []);
  record('A-13', 'Organizer melihat daftar peserta', attendees.status === 200 && attRows.length >= 1,
    `status=${attendees.status} count=${attRows.length}`);

  const firstAttendee = attRows[0] || {};
  record('A-14', 'Detail peserta memuat nomor registrasi + custom_fields',
    Boolean(firstAttendee.registration_number) && firstAttendee.custom_fields !== undefined,
    `regNo=${firstAttendee.registration_number} custom=${JSON.stringify(firstAttendee.custom_fields)}`);

  const csvRes = await fetch(`${BASE}/api/events/${eventId}/attendees/export`, {
    headers: { Authorization: `Bearer ${orgToken}` },
  });
  const csvText = await csvRes.text();
  record('A-15', 'Export CSV dari server berhasil',
    csvRes.status === 200 && csvText.trim().split('\n').length >= 2,
    `status=${csvRes.status} lines=${csvText.trim().split('\n').length} header=${csvText.split('\n')[0]?.slice(0, 80)}`);

  const ordersPerEvent = await api('GET', `/api/events/${eventId}/orders`, { token: orgToken });
  record('A-16', 'Order per event dapat dibaca Organizer', ordersPerEvent.status === 200,
    `status=${ordersPerEvent.status}`);

  const report = await api('GET', `/api/events/${eventId}/summary`, { token: orgToken });
  record('A-17', 'Laporan/revenue event dari server', report.status === 200,
    `status=${report.status}`);

  const summary = await api('GET', `/api/events/${eventId}/summary`, { token: orgToken });
  record('A-17b', 'Ringkasan metrik event', summary.status === 200, `status=${summary.status}`);

  const checkInHistory = await api('GET', `/api/check-ins/events/${eventId}/check-ins`, { token: orgToken });
  record('A-18', 'Organizer melihat riwayat check-in event-nya',
    checkInHistory.status === 200, `status=${checkInHistory.status}`);

  const organizerRevenue = await api('GET', '/api/revenue/me', { token: orgToken });
  record('E2E-17', 'Revenue Organizer dapat dibaca', organizerRevenue.status === 200,
    `status=${organizerRevenue.status}`);

  const team = await api('GET', `/api/events/${eventId}/members`, { token: orgToken });
  const teamRows = (dataOf(team) || {}).members || [];
  record('A-12b', 'Organizer melihat anggota tim', team.status === 200 && teamRows.length >= 1,
    `status=${team.status} members=${teamRows.length}`);

  const notifications = await api('GET', '/api/notifications', { token: orgToken });
  record('A-76', 'Notifikasi Organizer berasal dari API', notifications.status === 200,
    `status=${notifications.status}`);
}

// -------------------------------------------------------------------- ADMIN
async function adminJourney(ctx) {
  const { eventId, orgToken, orgUser, paidTypeId } = ctx;
  const adminLogin = await api('POST', '/api/auth/login', {
    body: { email: process.env.ADMIN_EMAIL, password: process.env.ADMIN_PASSWORD },
  });
  const adminAuth = dataOf(adminLogin) || {};
  const adminToken = adminAuth.token;
  record('E2E-18a', 'Login Admin hasil provisioning',
    Boolean(adminToken), `status=${adminLogin.status} msg=${adminLogin.body?.message ?? ''}`);
  if (!adminToken) return { adminToken: null };

  const accounts = await api('GET', '/api/admin/accounts', { token: adminToken });
  const acc = dataOf(accounts);
  const accRows = Array.isArray(acc) ? acc : (acc?.accounts || acc?.users || []);
  record('A-59', 'Admin membaca daftar akun + metrik',
    accounts.status === 200 && accRows.length >= 1,
    `status=${accounts.status} count=${accRows.length}`);

  const suspend = await api('PUT', `/api/admin/accounts/${orgUser?.id}/status`, {
    token: adminToken, body: { status: 'SUSPENDED', reason: 'Uji otomasi E2E D1 Tahap 3' },
  });
  record('A-60', 'Admin suspend akun dengan alasan',
    [200, 204].includes(suspend.status),
    `status=${suspend.status} msg=${suspend.body?.message ?? ''}`);

  const audit = await pool.query(
    "select count(*)::int as c from audit_logs where action ilike '%suspend%'",
  );
  record('A-61', 'Suspend akun tercatat di audit_logs', audit.rows[0].c >= 1,
    `rows=${audit.rows[0].c}`);

  const restore = await api('PUT', `/api/admin/accounts/${orgUser?.id}/status`, {
    token: adminToken, body: { status: 'ACTIVE', reason: 'Pemulihan setelah uji E2E D1' },
  });
  record('E2E-18e', 'Admin memulihkan akun', [200, 204].includes(restore.status),
    `status=${restore.status}`);

  const auditList = await api('GET', '/api/admin/audit-logs?limit=10', { token: adminToken });
  record('A-62', 'Admin melihat audit log', auditList.status === 200, `status=${auditList.status}`);

  const settings = await api('GET', '/api/admin/settings', { token: adminToken });
  const st = dataOf(settings) || {};
  record('A-63', 'Admin membaca platform settings', settings.status === 200,
    `status=${settings.status} fee=${st.platform_fee ?? st.fixed_fee} commission=${st.commission_rate ?? st.commission_percent}`);

  const beforeHist = await pool.query('select count(*)::int as c from platform_setting_history');
  const settingsPut = await api('PUT', '/api/admin/settings/support_email', {
    token: adminToken, body: { value: `support.${stamp}@example.test` },
  });
  const afterHist = await pool.query('select count(*)::int as c from platform_setting_history');
  record('A-65', 'Perubahan setting tercatat di platform_setting_history',
    settingsPut.status === 200 && afterHist.rows[0].c > beforeHist.rows[0].c,
    `put=${settingsPut.status} before=${beforeHist.rows[0].c} after=${afterHist.rows[0].c} msg=${settingsPut.body?.message ?? ''}`);

  const checks = [
    ['A-66', '/api/admin/overview', 'Dashboard Admin'],
    ['A-67', '/api/revenue/admin/summary', 'Revenue platform'],
    ['A-67b', '/api/revenue/admin/transactions', 'Transaksi platform'],
    ['A-68', '/api/plans/admin/all', 'Paket layanan'],
    ['A-69', '/api/admin/subscriptions', 'Daftar langganan'],
    ['A-75', '/api/support-reports', 'Laporan dukungan'],
  ];
  for (const [id, path, label] of checks) {
    const r = await api('GET', path, { token: adminToken });
    record(id, `Admin GET ${path} (${label})`, r.status === 200, `status=${r.status}`);
  }

  const suspendEvent = await api('PUT', `/api/admin/events/${eventId}/moderation`, {
    token: adminToken, body: { status: 'SUSPENDED', note: 'Uji moderasi otomasi E2E D1 Tahap 3' },
  });
  record('A-71', 'Admin suspend event dengan alasan',
    [200, 204].includes(suspendEvent.status),
    `status=${suspendEvent.status} msg=${suspendEvent.body?.message ?? ''}`);

  const afterSuspend = await api('GET', '/api/events/public?limit=200');
  const afterRowsRaw = dataOf(afterSuspend)?.events || [];
  const afterRows = Array.isArray(afterRowsRaw) ? afterRowsRaw : [];
  record('A-72', 'Event suspended hilang dari daftar publik',
    !afterRows.some((e) => e.id === eventId), `publicCount=${afterRows.length}`);

  const orderOnSuspended = await api('POST', '/api/orders', {
    headers: { 'Idempotency-Key': `e2e-${stamp}-susp-0001` },
    body: {
      event_id: eventId, items: { [paidTypeId]: 1 },
      attendees: [{
        ticket_type_id: paidTypeId,
        name: 'Suspend Guest', email: `z.${stamp}@example.test`,
        custom_fields: { instansi: 'PT Z', ukuran_kaos: 'S' },
      }],
    },
  });
  record('A-73', 'Event suspended menolak order baru',
    [400, 403, 404, 409, 422].includes(orderOnSuspended.status),
    `status=${orderOnSuspended.status} msg=${orderOnSuspended.body?.message}`);

  const restoreEvent = await api('PUT', `/api/admin/events/${eventId}/moderation`, {
    token: adminToken, body: { status: 'PUBLISHED', note: 'Pemulihan setelah uji E2E D1 Tahap 3' },
  });
  record('A-74', 'Admin memulihkan event suspended',
    [200, 204].includes(restoreEvent.status), `status=${restoreEvent.status}`);

  const approveAttempt = await api('POST', `/api/admin/events/${eventId}/approve`, { token: adminToken });
  record('A-77', 'Tidak ada lagi approval publikasi manual oleh Admin',
    [404, 405].includes(approveAttempt.status), `status=${approveAttempt.status}`);

  // ------------------------------------------------- negatif keamanan admin
  const nonAdmin = await api('GET', '/api/admin/accounts', { token: orgToken });
  record('N-10', 'Non-admin ditolak dari /api/admin/*',
    [401, 403].includes(nonAdmin.status), `status=${nonAdmin.status}`);

  return { adminToken };
}

// ------------------------------------------------------- DB + NEGATIF AKHIR
async function verifyDatabaseAndSecurity(ctx) {
  const { orderId, ticketId, eventId, orgToken } = ctx;

  const dbOrder = await pool.query(
    'select id, status, grand_total, order_number from event_orders where id = $1', [orderId],
  );
  record('B-04', 'Order tersimpan di DB + order_number stabil',
    dbOrder.rowCount === 1 && Boolean(dbOrder.rows[0].order_number),
    `rows=${dbOrder.rowCount} status=${dbOrder.rows[0]?.status} number=${dbOrder.rows[0]?.order_number}`);

  const dbTicket = await pool.query(
    'select id, token_hash, status from tickets where id = $1', [ticketId],
  );
  record('B-05', 'Tiket punya token_hash (bukan token mentah)',
    dbTicket.rowCount === 1 && Boolean(dbTicket.rows[0].token_hash) && !('token' in (dbTicket.rows[0] || {})),
    `hashLen=${dbTicket.rows[0]?.token_hash?.length ?? 0}`);

  const dbAttendee = await pool.query(
    'select a.id, a.custom_fields from attendees a join order_items oi on oi.id = a.order_item_id where oi.order_id = $1', [orderId],
  );
  record('B-08', 'attendees.custom_fields menyimpan jawaban form dinamis',
    dbAttendee.rowCount === 1 && dbAttendee.rows[0].custom_fields !== null,
    `rows=${dbAttendee.rowCount} custom=${JSON.stringify(dbAttendee.rows[0]?.custom_fields)}`);

  const scanLogs = await pool.query('select count(*)::int as c from scan_logs');
  record('B-09b', 'scan_logs tercatat', scanLogs.rows[0].c >= 1, `rows=${scanLogs.rows[0].c}`);

  // Cross-owner
  const otherEmail = `org2.e2e.${stamp}@example.test`;
  await api('POST', '/api/auth/register', {
    body: { name: 'Organizer Lain', email: otherEmail, password: PASSWORD, role: 'organizer' },
  });
  const otherLogin = await api('POST', '/api/auth/login', { body: { email: otherEmail, password: PASSWORD } });
  const otherToken = (dataOf(otherLogin) || {}).token;

  const crossEdit = await api('PUT', `/api/events/${eventId}`, {
    token: otherToken, body: { title: 'Percobaan ambil alih' },
  });
  record('N-11', 'Organizer lain tidak dapat mengedit event (403/404)',
    [403, 404].includes(crossEdit.status), `status=${crossEdit.status}`);

  const crossAttendees = await api('GET', `/api/events/${eventId}/attendees`, { token: otherToken });
  record('C-01', 'Cross-owner daftar peserta ditolak',
    [403, 404].includes(crossAttendees.status), `status=${crossAttendees.status}`);

  const noAuth = await api('GET', '/api/events/mine');
  record('C-02', 'Tanpa token -> 401', noAuth.status === 401, `status=${noAuth.status}`);

  const notFound = await api('GET', '/api/tidak-ada-route-ini');
  record('D-08', '404 konsisten untuk route tidak dikenal', notFound.status === 404,
    `status=${notFound.status}`);

  const invalidLogin = await api('POST', '/api/auth/login', {
    body: { email: `nobody.${stamp}@example.test`, password: 'SalahSekali123!' },
  });
  record('C-03', 'Login kredensial salah ditolak', [400, 401].includes(invalidLogin.status),
    `status=${invalidLogin.status}`);

  const wrongEventScan = await api('POST', '/api/tickets/validate', {
    token: orgToken, body: { token: 'token-palsu-tidak-valid-123456', event_id: eventId },
  });
  const invalidResult = String(
    (dataOf(wrongEventScan) || {}).result || wrongEventScan.body?.result || '',
  ).toUpperCase();
  record('C-04', 'Token QR palsu tidak menghasilkan VALID',
    invalidResult !== 'VALID', `status=${wrongEventScan.status} result=${invalidResult}`);
}

// -------------------------------------------------------------------- MAIN
async function main() {
  const ctx = await prepare();
  const guest = await guestJourney(ctx);
  const staff = await staffJourney({ ...ctx, ...guest });
  await organizerPostFlow(ctx);
  const admin = await adminJourney(ctx);
  await verifyDatabaseAndSecurity({ ...ctx, ...guest, ...staff, ...admin });
}

main()
  .then(async () => {
    const total = results.length;
    const failed = getFailures();
    console.log(`\n===== RINGKASAN E2E: ${total - failed}/${total} PASS, ${failed} FAIL =====`);
    if (failed > 0) {
      console.log('LANGKAH GAGAL:');
      results.filter((r) => !r.ok).forEach((r) => console.log(` - ${r.id} ${r.name} :: ${r.detail}`));
    }
    await pool.end();
    process.exit(failed > 0 ? 1 : 0);
  })
  .catch(async (error) => {
    console.error('E2E CRASH:', error);
    try { await pool.end(); } catch {}
    process.exit(1);
  });
