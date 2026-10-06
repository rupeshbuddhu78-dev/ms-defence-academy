const jwt = require('jsonwebtoken');
const User = require('../models/User');
const StudentProfile = require('../models/StudentProfile');
const { HttpError } = require('../middleware/errors');

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
  if (!user || !user.isActive || !(await user.comparePassword(password))) {
    throw new HttpError(401, 'Phone/email or password is incorrect');
  }
  const token = jwt.sign({ sub: user.id }, process.env.JWT_SECRET, {
    expiresIn: process.env.JWT_EXPIRES_IN || '7d',
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

module.exports = { login, me, changePassword };
