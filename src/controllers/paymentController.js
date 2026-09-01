const Razorpay = require('razorpay');
const crypto = require('crypto');
const Payment = require('../models/Payment');
const Student = require('../models/Student');
const Fee = require('../models/Fee');

const getRazorpay = () => {
  if (!process.env.RAZORPAY_KEY_ID || !process.env.RAZORPAY_KEY_SECRET) {
    return null;
  }
  return new Razorpay({
    key_id: process.env.RAZORPAY_KEY_ID,
    key_secret: process.env.RAZORPAY_KEY_SECRET
  });
};

exports.createOrder = async (req, res, next) => {
  try {
    const { amount } = req.body;
    if (!amount || amount < 1) {
      return res.status(400).json({ success: false, message: 'Valid amount required', code: 'VALIDATION_ERROR' });
    }
    const student = await Student.findOne({ user: req.user._id });
    if (!student) return res.status(404).json({ success: false, message: 'Student not found', code: 'NOT_FOUND' });

    const razorpay = getRazorpay();
    if (!razorpay) {
      return res.status(503).json({ success: false, message: 'Payment gateway not configured', code: 'GATEWAY_NOT_CONFIGURED' });
    }

    const options = {
      amount: Math.round(amount * 100),
      currency: 'INR',
      receipt: `rcpt_${student.studentId}_${Date.now()}`,
      notes: { studentId: student.studentId }
    };
    const order = await razorpay.orders.create(options);

    await Payment.create({
      student: student._id,
      studentId: student.studentId,
      amount,
      mode: 'ONLINE',
      status: 'PENDING',
      orderId: order.id,
      razorpayOrderId: order.id
    });

    res.status(200).json({
      success: true,
      data: {
        orderId: order.id,
        amount: order.amount,
        currency: order.currency,
        keyId: process.env.RAZORPAY_KEY_ID
      }
    });
  } catch (e) { next(e); }
};

exports.verifyPayment = async (req, res, next) => {
  try {
    const { orderId, paymentId, signature } = req.body;
    if (!orderId || !paymentId || !signature) {
      return res.status(400).json({ success: false, message: 'orderId, paymentId and signature required', code: 'VALIDATION_ERROR' });
    }

    const body = orderId + '|' + paymentId;
    const expected = crypto
      .createHmac('sha256', process.env.RAZORPAY_KEY_SECRET || '')
      .update(body)
      .digest('hex');

    if (expected !== signature) {
      return res.status(400).json({ success: false, message: 'Invalid payment signature', code: 'INVALID_SIGNATURE' });
    }

    const payment = await Payment.findOne({ orderId });
    if (!payment) return res.status(404).json({ success: false, message: 'Order not found', code: 'NOT_FOUND' });
    if (payment.status === 'PAID') {
      return res.status(200).json({ success: true, message: 'Payment already verified', data: payment });
    }

    payment.paymentId = paymentId;
    payment.signature = signature;
    payment.status = 'PAID';
    payment.paymentDate = new Date();
    await payment.save();

    const student = await Student.findById(payment.student);
    if (student) {
      student.paidFee = (student.paidFee || 0) + payment.amount;
      await student.save();
    }
    const fee = await Fee.findOne({ student: payment.student });
    if (fee) {
      fee.paidAmount = (fee.paidAmount || 0) + payment.amount;
      fee.pendingAmount = Math.max(0, fee.totalFee - fee.paidAmount);
      fee.status = fee.pendingAmount === 0 ? 'PAID' : 'PARTIAL';
      await fee.save();
    }

    res.status(200).json({ success: true, message: 'Payment verified successfully', data: payment });
  } catch (e) { next(e); }
};
