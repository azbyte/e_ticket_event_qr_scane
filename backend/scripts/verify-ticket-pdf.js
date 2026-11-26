/**
 * Skrip verifikasi manual (bukan bagian test suite): memastikan template dan
 * tiket PDF benar-benar terbentuk, termasuk dengan desain unggahan.
 *
 * Jalankan dari `backend/`: npm run verify:ticket-pdf
 * (hasil ditulis ke `backend/_verify-out/`, folder diabaikan git)
 */
const fs = require('node:fs');
const path = require('node:path');
const svc = require('../src/services/ticketDesignService');

const outDir = path.join(__dirname, '..', '_verify-out');
fs.mkdirSync(outDir, { recursive: true });

const ticket = {
  id: '11111111-1111-4111-8111-111111111111',
  ticket_code: 'TKT-VERIFY-001',
  issued_at: new Date('2026-11-26T10:00:00Z').toISOString(),
  purchased_at: new Date('2026-11-26T10:00:00Z').toISOString(),
  event_title: 'Konser Verifikasi',
  attendee_name: 'Peserta Verifikasi',
  ticket_type_name: 'VIP',
  event_date: new Date('2026-12-01T12:00:00Z').toISOString(),
  location: 'Jakarta Convention Center',
  order_number: 'ORD-VERIFY-1',
};

(async () => {
  const template = await svc.buildTemplatePdf({ title: 'Konser Verifikasi' });
  fs.writeFileSync(path.join(outDir, 'template.pdf'), template);

  const plain = await svc.buildTicketPdf(ticket);
  fs.writeFileSync(path.join(outDir, 'ticket-default.pdf'), plain);

  const png = fs.readFileSync(
    path.join(__dirname, '..', 'assets', 'ticket-templates', 'ticket-template.png'),
  );
  const saved = await svc.saveDesignImage({
    eventId: ticket.event_id || 'verify-event',
    buffer: png,
    contentType: 'image/png',
  });
  const designed = await svc.buildTicketPdf({
    ...ticket,
    event_ticket_design: {
      source: 'upload',
      file_path: saved.filePath,
      content_type: 'image/png',
      qr: { x: 0.74, y: 0.25, size: 0.5 },
      info: svc.DEFAULT_INFO,
    },
  });
  fs.writeFileSync(path.join(outDir, 'ticket-designed.pdf'), designed);

  console.log(JSON.stringify({
    templateBytes: template.length,
    defaultTicketBytes: plain.length,
    designedTicketBytes: designed.length,
    designFile: saved.filePath,
  }, null, 2));
})().catch((error) => {
  console.error('FAILED', error);
  process.exitCode = 1;
});
