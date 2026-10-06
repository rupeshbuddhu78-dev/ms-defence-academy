const mongoose = require('mongoose');

const adjustmentSchema = new mongoose.Schema({
  previousTotal: { type: Number, required: true, min: 0 },
  newTotal: { type: Number, required: true, min: 0 },
  previousPaid: { type: Number, required: true, min: 0 },
  newPaid: { type: Number, required: true, min: 0 },
  note: { type: String, default: 'Admin fee correction' },
  recordedBy: { type: mongoose.Schema.Types.ObjectId, ref: 'User' },
  adjustedAt: { type: Date, default: Date.now },
}, { _id: false });

const schema = new mongoose.Schema({
  studentId: { type: mongoose.Schema.Types.ObjectId, ref: 'StudentProfile', required: true, index: true },
  batchId: { type: mongoose.Schema.Types.ObjectId, ref: 'Batch', index: true },
  totalFees: { type: Number, required: true, min: 0 },
  paidAmount: { type: Number, default: 0, min: 0 },
  payments: [{
    amount: { type: Number, min: 0 },
    paymentDate: { type: Date, default: Date.now },
    note: { type: String, default: '' },
    recordedBy: { type: mongoose.Schema.Types.ObjectId, ref: 'User' },
  }],
  adjustments: { type: [adjustmentSchema], default: [] },
  dueDate: { type: Date },
  status: { type: String, enum: ['due', 'partial', 'paid'], default: 'due' },
  remarks: { type: String, default: '' },
}, { timestamps: true });

schema.virtual('remainingAmount').get(function () {
  return Math.max(0, this.totalFees - this.paidAmount);
});
schema.set('toJSON', { virtuals: true });

module.exports = mongoose.model('Fee', schema);
