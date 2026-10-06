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
  village: { type: String, trim: true, default: '' },
  post: { type: String, trim: true, default: '' },
  policeStation: { type: String, trim: true, default: '' },
  district: { type: String, trim: true, default: '' },
  state: { type: String, trim: true, default: '' },
  postalCode: { type: String, trim: true, maxlength: 12, default: '' },
  fatherName: { type: String, trim: true, maxlength: 100, default: '' },
  motherName: { type: String, trim: true, maxlength: 100, default: '' },
  parentPhone: { type: String, trim: true, maxlength: 20, default: '' },
  dateOfBirth: { type: Date, default: null },
  heightCm: { type: Number, min: 0, default: null },
  weightKg: { type: Number, min: 0, default: null },
  chestCm: { type: Number, min: 0, default: null },
  aadhaarEncrypted: { type: String, default: '', select: false },
  aadhaarLast4: { type: String, default: '', select: false },
  joiningDate: { type: Date, default: Date.now },
  qrToken: { type: String, default: () => crypto.randomBytes(32).toString('hex'), select: false, unique: true },
}, { timestamps: true });

module.exports = mongoose.model('StudentProfile', schema);
