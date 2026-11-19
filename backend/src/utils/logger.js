/**
 * Logger terstruktur (JSON) tanpa dependensi tambahan.
 *
 * Tujuan: log dapat dibaca mesin, tidak mencetak objek mentah yang mungkin
 * memuat token/kredensial, dan tidak pernah menulis body request.
 */
const LEVELS = { debug: 10, info: 20, warn: 30, error: 40 };
const currentLevel = LEVELS[String(process.env.LOG_LEVEL || 'info').toLowerCase()] || LEVELS.info;

const REDACTED_KEYS = [
  'password', 'password_hash', 'token', 'access_token', 'order_access_token',
  'authorization', 'jwt', 'secret', 'token_hash', 'apikey', 'api_key',
];

const redact = (value, depth = 0) => {
  if (value === null || value === undefined) return value;
  if (depth > 4) return '[depth-limit]';
  if (Array.isArray(value)) return value.slice(0, 20).map((item) => redact(item, depth + 1));
  if (typeof value === 'object') {
    const out = {};
    for (const [key, item] of Object.entries(value)) {
      out[key] = REDACTED_KEYS.some((needle) => key.toLowerCase().includes(needle))
        ? '[redacted]'
        : redact(item, depth + 1);
    }
    return out;
  }
  return value;
};

const write = (level, message, meta) => {
  if (LEVELS[level] < currentLevel) return;
  const entry = {
    ts: new Date().toISOString(),
    level,
    message,
    ...(meta ? { meta: redact(meta) } : {}),
  };
  const line = JSON.stringify(entry);
  if (level === 'error') console.error(line);
  else if (level === 'warn') console.warn(line);
  else console.log(line);
};

module.exports = {
  debug: (message, meta) => write('debug', message, meta),
  info: (message, meta) => write('info', message, meta),
  warn: (message, meta) => write('warn', message, meta),
  error: (message, meta) => write('error', message, meta),
  redact,
};
