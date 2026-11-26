const { body } = require('express-validator');

/**
 * Kumpulan validator request (express-validator) untuk seluruh domain.
 *
 * Sebelumnya terpisah pada `authValidator.js` dan `ticketValidator.js`. Kedua
 * berkas digabung di sini karena isinya kecil, saling sejenis, dan selalu
 * dipakai bersama `validationMiddleware`. Nama export tidak berubah sehingga
 * pemanggil lama hanya perlu menyesuaikan path import.
 */

const registerValidator = [
  body('name').notEmpty().withMessage('Name is required'),
  body('email').isEmail().withMessage('Valid email is required'),
  body('password').isLength({ min: 6 }).withMessage('Password must be at least 6 characters'),
];

const loginValidator = [
  body('email').isEmail().withMessage('Valid email is required'),
  body('password').notEmpty().withMessage('Password is required'),
];

const createTicketValidator = [
  body('event_id').notEmpty().withMessage('Event ID is required'),
];

/**
 * Scanner mengirim token QR opaque pada `token` (aplikasi Flutter) atau kode
 * tiket human-readable pada `ticket_code` (input manual). Keduanya harus
 * diterima; sebelumnya hanya `ticket_code` yang lolos sehingga seluruh scan
 * kamera ditolak 400.
 */
const verifyTicketValidator = [
  body().custom((value) => {
    const token = typeof value?.token === 'string' ? value.token.trim() : '';
    const ticketCode = typeof value?.ticket_code === 'string' ? value.ticket_code.trim() : '';
    if (!token && !ticketCode) {
      throw new Error('Token tiket atau kode tiket wajib dikirim');
    }
    return true;
  }),
];

module.exports = {
  registerValidator,
  loginValidator,
  createTicketValidator,
  verifyTicketValidator,
};
