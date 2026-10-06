class HttpError extends Error { constructor(status, message, details) { super(message); this.status = status; this.details = details; } }
const asyncHandler = fn => (req, res, next) => Promise.resolve(fn(req, res, next)).catch(next);
function notFound(_req, _res, next) { next(new HttpError(404, 'Route not found')); }
function errorHandler(err, _req, res, _next) {
  let status = err.status || 500;
  let message = err.message || 'Internal server error';
  if (err.name === 'ValidationError' || err.name === 'ZodError') status = 400;
  if (err.code === 11000) { status = 409; message = 'A record with this value already exists'; }
  if (err.name === 'CastError') { status = 400; message = 'Invalid identifier'; }
  if (status >= 500) console.error(err);
  res.status(status).json({ ok: false, error: { message: status >= 500 && process.env.NODE_ENV === 'production' ? 'Internal server error' : message, ...(err.details ? { details: err.details } : {}) } });
}
module.exports = { HttpError, asyncHandler, notFound, errorHandler };
