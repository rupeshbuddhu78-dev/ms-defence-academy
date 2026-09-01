const mongoose = require('mongoose');

const paymentSchema = new mongoose.Schema({
  student: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'Student',
    required: true
  },
  studentId: {
    type: String,
    required: true
  },
  amount: {
    type: Number,
    required: true,
    min: 1
  },
  mode: {
    type: String,
    enum: ['ONLINE', 'CASH', 'UPI', 'BANK_TRANSFER', 'OTHER'],
    required: true
  },
  status: {
    type: String,
    enum: ['PENDING', 'PAID', 'FAILED', 'REFUNDED'],
    default: 'PENDING'
  },
  receiptNumber: {
    type: String
  },
  orderId: {
    type: String,
    unique: true,
    sparse: true
  },
  paymentId: {
    type: String,
    unique: true,
    sparse: true
  },
  signature: {
    type: String
  },
  razorpayOrderId: {
    type: String
  },
  remarks: {
    type: String
  },
  recordedBy: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'User'
  },
  paymentDate: {
    type: Date,
    default: Date.now
  }
}, {
  timestamps: true
});

paymentSchema.index({ student: 1 });
paymentSchema.index({ studentId: 1 });
paymentSchema.index({ orderId: 1 });
paymentSchema.index({ paymentId: 1 });
paymentSchema.index({ status: 1 });

module.exports = mongoose.model('Payment', paymentSchema);
