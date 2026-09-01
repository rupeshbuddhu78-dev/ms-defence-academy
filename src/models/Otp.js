const mongoose = require('mongoose');
const bcrypt = require('bcryptjs');

const otpSchema = new mongoose.Schema({
  identifier: {
    type: String,
    required: true,
    index: true
  },
  purpose: {
    type: String,
    enum: ['PASSWORD_RESET', 'VERIFY_EMAIL'],
    default: 'PASSWORD_RESET'
  },
  otpHash: {
    type: String,
    required: true
  },
  attempts: {
    type: Number,
    default: 0
  },
  maxAttempts: {
    type: Number,
    default: 5
  },
  expiresAt: {
    type: Date,
    required: true
  },
  used: {
    type: Boolean,
    default: false
  }
}, { timestamps: true });

otpSchema.index({ expiresAt: 1 }, { expireAfterSeconds: 0 });

otpSchema.statics.createOtp = async function (identifier, purpose = 'PASSWORD_RESET') {
  // Invalidate old
  await this.deleteMany({ identifier, purpose, used: false });
  const code = String(Math.floor(100000 + Math.random() * 900000));
  const otpHash = await bcrypt.hash(code, 10);
  const doc = await this.create({
    identifier: identifier.toLowerCase(),
    purpose,
    otpHash,
    expiresAt: new Date(Date.now() + 5 * 60 * 1000)
  });
  return { doc, code };
};

otpSchema.methods.verify = async function (code) {
  if (this.used) return { ok: false, message: 'OTP already used' };
  if (this.expiresAt < new Date()) return { ok: false, message: 'OTP expired' };
  if (this.attempts >= this.maxAttempts) return { ok: false, message: 'Too many attempts' };
  this.attempts += 1;
  await this.save();
  const match = await bcrypt.compare(String(code), this.otpHash);
  if (!match) return { ok: false, message: 'Invalid OTP' };
  this.used = true;
  await this.save();
  return { ok: true };
};

module.exports = mongoose.model('Otp', otpSchema);
