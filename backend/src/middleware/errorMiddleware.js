const logger = require('../utils/logger');

const DATABASE_ERRORS = {
  '22P02': { status: 400, message: 'Invalid identifier or value format' },
  '23505': { status: 409, message: 'Resource already exists' },
  '23503': { status: 409, message: 'Related resource does not exist or is still in use' },
  '23514': { status: 400, message: 'Value violates a database constraint' },
  '22001': { status: 400, message: 'Value is too long' },
};

const safePath = (req) => String(req.originalUrl || req.url || req.path || '/').split('?')[0];

const errorMiddleware = (err, req, res, next) => {
  if (err && err.message === 'Origin not allowed by CORS') {
    return res.status(403).json({ success: false, message: 'Origin not allowed' });
  }
  const databaseError = DATABASE_ERRORS[err.code];
  const businessError = err.code === 'P0001';
  const oversized = err.type === 'entity.too.large';
  const status = err.statusCode || databaseError?.status || (businessError ? 400 : null)
    || (oversized ? 413 : null) || (res.statusCode === 200 ? 500 : res.statusCode);
  const message = databaseError ? databaseError.message
    : oversized ? 'Request body too large'
      : businessError ? err.message
        : status >= 500 ? 'Internal Server Error' : (err.message || 'Request failed');

  const metadata = {
    method: req.method || 'UNKNOWN',
    path: safePath(req),
    status,
    error: err.message,
    code: err.code,
    ...(status >= 500 ? { stack: err.stack } : {}),
  };
  if (status >= 500) logger.error('unhandled_error', metadata);
  else logger.warn('request_error', metadata);
  return res.status(status).json({ success: false, message });
};

module.exports = errorMiddleware;
