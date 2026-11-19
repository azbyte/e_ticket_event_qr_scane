const rateLimit = require('express-rate-limit');
const config = require('../config/env');

/**
 * Rate limiting.
 *
 * Nilai dapat diatur lewat environment. Pada NODE_ENV=test limiter dimatikan
 * agar test suite tidak saling mengganggu, kecuali `RATE_LIMIT_FORCE=true`
 * (dipakai test khusus yang memang menguji pembatasan).
 */
const enabled = process.env.NODE_ENV !== 'test' || process.env.RATE_LIMIT_FORCE === 'true';

const build = ({ windowMs, max, message, keyPrefix }) => rateLimit({
  windowMs,
  max,
  standardHeaders: true,
  legacyHeaders: false,
  // Kunci per IP; `trust proxy` sudah diset di app sehingga IP asli dipakai.
  keyGenerator: (req) => `${keyPrefix}:${req.ip}`,
  handler: (req, res) => {
    res.status(429).json({
      success: false,
      message,
      retry_after_seconds: Math.ceil(windowMs / 1000),
    });
  },
  skip: () => !enabled,


});

const windowMs = config.rateLimit.windowMs;

const globalLimiter = build({
  windowMs,
  max: config.rateLimit.globalMax,
  keyPrefix: 'global',
  message: 'Terlalu banyak permintaan. Coba lagi nanti.',
});

const authLimiter = build({
  windowMs,
  max: config.rateLimit.authMax,
  keyPrefix: 'auth',
  message: 'Terlalu banyak percobaan autentikasi. Coba lagi nanti.',
});

const scanLimiter = build({
  windowMs,
  max: config.rateLimit.scanMax,
  keyPrefix: 'scan',
  message: 'Terlalu banyak pemindaian. Coba lagi nanti.',
});

const writeLimiter = build({
  windowMs,
  max: Math.max(60, Math.floor(config.rateLimit.globalMax / 4)),
  keyPrefix: 'write',
  message: 'Terlalu banyak permintaan tulis. Coba lagi nanti.',
});

module.exports = { globalLimiter, authLimiter, scanLimiter, writeLimiter, enabled };
