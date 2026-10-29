/**
 * 404 Not Found middleware
 */
const notFoundMiddleware = (req, res, next) => {
  res.status(404);
  next(new Error(`Not Found - ${req.originalUrl}`));
};

module.exports = notFoundMiddleware;