const rateLimit = require('express-rate-limit');

const common = {
  standardHeaders: true,
  legacyHeaders: false,
  validate: false  // disable all validations (fixes Render X-Forwarded-For crash)
};

const globalLimiter = rateLimit({
  ...common,
  windowMs: 15 * 60 * 1000,
  max: 500,
  message: {
    success: false,
    message: 'Too many requests. Please try again later.',
    code: 'RATE_LIMIT'
  }
});

const authLimiter = rateLimit({
  ...common,
  windowMs: 15 * 60 * 1000,
  max: 50,
  message: {
    success: false,
    message: 'Too many login attempts. Please try again after 15 minutes.',
    code: 'AUTH_RATE_LIMIT'
  }
});

const attendanceLimiter = rateLimit({
  ...common,
  windowMs: 1 * 60 * 1000,
  max: 60,
  message: {
    success: false,
    message: 'Too many attendance requests.',
    code: 'ATTENDANCE_RATE_LIMIT'
  }
});

const paymentLimiter = rateLimit({
  ...common,
  windowMs: 5 * 60 * 1000,
  max: 20,
  message: {
    success: false,
    message: 'Too many payment requests.',
    code: 'PAYMENT_RATE_LIMIT'
  }
});

module.exports = {
  globalLimiter,
  authLimiter,
  attendanceLimiter,
  paymentLimiter
};
