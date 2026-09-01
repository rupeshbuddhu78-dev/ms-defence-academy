const Student = require('../models/Student');
const User = require('../models/User');
const Batch = require('../models/Batch');
const Fee = require('../models/Fee');
const { logAudit } = require('../utils/auditLogger');
const { createNotification } = require('../utils/notify');
const { notifyUser } = require('../services/fcmService');

exports.listPending = async (req, res, next) => {
  try {
    const students = await Student.find({ status: 'PENDING' })
      .populate('user', 'email mobile isActive createdAt fullName')
      .populate('batch', 'name course')
      .sort({ createdAt: -1 });
    res.status(200).json({
      success: true,
      data: {
        students,
        count: students.length
      }
    });
  } catch (e) { next(e); }
};

exports.approveStudent = async (req, res, next) => {
  try {
    const { course, batchId, joiningDate, totalFee } = req.body;
    const student = await Student.findById(req.params.id).populate('user');
    if (!student) {
      return res.status(404).json({ success: false, message: 'Student not found', code: 'NOT_FOUND' });
    }
    if (student.status !== 'PENDING') {
      return res.status(400).json({
        success: false,
        message: `Student is already ${student.status}`,
        code: 'INVALID_STATUS'
      });
    }

    student.status = 'ACTIVE';
    if (course) student.course = course;
    if (batchId) student.batch = batchId;
    if (joiningDate) student.joiningDate = new Date(joiningDate);
    if (totalFee != null) student.totalFee = Number(totalFee);

    // Ensure QR exists
    if (!student.qrIdentifier) {
      student.qrIdentifier = Student.generateQrIdentifier();
      student.qrActive = true;
    }

    await student.save();

    const user = await User.findById(student.user);
    if (user) {
      user.isActive = true;
      user.role = 'STUDENT';
      await user.save();
    }

    if (totalFee && Number(totalFee) > 0) {
      let fee = await Fee.findOne({ student: student._id });
      if (!fee) {
        await Fee.create({
          student: student._id,
          studentId: student.studentId,
          totalFee: Number(totalFee),
          paidAmount: 0,
          pendingAmount: Number(totalFee),
          status: 'PENDING',
          course: student.course
        });
      }
    }

    if (user) {
      await notifyUser(user._id, {
        title: 'Registration Approved',
        message: 'Your student account is now ACTIVE. Student ID: ' + student.studentId,
        type: 'ACCOUNT',
        deepLink: 'PROFILE'
      });
    }

    await logAudit({
      adminId: req.user._id,
      action: 'STUDENT_APPROVED',
      entityType: 'Student',
      entityId: student._id,
      newValue: { status: 'ACTIVE', course: student.course, batchId },
      req
    });

    res.status(200).json({
      success: true,
      message: 'Student approved and activated',
      data: {
        studentId: student.studentId,
        fullName: student.fullName,
        status: student.status
      }
    });
  } catch (e) { next(e); }
};

exports.rejectStudent = async (req, res, next) => {
  try {
    const { reason } = req.body;
    if (!reason || !String(reason).trim()) {
      return res.status(400).json({
        success: false,
        message: 'Rejection reason is required',
        code: 'VALIDATION_ERROR'
      });
    }

    const student = await Student.findById(req.params.id);
    if (!student) {
      return res.status(404).json({ success: false, message: 'Student not found', code: 'NOT_FOUND' });
    }
    if (student.status !== 'PENDING') {
      return res.status(400).json({
        success: false,
        message: `Student is already ${student.status}`,
        code: 'INVALID_STATUS'
      });
    }

    student.status = 'REJECTED';
    student.rejectionReason = String(reason).trim();
    student.rejectedBy = req.user._id;
    student.rejectedAt = new Date();
    await student.save();

    const user = await User.findById(student.user);
    if (user) {
      user.isActive = false;
      await user.save();
    }

    const u2 = await User.findById(student.user);
    if (u2) {
      await notifyUser(u2._id, {
        title: 'Registration Rejected',
        message: 'Your student registration was rejected. ' + (reason || ''),
        type: 'ACCOUNT'
      });
    }

    await logAudit({
      adminId: req.user._id,
      action: 'STUDENT_REJECTED',
      entityType: 'Student',
      entityId: student._id,
      newValue: { status: 'REJECTED', reason },
      req
    });

    res.status(200).json({
      success: true,
      message: 'Student registration rejected',
      data: { studentId: student.studentId, status: 'REJECTED' }
    });
  } catch (e) { next(e); }
};
