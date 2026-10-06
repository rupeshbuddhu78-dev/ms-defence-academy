const mongoose = require('mongoose');
const schema = new mongoose.Schema({
  name: { type: String, required: true, trim: true }, course: { type: String, trim: true, default: '' },
  trainer: { type: String, trim: true, default: '' }, startTime: { type: String, default: '' }, endTime: { type: String, default: '' },
  status: { type: String, enum: ['active', 'inactive'], default: 'active', index: true }, location: { type: String, default: '' }
}, { timestamps: true });
schema.index({ name: 1 }, { unique: true });
module.exports = mongoose.model('Batch', schema);
