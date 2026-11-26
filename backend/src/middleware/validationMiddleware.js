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
      // express-validator v7 mengganti `param` menjadi `path`; `param` tetap
      // dibaca sebagai fallback agar bentuk response lama tidak berubah menjadi
      // `field: undefined` pada klien.
      errors: errors.array().map((e) => ({ field: e.path || e.param, message: e.msg })),
    });
  }
  next();
};

module.exports = validationMiddleware;
module.exports.validationMiddleware = validationMiddleware;