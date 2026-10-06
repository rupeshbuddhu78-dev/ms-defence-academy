const mongoose = require('mongoose');
const schema = new mongoose.Schema({
  studentId: { type: mongoose.Schema.Types.ObjectId, ref: 'StudentProfile', required: true, index: true }, totalFees: { type: Number, required: true, min: 0 }, paidAmount: { type: Number, default: 0, min: 0 },
  payments: [{ amount: { type: Number, min: 0 }, paymentDate: { type: Date, default: Date.now }, note: { type: String, default: '' }, recordedBy: { type: mongoose.Schema.Types.ObjectId, ref: 'User' } }],
  dueDate: { type: Date }, status: { type: String, enum: ['due', 'partial', 'paid'], default: 'due' }, remarks: { type: String, default: '' }
}, { timestamps: true });
schema.virtual('remainingAmount').get(function () { return Math.max(0, this.totalFees - this.paidAmount); });
schema.set('toJSON', { virtuals: true });
module.exports = mongoose.model('Fee', schema);
