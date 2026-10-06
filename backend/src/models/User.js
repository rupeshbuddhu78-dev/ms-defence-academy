const mongoose = require('mongoose');
const bcrypt = require('bcryptjs');
const schema = new mongoose.Schema({
  name: { type: String, required: true, trim: true, maxlength: 100 },
  email: { type: String, required: true, unique: true, lowercase: true, trim: true, index: true },
  phone: { type: String, trim: true, maxlength: 20 },
  passwordHash: { type: String, required: true, select: false },
  role: { type: String, enum: ['student', 'admin'], default: 'student', index: true },
  isActive: { type: Boolean, default: true }
}, { timestamps: true, toJSON: { transform: (_d, r) => { delete r.passwordHash; delete r.__v; return r; } } });
schema.methods.comparePassword = function (password) { return bcrypt.compare(password, this.passwordHash); };
schema.statics.hashPassword = password => bcrypt.hash(password, 12);
module.exports = mongoose.model('User', schema);
