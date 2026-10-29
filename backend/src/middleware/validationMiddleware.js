const { validationResult } = require('express-validator');

/**
 * Validate request body using express-validator chains
 * Usage: router.post('/login', [validators], validationMiddleware, controller)
 */
const validationMiddleware = (req, res, next) => {
  const errors = validationResult(req);
  if (!errors.isEmpty()) {
    return res.status(400).json({
      success: false,
      message: 'Validation failed',
      errors: errors.array().map((e) => ({ field: e.param, message: e.msg })),
    });
  }
  next();
};

module.exports = validationMiddleware;