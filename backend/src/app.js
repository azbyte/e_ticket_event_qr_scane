const express = require('express');
const cors = require('cors');
const helmet = require('helmet');
const path = require('node:path');
const config = require('./config/env');
const { pool } = require('./config/db');
const logger = require('./utils/logger');

// Router per domain. Masing-masing di-mount pada `/api` dan mendaftarkan
// sub-path-nya sendiri (mis. `/events`, `/admin`), sehingga path API tetap sama
// seperti sebelum penggabungan. Lihat `src/routes/*.js`.
const authRoutes = require('./routes/auth');
const eventsRoutes = require('./routes/events');
const ordersRoutes = require('./routes/orders');
const adminRoutes = require('./routes/admin');
const organizerRoutes = require('./routes/organizer');

const errorMiddleware = require('./middleware/errorMiddleware');
const notFoundMiddleware = require('./middleware/notFoundMiddleware');
const requestLogger = require('./middleware/requestLogger');
const { globalLimiter } = require('./middleware/rateLimitMiddleware');

const app = express();
app.set('trust proxy', 1);
app.disable('x-powered-by');
app.use(helmet({ contentSecurityPolicy: false, crossOriginResourcePolicy: { policy: 'cross-origin' } }));

const allowedOrigins = Array.isArray(config.corsOrigin)
  ? config.corsOrigin
  : (config.corsOrigin === '*' ? '*' : [config.corsOrigin]);

// Pada development, `flutter run -d chrome` memakai port acak (mis.
// http://localhost:54321). Tanpa pengecualian ini, browser memblokir seluruh
// request login/registrasi karena origin tidak ada di ALLOWED_ORIGINS.
// Hanya loopback yang diizinkan dan hanya di luar production.
const isDevelopment = config.nodeEnv !== 'production';
const LOOPBACK_ORIGIN = /^https?:\/\/(localhost|127\.0\.0\.1|\[::1\])(:\d+)?$/;

const isOriginAllowed = (origin) => {
  if (!origin) return true; // same-origin / non-browser client (emulator, curl)
  if (allowedOrigins === '*') return true;
  if (allowedOrigins.includes(origin)) return true;
  if (isDevelopment && LOOPBACK_ORIGIN.test(origin)) return true;
  return false;
};

app.use(cors({
  origin(origin, callback) {
    if (isOriginAllowed(origin)) return callback(null, true);
    return callback(new Error('Origin not allowed by CORS'));
  },
  credentials: false,
  methods: ['GET', 'POST', 'PUT', 'PATCH', 'DELETE', 'OPTIONS'],
  allowedHeaders: ['Content-Type', 'Authorization', 'X-Order-Access-Token', 'Idempotency-Key'],
  maxAge: 600,
}));
app.use(requestLogger);
app.use(express.json({ limit: config.maxJsonBody }));
app.use(express.urlencoded({ extended: false, limit: config.maxJsonBody }));

// Media publik: file desain tiket yang diunggah Organizer. Nama file dibuat
// server (UUID) sehingga tidak dapat ditebak/di-traversal; tidak ada data
// sensitif pada gambar desain.
app.use(
  '/media',
  express.static(path.join(__dirname, '..', 'storage'), {
    fallthrough: true,
    maxAge: '1h',
    index: false,
    dotfiles: 'deny',
  }),
);

app.get('/health', async (req, res) => {
  try {
    await pool.query('SELECT 1');
    res.status(200).json({ success: true, message: 'Server is running', database: 'connected', timestamp: new Date().toISOString() });
  } catch (error) {
    logger.error('health_check_db_failed', { error: error.message });
    res.status(503).json({ success: false, message: 'Database unavailable', database: 'disconnected', timestamp: new Date().toISOString() });
  }
});

app.use('/api', globalLimiter);

// Router per domain. Semua di-mount pada `/api`; masing-masing mendaftarkan
// sub-path internalnya sehingga path API identik dengan konfigurasi sebelumnya
// (mis. `/api/auth/login`, `/api/events/public`, `/api/admin/overview`).
app.use('/api', authRoutes);
app.use('/api', eventsRoutes);
app.use('/api', ordersRoutes);
app.use('/api', adminRoutes);
app.use('/api', organizerRoutes);

app.use(notFoundMiddleware);
app.use(errorMiddleware);

module.exports = app;
