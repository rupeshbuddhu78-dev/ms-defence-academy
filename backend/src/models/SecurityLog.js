const mongoose = require('mongoose');

const schema = new mongoose.Schema({
  userId: { type: mongoose.Schema.Types.ObjectId, ref: 'User', default: null, index: true },
  event: {
    type: String,
    enum: ['login_success', 'login_failed', 'password_reset_requested', 'password_reset_completed'],
    required: true,
    index: true,
  },
  role: { type: String, enum: ['student', 'admin', 'unknown'], default: 'unknown' },
  email: { type: String, default: '', lowercase: true, trim: true },
  ip: { type: String, default: '', maxlength: 128 },
  userAgent: { type: String, default: '', maxlength: 500 },
  details: { type: String, default: '', maxlength: 300 },
}, { timestamps: true });

schema.index({ createdAt: -1 });
module.exports = mongoose.model('SecurityLog', schema);
