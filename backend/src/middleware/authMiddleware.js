const jwt = require('jsonwebtoken');
const config = require('../config/env');
const { supabaseAdmin } = require('../config/supabase');
const asyncHandler = require('express-async-handler');

/**
 * Protect routes - verify JWT token from Authorization header
 * Usage: router.get('/protected', authMiddleware, controller)
 */
const authMiddleware = asyncHandler(async (req, res, next) => {
  let token;

  if (
    req.headers.authorization &&
    req.headers.authorization.startsWith('Bearer')
  ) {
    token = req.headers.authorization.split(' ')[1];
  }

  if (!token) {
    res.status(401);
    throw new Error('Not authorized, no token');
  }

  let decoded;
  try {
    decoded = jwt.verify(token, config.jwtSecret);
  } catch (error) {
    res.status(401);
    throw new Error('Not authorized, token failed');
  }

  const { data: user, error } = await supabaseAdmin
      .from('profiles')
      .select('id, email, role, disabled_at')
      .eq('id', decoded.id)
      .maybeSingle();

  if (error || !user) {
    res.status(401);
    throw new Error('Not authorized, user no longer exists');
  }
  if (user.disabled_at) {
    res.status(401);
    throw new Error('This account is disabled');
  }
  const { data: revoked, error: revokeLookupError } = await supabaseAdmin
    .from('revoked_tokens').select('token_hash')
    .eq('token_hash', require('../services/authService').hashToken(token)).maybeSingle();
  if (revokeLookupError) throw revokeLookupError;
  if (revoked) {
    res.status(401);
    throw new Error('This session has been revoked');
  }

  // Load the current role from the database rather than trusting a role
  // retained in a potentially outdated JWT.
  req.user = user;
  next();
});

/**
 * Optional auth - attach user if token valid, but don't require it
 */
const optionalAuth = asyncHandler(async (req, res, next) => {
  let token;

  if (
    req.headers.authorization &&
    req.headers.authorization.startsWith('Bearer')
  ) {
    token = req.headers.authorization.split(' ')[1];
  }

  if (token) {
    try {
      const decoded = jwt.verify(token, config.jwtSecret);
      const { data: user } = await supabaseAdmin
        .from('profiles')
        .select('id, email, role')
        .eq('id', decoded.id)
        .maybeSingle();
      req.user = user || null;
    } catch (error) {
      // Token invalid, just ignore for optional auth
      req.user = null;
    }
  } else {
    req.user = null;
  }

  next();
});

module.exports = { authMiddleware, optionalAuth };