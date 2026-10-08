const mongoose = require('mongoose');
const User = require('../models/User');
const StudentProfile = require('../models/StudentProfile');
const Batch = require('../models/Batch');
const Fee = require('../models/Fee');
const Attendance = require('../models/Attendance');
const TestAttempt = require('../models/TestAttempt');
const PhysicalTrainingResult = require('../models/PhysicalTrainingResult');
const PhysicalTrainingSheet = require('../models/PhysicalTrainingSheet');
const Notification = require('../models/Notification');
const { HttpError } = require('../middleware/errors');
const cloudImages = require('../services/cloudinary');
const { encryptAadhaar, decryptAadhaar, normalizeAadhaar } = require('../services/personal-data');
const reserveStudentId = require('../services/student-id');

const respond = (res, data, status = 200) => res.status(status).json({ ok: true, data });
const profileStringFields = [
  'course', 'address', 'fatherName', 'motherName', 'parentPhone', 'village',
  'post', 'policeStation', 'district', 'state', 'postalCode',
];

function normalizePhone(value) {
  const digits = String(value || '').replace(/\D/g, '');
  if (digits.length === 10) return digits;
  if (digits.length === 12 && digits.startsWith('91')) return digits.slice(2);
  return '';
}

function phoneVariants(phone) {
  return [phone, `91${phone}`, `+91${phone}`, `+91 ${phone}`];
}

function optionalDate(value, label, allowBlank = true) {
  if ((value === undefined || value === null || value === '') && allowBlank) return null;
  const date = new Date(value);
  if (Number.isNaN(date.getTime())) throw new HttpError(400, `${label} is invalid`);
  return date;
}

function optionalMeasurement(value, label) {
  if (value === undefined || value === null || value === '') return null;
  const number = Number(value);
  if (!Number.isFinite(number) || number < 0 || number > 1000) {
    throw new HttpError(400, `${label} must be a valid positive measurement`);
  }
  return number;
}

function aadhaarPayload(value) {
  if (value === undefined) return null;
  const normalized = normalizeAadhaar(value);
  if (normalized && normalized.length !== 12) throw new HttpError(400, 'Aadhaar number must contain exactly 12 digits');
  return {
    aadhaarEncrypted: normalized ? encryptAadhaar(normalized) : '',
    aadhaarLast4: normalized ? normalized.slice(-4) : '',
  };
}

function safeProfile(profile, { includeAadhaar = false } = {}) {
  const result = profile.toObject ? profile.toObject({ virtuals: true }) : { ...profile };
  const encrypted = result.aadhaarEncrypted || profile.aadhaarEncrypted || '';
  delete result.aadhaarEncrypted;
  delete result.aadhaarLast4;
  if (includeAadhaar) result.aadhaarNumber = decryptAadhaar(encrypted);
  return result;
}

async function feeDetails(profileIds) {
  if (!profileIds.length) return new Map();
  const records = await Fee.find({ studentId: { $in: profileIds } }).sort({ createdAt: -1 });
  const byStudent = new Map();
  for (const record of records) {
    const key = String(record.studentId);
    if (!byStudent.has(key)) byStudent.set(key, []);
    byStudent.get(key).push(record.toObject());
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

function numericAmount(value, fieldName) {
  const amount = value === undefined || value === null || value === '' ? 0 : Number(value);
  if (!Number.isFinite(amount) || amount < 0) throw new HttpError(400, `${fieldName} must be a non-negative amount`);
  return amount;
}

function validEmail(value) {
  const email = String(value || '').trim().toLowerCase();
  const at = email.indexOf('@');
  return at > 0 && email.indexOf('@', at + 1) === -1 && email.slice(at + 1).includes('.') &&
    !email.slice(at + 1).endsWith('.') && ![...email].some(character => character.trim() === '')
    ? email : '';
}

async function listStudents(req, res) {
  const filter = {};
  if (req.query.batchId) {
    if (!mongoose.isValidObjectId(req.query.batchId)) throw new HttpError(400, 'Batch ID is invalid');
    filter.batchId = req.query.batchId;
  }
  const query = String(req.query.q || '').trim();
  if (query) {
    const escaped = query.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
    const regex = new RegExp(escaped, 'i');
    const matchingUsers = await User.find({
      role: 'student',
      $or: [{ name: regex }, { phone: regex }, { email: regex }],
    }).select('_id').limit(500).lean();
    filter.$or = [
      { studentId: regex },
      { userId: { $in: matchingUsers.map(user => user._id) } },
    ];
  }
  const profiles = await StudentProfile.find(filter)
    .select('-aadhaarEncrypted -aadhaarLast4')
    .populate('userId', 'name email phone isActive')
    .populate('batchId', 'name course trainer startTime endTime status')
    .sort({ createdAt: -1 })
    .limit(200);
  const fees = await feeDetails(profiles.map(profile => profile._id));
  return respond(res, profiles.map(profile => addFeeSummary(
    safeProfile(profile), fees.get(String(profile._id)) || [],
  )));
}

async function createStudent(req, res) {
  const body = req.body || {};
  const name = String(body.name || '').trim();
  const phone = normalizePhone(body.phone);
  const emailInput = String(body.email || '').trim();
  const email = emailInput ? validEmail(emailInput) : (phone ? `student-${phone}@students.msda.local` : '');
  const batchId = String(body.batchId || '').trim();
  const totalFees = numericAmount(body.totalFees, 'Total fees');
  const paidAmount = numericAmount(body.paidAmount, 'Paid amount');

  if (name.length < 2) throw new HttpError(400, 'Student name is required');
  if (!phone) throw new HttpError(400, 'Enter a valid 10-digit Indian student phone number');
  if (!email) throw new HttpError(400, 'Enter a valid email address or leave it blank');
  if (!batchId || !mongoose.isValidObjectId(batchId)) throw new HttpError(400, 'Select an active batch');
  if (paidAmount > totalFees) throw new HttpError(400, 'Paid amount cannot exceed total fees');
  if (await User.exists({ email })) throw new HttpError(409, 'An account already uses this email');
  if (await User.exists({ phone: { $in: phoneVariants(phone) } })) throw new HttpError(409, 'A student account already uses this phone number');
  const batch = await Batch.findOne({ _id: batchId, status: 'active' });
  if (!batch) throw new HttpError(400, 'Selected batch is not active');

  let studentId = String(body.studentId || '').trim().toUpperCase();
  if (studentId && await StudentProfile.exists({ studentId })) throw new HttpError(409, 'Student ID already exists');
  if (!studentId) studentId = await reserveStudentId();
  const joiningDate = optionalDate(body.joiningDate, 'Joining date', false);
  const dateOfBirth = optionalDate(body.dateOfBirth, 'Date of birth');
  if (dateOfBirth && dateOfBirth > new Date()) throw new HttpError(400, 'Date of birth cannot be in the future');
  const aadhaar = aadhaarPayload(body.aadhaarNumber);
  const uploaded = req.file ? await cloudImages.uploadImage(req.file.buffer) : null;

  let user;
  let profile;
  let fee;
  try {
    user = await User.create({
      name,
      email,
      phone,
      passwordHash: await User.hashPassword(phone),
      mustChangePassword: true,
      role: 'student',
    });
    const profileData = {
      userId: user._id,
      studentId,
      batchId: batch._id,
      course: String(body.course || batch.course || '').trim(),
      address: String(body.address || '').trim(),
      joiningDate,
      dateOfBirth,
      fatherName: String(body.fatherName || '').trim(),
      motherName: String(body.motherName || '').trim(),
      parentPhone: normalizePhone(body.parentPhone) || String(body.parentPhone || '').trim(),
      village: String(body.village || '').trim(),
      post: String(body.post || '').trim(),
      policeStation: String(body.policeStation || '').trim(),
      district: String(body.district || '').trim(),
      state: String(body.state || '').trim(),
      postalCode: String(body.postalCode || '').trim(),
      heightCm: optionalMeasurement(body.heightCm, 'Height'),
      weightKg: optionalMeasurement(body.weightKg, 'Weight'),
      chestCm: optionalMeasurement(body.chestCm, 'Chest'),
      photo: uploaded?.url || '',
      photoPublicId: uploaded?.publicId || '',
      ...(aadhaar || {}),
    };
    if (!profileData.address) {
      profileData.address = [profileData.village, profileData.post, profileData.policeStation, profileData.district, profileData.state, profileData.postalCode].filter(Boolean).join(', ');
    }
    profile = await StudentProfile.create(profileData);
    if (totalFees > 0) {
      fee = await Fee.create({
        studentId: profile._id,
        batchId: batch._id,
        totalFees,
        paidAmount,
        status: paidAmount >= totalFees ? 'paid' : paidAmount > 0 ? 'partial' : 'due',
        remarks: String(body.feeRemarks || '').trim(),
        payments: paidAmount > 0 ? [{ amount: paidAmount, note: 'Initial payment at enrollment', recordedBy: req.user._id }] : [],
      });
    }
    await profile.populate([
      { path: 'userId', select: 'name email phone isActive mustChangePassword' },
      { path: 'batchId', select: 'name course trainer startTime endTime location status' },
    ]);
    return respond(res, {
      profile: addFeeSummary(safeProfile(profile, { includeAadhaar: true }), fee ? [fee.toObject()] : []),
      credentials: { phone, loginId: phone, initialPassword: phone, studentId },
    }, 201);
  } catch (error) {
    if (fee) await Fee.findByIdAndDelete(fee._id).catch(() => {});
    if (profile) await StudentProfile.findByIdAndDelete(profile._id).catch(() => {});
    if (user) await User.findByIdAndDelete(user._id).catch(() => {});
    if (uploaded?.publicId) await cloudImages.deleteImage(uploaded.publicId);
    if (error?.code === 11000) throw new HttpError(409, 'Phone, email, or student ID already exists');
    throw error;
  }
}

async function getStudent(req, res) {
  if (!mongoose.isValidObjectId(req.params.id)) throw new HttpError(404, 'Student not found');
  const profile = await StudentProfile.findById(req.params.id)
    .select('+aadhaarEncrypted +aadhaarLast4')
    .populate('userId', 'name email phone isActive mustChangePassword')
    .populate('batchId', 'name course trainer startTime endTime location status');
  if (!profile) throw new HttpError(404, 'Student not found');
  const records = (await feeDetails([profile._id])).get(String(profile._id)) || [];
  return respond(res, addFeeSummary(safeProfile(profile, { includeAadhaar: true }), records));
}

async function resetStudentPassword(req, res) {
  if (!mongoose.isValidObjectId(req.params.id)) throw new HttpError(404, 'Student not found');
  const temporaryPassword = String(req.body?.temporaryPassword || '');
  if (temporaryPassword.length < 10 || temporaryPassword.length > 72) {
    throw new HttpError(400, 'Temporary password must be between 10 and 72 characters');
  }
  const profile = await StudentProfile.findById(req.params.id);
  if (!profile) throw new HttpError(404, 'Student not found');
  const user = await User.findById(profile.userId).select('+passwordHash');
  if (!user || user.role !== 'student' || !user.isActive) {
    throw new HttpError(404, 'Active student account not found');
  }
  user.passwordHash = await User.hashPassword(temporaryPassword);
  user.mustChangePassword = true;
  await user.save();
  return respond(res, {
    message: 'Temporary password reset successfully',
    studentId: profile.studentId,
    mustChangePassword: true,
  });
}

async function getOwnProfile(req, res) {
  const profile = await StudentProfile.findOne({ userId: req.user.id })
    .select('+aadhaarEncrypted +aadhaarLast4')
    .populate('userId', 'name email phone isActive mustChangePassword')
    .populate('batchId', 'name course trainer startTime endTime location status');
  if (!profile) throw new HttpError(404, 'Student profile not found; contact the academy administrator');
  const records = (await feeDetails([profile._id])).get(String(profile._id)) || [];
  return respond(res, addFeeSummary(safeProfile(profile, { includeAadhaar: true }), records));
}

async function updateStudent(req, res) {
  if (!mongoose.isValidObjectId(req.params.id)) throw new HttpError(404, 'Student not found');
  const profile = await StudentProfile.findById(req.params.id).select('+aadhaarEncrypted +aadhaarLast4');
  if (!profile) throw new HttpError(404, 'Student not found');
  const body = req.body || {};
  const currentUser = await User.findById(profile.userId);
  if (!currentUser) throw new HttpError(404, 'Student account not found');

  const userUpdate = {};
  if (body.name !== undefined) {
    const name = String(body.name).trim();
    if (name.length < 2) throw new HttpError(400, 'Student name is required');
    userUpdate.name = name;
  }
  if (body.phone !== undefined) {
    const phone = normalizePhone(body.phone);
    if (!phone) throw new HttpError(400, 'Enter a valid 10-digit Indian student phone number');
    const conflict = await User.exists({ _id: { $ne: currentUser._id }, phone: { $in: phoneVariants(phone) } });
    if (conflict) throw new HttpError(409, 'Another student account already uses this phone number');
    userUpdate.phone = phone;
  }
  if (body.email !== undefined && String(body.email).trim()) {
    const email = validEmail(body.email);
    if (!email) throw new HttpError(400, 'Enter a valid email address');
    if (await User.exists({ _id: { $ne: currentUser._id }, email })) throw new HttpError(409, 'An account already uses this email');
    userUpdate.email = email;
  }

  for (const key of profileStringFields) {
    if (body[key] !== undefined) profile[key] = String(body[key] || '').trim();
  }
  for (const key of ['heightCm', 'weightKg', 'chestCm']) {
    if (body[key] !== undefined) profile[key] = optionalMeasurement(body[key], key);
  }
  for (const key of ['dateOfBirth', 'joiningDate']) {
    if (body[key] !== undefined) profile[key] = optionalDate(body[key], key === 'dateOfBirth' ? 'Date of birth' : 'Joining date');
  }
  if (profile.dateOfBirth && profile.dateOfBirth > new Date()) throw new HttpError(400, 'Date of birth cannot be in the future');
  if (body.studentId !== undefined) {
    const studentId = String(body.studentId).trim().toUpperCase();
    if (!studentId) throw new HttpError(400, 'Student ID cannot be blank');
    if (await StudentProfile.exists({ _id: { $ne: profile._id }, studentId })) throw new HttpError(409, 'Student ID already exists');
    profile.studentId = studentId;
  }
  if (body.course !== undefined) profile.course = String(body.course || '').trim();
  if (body.batchId !== undefined) {
    if (!body.batchId || !mongoose.isValidObjectId(body.batchId)) throw new HttpError(400, 'Select an active batch');
    if (!await Batch.exists({ _id: body.batchId, status: 'active' })) throw new HttpError(400, 'Selected batch is not active');
    profile.batchId = body.batchId;
  }
  if (body.aadhaarNumber !== undefined) {
    const aadhaar = aadhaarPayload(body.aadhaarNumber);
    profile.aadhaarEncrypted = aadhaar.aadhaarEncrypted;
    profile.aadhaarLast4 = aadhaar.aadhaarLast4;
  }
  if (body.resetPasswordToPhone === true) {
    const phone = userUpdate.phone || normalizePhone(currentUser.phone);
    if (!phone) throw new HttpError(400, 'Add a valid phone number before resetting the password');
    userUpdate.passwordHash = await User.hashPassword(phone);
    userUpdate.mustChangePassword = true;
  }
  if (Object.keys(userUpdate).length) {
    await User.findByIdAndUpdate(currentUser._id, userUpdate, { runValidators: true });
  }
  await profile.save();
  if (body.totalFees !== undefined || body.paidAmount !== undefined) {
    const currentFee = await Fee.findOne({ studentId: profile._id }).sort({ createdAt: -1 });
    const totalFees = body.totalFees === undefined
      ? Number(currentFee?.totalFees || 0)
      : Number(body.totalFees);
    const paidAmount = body.paidAmount === undefined
      ? Number(currentFee?.paidAmount || 0)
      : Number(body.paidAmount);
    if (!Number.isFinite(totalFees) || totalFees < 0 || !Number.isFinite(paidAmount) || paidAmount < 0) {
      throw new HttpError(400, 'Total fee and paid amount must be valid non-negative values');
    }
    if (paidAmount > totalFees) throw new HttpError(400, 'Paid amount cannot exceed total fee');
    if (currentFee) {
      if (totalFees !== Number(currentFee.totalFees) || paidAmount !== Number(currentFee.paidAmount)) {
        currentFee.adjustments.push({
          previousTotal: currentFee.totalFees,
          newTotal: totalFees,
          previousPaid: currentFee.paidAmount,
          newPaid: paidAmount,
          note: 'Updated from student edit',
          recordedBy: req.user._id,
        });
        currentFee.totalFees = totalFees;
        currentFee.paidAmount = paidAmount;
        currentFee.status = totalFees === 0 ? 'due' : paidAmount >= totalFees ? 'paid' : paidAmount > 0 ? 'partial' : 'due';
        await currentFee.save();
      }
    } else if (totalFees > 0) {
      await Fee.create({
        studentId: profile._id,
        batchId: profile.batchId,
        totalFees,
        paidAmount,
        status: paidAmount >= totalFees ? 'paid' : paidAmount > 0 ? 'partial' : 'due',
      });
    }
  }
  return getStudent({ ...req, params: { id: profile.id } }, res);
}

async function deleteStudent(req, res) {
  if (!mongoose.isValidObjectId(req.params.id)) throw new HttpError(404, 'Student not found');
  const profile = await StudentProfile.findById(req.params.id);
  if (!profile) throw new HttpError(404, 'Student not found');
  const userId = profile.userId;
  const publicId = profile.photoPublicId;
  const session = await mongoose.startSession();
  try {
    await session.withTransaction(async () => {
      await Attendance.deleteMany({ studentId: profile._id }).session(session);
      await TestAttempt.deleteMany({ studentId: profile._id }).session(session);
      await PhysicalTrainingResult.deleteMany({ studentId: profile._id }).session(session);
      await PhysicalTrainingSheet.updateMany(
        { 'rows.studentId': profile._id },
        { $pull: { rows: { studentId: profile._id } } },
        { session },
      );
      await Fee.deleteMany({ studentId: profile._id }).session(session);
      await Notification.deleteMany({ userId }).session(session);
      await StudentProfile.deleteOne({ _id: profile._id }).session(session);
      await User.deleteOne({ _id: userId }).session(session);
    });
  } finally {
    await session.endSession();
  }
  if (publicId) await cloudImages.deleteImage(publicId);
  return respond(res, { message: 'Student account and associated profile, attendance, test attempts, physical results, physical marks-sheet rows, fees, and notifications were permanently deleted' });
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
async function deleteStudentPhoto(req, res) {
  if (!mongoose.isValidObjectId(req.params.id)) throw new HttpError(404, 'Student not found');
  const profile = await StudentProfile.findById(req.params.id);
  if (!profile) throw new HttpError(404, 'Student not found');
  const publicId = profile.photoPublicId;
  profile.photo = '';
  profile.photoPublicId = '';
  await profile.save();
  if (publicId) await cloudImages.deleteImage(publicId);
  return respond(res, { photo: '' });
}
module.exports = {
  listStudents,
  createStudent,
  getStudent,
  resetStudentPassword,
  getOwnProfile,
  updateStudent,
  deleteStudent,
  uploadOwnPhoto,
  uploadStudentPhoto,
  deleteStudentPhoto,
};
