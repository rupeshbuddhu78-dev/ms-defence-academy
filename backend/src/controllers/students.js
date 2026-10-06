const crypto = require('crypto');
const mongoose = require('mongoose');
const User = require('../models/User');
const StudentProfile = require('../models/StudentProfile');
const Batch = require('../models/Batch');
const Fee = require('../models/Fee');
const { HttpError } = require('../middleware/errors');
const cloudImages = require('../services/cloudinary');

const respond = (res, data, status = 200) => res.status(status).json({ ok: true, data });

async function feeDetails(profileIds) {
  if (!profileIds.length) return new Map();
  const records = await Fee.find({ studentId: { $in: profileIds } }).sort({ createdAt: -1 }).lean();
  const byStudent = new Map();
  for (const record of records) {
    const key = String(record.studentId);
    if (!byStudent.has(key)) byStudent.set(key, []);
    byStudent.get(key).push(record);
  }
  return byStudent;
}

function addFeeSummary(profile, records = []) {
  const totalFees = records.reduce((sum, item) => sum + Number(item.totalFees || 0), 0);
  const paidAmount = records.reduce((sum, item) => sum + Number(item.paidAmount || 0), 0);
  return {
    ...profile,
    feeRecords: records,
    feeSummary: {
      totalFees,
      paidAmount,
      remainingAmount: Math.max(0, totalFees - paidAmount),
      status: records.length ? (paidAmount >= totalFees ? 'paid' : paidAmount > 0 ? 'partial' : 'due') : 'none',
    },
  };
}

async function populateProfile(profile) {
  await profile.populate([
    { path: 'userId', select: 'name email phone isActive' },
    { path: 'batchId', select: 'name course trainer startTime endTime location status' },
  ]);
  const raw = profile.toObject({ virtuals: true });
  const records = (await feeDetails([profile._id])).get(String(profile._id)) || [];
  return addFeeSummary(raw, records);
}

async function generateStudentId() {
  for (let attempts = 0; attempts < 5; attempts += 1) {
    const value = `MSDA${Date.now().toString().slice(-7)}${crypto.randomBytes(2).toString('hex').toUpperCase()}`;
    if (!await StudentProfile.exists({ studentId: value })) return value;
  }
  throw new HttpError(503, 'Could not generate a unique student ID; try again');
}

function numericAmount(value, fieldName) {
  const amount = value === undefined || value === null || value === '' ? 0 : Number(value);
  if (!Number.isFinite(amount) || amount < 0) throw new HttpError(400, `${fieldName} must be a non-negative amount`);
  return amount;
}

async function listStudents(req, res) {
  const filter = {};
  if (req.query.batchId) {
    if (!mongoose.isValidObjectId(req.query.batchId)) throw new HttpError(400, 'Batch ID is invalid');
    filter.batchId = req.query.batchId;
  }
  let profiles = await StudentProfile.find(filter)
    .populate('userId', 'name email phone isActive')
    .populate('batchId', 'name course trainer startTime endTime status')
    .sort({ createdAt: -1 })
    .limit(500);
  if (req.query.q) {
    const query = String(req.query.q).trim().toLowerCase();
    profiles = profiles.filter(profile => {
      const user = profile.userId || {};
      return [profile.studentId, user.name, user.email, user.phone]
        .some(value => String(value || '').toLowerCase().includes(query));
    }).slice(0, 200);
  } else {
    profiles = profiles.slice(0, 200);
  }
  const fees = await feeDetails(profiles.map(profile => profile._id));
  return respond(res, profiles.map(profile => addFeeSummary(
    profile.toObject({ virtuals: true }),
    fees.get(String(profile._id)) || [],
  )));
}

async function createStudent(req, res) {
  const body = req.body || {};
  const name = String(body.name || '').trim();
  const email = String(body.email || '').trim().toLowerCase();
  const phone = String(body.phone || '').trim();
  const password = String(body.password || '');
  const batchId = String(body.batchId || '').trim();
  const totalFees = numericAmount(body.totalFees, 'Total fees');
  const paidAmount = numericAmount(body.paidAmount, 'Paid amount');

  if (name.length < 2) throw new HttpError(400, 'Student name is required');
  const at = email.indexOf('@');
  const validEmail = at > 0 && email.indexOf('@', at + 1) === -1 &&
    email.slice(at + 1).includes('.') && !email.slice(at + 1).endsWith('.') &&
    ![...email].some(character => character.trim() === '');
  if (!validEmail) throw new HttpError(400, 'A valid email is required for student login');
  const digitCount = phone.split('').filter(character => character >= '0' && character <= '9').length;
  if (digitCount < 7) throw new HttpError(400, 'A valid phone number is required');
  if (password.length < 10) throw new HttpError(400, 'Initial password must be at least 10 characters');
  if (!batchId || !mongoose.isValidObjectId(batchId)) throw new HttpError(400, 'Select an active batch');
  if (paidAmount > totalFees) throw new HttpError(400, 'Paid amount cannot exceed total fees');
  if (await User.exists({ email })) throw new HttpError(409, 'An account already uses this email');
  const batch = await Batch.findOne({ _id: batchId, status: 'active' });
  if (!batch) throw new HttpError(400, 'Selected batch is not active');

  let studentId = String(body.studentId || '').trim().toUpperCase();
  if (studentId && await StudentProfile.exists({ studentId })) throw new HttpError(409, 'Student ID already exists');
  if (!studentId) studentId = await generateStudentId();
  const joiningDate = body.joiningDate ? new Date(body.joiningDate) : new Date();
  if (Number.isNaN(joiningDate.getTime())) throw new HttpError(400, 'Joining date is invalid');
  const dueDate = body.dueDate ? new Date(body.dueDate) : undefined;
  if (dueDate && Number.isNaN(dueDate.getTime())) throw new HttpError(400, 'Fee due date is invalid');

  let uploaded = null;
  let user = null;
  let profile = null;
  let fee = null;
  try {
    if (req.file) uploaded = await cloudImages.uploadImage(req.file.buffer);
    user = await User.create({
      name,
      email,
      phone,
      passwordHash: await User.hashPassword(password),
      role: 'student',
    });
    profile = await StudentProfile.create({
      userId: user._id,
      studentId,
      batchId: batch._id,
      course: String(body.course || batch.course || '').trim(),
      address: String(body.address || '').trim(),
      joiningDate,
      photo: uploaded?.url || '',
      photoPublicId: uploaded?.publicId || '',
    });
    if (totalFees > 0) {
      fee = await Fee.create({
        studentId: profile._id,
        totalFees,
        paidAmount,
        dueDate,
        remarks: String(body.feeRemarks || '').trim(),
        status: paidAmount >= totalFees ? 'paid' : paidAmount > 0 ? 'partial' : 'due',
        payments: paidAmount > 0 ? [{ amount: paidAmount, note: 'Initial payment at enrollment', recordedBy: req.user._id }] : [],
      });
    }
    await profile.populate([
      { path: 'userId', select: 'name email phone isActive' },
      { path: 'batchId', select: 'name course trainer startTime endTime location' },
    ]);
    return respond(res, {
      profile: addFeeSummary(profile.toObject({ virtuals: true }), fee ? [fee.toObject()] : []),
      credentials: { email, studentId },
    }, 201);
  } catch (error) {
    if (fee) await Fee.findByIdAndDelete(fee._id).catch(() => {});
    if (profile) await StudentProfile.findByIdAndDelete(profile._id).catch(() => {});
    if (user) await User.findByIdAndDelete(user._id).catch(() => {});
    if (uploaded?.publicId) await cloudImages.deleteImage(uploaded.publicId);
    if (error?.code === 11000) throw new HttpError(409, 'Email or student ID already exists');
    throw error;
  }
}

async function getStudent(req, res) {
  if (!mongoose.isValidObjectId(req.params.id)) throw new HttpError(404, 'Student not found');
  const profile = await StudentProfile.findById(req.params.id)
    .populate('userId', 'name email phone isActive')
    .populate('batchId', 'name course trainer startTime endTime location status');
  if (!profile) throw new HttpError(404, 'Student not found');
  const records = (await feeDetails([profile._id])).get(String(profile._id)) || [];
  return respond(res, addFeeSummary(profile.toObject({ virtuals: true }), records));
}

async function getOwnProfile(req, res) {
  const profile = await StudentProfile.findOne({ userId: req.user.id })
    .populate('userId', 'name email phone isActive')
    .populate('batchId', 'name course trainer startTime endTime location status');
  if (!profile) throw new HttpError(404, 'Student profile not found; contact the academy administrator');
  const records = (await feeDetails([profile._id])).get(String(profile._id)) || [];
  return respond(res, addFeeSummary(profile.toObject({ virtuals: true }), records));
}

async function updateStudent(req, res) {
  if (!mongoose.isValidObjectId(req.params.id)) throw new HttpError(404, 'Student not found');
  const profile = await StudentProfile.findById(req.params.id);
  if (!profile) throw new HttpError(404, 'Student not found');
  const body = req.body || {};
  for (const key of ['studentId', 'course', 'address', 'joiningDate']) {
    if (body[key] !== undefined) profile[key] = body[key];
  }
  if (body.batchId !== undefined) {
    if (!body.batchId) profile.batchId = null;
    else {
      if (!mongoose.isValidObjectId(body.batchId) || !await Batch.exists({ _id: body.batchId, status: 'active' })) {
        throw new HttpError(400, 'Select an active batch');
      }
      profile.batchId = body.batchId;
    }
  }
  if (body.studentId !== undefined) profile.studentId = String(body.studentId).trim().toUpperCase();
  await profile.save();
  const userUpdate = {};
  for (const key of ['name', 'phone', 'email']) {
    if (body[key] !== undefined) userUpdate[key] = String(body[key]).trim();
  }
  if (userUpdate.email) userUpdate.email = userUpdate.email.toLowerCase();
  if (Object.keys(userUpdate).length) {
    await User.findByIdAndUpdate(profile.userId, userUpdate, { runValidators: true });
  }
  return getStudent({ ...req, params: { id: profile.id } }, res);
}

async function deactivateStudent(req, res) {
  if (!mongoose.isValidObjectId(req.params.id)) throw new HttpError(404, 'Student not found');
  const profile = await StudentProfile.findById(req.params.id);
  if (!profile) throw new HttpError(404, 'Student not found');
  await User.findByIdAndUpdate(profile.userId, { isActive: false });
  return respond(res, { message: 'Student deactivated' });
}

async function storePhoto(profile, file) {
  if (!file) throw new HttpError(400, 'Choose a profile photo first');
  const uploaded = await cloudImages.uploadImage(file.buffer);
  const oldPublicId = profile.photoPublicId;
  try {
    profile.photo = uploaded.url;
    profile.photoPublicId = uploaded.publicId;
    await profile.save();
  } catch (error) {
    await cloudImages.deleteImage(uploaded.publicId);
    throw error;
  }
  if (oldPublicId && oldPublicId !== uploaded.publicId) await cloudImages.deleteImage(oldPublicId);
  return { photo: profile.photo };
}

async function uploadOwnPhoto(req, res) {
  const profile = await StudentProfile.findOne({ userId: req.user.id });
  if (!profile) throw new HttpError(404, 'Student profile not found');
  return respond(res, await storePhoto(profile, req.file));
}

async function uploadStudentPhoto(req, res) {
  if (!mongoose.isValidObjectId(req.params.id)) throw new HttpError(404, 'Student not found');
  const profile = await StudentProfile.findById(req.params.id);
  if (!profile) throw new HttpError(404, 'Student not found');
  return respond(res, await storePhoto(profile, req.file));
}

module.exports = { listStudents, createStudent, getStudent, getOwnProfile, updateStudent, deactivateStudent, uploadOwnPhoto, uploadStudentPhoto };
