const mongoose = require('mongoose');

const schema = new mongoose.Schema({
  studentId: { type: mongoose.Schema.Types.ObjectId, ref: 'StudentProfile', required: true, index: true },
  batchId: { type: mongoose.Schema.Types.ObjectId, ref: 'Batch', required: true, index: true },
  testDate: { type: Date, required: true, default: Date.now, index: true },
  runTimeSeconds: { type: Number, min: 0, max: 86400, default: null },
  beamReps: { type: Number, min: 0, max: 1000, default: null },
  longJumpCm: { type: Number, min: 0, max: 1000, default: null },
  highJumpCm: { type: Number, min: 0, max: 1000, default: null },
  pushUps: { type: Number, min: 0, max: 1000, default: null },
  sitUps: { type: Number, min: 0, max: 1000, default: null },
  shuttleRunSeconds: { type: Number, min: 0, max: 86400, default: null },
  remarks: { type: String, trim: true, maxlength: 1000, default: '' },
  recordedBy: { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true },
}, { timestamps: true });

schema.index({ studentId: 1, testDate: -1 });
schema.index({ batchId: 1, testDate: -1 });
module.exports = mongoose.model('PhysicalTrainingResult', schema);
