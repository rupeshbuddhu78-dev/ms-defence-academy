const mongoose = require('mongoose');
const schema = new mongoose.Schema({
  email: { type: String, required: true, lowercase: true, index: true },
  codeHash: { type: String, required: true, select: false },
  payload: { type: mongoose.Schema.Types.Mixed, required: true },
  expiresAt: { type: Date, required: true },
  attempts: { type: Number, default: 0 },
}, { timestamps: true });
schema.index({ expiresAt: 1 }, { expireAfterSeconds: 0 });
module.exports = mongoose.model('RegistrationOtp', schema);
