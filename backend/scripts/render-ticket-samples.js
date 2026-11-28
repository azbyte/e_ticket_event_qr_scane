/**
 * Buat contoh PDF e-tiket untuk pemeriksaan visual & pengujian QR.
 *
 * Skrip verifikasi manual (bukan bagian runtime aplikasi):
 *   cd backend
 *   node scripts/render-ticket-samples.js
 *   py tools/compare_ticket_render.py
 *
 * Hasil ada di `backend/_verify-out/ticket-samples/` beserta `manifest.json`
 * yang memuat token QR setiap tiket (untuk verifikasi `--expect` saat decode).
 * Tidak menyentuh database: seluruh baris tiket adalah data sintetis.
 */
process.env.DATABASE_URL = process.env.DATABASE_URL
  || 'postgresql://verify:verify@127.0.0.1:5432/verify_only';
process.env.JWT_SECRET = process.env.JWT_SECRET || 'verify-only-jwt-secret';
process.env.TICKET_TOKEN_SECRET = process.env.TICKET_TOKEN_SECRET || 'verify-only-token-secret';

const fs = require('node:fs');
const path = require('node:path');

const design = require('../src/services/ticketDesignService');
const { rawTokenFor } = require('../src/services/ticketTokenService');

const OUT_DIR = path.join(__dirname, '..', '_verify-out', 'ticket-samples');
const REFERENCE = path.join(__dirname, '..', '..', 'docs', 'references', 'desain_tiket_referensi.png');

const baseTicket = {
  id: '11111111-1111-4111-8111-111111111111',
  ticket_code: 'ETK-6NGS2R',
  issued_at: new Date('2026-11-26T10:00:00.000Z').toISOString(),
  purchased_at: new Date('2026-11-26T10:00:00.000Z').toISOString(),
  event_title: 'Konser',
  attendee_name: 'Peserta Uji',
  ticket_type_name: 'VIP',
  event_date: new Date('2026-12-01T12:00:00.000Z').toISOString(),
  location: 'Jakarta',
  order_number: 'ORD-UJI-1',
};

/** Desain kustom lengkap (berkas gambar + tata letak) dari file PNG. */
const customDesignFrom = (pngPath, overrides = {}) => {
  const buffer = fs.readFileSync(pngPath);
  const size = design.readImageSize(buffer);
  // Salin ke storage desain agar jalur render memakai berkas nyata.
  const eventDir = path.join(design.STORAGE_ROOT, 'ticket-designs', 'verify-event');
  fs.mkdirSync(eventDir, { recursive: true });
  const filename = `verify-${Date.now()}-${Math.random().toString(16).slice(2, 8)}.png`;
  fs.writeFileSync(path.join(eventDir, filename), buffer);
  return {
    source: 'upload',
    template: 'custom',
    file_path: `${design.DESIGN_URL_PREFIX}/verify-event/${filename}`,
    content_type: 'image/png',
    orientation: 'landscape',
    width: size?.width ?? null,
    height: size?.height ?? null,
    ...overrides,
  };
};

const writePdf = (name, buffer) => {
  fs.writeFileSync(path.join(OUT_DIR, name), buffer);
  return { file: name, bytes: buffer.length };
};

const main = async () => {
  fs.mkdirSync(OUT_DIR, { recursive: true });
  const manifest = { generated_at: new Date().toISOString(), tickets: [] };

  const emit = async (name, ticket, note) => {
    const pdf = await design.buildTicketPdf(ticket);
    const info = writePdf(name, pdf);
    manifest.tickets.push({
      ...info, note, token: rawTokenFor(ticket), ticket_id: ticket.id, ticket_code: ticket.ticket_code,
    });
    console.log(`${name}  ${(info.bytes / 1024).toFixed(1)} KB  ${note}`);
  };

  // 1. Desain default, nama acara pendek.
  await emit('01-default-landscape.pdf', { ...baseTicket }, 'default landscape, judul pendek');

  // 2. Nama acara panjang (harus mengecil/membungkus tanpa keluar kanvas).
  await emit('02-long-title.pdf', {
    ...baseTicket,
    event_title: 'Konferensi Nasional Teknologi Informasi dan Sistem Informasi Kesehatan 2026',
  }, 'default landscape, judul panjang');

  // 3. Orientasi portrait.
  await emit('03-default-portrait.pdf', {
    ...baseTicket, event_ticket_orientation: 'portrait',
  }, 'default portrait');

  // 4. Desain kustom (gambar referensi) + tata letak default.
  await emit('04-custom-artwork.pdf', {
    ...baseTicket, event_ticket_design: customDesignFrom(REFERENCE),
  }, 'artwork kustom + tata letak default');

  // 5. Konfigurasi tata letak kustom: QR dipindah & diperbesar, judul diperkecil.
  await emit('05-custom-layout.pdf', {
    ...baseTicket,
    event_ticket_design: {
      orientation: 'landscape',
      panel_split: 0.558,
      text_width: 0.6,
      title: { x: 0.0445, y: 0.0286, font_size: 40, bold: true },
      ticket_id: { x: 0.0445, y: 0.132, font_size: 26, bold: false },
      instruction: { x: 0.0445, y: 0.196, font_size: 26, bold: false },
      qr: { x: 0.55, y: 0.55, size: 0.3 },
    },
  }, 'tata letak kustom: QR kanan bawah, huruf lebih kecil');

  // 6-7. Dua peserta berbeda: ID tiket & QR harus berbeda.
  await emit('06-ticket-a.pdf', {
    ...baseTicket, id: 'aaaaaaaa-1111-4111-8111-111111111111', ticket_code: 'ETK-AAA111',
  }, 'peserta A');
  await emit('07-ticket-b.pdf', {
    ...baseTicket, id: 'bbbbbbbb-2222-4222-8222-222222222222', ticket_code: 'ETK-BBB222',
  }, 'peserta B');

  // 8. Template desain (penanda area, tanpa teks contoh).
  const template = await design.buildTemplatePdf({ title: 'Template Desain Tiket', orientation: 'landscape' });
  writePdf('08-template-landscape.pdf', template);
  console.log('08-template-landscape.pdf  template kanvas + penanda elemen');

  const templatePortrait = await design.buildTemplatePdf({
    title: 'Template Desain Tiket', orientation: 'portrait',
  });
  writePdf('08-template-portrait.pdf', templatePortrait);
  console.log('08-template-portrait.pdf  template kanvas portrait + penanda elemen');

  // 9. Tata letak tersimpan tanpa berkas gambar (berkas hilang / hanya atur posisi).
  await emit('09-layout-only.pdf', {
    ...baseTicket,
    event_ticket_design: {
      orientation: 'landscape',
      title: { x: 0.06, y: 0.06, font_size: 34, bold: true },
      ticket_id: { x: 0.06, y: 0.18, font_size: 20, bold: false },
      instruction: { x: 0.06, y: 0.25, font_size: 20, bold: false },
      qr: { x: 0.06, y: 0.42, size: 0.3 },
    },
  }, 'konfigurasi tata letak tanpa berkas gambar');

  fs.writeFileSync(path.join(OUT_DIR, 'manifest.json'), `${JSON.stringify(manifest, null, 2)}\n`);
  console.log(`\n${manifest.tickets.length} PDF + template ditulis ke ${OUT_DIR}`);
};

main().catch((error) => {
  console.error(error);
  process.exit(1);
});
