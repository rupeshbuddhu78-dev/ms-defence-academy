const mongoose = require('mongoose');

const schema = new mongoose.Schema({
  name: { type: String, required: true, trim: true },
  email: { type: String, required: true, lowercase: true, trim: true, index: true },
  phone: { type: String, required: true, trim: true },
  passwordHash: { type: String, required: true, select: false },
  batchId: { type: mongoose.Schema.Types.ObjectId, ref: 'Batch', required: true },
  course: { type: String, default: '' }, address: { type: String, default: '' },
  village: { type: String, default: '' }, post: { type: String, default: '' },
  policeStation: { type: String, default: '' }, district: { type: String, default: '' },
  state: { type: String, default: '' }, postalCode: { type: String, default: '' },
  fatherName: { type: String, default: '' }, motherName: { type: String, default: '' },
  parentPhone: { type: String, default: '' }, dateOfBirth: { type: Date, default: null },
  heightCm: { type: Number, default: null }, weightKg: { type: Number, default: null }, chestCm: { type: Number, default: null },
  aadhaarEncrypted: { type: String, default: '' }, aadhaarLast4: { type: String, default: '' },
  photo: { type: String, default: '' }, photoPublicId: { type: String, default: '' },
  status: { type: String, enum: ['pending', 'approved', 'rejected'], default: 'pending', index: true },
  reviewedAt: { type: Date, default: null }, reviewedBy: { type: mongoose.Schema.Types.ObjectId, ref: 'User', default: null },
  rejectionReason: { type: String, default: '' },
}, { timestamps: true });

schema.index({ email: 1, status: 1 });
module.exports = mongoose.model('StudentApplication', schema);
