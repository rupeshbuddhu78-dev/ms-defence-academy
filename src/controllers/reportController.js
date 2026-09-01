const Student = require('../models/Student');
const Attendance = require('../models/Attendance');
const Fee = require('../models/Fee');
const Payment = require('../models/Payment');

exports.attendanceReport = async (req, res, next) => {
  try {
    const { from, to, batchId } = req.query;
    const match = {};
    if (from || to) {
      match.date = {};
      if (from) match.date.$gte = from;
      if (to) match.date.$lte = to;
    }
    if (batchId) match.batch = batchId;
    const records = await Attendance.find(match)
      .populate('student', 'fullName studentId mobile')
      .sort({ date: -1 })
      .limit(500);
    res.json({ success: true, data: { records, count: records.length } });
  } catch (e) { next(e); }
};

exports.feeReport = async (req, res, next) => {
  try {
    const fees = await Fee.find().populate('student', 'fullName studentId mobile').limit(500);
    const payments = await Payment.find({ status: 'PAID' }).sort({ paymentDate: -1 }).limit(500);
    const totalCollected = payments.reduce((s, p) => s + (p.amount || 0), 0);
    const totalPending = fees.reduce((s, f) => s + (f.pendingAmount || 0), 0);
    res.json({
      success: true,
      data: { totalCollected, totalPending, fees, payments: payments.slice(0, 100) }
    });
  } catch (e) { next(e); }
};

exports.studentReport = async (req, res, next) => {
  try {
    const [active, pending, suspended, inactive, total] = await Promise.all([
      Student.countDocuments({ status: 'ACTIVE' }),
      Student.countDocuments({ status: 'PENDING' }),
      Student.countDocuments({ status: 'SUSPENDED' }),
      Student.countDocuments({ status: 'INACTIVE' }),
      Student.countDocuments()
    ]);
    res.json({
      success: true,
      data: { total, active, pending, suspended, inactive }
    });
  } catch (e) { next(e); }
};

exports.lowAttendance = async (req, res, next) => {
  try {
    const threshold = parseFloat(req.query.threshold) || 75;
    const students = await Student.find({ status: 'ACTIVE' }).select('fullName studentId mobile totalFee paidFee');
    // Simplified: return active students for admin review (full calc would aggregate attendance)
    res.json({
      success: true,
      data: { threshold, students, note: 'Review individual attendance on student detail' }
    });
  } catch (e) { next(e); }
};
