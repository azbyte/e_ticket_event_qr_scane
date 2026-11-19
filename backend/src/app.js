const express = require('express');
const cors = require('cors');
const helmet = require('helmet');
const config = require('./config/env');
const { pool } = require('./config/db');
const logger = require('./utils/logger');
const asyncHandler = require('express-async-handler');

const authRoutes = require('./routes/authRoutes');
const eventRoutes = require('./routes/eventRoutes');
const ticketRoutes = require('./routes/ticketRoutes');
const ticketTypeRoutes = require('./routes/ticketTypeRoutes');
const checkInRoutes = require('./routes/checkInRoutes');
const invitationsRoutes = require('./routes/invitationsRoutes');
const notificationRoutes = require('./routes/notificationRoutes');
const reportRoutes = require('./routes/reportRoutes');
const adminRoutes = require('./routes/adminRoutes');
const organizerRoutes = require('./routes/organizerRoutes');
const orderRoutes = require('./routes/orderRoutes');
const paymentRoutes = require('./routes/paymentRoutes');
const planRoutes = require('./routes/planRoutes');
const subscriptionRoutes = require('./routes/subscriptionRoutes');
const revenueRoutes = require('./routes/revenueRoutes');
const organizerProfileController = require('./controllers/organizerProfileController');
const emailService = require('./services/emailService');
const { authMiddleware } = require('./middleware/authMiddleware');
const allowRoles = require('./middleware/roleMiddleware');
const errorMiddleware = require('./middleware/errorMiddleware');
const notFoundMiddleware = require('./middleware/notFoundMiddleware');
const requestLogger = require('./middleware/requestLogger');
const { globalLimiter, authLimiter, writeLimiter } = require('./middleware/rateLimitMiddleware');

const app = express();
app.set('trust proxy', 1);
app.disable('x-powered-by');
app.use(helmet({ contentSecurityPolicy: false, crossOriginResourcePolicy: { policy: 'cross-origin' } }));

const allowedOrigins = Array.isArray(config.corsOrigin)
  ? config.corsOrigin
  : (config.corsOrigin === '*' ? '*' : [config.corsOrigin]);
app.use(cors({
  origin(origin, callback) {
    if (!origin || allowedOrigins === '*' || allowedOrigins.includes(origin)) return callback(null, true);
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
app.use('/api/auth', authLimiter, authRoutes);
app.use('/api/admin', adminRoutes);
app.use('/api/organizer', organizerRoutes);
app.use('/api/events', eventRoutes);
app.use('/api/plans', planRoutes);
app.use('/api/subscriptions', subscriptionRoutes);
app.use('/api/revenue', revenueRoutes);
app.get('/api/organizer/profile', authMiddleware, allowRoles('organizer'), organizerProfileController.getMyProfile);
app.put('/api/organizer/profile', authMiddleware, allowRoles('organizer'), organizerProfileController.updateMyProfile);
app.post('/api/admin/email/retry', authMiddleware, allowRoles('admin'), asyncHandler(async (req, res) => {
  const results = await emailService.retryPendingDeliveries(Math.min(Number(req.body.limit) || 20, 100));
  res.json({
    success: true,
    attempted: results.length,
    sent: results.filter((item) => item.status === 'SENT').length,
    pending: results.filter((item) => item.status === 'NOT_CONFIGURED').length,
    failed: results.filter((item) => item.status === 'FAILED').length,
    results,
  });
}));
app.use('/api/tickets', ticketRoutes);
app.use('/api/ticket-types', ticketTypeRoutes);
app.use('/api/check-ins', checkInRoutes);
app.use('/api/invitations', invitationsRoutes);
app.use('/api/notifications', notificationRoutes);
app.use('/api/support-reports', reportRoutes);
app.use('/api/orders', writeLimiter, orderRoutes);
app.use('/api/payments', writeLimiter, paymentRoutes);

app.use(notFoundMiddleware);
app.use(errorMiddleware);

module.exports = app;
