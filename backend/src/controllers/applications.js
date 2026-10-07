const mongoose = require('mongoose');
const StudentApplication = require('../models/StudentApplication');
const StudentProfile = require('../models/StudentProfile');
const User = require('../models/User');
const Batch = require('../models/Batch');
const Notification = require('../models/Notification');
const { HttpError } = require('../middleware/errors');

async function list(req, res) { const records = await StudentApplication.find({ status: 'pending' }).select('-passwordHash -aadhaarEncrypted').populate('batchId', 'name course').sort({ createdAt: -1 }); res.json({ ok: true, data: records }); }
async function nextId() { const rows = await StudentProfile.find({ studentId: /^MSDA\d+$/i }).select('studentId').lean(); const max = rows.reduce((m, x) => Math.max(m, Number(String(x.studentId).replace(/^MSDA/i)) || 0), 0); return `MSDA${String(max + 1).padStart(2, '0')}`; }
async function review(req, res) {
  if (!mongoose.isValidObjectId(req.params.id)) throw new HttpError(404, 'Application not found');
  const application = await StudentApplication.findById(req.params.id).select('+passwordHash +aadhaarEncrypted');
  if (!application || application.status !== 'pending') throw new HttpError(404, 'Pending application not found');
  const action = String(req.body.action || '').toLowerCase();
  if (!['approve','reject'].includes(action)) throw new HttpError(400, 'Action must be approve or reject');
  if (action === 'reject') { application.status = 'rejected'; application.rejectionReason = String(req.body.reason || 'Rejected by admin').slice(0, 300); application.reviewedAt = new Date(); application.reviewedBy = req.user._id; await application.save(); return res.json({ ok: true, data: { message: 'Application rejected' } }); }
  if (await User.exists({ $or: [{ email: application.email }, { phone: application.phone }] })) throw new HttpError(409, 'An account already exists with this email or phone');
  const batch = await Batch.findOne({ _id: application.batchId, status: 'active' }); if (!batch) throw new HttpError(400, 'Selected batch is not active');
  const user = await User.create({ name: application.name, email: application.email, phone: application.phone, passwordHash: application.passwordHash, mustChangePassword: false, role: 'student' });
  const studentId = await nextId();
  const profile = await StudentProfile.create({ userId: user._id, studentId, batchId: application.batchId, course: application.course || batch.course || '', address: application.address, village: application.village, post: application.post, policeStation: application.policeStation, district: application.district, state: application.state, postalCode: application.postalCode, fatherName: application.fatherName, motherName: application.motherName, parentPhone: application.parentPhone, dateOfBirth: application.dateOfBirth, heightCm: application.heightCm, weightKg: application.weightKg, chestCm: application.chestCm, aadhaarEncrypted: application.aadhaarEncrypted, aadhaarLast4: application.aadhaarLast4, photo: application.photo, photoPublicId: application.photoPublicId, joiningDate: new Date() });
  application.status = 'approved'; application.reviewedAt = new Date(); application.reviewedBy = req.user._id; await application.save();
  await Notification.create({ userId: user._id, title: 'Student account approved', message: 'Your account has been approved. You can now log in.', type: 'system', data: { studentId } });
  res.json({ ok: true, data: { message: 'Application approved and student account created', studentId, profile } });
}
module.exports = { list, review };
