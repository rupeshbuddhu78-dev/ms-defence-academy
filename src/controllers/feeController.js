const Fee = require('../models/Fee');
const Payment = require('../models/Payment');
const Student = require('../models/Student');
const { logAudit } = require('../utils/auditLogger');

exports.getFees = async (req, res, next) => {
  try {
    const { studentId, status, page = 1, limit = 20 } = req.query;
    const query = {};
    if (studentId) query.studentId = studentId.toUpperCase();
    if (status) query.status = status;
    const skip = (Math.max(1, parseInt(page)) - 1) * Math.min(100, parseInt(limit) || 20);
    const lim = Math.min(100, parseInt(limit) || 20);
    const [fees, total] = await Promise.all([
      Fee.find(query).populate('student', 'fullName photoUrl').sort({ updatedAt: -1 }).skip(skip).limit(lim),
      Fee.countDocuments(query)
    ]);
    res.status(200).json({ success: true, data: { fees, pagination: { page: parseInt(page)||1, limit: lim, total, pages: Math.ceil(total/lim) } } });
  } catch (e) { next(e); }
};

exports.recordOfflinePayment = async (req, res, next) => {
  try {
    const { studentId, amount, mode, receiptNumber, remarks, paymentDate } = req.body;
    if (!studentId || !amount || !mode) {
      return res.status(400).json({ success: false, message: 'studentId, amount and mode required', code: 'VALIDATION_ERROR' });
    }
    const student = await Student.findOne({ studentId: studentId.toUpperCase() });
    if (!student) return res.status(404).json({ success: false, message: 'Student not found', code: 'NOT_FOUND' });

    const payment = await Payment.create({
      student: student._id,
      studentId: student.studentId,
      amount,
      mode,
      status: 'PAID',
      receiptNumber: receiptNumber || `RCP${Date.now()}`,
      remarks,
      recordedBy: req.user._id,
      paymentDate: paymentDate ? new Date(paymentDate) : new Date()
    });

    student.paidFee = (student.paidFee || 0) + Number(amount);
    await student.save();

    let fee = await Fee.findOne({ student: student._id });
    if (fee) {
      fee.paidAmount = (fee.paidAmount || 0) + Number(amount);
      fee.pendingAmount = Math.max(0, fee.totalFee - fee.paidAmount);
      fee.status = fee.pendingAmount === 0 ? 'PAID' : 'PARTIAL';
      await fee.save();
    }

    await logAudit({ adminId: req.user._id, action: 'OFFLINE_PAYMENT', entityType: 'Payment', entityId: payment._id, newValue: { studentId, amount, mode }, req });

    res.status(201).json({ success: true, message: 'Payment recorded', data: payment });
  } catch (e) { next(e); }
};
