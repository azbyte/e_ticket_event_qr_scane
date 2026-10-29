const jwt = require('jsonwebtoken');
const config = require('../config/env');
const { supabase } = require('../config/supabase');
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

  try {
    const decoded = jwt.verify(token, config.jwtSecret);
    req.user = { id: decoded.id, email: decoded.email };
    next();
  } catch (error) {
    res.status(401);
    throw new Error('Not authorized, token failed');
  }
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
      req.user = { id: decoded.id, email: decoded.email };
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