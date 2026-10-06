const mongoose = require('mongoose');
const schema = new mongoose.Schema({
  title: { type: String, required: true, trim: true }, description: { type: String, required: true }, priority: { type: String, enum: ['normal', 'important', 'urgent'], default: 'normal' },
  attachment: { type: String, default: '' }, batchId: { type: mongoose.Schema.Types.ObjectId, ref: 'Batch', default: null, index: true }, publishedAt: { type: Date, default: Date.now, index: true }, createdBy: { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true }, isPublished: { type: Boolean, default: true }
}, { timestamps: true });
module.exports = mongoose.model('Notice', schema);
