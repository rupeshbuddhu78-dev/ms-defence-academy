const Attendance = require('../models/Attendance');
const Student = require('../models/Student');
const { logAudit } = require('../utils/auditLogger');

// Helper: get server date as YYYY-MM-DD in IST
const getServerDate = () => {
  const now = new Date();
  // Convert to IST (UTC+5:30)
  const istOffset = 5.5 * 60 * 60 * 1000;
  const ist = new Date(now.getTime() + istOffset);
  return ist.toISOString().slice(0, 10);
};

// @desc    Mark ENTRY attendance via QR
// @route   POST /api/admin/attendance/entry
exports.markEntry = async (req, res, next) => {
  try {
    const { qrIdentifier } = req.body;
    if (!qrIdentifier) {
      return res.status(400).json({
        success: false,
        message: 'QR identifier is required',
        code: 'VALIDATION_ERROR'
      });
    }

    const student = await Student.findOne({ qrIdentifier, qrActive: true })
      .populate('batch', 'name');
    if (!student) {
      return res.status(404).json({
        success: false,
        message: 'Invalid or revoked QR code',
        code: 'INVALID_QR'
      });
    }
    if (student.status !== 'ACTIVE') {
      return res.status(403).json({
        success: false,
        message: 'Student is not active',
        code: 'STUDENT_INACTIVE'
      });
    }

    const date = getServerDate();
    const now = new Date();

    // Atomic: try to create or update only if no entry yet
    let attendance = await Attendance.findOne({ student: student._id, date });

    if (attendance && attendance.entryTime) {
      return res.status(409).json({
        success: false,
        message: "Today's ENTRY attendance is already recorded.",
        code: 'DUPLICATE_ENTRY'
      });
    }

    if (!attendance) {
      attendance = new Attendance({
        student: student._id,
        studentId: student.studentId,
        batch: student.batch,
        date,
        entryTime: now,
        entryMarkedBy: req.user._id,
        status: 'PRESENT'
      });
    } else {
      attendance.entryTime = now;
      attendance.entryMarkedBy = req.user._id;
      attendance.status = 'PRESENT';
    }

    await attendance.save();

    await logAudit({
      adminId: req.user._id,
      action: 'ATTENDANCE_ENTRY',
      entityType: 'Attendance',
      entityId: attendance._id,
      newValue: { studentId: student.studentId, date, entryTime: now },
      req
    });

    res.status(200).json({
      success: true,
      message: 'Entry attendance recorded successfully',
      data: {
        student: {
          studentId: student.studentId,
          fullName: student.fullName,
          photoUrl: student.photoUrl,
          batch: student.batch
        },
        attendance: {
          date,
          entryTime: attendance.entryTime,
          type: 'ENTRY'
        }
      }
    });
  } catch (error) {
    if (error.code === 11000) {
      return res.status(409).json({
        success: false,
        message: "Today's ENTRY attendance is already recorded.",
        code: 'DUPLICATE_ENTRY'
      });
    }
    next(error);
  }
};

// @desc    Mark EXIT attendance via QR
// @route   POST /api/admin/attendance/exit
exports.markExit = async (req, res, next) => {
  try {
    const { qrIdentifier } = req.body;
    if (!qrIdentifier) {
      return res.status(400).json({
        success: false,
        message: 'QR identifier is required',
        code: 'VALIDATION_ERROR'
      });
    }

    const student = await Student.findOne({ qrIdentifier, qrActive: true })
      .populate('batch', 'name');
    if (!student) {
      return res.status(404).json({
        success: false,
        message: 'Invalid or revoked QR code',
        code: 'INVALID_QR'
      });
    }

    const date = getServerDate();
    const now = new Date();

    let attendance = await Attendance.findOne({ student: student._id, date });

    if (!attendance || !attendance.entryTime) {
      return res.status(400).json({
        success: false,
        message: 'Please record ENTRY attendance before EXIT.',
        code: 'NO_ENTRY'
      });
    }

    if (attendance.exitTime) {
      return res.status(409).json({
        success: false,
        message: "Today's EXIT attendance is already recorded.",
        code: 'DUPLICATE_EXIT'
      });
    }

    attendance.exitTime = now;
    attendance.exitMarkedBy = req.user._id;
    await attendance.save();

    await logAudit({
      adminId: req.user._id,
      action: 'ATTENDANCE_EXIT',
      entityType: 'Attendance',
      entityId: attendance._id,
      newValue: { studentId: student.studentId, date, exitTime: now },
      req
    });

    res.status(200).json({
      success: true,
      message: 'Exit attendance recorded successfully',
      data: {
        student: {
          studentId: student.studentId,
          fullName: student.fullName,
          photoUrl: student.photoUrl,
          batch: student.batch
        },
        attendance: {
          date,
          entryTime: attendance.entryTime,
          exitTime: attendance.exitTime,
          type: 'EXIT'
        }
      }
    });
  } catch (error) {
    next(error);
  }
};

// @desc    Currently inside academy
// @route   GET /api/admin/attendance/currently-inside
exports.currentlyInside = async (req, res, next) => {
  try {
    const date = getServerDate();
    const records = await Attendance.find({
      date,
      entryTime: { $exists: true, $ne: null },
      $or: [{ exitTime: null }, { exitTime: { $exists: false } }]
    })
      .populate({
        path: 'student',
        select: 'studentId fullName photoUrl batch',
        populate: { path: 'batch', select: 'name' }
      })
      .sort({ entryTime: -1 });

    res.status(200).json({
      success: true,
      data: {
        count: records.length,
        students: records.map(r => ({
          studentId: r.student?.studentId,
          fullName: r.student?.fullName,
          photoUrl: r.student?.photoUrl,
          batch: r.student?.batch,
          entryTime: r.entryTime
        }))
      }
    });
  } catch (error) {
    next(error);
  }
};

// @desc    Get attendance list (admin)
// @route   GET /api/admin/attendance
exports.getAttendance = async (req, res, next) => {
  try {
    const { date, batchId, studentId, page = 1, limit = 20 } = req.query;
    const query = {};
    if (date) query.date = date;
    if (batchId) query.batch = batchId;
    if (studentId) query.studentId = studentId.toUpperCase();

    const skip = (Math.max(1, parseInt(page)) - 1) * Math.min(100, parseInt(limit) || 20);
    const lim = Math.min(100, parseInt(limit) || 20);

    const [records, total] = await Promise.all([
      Attendance.find(query)
        .populate('student', 'studentId fullName photoUrl')
        .populate('batch', 'name')
        .sort({ date: -1, entryTime: -1 })
        .skip(skip)
        .limit(lim),
      Attendance.countDocuments(query)
    ]);

    res.status(200).json({
      success: true,
      data: {
        records,
        pagination: {
          page: parseInt(page) || 1,
          limit: lim,
          total,
          pages: Math.ceil(total / lim)
        }
      }
    });
  } catch (error) {
    next(error);
  }
};

// @desc    Student own attendance
// @route   GET /api/student/attendance
exports.getStudentAttendance = async (req, res, next) => {
  try {
    const student = await Student.findOne({ user: req.user._id });
    if (!student) {
      return res.status(404).json({
        success: false,
        message: 'Student profile not found',
        code: 'NOT_FOUND'
      });
    }

    const { month, year, from, to } = req.query;
    const query = { student: student._id };

    if (from && to) {
      query.date = { $gte: from, $lte: to };
    } else if (month && year) {
      const m = String(month).padStart(2, '0');
      query.date = { $regex: `^${year}-${m}` };
    }

    const records = await Attendance.find(query).sort({ date: -1 });

    const totalDays = records.length;
    const present = records.filter(r => r.entryTime).length;
    const absent = totalDays - present;
    const percentage = totalDays > 0 ? ((present / totalDays) * 100).toFixed(2) : 0;

    res.status(200).json({
      success: true,
      data: {
        summary: {
          totalDays,
          present,
          absent,
          percentage: parseFloat(percentage)
        },
        history: records.map(r => ({
          date: r.date,
          entryTime: r.entryTime,
          exitTime: r.exitTime,
          status: r.entryTime ? 'PRESENT' : 'ABSENT'
        }))
      }
    });
  } catch (error) {
    next(error);
  }
};


exports.correctAttendance = async (req, res, next) => {
  try {
    const { entryTime, exitTime, status, reason } = req.body;
    if (!reason || !String(reason).trim()) {
      return res.status(400).json({ success: false, message: 'Correction reason is required', code: 'VALIDATION_ERROR' });
    }
    const Attendance = require('../models/Attendance');
    const record = await Attendance.findById(req.params.id);
    if (!record) {
      return res.status(404).json({ success: false, message: 'Attendance not found', code: 'NOT_FOUND' });
    }
    const oldValue = {
      entryTime: record.entryTime,
      exitTime: record.exitTime,
      status: record.status
    };
    if (entryTime !== undefined) record.entryTime = entryTime ? new Date(entryTime) : record.entryTime;
    if (exitTime !== undefined) record.exitTime = exitTime ? new Date(exitTime) : null;
    if (status) record.status = status;
    record.correctedBy = req.user._id;
    record.correctedAt = new Date();
    record.correctionReason = String(reason).trim();
    await record.save();

    try {
      const { logAudit } = require('../utils/auditLogger');
      await logAudit({
        adminId: req.user._id,
        action: 'ATTENDANCE_CORRECTED',
        entityType: 'Attendance',
        entityId: record._id,
        oldValue,
        newValue: { entryTime: record.entryTime, exitTime: record.exitTime, status: record.status },
        reason,
        req
      });
    } catch (_) {}

    res.status(200).json({ success: true, message: 'Attendance corrected', data: record });
  } catch (error) { next(error); }
};

exports.adminCalendar = async (req, res, next) => {
  try {
    const { month, year, batchId } = req.query;
    if (!month || !year) {
      return res.status(400).json({ success: false, message: 'month and year required (1-12, YYYY)' });
    }
    const m = String(month).padStart(2, '0');
    const prefix = `${year}-${m}`;
    const query = { date: { $regex: `^${prefix}` } };
    if (batchId) query.batch = batchId;

    const records = await Attendance.find(query)
      .populate('student', 'fullName studentId photoUrl mobile')
      .populate('batch', 'name');

    const byDate = {};
    for (const r of records) {
      if (!byDate[r.date]) {
        byDate[r.date] = { date: r.date, present: 0, absent: 0, total: 0, records: [] };
      }
      byDate[r.date].total += 1;
      if (r.entryTime) byDate[r.date].present += 1;
      else byDate[r.date].absent += 1;
      byDate[r.date].records.push({
        id: r._id,
        studentId: r.studentId,
        fullName: r.student?.fullName,
        photoUrl: r.student?.photoUrl,
        status: r.status,
        entryTime: r.entryTime,
        exitTime: r.exitTime,
        batchName: r.batch?.name
      });
    }

    res.status(200).json({
      success: true,
      data: {
        month: parseInt(month, 10),
        year: parseInt(year, 10),
        days: Object.values(byDate).sort((a, b) => a.date.localeCompare(b.date))
      }
    });
  } catch (error) { next(error); }
};
