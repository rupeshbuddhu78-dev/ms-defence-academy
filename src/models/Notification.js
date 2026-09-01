const mongoose = require('mongoose');
const notificationSchema = new mongoose.Schema({
  user: { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true, index: true },
  title: { type: String, required: true },
  message: { type: String, required: true },
  type: {
    type: String,
    enum: ['ATTENDANCE', 'NOTICE', 'FEE', 'TEST', 'RESULT', 'VIDEO', 'ACCOUNT', 'SYSTEM'],
    default: 'SYSTEM'
  },
  data: { type: mongoose.Schema.Types.Mixed },
  read: { type: Boolean, default: false, index: true },
  deepLink: { type: String }
}, { timestamps: true });
notificationSchema.index({ user: 1, createdAt: -1 });
module.exports = mongoose.model('Notification', notificationSchema);
