/**
 * Simple utility validators
 */

const validateEmail = (email) => {
  const re = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
  return re.test(email);
};

const validatePassword = (password) => {
  return password && password.length >= 6;
};

/**
 * Format kode tiket yang sah:
 *  - `ETK-XXXXXX` : ID publik ringkas (format saat ini, alfabet Crockford),
 *  - `TKT-<32 hex>`: kode lama buatan RPC database (tiket yang belum dirapikan).
 */
const TICKET_CODE_PATTERN = /^(ETK-[0-9A-HJKMNP-TV-Z]{6}|TKT-[0-9a-fA-F]{32})$/;

const validateTicketCode = (code) => TICKET_CODE_PATTERN.test(String(code ?? '').trim());

module.exports = { validateEmail, validatePassword, validateTicketCode };