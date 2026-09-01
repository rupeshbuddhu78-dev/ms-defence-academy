const mongoose = require('mongoose');
const crypto = require('crypto');

const studentSchema = new mongoose.Schema({
  user: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'User',
    required: true,
    unique: true
  },
  studentId: {
    type: String,
    required: true,
    unique: true,
    uppercase: true
  },
  fullName: {
    type: String,
    required: true,
    trim: true
  },
  fatherName: {
    type: String,
    trim: true
  },
  motherName: {
    type: String,
    trim: true
  },
  mobile: {
    type: String,
    required: true,
    unique: true
  },
  alternateMobile: {
    type: String
  },
  dateOfBirth: {
    type: Date
  },
  gender: {
    type: String,
    enum: ['MALE', 'FEMALE', 'OTHER']
  },
  address: {
    type: String
  },
  district: {
    type: String
  },
  state: {
    type: String,
    default: 'Bihar'
  },
  photoUrl: {
    type: String
  },
  photoPublicId: {
    type: String
  },
  batch: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'Batch'
  },
  course: {
    type: String,
    default: 'NDA'
  },
  qualification: {
    type: String,
    default: ''
  },
  qrIdentifier: {
    type: String,
    unique: true,
    required: true
  },
  qrActive: {
    type: Boolean,
    default: true
  },
  status: {
    type: String,
    enum: ['PENDING', 'ACTIVE', 'INACTIVE', 'SUSPENDED', 'REJECTED'],
    default: 'PENDING'
  },
  rejectionReason: { type: String },
  rejectedBy: { type: mongoose.Schema.Types.ObjectId, ref: 'User' },
  rejectedAt: { type: Date },
  totalFee: {
    type: Number,
    default: 0
  },
  paidFee: {
    type: Number,
    default: 0
  },
  pin: {
    type: String
  },
  emergencyContactName: {
    type: String
  },
  emergencyContactNumber: {
    type: String
  },
  emergencyRelation: {
    type: String
  },
  email: {
    type: String,
    lowercase: true
  },
  joiningDate: {
    type: Date,
    default: Date.now
  }
}, {
  timestamps: true
});

studentSchema.index({ batch: 1 });
studentSchema.index({ status: 1 });
studentSchema.index({ fullName: 'text' });

studentSchema.statics.generateStudentId = async function () {
  const year = new Date().getFullYear();
  const prefix = `MSDA${year}`;
  const last = await this.findOne({ studentId: new RegExp(`^${prefix}`) })
    .sort({ studentId: -1 })
    .select('studentId')
    .lean();
  let nextNum = 1;
  if (last && last.studentId) {
    const numPart = parseInt(last.studentId.replace(prefix, ''), 10);
    if (!isNaN(numPart)) nextNum = numPart + 1;
  }
  return `${prefix}${String(nextNum).padStart(4, '0')}`;
};

studentSchema.statics.generateQrIdentifier = function () {
  return crypto.randomBytes(24).toString('hex');
};

studentSchema.virtual('pendingFee').get(function () {
  return Math.max(0, (this.totalFee || 0) - (this.paidFee || 0));
});

studentSchema.set('toJSON', { virtuals: true });
studentSchema.set('toObject', { virtuals: true });

module.exports = mongoose.model('Student', studentSchema);
