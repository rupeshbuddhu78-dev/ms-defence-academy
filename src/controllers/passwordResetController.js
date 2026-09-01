const User = require('../models/User');
const Otp = require('../models/Otp');
const { sendOtpEmail } = require('../utils/mailer');

exports.forgotPassword = async (req, res, next) => {
  try {
    const { emailOrMobile } = req.body;
    if (!emailOrMobile) {
      return res.status(400).json({
        success: false,
        message: 'Email or mobile is required',
        code: 'VALIDATION_ERROR'
      });
    }

    const user = await User.findOne({
      $or: [
        { email: emailOrMobile.toLowerCase() },
        { mobile: emailOrMobile }
      ]
    });

    // Always generic response (anti-enumeration)
    const generic = {
      success: true,
      message: 'If an account exists, an OTP has been sent to the registered email.'
    };

    if (!user) {
      return res.status(200).json(generic);
    }

    const identifier = (user.email || user.mobile || emailOrMobile).toLowerCase();
    const { code } = await Otp.createOtp(identifier, 'PASSWORD_RESET');

    if (user.email) {
      try {
        await sendOtpEmail(user.email, code);
      } catch (e) {
        console.error('SMTP error:', e.message);
        if (process.env.NODE_ENV !== 'production') {
          console.log(`[DEV OTP fallback] ${identifier} => ${code}`);
        } else {
          return res.status(500).json({
            success: false,
            message: 'Unable to send OTP email. Contact admin.',
            code: 'SMTP_ERROR'
          });
        }
      }
    } else if (process.env.NODE_ENV !== 'production') {
      console.log(`[DEV OTP mobile] ${identifier} => ${code}`);
    }

    const response = { ...generic };
    if (process.env.NODE_ENV !== 'production') {
      response.devHint = 'Check server logs for OTP in development';
    }
    res.status(200).json(response);
  } catch (e) { next(e); }
};

exports.verifyOtp = async (req, res, next) => {
  try {
    const { emailOrMobile, otp } = req.body;
    if (!emailOrMobile || !otp) {
      return res.status(400).json({
        success: false,
        message: 'Email/mobile and OTP are required',
        code: 'VALIDATION_ERROR'
      });
    }

    const user = await User.findOne({
      $or: [
        { email: emailOrMobile.toLowerCase() },
        { mobile: emailOrMobile }
      ]
    });
    if (!user) {
      return res.status(400).json({ success: false, message: 'Invalid OTP', code: 'INVALID_OTP' });
    }

    const identifier = (user.email || user.mobile || emailOrMobile).toLowerCase();
    const record = await Otp.findOne({
      identifier,
      purpose: 'PASSWORD_RESET',
      used: false
    }).sort({ createdAt: -1 });

    if (!record) {
      return res.status(400).json({ success: false, message: 'OTP expired or not found', code: 'OTP_EXPIRED' });
    }

    const result = await record.verify(otp);
    if (!result.ok) {
      return res.status(400).json({ success: false, message: result.message, code: 'INVALID_OTP' });
    }

    // Issue short-lived reset token (reuse passwordResetToken fields)
    const crypto = require('crypto');
    const resetToken = crypto.randomBytes(32).toString('hex');
    user.passwordResetToken = crypto.createHash('sha256').update(resetToken).digest('hex');
    user.passwordResetExpires = Date.now() + 15 * 60 * 1000;
    await user.save({ validateBeforeSave: false });

    res.status(200).json({
      success: true,
      message: 'OTP verified',
      data: { resetToken }
    });
  } catch (e) { next(e); }
};

exports.resetPasswordWithToken = async (req, res, next) => {
  try {
    const { resetToken, newPassword, confirmPassword } = req.body;
    if (!resetToken || !newPassword || !confirmPassword) {
      return res.status(400).json({
        success: false,
        message: 'Token and new password are required',
        code: 'VALIDATION_ERROR'
      });
    }
    if (newPassword !== confirmPassword) {
      return res.status(400).json({
        success: false,
        message: 'Passwords do not match',
        code: 'PASSWORD_MISMATCH'
      });
    }
    if (newPassword.length < 6) {
      return res.status(400).json({
        success: false,
        message: 'Password must be at least 6 characters',
        code: 'WEAK_PASSWORD'
      });
    }

    const crypto = require('crypto');
    const hashed = crypto.createHash('sha256').update(resetToken).digest('hex');
    const user = await User.findOne({
      passwordResetToken: hashed,
      passwordResetExpires: { $gt: Date.now() }
    }).select('+passwordResetToken +passwordResetExpires');

    if (!user) {
      return res.status(400).json({
        success: false,
        message: 'Invalid or expired reset token',
        code: 'INVALID_TOKEN'
      });
    }

    user.password = newPassword;
    user.passwordResetToken = undefined;
    user.passwordResetExpires = undefined;
    user.mustChangePassword = false;
    user.failedLoginAttempts = 0;
    user.lockUntil = undefined;
    await user.save();

    res.status(200).json({
      success: true,
      message: 'Password reset successful. Please login.'
    });
  } catch (e) { next(e); }
};
