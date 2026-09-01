const notFound = (req, res, next) => {
  res.status(404).json({
    success: false,
    message: `Route not found: ${req.originalUrl}`,
    code: 'NOT_FOUND'
  });
};

const errorHandler = (err, req, res, next) => {
  console.error('API Error:', err.message);
  if (process.env.NODE_ENV !== 'production') {
    console.error(err.stack);
  }

  let statusCode = res.statusCode && res.statusCode !== 200 ? res.statusCode : 500;
  let message = err.message || 'Internal Server Error';
  let code = err.code || 'SERVER_ERROR';

  if (err.code === 11000) {
    statusCode = 409;
    const field = Object.keys(err.keyPattern || {})[0] || 'field';
    message = `Duplicate value for ${field}`;
    code = 'DUPLICATE_KEY';
  }

  if (err.name === 'ValidationError') {
    statusCode = 422;
    message = Object.values(err.errors).map(e => e.message).join(', ');
    code = 'VALIDATION_ERROR';
  }

  if (err.name === 'CastError') {
    statusCode = 400;
    message = 'Invalid ID format';
    code = 'INVALID_ID';
  }

  // Rate limit validation errors
  if (err.code === 'ERR_ERL_UNEXPECTED_X_FORWARDED_FOR') {
    statusCode = 500;
    message = 'Server proxy configuration error. Please contact admin.';
    code = 'PROXY_CONFIG';
  }

  res.status(statusCode).json({
    success: false,
    message,
    code
  });
};

module.exports = { notFound, errorHandler };
