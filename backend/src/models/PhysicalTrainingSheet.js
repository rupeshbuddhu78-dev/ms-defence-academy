const mongoose = require('mongoose');

const columnSchema = new mongoose.Schema({
  key: { type: String, required: true, trim: true, maxlength: 40 },
  label: { type: String, required: true, trim: true, maxlength: 60 },
  type: { type: String, required: true, enum: ['measurement', 'marks', 'passfail'] },
}, { _id: false });

const rowSchema = new mongoose.Schema({
  studentId: { type: mongoose.Schema.Types.ObjectId, ref: 'StudentProfile', required: true },
  values: { type: Map, of: mongoose.Schema.Types.Mixed, default: () => new Map() },
  totalMarks: { type: Number, min: 0, default: 0 },
}, { _id: false });

const schema = new mongoose.Schema({
  batchId: { type: mongoose.Schema.Types.ObjectId, ref: 'Batch', required: true, index: true },
  title: { type: String, required: true, trim: true, maxlength: 100 },
  template: { type: String, required: true, trim: true, maxlength: 60 },
  testDate: { type: Date, required: true, default: Date.now, index: true },
  columns: { type: [columnSchema], required: true, validate: value => value.length > 0 && value.length <= 24 },
  rows: { type: [rowSchema], default: [] },
  createdBy: { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true },
}, {
  timestamps: true,
  toJSON: { flattenMaps: true },
  toObject: { flattenMaps: true },
});

schema.index({ batchId: 1, testDate: -1 });
module.exports = mongoose.model('PhysicalTrainingSheet', schema);
