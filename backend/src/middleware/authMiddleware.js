const jwt = require('jsonwebtoken');
const asyncHandler = require('express-async-handler');
const config = require('../config/env');
const { getOne } = require('../config/db');
const { hashToken } = require('../services/authService');

const extractToken = (req) => {
  const header = req.headers.authorization;
  if (!header || !header.startsWith('Bearer')) return null;
  const token = header.split(' ')[1];
  return token && token.trim() ? token.trim() : null;
};

/**
 * Verifikasi token lalu muat profil terbaru dari PostgreSQL.
 * Role dan status akun tidak pernah dipercaya dari klaim JWT lama.
 * @returns {Promise<{user?: object, error?: string}>}
 */
const resolveAuthenticatedUser = async (token) => {
  let decoded;
  try {
    decoded = jwt.verify(token, config.jwtSecret);
  } catch (_) {
    return { error: 'Not authorized, token failed' };
  }

  const user = await getOne(
    'SELECT id, name, email, role, disabled_at FROM profiles WHERE id = $1',
    [decoded.id]
  );
  if (!user) return { error: 'Not authorized, user no longer exists' };
  if (user.disabled_at) return { error: 'This account is disabled' };

  const revoked = await getOne(
    'SELECT token_hash FROM revoked_tokens WHERE token_hash = $1',
    [hashToken(token)]
  );
  if (revoked) return { error: 'This session has been revoked' };

  return {
    user: { id: user.id, name: user.name, email: user.email, role: user.role },
  };
};

/**
 * Protect routes - verify JWT token from Authorization header
 * Usage: router.get('/protected', authMiddleware, controller)
 */
const authMiddleware = asyncHandler(async (req, res, next) => {
  const token = extractToken(req);
  if (!token) {
    res.status(401);
    throw new Error('Not authorized, no token');
  }

  const { user, error } = await resolveAuthenticatedUser(token);
  if (!user) {
    res.status(401);
    throw new Error(error);
  }

  req.user = user;
  next();
});

/**
 * Optional auth - attach user if token valid, but don't require it
 */
const optionalAuth = asyncHandler(async (req, res, next) => {
  const token = extractToken(req);
  if (!token) {
    req.user = null;
    return next();
  }

  try {
    const { user } = await resolveAuthenticatedUser(token);
    req.user = user || null;
  } catch (_) {
    // Token invalid/expired: guest tetap boleh melanjutkan pada route publik.
    req.user = null;
  }
  return next();
});

module.exports = { authMiddleware, optionalAuth };