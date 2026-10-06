const mongoose = require('mongoose');
const crypto = require('crypto');
const schema = new mongoose.Schema({
  userId: { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true, unique: true, index: true },
  studentId: { type: String, required: true, unique: true, uppercase: true, trim: true, index: true },
  photo: { type: String, default: '' },
  photoPublicId: { type: String, default: '' },
  batchId: { type: mongoose.Schema.Types.ObjectId, ref: 'Batch', index: true },
  course: { type: String, trim: true, default: '' },
  address: { type: String, trim: true, default: '' },
  joiningDate: { type: Date, default: Date.now },
  qrToken: { type: String, default: () => crypto.randomBytes(32).toString('hex'), select: false, unique: true }
}, { timestamps: true });
module.exports = mongoose.model('StudentProfile', schema);
