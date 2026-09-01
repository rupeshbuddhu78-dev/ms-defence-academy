const mongoose = require('mongoose');

const feeSchema = new mongoose.Schema({
  student: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'Student',
    required: true
  },
  studentId: {
    type: String,
    required: true
  },
  totalFee: {
    type: Number,
    required: true,
    min: 0
  },
  paidAmount: {
    type: Number,
    default: 0,
    min: 0
  },
  pendingAmount: {
    type: Number,
    default: 0
  },
  nextDueDate: {
    type: Date
  },
  course: {
    type: String
  },
  remarks: {
    type: String
  },
  status: {
    type: String,
    enum: ['PENDING', 'PARTIAL', 'PAID', 'OVERDUE'],
    default: 'PENDING'
  }
}, {
  timestamps: true
});

feeSchema.index({ student: 1 });
feeSchema.index({ studentId: 1 });
feeSchema.index({ status: 1 });

module.exports = mongoose.model('Fee', feeSchema);
