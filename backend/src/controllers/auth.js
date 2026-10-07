const jwt = require('jsonwebtoken');
const bcrypt = require('bcryptjs');
const User = require('../models/User');
const StudentProfile = require('../models/StudentProfile');
const StudentApplication = require('../models/StudentApplication');
const PasswordResetOtp = require('../models/PasswordResetOtp');
const { HttpError } = require('../middleware/errors');
const security = require('./security');

function normalizedPhone(value) {
  const digits = String(value || '').replace(/\D/g, '');
  if (digits.length === 10) return digits;
  if (digits.length === 12 && digits.startsWith('91')) return digits.slice(2);
  return null;
}

async function login(req, res) {
  const identifier = String(req.body.identifier || req.body.email || '').trim();
  const password = String(req.body.password || '');
  if (!identifier || !password) throw new HttpError(400, 'Email or phone and password are required');
  const phone = normalizedPhone(identifier);
  const clauses = [{ email: identifier.toLowerCase() }];
  if (phone) clauses.push({ phone });
  const user = await User.findOne({ $or: clauses }).select('+passwordHash');
  if (!user) {
    const application = await StudentApplication.findOne({
      email: identifier.toLowerCase(),
      status: { $in: ['pending', 'rejected'] },
    }).select('+passwordHash').populate('batchId', 'name course');
    if (application && await bcrypt.compare(password, application.passwordHash)) {
      const safe = application.toObject();
      delete safe.passwordHash;
      await security.record(req, 'application_login', { email: application.email, details: application.status });
      return res.json({ ok: true, data: { pendingApplication: true, application: safe } });
    }
  }
  if (!user || !user.isActive || !(await user.comparePassword(password))) {
    await security.record(req, 'login_failed', { email: identifier.toLowerCase(), details: 'Invalid credentials' });
    throw new HttpError(401, 'Phone/email or password is incorrect');
  }
  await security.record(req, 'login_success', { userId: user._id, role: user.role, email: user.email });
  const token = jwt.sign({ sub: user.id }, process.env.JWT_SECRET, {
    expiresIn: process.env.JWT_EXPIRES_IN || '30d',
    issuer: 'ms-defence-academy',
  });
  const profile = user.role === 'student'
    ? await StudentProfile.findOne({ userId: user.id }).select('-aadhaarEncrypted -aadhaarLast4').populate('batchId')
    : null;
  res.json({ ok: true, data: { token, user, profile } });
}

async function me(req, res) {
  const profile = req.user.role === 'student'
    ? await StudentProfile.findOne({ userId: req.user.id }).select('-aadhaarEncrypted -aadhaarLast4').populate('batchId')
    : null;
  res.json({ ok: true, data: { user: req.user, profile } });
}

async function changePassword(req, res) {
  const password = String(req.body.newPassword || '');
  if (password.length < 10 || password.length > 72) {
    throw new HttpError(400, 'New password must be between 10 and 72 characters');
  }
  const user = await User.findById(req.user.id).select('+passwordHash');
  if (!user || !user.isActive) throw new HttpError(401, 'Account is unavailable');
  if (!user.mustChangePassword) throw new HttpError(409, 'Password change is not required');
  if (await user.comparePassword(password)) throw new HttpError(400, 'Choose a password different from your temporary phone password');
  user.passwordHash = await User.hashPassword(password);
  user.mustChangePassword = false;
  await user.save();
  res.json({ ok: true, data: { user } });
}

async function updateAdminAccount(req, res) {
  const email = String(req.body.email || '').trim().toLowerCase();
  const password = String(req.body.newPassword || '');
  if (!email || !email.includes('@') || !email.includes('.') || email.length > 254) {
    throw new HttpError(400, 'Enter a valid Gmail or email address');
  }
  if (password.length < 10 || password.length > 72) {
    throw new HttpError(400, 'New password must be between 10 and 72 characters');
  }
  const conflict = await User.exists({ _id: { $ne: req.user.id }, email });
  if (conflict) throw new HttpError(409, 'Another account already uses this email');
  const user = await User.findById(req.user.id).select('+passwordHash');
  if (!user || !user.isActive || user.role !== 'admin') {
    throw new HttpError(403, 'Only an active admin can update this account');
  }
  user.email = email;
  user.passwordHash = await User.hashPassword(password);
  user.mustChangePassword = false;
  await user.save();
  res.json({ ok: true, data: { user } });
}

async function requestPasswordReset(req, res) {
  const email = security.cleanEmail(req.body.email);
  if (!email || !email.includes('@')) throw new HttpError(400, 'Enter the registered email address');
  const user = await User.findOne({ email, isActive: true });
  if (user) {
    const otp = String(Math.floor(100000 + Math.random() * 900000));
    await PasswordResetOtp.deleteMany({ userId: user._id });
    const reset = await PasswordResetOtp.create({
      userId: user._id,
      email,
      codeHash: await User.hashPassword(otp),
      expiresAt: new Date(Date.now() + 10 * 60 * 1000),
      requestIp: req.ip || '',
    });
    try {
      await security.sendOtpEmail({ email, name: user.name, otp });
    } catch (error) {
      await PasswordResetOtp.findByIdAndDelete(reset._id);
      throw error;
    }
    await security.record(req, 'password_reset_requested', { userId: user._id, role: user.role, email });
  }
  // Do not reveal whether an email is registered.
  res.json({ ok: true, data: { message: 'If the email is registered, an OTP has been sent.' } });
}

async function resetPassword(req, res) {
  const email = security.cleanEmail(req.body.email);
  const otp = String(req.body.otp || '').trim();
  const password = String(req.body.newPassword || '');
  if (!email || !otp || !/^\d{6}$/.test(otp)) throw new HttpError(400, 'Enter the 6-digit OTP');
  if (password.length < 10 || password.length > 72) throw new HttpError(400, 'New password must be between 10 and 72 characters');
  const user = await User.findOne({ email, isActive: true }).select('+passwordHash');
  const reset = user && await PasswordResetOtp.findOne({ userId: user._id, email, usedAt: null, expiresAt: { $gt: new Date() } }).select('+codeHash').sort({ createdAt: -1 });
  if (!user || !reset || reset.attempts >= 5) throw new HttpError(400, 'OTP is invalid or expired');
  const otpValid = await bcrypt.compare(otp, reset.codeHash);
  if (!otpValid) {
    await PasswordResetOtp.updateOne({ _id: reset._id }, { $inc: { attempts: 1 } });
    throw new HttpError(400, 'OTP is invalid or expired');
  }
  if (await user.comparePassword(password)) throw new HttpError(400, 'Choose a different password');
  user.passwordHash = await User.hashPassword(password);
  user.mustChangePassword = false;
  await user.save();
  reset.usedAt = new Date();
  await reset.save();
  await security.record(req, 'password_reset_completed', { userId: user._id, role: user.role, email });
  res.json({ ok: true, data: { message: 'Password reset successfully' } });
}

module.exports = { login, me, changePassword, updateAdminAccount, requestPasswordReset, resetPassword };
