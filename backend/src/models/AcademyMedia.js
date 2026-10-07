const mongoose = require('mongoose');

const schema = new mongoose.Schema({
  title: { type: String, required: true, trim: true, maxlength: 160 },
  description: { type: String, default: '', trim: true, maxlength: 2000 },
  kind: { type: String, enum: ['file', 'video'], required: true, index: true },
  url: { type: String, required: true },
  publicId: { type: String, default: '' },
  resourceType: { type: String, default: 'auto' },
  format: { type: String, default: '' },
  mimeType: { type: String, default: '' },
  bytes: { type: Number, default: 0 },
  originalName: { type: String, default: '' },
  createdBy: { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true },
  publishedAt: { type: Date, default: Date.now, index: true },
}, { timestamps: true });

module.exports = mongoose.model('AcademyMedia', schema);
