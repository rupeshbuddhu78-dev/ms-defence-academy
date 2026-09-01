const mongoose = require('mongoose');

const attendanceSchema = new mongoose.Schema({
  student: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'Student',
    required: true
  },
  studentId: {
    type: String,
    required: true
  },
  batch: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'Batch'
  },
  date: {
    type: String,
    required: true
  },
  entryTime: {
    type: Date
  },
  exitTime: {
    type: Date
  },
  entryMarkedBy: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'User'
  },
  exitMarkedBy: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'User'
  },
  status: {
    type: String,
    enum: ['PRESENT', 'ABSENT', 'PARTIAL', 'LATE', 'HALF_DAY'],
    default: 'PRESENT'
  },
  correctionReason: { type: String },
  correctedBy: { type: mongoose.Schema.Types.ObjectId, ref: 'User' },
  correctedAt: { type: Date }
}, {
  timestamps: true
});

attendanceSchema.index({ student: 1, date: 1 }, { unique: true });
attendanceSchema.index({ studentId: 1, date: 1 });
attendanceSchema.index({ batch: 1, date: 1 });
attendanceSchema.index({ date: 1 });

module.exports = mongoose.model('Attendance', attendanceSchema);
