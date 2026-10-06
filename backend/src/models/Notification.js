const mongoose = require('mongoose');
const schema = new mongoose.Schema({
  userId: { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true, index: true },
  title: { type: String, required: true, trim: true }, message: { type: String, required: true },
  type: { type: String, enum: ['notice', 'test', 'training', 'attendance', 'system'], default: 'system', index: true },
  data: { type: mongoose.Schema.Types.Mixed, default: {} }, readAt: { type: Date, default: null, index: true }
}, { timestamps: true });
schema.index({ userId: 1, createdAt: -1 });
module.exports = mongoose.model('Notification', schema);
