const mongoose = require('mongoose');

const adminSchema = new mongoose.Schema({
  user: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'User',
    required: true,
    unique: true
  },
  adminId: {
    type: String,
    required: true,
    unique: true
  },
  fullName: {
    type: String,
    required: true,
    trim: true
  },
  mobile: {
    type: String
  },
  email: {
    type: String,
    lowercase: true
  },
  designation: {
    type: String,
    default: 'Administrator'
  },
  photoUrl: {
    type: String
  }
}, {
  timestamps: true
});

adminSchema.index({ email: 1 });

module.exports = mongoose.model('Admin', adminSchema);
