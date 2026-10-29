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

const validateTicketCode = (code) => {
  return code && code.startsWith('TKT-');
};

module.exports = { validateEmail, validatePassword, validateTicketCode };