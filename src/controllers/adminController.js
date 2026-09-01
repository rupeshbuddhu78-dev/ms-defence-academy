const Student = require('../models/Student');
const User = require('../models/User');
const Admin = require('../models/Admin');
const Batch = require('../models/Batch');
const Attendance = require('../models/Attendance');
const Fee = require('../models/Fee');
const Payment = require('../models/Payment');
const Notice = require('../models/Notice');
const Media = require('../models/Media');
const { logAudit } = require('../utils/auditLogger');
const crypto = require('crypto');

const getServerDate = () => {
  const now = new Date();
  const ist = new Date(now.getTime() + 5.5 * 60 * 60 * 1000);
  return ist.toISOString().slice(0, 10);
};

exports.getDashboard = async (req, res, next) => {
  try {
    const date = getServerDate();
    const [
      totalStudents,
      activeStudents,
      todayEntries,
      todayExits,
      currentlyInside,
      pendingFeesCount,
      activeBatches
    ] = await Promise.all([
      Student.countDocuments(),
      Student.countDocuments({ status: 'ACTIVE' }),
      Attendance.countDocuments({ date, entryTime: { $exists: true, $ne: null } }),
      Attendance.countDocuments({ date, exitTime: { $exists: true, $ne: null } }),
      Attendance.countDocuments({
        date,
        entryTime: { $exists: true, $ne: null },
        $or: [{ exitTime: null }, { exitTime: { $exists: false } }]
      }),
      Student.countDocuments({ $expr: { $gt: ['$totalFee', '$paidFee'] } }),
      Batch.countDocuments({ status: 'ACTIVE' })
    ]);

    res.status(200).json({
      success: true,
      data: {
        totalStudents,
        activeStudents,
        todayEntry: todayEntries,
        todayExit: todayExits,
        currentlyInside,
        pendingFees: pendingFeesCount,
        activeBatches
      }
    });
  } catch (error) { next(error); }
};

exports.getStudents = async (req, res, next) => {
  try {
    const { search, status, batchId, page = 1, limit = 20 } = req.query;
    const query = {};
    if (status) query.status = status;
    if (batchId) query.batch = batchId;
    if (search) {
      query.$or = [
        { fullName: new RegExp(search, 'i') },
        { studentId: new RegExp(search, 'i') },
        { mobile: new RegExp(search, 'i') }
      ];
    }
    const skip = (Math.max(1, parseInt(page)) - 1) * Math.min(100, parseInt(limit) || 20);
    const lim = Math.min(100, parseInt(limit) || 20);
    const [students, total] = await Promise.all([
      Student.find(query)
        .populate('batch', 'name course')
        .select('-qrIdentifier')
        .sort({ createdAt: -1 })
        .skip(skip)
        .limit(lim),
      Student.countDocuments(query)
    ]);
    res.status(200).json({
      success: true,
      data: {
        students,
        pagination: { page: parseInt(page) || 1, limit: lim, total, pages: Math.ceil(total / lim) }
      }
    });
  } catch (error) { next(error); }
};

exports.getStudentById = async (req, res, next) => {
  try {
    const student = await Student.findById(req.params.id)
      .populate('batch', 'name course instructor startTime endTime days')
      .populate('user', 'isActive lastLogin');
    if (!student) {
      return res.status(404).json({ success: false, message: 'Student not found', code: 'NOT_FOUND' });
    }
    const Attendance = require('../models/Attendance');
    const Fee = require('../models/Fee');
    const Payment = require('../models/Payment');
    const [attendance, fee, payments] = await Promise.all([
      Attendance.find({ student: student._id }).sort({ date: -1 }).limit(60),
      Fee.findOne({ student: student._id }),
      Payment.find({ student: student._id, status: 'PAID' }).sort({ paymentDate: -1 })
    ]);
    const present = attendance.filter(a => a.entryTime).length;
    const total = attendance.length;
    res.status(200).json({
      success: true,
      data: {
        student,
        attendance: {
          summary: {
            totalDays: total,
            present,
            absent: total - present,
            percentage: total > 0 ? parseFloat(((present / total) * 100).toFixed(2)) : 0
          },
          history: attendance
        },
        fee: fee || { totalFee: student.totalFee, paidAmount: student.paidFee, pendingAmount: Math.max(0, (student.totalFee||0)-(student.paidFee||0)) },
        payments
      }
    });
  } catch (error) { next(error); }
};

exports.createStudent = async (req, res, next) => {
  try {
    const {
      fullName, fatherName, motherName, mobile, alternateMobile,
      dateOfBirth, gender, address, district, state, course, batchId, password, totalFee
    } = req.body;

    if (!fullName || !mobile || !password) {
      return res.status(400).json({ success: false, message: 'Required fields missing', code: 'VALIDATION_ERROR' });
    }

    const existing = await User.findOne({ mobile });
    if (existing) {
      return res.status(409).json({ success: false, message: 'Mobile already registered', code: 'MOBILE_EXISTS' });
    }

    const studentId = await Student.generateStudentId();
    const qrIdentifier = Student.generateQrIdentifier();

    const user = await User.create({
      role: 'STUDENT',
      mobile,
      password,
      isActive: true
    });

    const student = await Student.create({
      user: user._id,
      studentId,
      fullName,
      fatherName,
      motherName,
      mobile,
      alternateMobile,
      dateOfBirth: dateOfBirth ? new Date(dateOfBirth) : undefined,
      gender,
      address,
      district,
      state: state || 'Bihar',
      course: course || 'NDA',
      batch: batchId || undefined,
      qrIdentifier,
      status: 'ACTIVE',
      totalFee: totalFee || 0
    });

    if (totalFee) {
      await Fee.create({
        student: student._id,
        studentId: student.studentId,
        totalFee,
        paidAmount: 0,
        pendingAmount: totalFee,
        status: 'PENDING'
      });
    }

    await logAudit({
      adminId: req.user._id,
      action: 'STUDENT_CREATED',
      entityType: 'Student',
      entityId: student._id,
      newValue: { studentId, fullName, mobile },
      req
    });

    res.status(201).json({
      success: true,
      message: 'Student created successfully',
      data: { studentId: student.studentId, fullName: student.fullName, id: student._id }
    });
  } catch (error) { next(error); }
};

exports.updateStudent = async (req, res, next) => {
  try {
    const allowed = [
      'fullName', 'fatherName', 'motherName', 'alternateMobile', 'dateOfBirth',
      'gender', 'address', 'district', 'state', 'course', 'batch', 'totalFee'
    ];
    const updates = {};
    allowed.forEach(f => { if (req.body[f] !== undefined) updates[f] = req.body[f]; });
    if (req.body.batchId) updates.batch = req.body.batchId;

    const student = await Student.findByIdAndUpdate(req.params.id, updates, { new: true, runValidators: true })
      .populate('batch', 'name course');
    if (!student) {
      return res.status(404).json({ success: false, message: 'Student not found', code: 'NOT_FOUND' });
    }

    await logAudit({
      adminId: req.user._id,
      action: 'STUDENT_UPDATED',
      entityType: 'Student',
      entityId: student._id,
      newValue: updates,
      req
    });

    res.status(200).json({ success: true, message: 'Student updated', data: student });
  } catch (error) { next(error); }
};

exports.updateStudentStatus = async (req, res, next) => {
  try {
    const { status } = req.body;
    if (!['PENDING', 'ACTIVE', 'INACTIVE', 'SUSPENDED'].includes(status)) {
      return res.status(400).json({ success: false, message: 'Invalid status', code: 'VALIDATION_ERROR' });
    }
    const student = await Student.findById(req.params.id);
    if (!student) {
      return res.status(404).json({ success: false, message: 'Student not found', code: 'NOT_FOUND' });
    }
    const oldStatus = student.status;
    student.status = status;
    await student.save();

    const user = await User.findById(student.user);
    if (user) {
      user.isActive = status === 'ACTIVE';
      await user.save();
    }

    await logAudit({
      adminId: req.user._id,
      action: 'STUDENT_STATUS_CHANGED',
      entityType: 'Student',
      entityId: student._id,
      oldValue: { status: oldStatus },
      newValue: { status },
      req
    });

    res.status(200).json({ success: true, message: `Student ${status.toLowerCase()}`, data: { status } });
  } catch (error) { next(error); }
};

exports.regenerateQR = async (req, res, next) => {
  try {
    const student = await Student.findById(req.params.id);
    if (!student) {
      return res.status(404).json({ success: false, message: 'Student not found', code: 'NOT_FOUND' });
    }
    const oldQr = student.qrIdentifier;
    student.qrIdentifier = Student.generateQrIdentifier();
    student.qrActive = true;
    await student.save();

    await logAudit({
      adminId: req.user._id,
      action: 'QR_REGENERATED',
      entityType: 'Student',
      entityId: student._id,
      oldValue: { qrIdentifier: oldQr },
      newValue: { qrIdentifier: student.qrIdentifier },
      req
    });

    res.status(200).json({
      success: true,
      message: 'QR regenerated. Old QR is now invalid.',
      data: { qrIdentifier: student.qrIdentifier }
    });
  } catch (error) { next(error); }
};

exports.resetStudentPassword = async (req, res, next) => {
  try {
    const { newPassword } = req.body;
    if (!newPassword || newPassword.length < 6) {
      return res.status(400).json({ success: false, message: 'Password must be at least 6 characters', code: 'VALIDATION_ERROR' });
    }
    const student = await Student.findById(req.params.id);
    if (!student) {
      return res.status(404).json({ success: false, message: 'Student not found', code: 'NOT_FOUND' });
    }
    const user = await User.findById(student.user).select('+password');
    user.password = newPassword;
    user.mustChangePassword = true;
    await user.save();

    await logAudit({
      adminId: req.user._id,
      action: 'STUDENT_PASSWORD_RESET',
      entityType: 'Student',
      entityId: student._id,
      req
    });

    res.status(200).json({ success: true, message: 'Password reset. Student must change on next login.' });
  } catch (error) { next(error); }
};
