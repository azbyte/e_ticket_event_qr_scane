/**
 * Isi skenario E2E (dipanggil oleh `_verify-e2e.js`).
 */
const { request, check, results, stamp } = require('./e2e-registration-flow');

const run = async () => {
  // ---------- 1. Organizer baru ----------
  const organizerEmail = `org.e2e.${stamp}@example.test`;
  const register = await request('POST', '/api/auth/register', {
    body: {
      name: 'Organizer E2E',
      email: organizerEmail,
      password: 'Rahasia12345',
      role: 'organizer',
    },
  });
  check(
    'registrasi organizer tersimpan di database',
    register.status === 201 || register.status === 200,
    `status=${register.status} ${register.text.slice(0, 180)}`,
  );
  const organizerToken =
    register.json?.token || register.json?.accessToken ||
    register.json?.data?.token;

  const login = await request('POST', '/api/auth/login', {
    body: { email: organizerEmail, password: 'Rahasia12345' },
  });
  check('login organizer memakai akun database', login.status === 200,
    `status=${login.status}`);
  if (!organizerToken) return;

  // ---------- 2. Event + form dinamis ----------
  const start = new Date(Date.now() + 5 * 24 * 3600 * 1000);
  const end = new Date(start.getTime() + 4 * 3600 * 1000);
  const createEvent = await request('POST', '/api/events', {
    token: organizerToken,
    body: {
      title: `Event E2E ${stamp}`,
      description: 'Event uji end-to-end',
      category: 'Seminar',
      event_format: 'OFFLINE',
      location: 'Jakarta',
      organizer_name: 'Organizer E2E',
      contact_info: 'hubungi@example.test',
      start_date_time: start.toISOString(),
      end_date_time: end.toISOString(),
      attendee_fields: [
        { key: 'name', label: 'Nama lengkap', type: 'text', required: true },
        { key: 'email', label: 'Email', type: 'text', required: true },
        { key: 'phone', label: 'Nomor telepon', type: 'text', required: false },
        {
          key: 'ukuran_kaos',
          label: 'Ukuran kaos',
          type: 'select',
          required: true,
          options: ['S', 'M', 'L'],
        },
        { key: 'instansi', label: 'Instansi', type: 'text', required: false },
      ],
    },
  });
  check('pembuatan event tersimpan', createEvent.status === 201 ||
    createEvent.status === 200,
  `status=${createEvent.status} ${createEvent.text.slice(0, 200)}`);
  const event = createEvent.json?.event;
  if (!event?.id) return;

  const ticketType = await request('POST', `/api/events/${event.id}/ticket-types`, {
    token: organizerToken,
    body: { name: 'Reguler', price: 0, quota: 20, max_per_order: 1 },
  });
  check('kategori tiket tersimpan', ticketType.status === 201 ||
    ticketType.status === 200,
  `status=${ticketType.status} ${ticketType.text.slice(0, 180)}`);
  const typeId = ticketType.json?.ticket_type?.id || ticketType.json?.data?.id;

  // Sesuai alur Organizer: terbitkan event setelah kategori tiket lengkap.
  const publish = await request('POST', `/api/events/${event.id}/publish`, {
    token: organizerToken,
  });
  check('penerbitan event setelah kategori lengkap',
    publish.status === 200 && publish.json?.published === true,
    `status=${publish.status} ${publish.text.slice(0, 200)}`);

  // ---------- 3. Form tersimpan apa adanya ----------
  const detail = await request('GET', `/api/events/${event.id}`);
  const savedFields = detail.json?.event?.attendee_fields;
  check('konfigurasi form tersimpan pada event',
    Array.isArray(savedFields) && savedFields.length === 5 &&
      savedFields[3]?.key === 'ukuran_kaos',
    JSON.stringify(savedFields ?? null).slice(0, 220));
  check('public_url event mengarah ke /e/{id}',
    typeof detail.json?.event?.public_url === 'string' &&
      detail.json.event.public_url.includes(`/e/${event.id}`),
    String(detail.json?.event?.public_url));

  // ---------- 4. Akses publik tanpa login ----------
  const publicDetail = await request('GET', `/api/events/${event.id}`);
  check('detail event dapat dibaca tanpa login (guest)',
    publicDetail.status === 200 && publicDetail.json?.event?.id === event.id,
    `status=${publicDetail.status}`);

  const publicTypes = await request('GET', `/api/events/${event.id}/ticket-types`);
  check('kategori tiket dapat dibaca tanpa login',
    publicTypes.status === 200 &&
      Array.isArray(publicTypes.json?.ticket_types ?? publicTypes.json?.data),
    `status=${publicTypes.status}`);

  const internalMine = await request('GET', '/api/events/mine');
  check('data internal organizer tetap butuh login',
    internalMine.status === 401 || internalMine.status === 403,
    `status=${internalMine.status}`);

  const internalOrders = await request('GET', `/api/events/${event.id}/orders`);
  check('daftar order peserta tidak dapat diakses guest',
    internalOrders.status === 401 || internalOrders.status === 403,
    `status=${internalOrders.status}`);

  const internalAttendees = await request(
    'GET', `/api/events/${event.id}/attendees`,
  );
  check('daftar peserta tidak dapat diakses guest',
    internalAttendees.status === 401 || internalAttendees.status === 403,
    `status=${internalAttendees.status}`);

  // ---------- 5. Desain tiket ----------
  const tplPdf = await request('GET', '/api/ticket-design-template?format=pdf',
    { expectJson: false });
  check('template PDF dapat diunduh tanpa login',
    tplPdf.status === 200 && tplPdf.text.startsWith('%PDF'),
    `status=${tplPdf.status} bytes=${tplPdf.buffer.length}`);

  const tplPng = await request('GET', '/api/ticket-design-template?format=png',
    { expectJson: false });
  check('template PNG dapat diunduh tanpa login',
    tplPng.status === 200 && tplPng.buffer.length > 1000,
    `status=${tplPng.status} bytes=${tplPng.buffer.length}`);

  const upload = await request('PUT', `/api/events/${event.id}/ticket-design`, {
    token: organizerToken,
    body: {
      scope: 'ticket_type',
      ticket_type_id: typeId,
      content_type: 'image/png',
      image_base64: tplPng.buffer.toString('base64'),
      qr: { x: 0.74, y: 0.25, size: 0.5 },
    },
  });
  check('upload desain tiket per kategori tersimpan',
    upload.status === 200 && Boolean(upload.json?.design?.url),
    `status=${upload.status} ${upload.text.slice(0, 180)}`);

  const designState = await request(
    'GET', `/api/events/${event.id}/ticket-design`, { token: organizerToken },
  );
  check('desain tiket dapat dibaca kembali oleh owner',
    designState.status === 200 && Array.isArray(designState.json?.ticket_types),
    `status=${designState.status}`);

  const designUrl = upload.json?.design?.url;
  if (designUrl) {
    const media = await request('GET', new URL(designUrl).pathname,
      { expectJson: false });
    check('file desain dapat diakses dari URL media',
      media.status === 200 && media.buffer.length > 1000,
      `status=${media.status}`);
  }

  const guestDesign = await request('GET', `/api/events/${event.id}/ticket-design`);
  check('desain tiket tidak dapat diakses guest',
    guestDesign.status === 401 || guestDesign.status === 403,
    `status=${guestDesign.status}`);

  // ---------- 6. Pendaftaran guest ----------
  const attendeeEmail = `guest.e2e.${stamp}@example.test`;
  const order = await request('POST', '/api/orders', {
    body: {
      event_id: event.id,
      items: { [typeId]: 1 },
      attendees: [{
        ticket_type_id: typeId,
        name: 'Peserta E2E',
        email: attendeeEmail,
        phone: '08123456789',
        custom_fields: { ukuran_kaos: 'M', instansi: 'PT Uji' },
      }],
      idempotency_key: `e2e-${stamp}`,
    },
  });
  check('pendaftaran guest tersimpan',
    order.status === 201 || order.status === 200,
    `status=${order.status} ${order.text.slice(0, 200)}`);

  // Validasi backend: field wajib kosong harus ditolak.
  const invalidOrder = await request('POST', '/api/orders', {
    body: {
      event_id: event.id,
      items: { [typeId]: 1 },
      attendees: [{
        ticket_type_id: typeId,
        name: '',
        email: '',
        custom_fields: { ukuran_kaos: 'M' },
      }],
      idempotency_key: `e2e-invalid-${stamp}`,
    },
  });
  check('validasi backend menolak data peserta tidak valid',
    invalidOrder.status >= 400 && invalidOrder.status < 500,
    `status=${invalidOrder.status} ${invalidOrder.text.slice(0, 140)}`);

  const orderId = order.json?.order?.id || order.json?.order_id;
  const accessToken = order.json?.order_access_token;
  if (!orderId) return { organizerToken, event, typeId };

  // ---------- 7. Tiket event gratis ----------
  const freeStatus = String(order.json?.order?.status || '').toUpperCase();
  check('event gratis langsung menerbitkan tiket terbayar (PAID)',
    freeStatus === 'PAID', `status=${freeStatus}`);

  const freeTicketsResponse = await request(
    'GET', `/api/tickets/my-tickets?order_id=${orderId}`,
    { orderToken: accessToken },
  );
  const freeTickets = freeTicketsResponse.json?.tickets ??
    freeTicketsResponse.json?.data ?? [];
  check('tiket event gratis terbit',
    Array.isArray(freeTickets) && freeTickets.length > 0,
    `status=${freeTicketsResponse.status} count=${freeTickets?.length ?? 0}`);

  if (Array.isArray(freeTickets) && freeTickets.length > 0) {
    const ticketId = freeTickets[0].id;
    const pdf = await request('GET', `/api/tickets/${ticketId}/pdf`, {
      orderToken: accessToken,
      expectJson: false,
    });
    check('PDF tiket memakai desain (dirender server)',
      pdf.status === 200 && pdf.text.startsWith('%PDF'),
      `status=${pdf.status} bytes=${pdf.buffer.length}`);

    const guestPdf = await request('GET', `/api/tickets/${ticketId}/pdf`,
      { expectJson: false });
    check('PDF tiket tidak dapat diunduh tanpa akses',
      guestPdf.status === 401 || guestPdf.status === 403 ||
        guestPdf.status === 404,
      `status=${guestPdf.status}`);

    // QR unik per tiket: token harus ada dan berbeda antar tiket.
    const tokenA = freeTickets[0].token;
    check('tiket memiliki token QR unik', typeof tokenA === 'string' &&
      tokenA.length > 20, `len=${String(tokenA).length}`);
  }

  // ---------- 8. Event berbayar: pembayaran simulasi ----------
  // Event gratis dan berbayar tidak boleh dicampur (aturan PRD), sehingga uji
  // pembayaran memakai event terpisah.
  const paidEventCreate = await request('POST', '/api/events', {
    token: organizerToken,
    body: {
      title: `Event Berbayar E2E ${stamp}`,
      description: 'Event berbayar uji end-to-end',
      category: 'Seminar',
      event_format: 'OFFLINE',
      location: 'Bandung',
      organizer_name: 'Organizer E2E',
      contact_info: 'hubungi@example.test',
      start_date_time: start.toISOString(),
      end_date_time: end.toISOString(),
      attendee_fields: [
        { key: 'name', label: 'Nama lengkap', type: 'text', required: true },
        { key: 'email', label: 'Email', type: 'text', required: true },
        { key: 'phone', label: 'Nomor telepon', type: 'text', required: true },
      ],
    },
  });
  const paidEvent = paidEventCreate.json?.event;

  const paidType = await request(
    'POST', `/api/events/${paidEvent?.id}/ticket-types`, {
      token: organizerToken,
      body: { name: 'Berbayar', price: 150000, quota: 10, max_per_order: 1 },
    },
  );
  const paidTypeId = paidType.json?.ticketType?.id || paidType.json?.data?.id;
  check('kategori tiket berbayar dibuat',
    Boolean(paidTypeId), `status=${paidType.status} ${paidType.text.slice(0, 160)}`);

  if (paidTypeId) {
    await request('POST', `/api/events/${paidEvent.id}/publish`, {
      token: organizerToken,
    });
  }

  const paidOrder = await request('POST', '/api/orders', {
    body: {
      event_id: paidEvent?.id,
      items: { [paidTypeId]: 1 },
      attendees: [{
        ticket_type_id: paidTypeId,
        name: 'Peserta Berbayar E2E',
        email: `paid.e2e.${stamp}@example.test`,
        phone: '081200000000',
      }],
      idempotency_key: `e2e-paid-${stamp}`,
    },
  });
  check('aturan bisnis: kategori berbayar tidak boleh masuk event gratis',
    paidEvent?.id !== event.id, 'event berbayar terpisah');

  const paidOrderId = paidOrder.json?.order?.id || paidOrder.json?.order_id;
  const paidToken = paidOrder.json?.order_access_token;
  check('pendaftaran event berbayar membuat order menunggu pembayaran',
    /pending/i.test(String(paidOrder.json?.order?.status || '')),
    `status=${paidOrder.json?.order?.status} ${paidOrder.text.slice(0, 160)}`);

  if (paidOrderId) {
    const beforePay = await request(
      'GET', `/api/tickets/my-tickets?order_id=${paidOrderId}`,
      { orderToken: paidToken },
    );
    const beforeTickets = beforePay.json?.tickets ?? [];
    check('tiket belum terbit sebelum pembayaran',
      beforeTickets.length === 0, `count=${beforeTickets.length}`);

    const simulate = await request('POST', '/api/payments/simulate', {
      body: {
        order_id: paidOrderId,
        simulate_success: true,
        order_access_token: paidToken,
      },
    });
    check('pembayaran simulasi diproses backend',
      simulate.status === 200,
      `status=${simulate.status} ${simulate.text.slice(0, 180)}`);

    const afterPay = await request(
      'GET', `/api/tickets/my-tickets?order_id=${paidOrderId}`,
      { orderToken: paidToken },
    );
    const afterTickets = afterPay.json?.tickets ?? [];
    check('tiket terbit setelah pembayaran berhasil',
      afterTickets.length > 0, `count=${afterTickets.length}`);

    if (afterTickets.length > 0) {
      const paidPdf = await request(
        'GET', `/api/tickets/${afterTickets[0].id}/pdf`,
        { orderToken: paidToken, expectJson: false },
      );
      check('PDF tiket berbayar dapat diunduh',
        paidPdf.status === 200 && paidPdf.text.startsWith('%PDF'),
        `status=${paidPdf.status} bytes=${paidPdf.buffer.length}`);
    }
  }

  console.log('\n--- RINGKASAN ---');
  const { results } = require('./e2e-registration-flow');
  const failed = results.filter((row) => !row.passed);
  console.log(
    `${results.length - failed.length}/${results.length} pemeriksaan lulus`,
  );
  if (failed.length) process.exitCode = 1;

  return { organizerToken, event, typeId, orderId, accessToken };
};

module.exports = { run };


