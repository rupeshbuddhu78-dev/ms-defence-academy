const bcrypt = require('bcryptjs');
const RegistrationOtp = require('../models/RegistrationOtp');
const StudentApplication = require('../models/StudentApplication');
const User = require('../models/User');
const Batch = require('../models/Batch');
const Notification = require('../models/Notification');
const { HttpError } = require('../middleware/errors');
const security = require('./security');
const cloudinary = require('../services/cloudinary');

function email(value) { const v = String(value || '').trim().toLowerCase(); return /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(v) ? v : ''; }
function phone(value) { const v = String(value || '').replace(/\D/g, ''); return v.length === 10 ? v : ''; }
function number(value) { if (value === '' || value == null) return null; const n = Number(value); return Number.isFinite(n) && n >= 0 ? n : null; }
function payload(body) {
  const result = { ...body };
  for (const key of ['name','email','phone','batchId','password']) result[key] = String(body[key] || '').trim();
  result.email = email(result.email); result.phone = phone(result.phone);
  if (result.name.length < 2 || !result.email || !result.phone || result.password.length < 10) throw new HttpError(400, 'Name, valid email, phone and password (10+ characters) are required');
  if (!result.batchId) throw new HttpError(400, 'Select a batch');
  delete result.photo;
  for (const key of ['heightCm','weightKg','chestCm']) result[key] = number(body[key]);
  return result;
}

async function requestOtp(req, res) {
  const data = payload(req.body || {});
  const batch = await Batch.findOne({ _id: data.batchId, status: 'active' });
  if (!batch) throw new HttpError(400, 'Selected batch is not active');
  if (await User.exists({ email: data.email })) throw new HttpError(409, 'An account already uses this email');
  if (await User.exists({ phone: data.phone })) throw new HttpError(409, 'An account already uses this phone');
  if (await StudentApplication.exists({ email: data.email, status: 'pending' })) throw new HttpError(409, 'A pending application already exists for this email');
  const otp = String(Math.floor(100000 + Math.random() * 900000));
  await RegistrationOtp.deleteMany({ email: data.email });
  const record = await RegistrationOtp.create({ email: data.email, codeHash: await User.hashPassword(otp), payload: data, expiresAt: new Date(Date.now() + 10 * 60 * 1000) });
  try { await security.sendOtpEmail({ email: data.email, name: data.name, otp }); } catch (error) { await RegistrationOtp.findByIdAndDelete(record._id); throw error; }
  res.json({ ok: true, data: { message: 'OTP sent to your email. Verify it to submit your application.' } });
}

async function listBatches(_req, res) {
  const batches = await Batch.find({ status: 'active' }).select('name course trainer startTime endTime').sort({ name: 1 }).lean();
  res.json({ ok: true, data: batches });
}

async function verifyOtp(req, res) {
  const body = req.body || {}; const mail = email(body.email); const otp = String(body.otp || '').trim();
  if (!mail || !/^\d{6}$/.test(otp)) throw new HttpError(400, 'Enter the registered email and 6-digit OTP');
  const record = await RegistrationOtp.findOne({ email: mail, expiresAt: { $gt: new Date() } }).select('+codeHash').sort({ createdAt: -1 });
  if (!record || record.attempts >= 5 || !(await bcrypt.compare(otp, record.codeHash))) {
    if (record) await RegistrationOtp.updateOne({ _id: record._id }, { $inc: { attempts: 1 } });
    throw new HttpError(400, 'OTP is invalid or expired');
  }
  const data = record.payload;
  const batch = await Batch.findOne({ _id: data.batchId, status: 'active' });
  if (!batch) throw new HttpError(400, 'Selected batch is no longer active');
  const uploaded = req.file ? await cloudinary.uploadImage(req.file.buffer, 'ms-defence-academy/applications') : null;
  const application = await StudentApplication.create({ ...data, photo: uploaded?.url || '', photoPublicId: uploaded?.publicId || '' });
  await RegistrationOtp.findByIdAndDelete(record._id);
  const admins = await User.find({ role: 'admin', isActive: true }).select('_id').lean();
  if (admins.length) await Notification.insertMany(admins.map(admin => ({ userId: admin._id, title: 'New student approval request', message: `${data.name} submitted a verified student application.`, type: 'system', data: { applicationId: application._id } })), { ordered: false });
  res.status(201).json({ ok: true, data: { message: 'Email verified. Your application is pending admin approval.', applicationId: application._id } });
}

module.exports = { requestOtp, verifyOtp, listBatches };
