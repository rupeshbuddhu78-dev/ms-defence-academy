const mongoose = require('mongoose');
const bcrypt = require('bcryptjs');
const StudentApplication = require('../models/StudentApplication');
const StudentProfile = require('../models/StudentProfile');
const User = require('../models/User');
const Batch = require('../models/Batch');
const Notification = require('../models/Notification');
const { HttpError } = require('../middleware/errors');

async function list(req, res) {
  const records = await StudentApplication.find({ status: 'pending' })
    .select('-passwordHash -aadhaarEncrypted')
    .populate('batchId', 'name course')
    .sort({ createdAt: -1 });
  res.json({ ok: true, data: records });
}

async function remove(req, res) {
  if (!mongoose.isValidObjectId(req.params.id)) throw new HttpError(404, 'Application not found');
  const application = await StudentApplication.findOneAndDelete({ _id: req.params.id, status: 'pending' });
  if (!application) throw new HttpError(404, 'Pending application not found');
  res.json({ ok: true, data: { message: 'Application deleted. The student must submit a new application.' } });
}

async function nextId() {
  const rows = await StudentProfile.find({ studentId: /^MSDA\d+$/i }).select('studentId').lean();
  const max = rows.reduce((m, x) => Math.max(m, Number(String(x.studentId).replace(/^MSDA/i)) || 0), 0);
  return `MSDA${String(max + 1).padStart(2, '0')}`;
}

function duplicateKey(error) {
  return error && (error.code === 11000 || error.codeName === 'DuplicateKey');
}

function phoneVariants(phone) {
  const value = String(phone || '').replace(/\D/g, '');
  return [value, `91${value}`, `+91${value}`, `+91 ${value}`].filter(Boolean);
}

async function findStudentUser(application) {
  const byEmail = await User.findOne({ email: application.email }).select('+passwordHash');
  const byPhone = application.phone ? await User.findOne({ phone: { $in: phoneVariants(application.phone) } }).select('+passwordHash') : null;
  if (byEmail && byPhone && String(byEmail._id) !== String(byPhone._id)) {
    throw new HttpError(409, 'This email and phone belong to different accounts');
  }
  return byEmail || byPhone;
}

async function review(req, res) {
  if (!mongoose.isValidObjectId(req.params.id)) throw new HttpError(404, 'Application not found');
  const application = await StudentApplication.findById(req.params.id).select('+passwordHash +aadhaarEncrypted');
  if (!application || application.status !== 'pending') throw new HttpError(404, 'Pending application not found');
  const action = String(req.body.action || '').toLowerCase();
  if (!['approve', 'reject'].includes(action)) throw new HttpError(400, 'Action must be approve or reject');
  if (action === 'reject') {
    const reason = String(req.body.reason || '').trim();
    if (reason.length < 3) throw new HttpError(400, 'Write the reason for rejection');
    application.status = 'rejected';
    application.rejectionReason = reason.slice(0, 500);
    application.reviewedAt = new Date();
    application.reviewedBy = req.user._id;
    await application.save();
    return res.json({ ok: true, data: { message: 'Application rejected' } });
  }
  const batch = await Batch.findOne({ _id: application.batchId, status: 'active' });
  if (!batch) throw new HttpError(400, 'Selected batch is not active');
  let user = await findStudentUser(application);
  if (user && user.role !== 'student') throw new HttpError(409, 'An admin account already uses this email or phone');
  if (!user) {
    try {
      user = await User.create({ name: application.name, email: application.email, phone: application.phone, passwordHash: application.passwordHash, mustChangePassword: false, role: 'student' });
    } catch (error) {
      if (!duplicateKey(error)) throw error;
      user = await findStudentUser(application);
      if (!user) throw error;
      if (user.role !== 'student') throw new HttpError(409, 'An admin account already uses this email or phone');
    }
  } else {
    try {
      user.name = application.name;
      user.email = application.email;
      user.phone = application.phone;
      user.isActive = true;
      await user.save();
    } catch (error) {
      if (!duplicateKey(error)) throw error;
      user = await findStudentUser(application);
      if (!user || user.role !== 'student') throw new HttpError(409, 'An admin account already uses this email or phone');
      user.isActive = true;
      await user.save();
    }
  }
  let profile = await StudentProfile.findOne({ userId: user._id });
  if (profile) {
    application.status = 'approved';
    application.reviewedAt = new Date();
    application.reviewedBy = req.user._id;
    await application.save();
    return res.json({ ok: true, data: { message: 'Application approved; existing student profile was restored', studentId: profile.studentId, profile } });
  }
  let studentId = await nextId();
  for (let attempt = 0; attempt < 3; attempt += 1) {
    try {
      profile = await StudentProfile.create({ userId: user._id, studentId, batchId: application.batchId, course: application.course || batch.course || '', address: application.address, village: application.village, post: application.post, policeStation: application.policeStation, district: application.district, state: application.state, postalCode: application.postalCode, fatherName: application.fatherName, motherName: application.motherName, parentPhone: application.parentPhone, dateOfBirth: application.dateOfBirth, heightCm: application.heightCm, weightKg: application.weightKg, chestCm: application.chestCm, aadhaarEncrypted: application.aadhaarEncrypted, aadhaarLast4: application.aadhaarLast4, photo: application.photo, photoPublicId: application.photoPublicId, joiningDate: new Date() });
      break;
    } catch (error) {
      if (!duplicateKey(error) || attempt === 2) throw error;
      const existingProfile = await StudentProfile.findOne({ userId: user._id });
      if (existingProfile) { profile = existingProfile; break; }
      studentId = await nextId();
    }
  }
  application.status = 'approved';
  application.reviewedAt = new Date();
  application.reviewedBy = req.user._id;
  await application.save();
  await Notification.create({ userId: user._id, title: 'Student account approved', message: 'Your account has been approved. You can now log in.', type: 'system', data: { studentId } });
  res.json({ ok: true, data: { message: 'Application approved and student account created', studentId, profile } });
}

async function resubmit(req, res) {
  if (!mongoose.isValidObjectId(req.params.id)) throw new HttpError(404, 'Application not found');
  const email = String(req.body.email || '').trim().toLowerCase();
  const password = String(req.body.password || '');
  const application = await StudentApplication.findById(req.params.id).select('+passwordHash');
  if (!application || application.email !== email || !['pending', 'rejected'].includes(application.status)) throw new HttpError(404, 'Application not found');
  if (!(await bcrypt.compare(password, application.passwordHash))) throw new HttpError(401, 'Incorrect application password');
  const allowed = ['name', 'phone', 'course', 'address', 'village', 'post', 'policeStation', 'district', 'state', 'postalCode', 'fatherName', 'motherName', 'parentPhone', 'heightCm', 'weightKg', 'chestCm'];
  for (const key of allowed) if (req.body[key] !== undefined) application[key] = String(req.body[key] ?? '').trim();
  if (req.body.dateOfBirth) {
    const date = new Date(req.body.dateOfBirth);
    if (Number.isNaN(date.getTime())) throw new HttpError(400, 'Date of birth is invalid');
    application.dateOfBirth = date;
  }
  if (req.body.batchId) {
    const batch = await Batch.findOne({ _id: req.body.batchId, status: 'active' });
    if (!batch) throw new HttpError(400, 'Selected batch is not active');
    application.batchId = batch._id;
  }
  application.status = 'pending';
  application.rejectionReason = '';
  application.reviewedAt = null;
  application.reviewedBy = null;
  await application.save();
  const admins = await User.find({ role: 'admin', isActive: true }).select('_id').lean();
  if (admins.length) await Notification.insertMany(admins.map(admin => ({ userId: admin._id, title: 'Application resubmitted', message: `${application.name} updated and resubmitted the student application.`, type: 'system', data: { applicationId: application._id } })), { ordered: false });
  const safe = application.toObject(); delete safe.passwordHash; delete safe.aadhaarEncrypted;
  res.json({ ok: true, data: { message: 'Application resubmitted for admin review', application: safe } });
}

module.exports = { list, review, remove, resubmit };
