const mongoose = require('mongoose');
const schema = new mongoose.Schema({
  studentId: { type: mongoose.Schema.Types.ObjectId, ref: 'StudentProfile', required: true, index: true },
  batchId: { type: mongoose.Schema.Types.ObjectId, ref: 'Batch', index: true },
  trainingSessionId: { type: mongoose.Schema.Types.ObjectId, ref: 'TrainingSession', default: null },
  date: { type: Date, required: true, index: true }, time: { type: Date, default: Date.now },
  status: { type: String, enum: ['present', 'absent', 'holiday'], default: 'present', index: true },
  markedBy: { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true }, notes: { type: String, default: '' }
}, { timestamps: true });
schema.index({ studentId: 1, trainingSessionId: 1, date: 1 }, { unique: true, partialFilterExpression: { status: 'present' } });
module.exports = mongoose.model('Attendance', schema);
