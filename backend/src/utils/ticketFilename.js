/**
 * Nama file e-tiket PDF.
 *
 * Format wajib (dipakai pada lampiran email DAN unduhan manual):
 *   `E-TIKET Nama Peserta.pdf`
 *
 * Aturan:
 *  - `E-TIKET` diikuti SATU spasi, lalu nama peserta apa adanya,
 *  - spasi biasa (bukan `_`/`-`) sebagai pemisah kata,
 *  - tanpa prefix lain (`ticket_`, `invoice_`, kode tiket, dsb.),
 *  - ekstensi `.pdf`.
 *
 * Karakter yang tidak sah pada nama file (`\ / : * ? " < > |`, karakter
 * kontrol) diganti spasi agar file tetap dapat disimpan di Windows, macOS,
 * Android, dan web — nama peserta tidak diubah selain karakter terlarang itu.
 */
const FILENAME_PREFIX = 'E-TIKET';
const MAX_NAME_LENGTH = 80;
const FALLBACK_NAME = 'Peserta';

/** Bersihkan nama peserta agar aman dipakai sebagai nama file. */
const sanitizeParticipantName = (value) => String(value ?? '')
  .normalize('NFC')
  // Karakter kontrol & pemisah baris.
  .replace(/[\u0000-\u001f\u007f]+/g, ' ')
  // Karakter terlarang pada filesystem.
  .replace(/[\\/:*?"<>|]+/g, ' ')
  // Spasi berlebih / spasi tak terlihat di ujung.
  .replace(/\s+/g, ' ')
  .trim()
  .slice(0, MAX_NAME_LENGTH)
  .trim();

/**
 * Nama file PDF e-tiket: `E-TIKET <Nama Peserta>.pdf`.
 * @param {string} attendeeName nama peserta dari database
 */
const ticketPdfFilename = (attendeeName) => {
  const name = sanitizeParticipantName(attendeeName) || FALLBACK_NAME;
  return `${FILENAME_PREFIX} ${name}.pdf`;
};

/**
 * Nilai header `Content-Disposition` untuk unduhan PDF.
 *
 * Menyertakan `filename` ASCII (fallback untuk klien lama) dan `filename*`
 * UTF-8 (RFC 5987) agar nama peserta beraksen/non-Latin tetap benar.
 */
const pdfContentDisposition = (attendeeName) => {
  const filename = ticketPdfFilename(attendeeName);
  const ascii = filename
    .normalize('NFKD')
    .replace(/[^\x20-\x7e]/g, '')
    .replace(/["\\]/g, '')
    .replace(/\s+/g, ' ')
    .trim() || `${FILENAME_PREFIX} ${FALLBACK_NAME}.pdf`;
  return `attachment; filename="${ascii}"; filename*=UTF-8''${encodeURIComponent(filename)}`;
};

module.exports = {
  FILENAME_PREFIX,
  MAX_NAME_LENGTH,
  sanitizeParticipantName,
  ticketPdfFilename,
  pdfContentDisposition,
};
