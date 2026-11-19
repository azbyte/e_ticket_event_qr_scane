const logger = require('../utils/logger');

/**
 * Logging request terstruktur (JSON) tanpa menulis body/header sensitif.
 * Tidak dipakai pada NODE_ENV=test agar output test tetap bersih.
 */
const requestLogger = (req, res, next) => {
  if (process.env.NODE_ENV === 'test') return next();
  const startedAt = process.hrtime.bigint();
  res.on('finish', () => {
    const durationMs = Number(process.hrtime.bigint() - startedAt) / 1e6;
    logger.info('http_request', {
      method: req.method,
      path: req.route ? req.baseUrl + req.route.path : req.originalUrl.split('?')[0],
      status: res.statusCode,
      durationMs: Math.round(durationMs * 10) / 10,
      userId: req.user?.id || null,
      role: req.user?.role || null,
      ip: req.ip,
    });
  });
  next();
};

module.exports = requestLogger;
