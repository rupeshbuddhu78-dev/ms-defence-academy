const express = require('express');
const router = express.Router();
const {
  studentRegister,
  studentLogin,
  adminLogin,
  changePassword,
  forgotPassword: oldForgot,
  resetPassword: oldReset
} = require('../controllers/authController');
const {
  forgotPassword,
  verifyOtp,
  resetPasswordWithToken
} = require('../controllers/passwordResetController');
const { protect } = require('../middleware/authMiddleware');
const { authLimiter } = require('../middleware/rateLimiter');

router.post('/student/register', authLimiter, studentRegister);
router.post('/student/login', authLimiter, studentLogin);
router.post('/admin/login', authLimiter, adminLogin);
router.post('/change-password', protect, changePassword);

// OTP password reset
router.post('/forgot-password', authLimiter, forgotPassword);
router.post('/verify-otp', authLimiter, verifyOtp);
router.post('/reset-password', authLimiter, resetPasswordWithToken);

module.exports = router;
