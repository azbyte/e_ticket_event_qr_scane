require('dotenv').config();

const requiredEnv = ['DATABASE_URL', 'JWT_SECRET'];

const missingEnv = requiredEnv.filter((key) => !process.env[key]);
  if (missingEnv.length > 0) {
    console.error('❌ Missing required environment variables:');
    missingEnv.forEach((key) => {
      console.error(`   - ${key}`);
    });
    console.error(
      '   Backend cannot start. Set these in your .env file (never commit .env).'
    );
    process.exit(1);
  }

// CORS_ORIGIN dipertahankan untuk kompatibilitas; ALLOWED_ORIGINS dipakai
// sebagai daftar origin terpisah koma pada deployment saat ini.
const configuredOrigins = String(
  process.env.CORS_ORIGIN || process.env.ALLOWED_ORIGINS || ''
).trim();
const corsOrigins = configuredOrigins
  ? configuredOrigins.split(',').map((origin) => origin.trim()).filter(Boolean)
  : [];

module.exports = {
  port: process.env.PORT || 5000,
  host: process.env.HOST || '0.0.0.0',
  nodeEnv: process.env.NODE_ENV || 'development',
  databaseUrl: process.env.DATABASE_URL,
  directUrl: process.env.DIRECT_URL,
  jwtSecret: process.env.JWT_SECRET,
  jwtExpiresIn: process.env.JWT_EXPIRES_IN || '7d',
  // Secret khusus token QR tiket. Fallback ke JWT_SECRET agar deployment lama
  // tetap berjalan, tetapi produksi wajib memakai nilai terpisah.
  ticketTokenSecret: process.env.TICKET_TOKEN_SECRET || process.env.JWT_SECRET,
  ticketTokenSecretIsDedicated: Boolean(process.env.TICKET_TOKEN_SECRET),
  corsOrigin: corsOrigins.length === 0 ? '*' : (corsOrigins.length === 1 ? corsOrigins[0] : corsOrigins),
  simulatedPaymentsEnabled: process.env.SIMULATED_PAYMENTS_ENABLED === 'true',
  seedDemoAccounts: process.env.SEED_DEMO_ACCOUNTS === 'true',
  // URL publik aplikasi, dipakai untuk tautan e-ticket di email.
  appPublicUrl: (process.env.APP_PUBLIC_URL || 'http://localhost:5000').replace(/\/$/, ''),
  // Konfigurasi email TIDAK dibaca di sini: `src/services/emailService.js`
  // membacanya langsung dari environment setiap kali dipakai, sehingga
  // perubahan .env tidak "nyangkut" dan tidak ada alamat pengirim default
  // palsu yang dapat dipakai tanpa sengaja.
  rateLimit: {
    windowMs: Number(process.env.RATE_LIMIT_WINDOW_MS || 15 * 60 * 1000),
    authMax: Number(process.env.RATE_LIMIT_AUTH_MAX || 20),
    scanMax: Number(process.env.RATE_LIMIT_SCAN_MAX || 600),
    globalMax: Number(process.env.RATE_LIMIT_GLOBAL_MAX || 1200),
  },
  maxJsonBody: process.env.MAX_JSON_BODY || '2mb',
};