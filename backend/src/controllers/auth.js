const jwt = require('jsonwebtoken');
const User = require('../models/User');
const StudentProfile = require('../models/StudentProfile');
const { HttpError } = require('../middleware/errors');

async function login(req, res) {
  const email = String(req.body.email || '').trim().toLowerCase();
  const password = String(req.body.password || '');
  if (!email || !password) throw new HttpError(400, 'Email and password are required');
  const user = await User.findOne({ email }).select('+passwordHash');
  if (!user || !user.isActive || !(await user.comparePassword(password))) throw new HttpError(401, 'Email or password is incorrect');
  const token = jwt.sign({ sub: user.id }, process.env.JWT_SECRET, { expiresIn: process.env.JWT_EXPIRES_IN || '7d', issuer: 'ms-defence-academy' });
  const profile = user.role === 'student' ? await StudentProfile.findOne({ userId: user.id }).populate('batchId') : null;
  res.json({ ok: true, data: { token, user, profile } });
}
async function me(req, res) {
  const profile = req.user.role === 'student' ? await StudentProfile.findOne({ userId: req.user.id }).populate('batchId') : null;
  res.json({ ok: true, data: { user: req.user, profile } });
}
module.exports = { login, me };
