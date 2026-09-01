const mongoose = require('mongoose');

const physicalTrainingSchema = new mongoose.Schema({
  student: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'Student',
    required: true
  },
  studentId: {
    type: String,
    required: true
  },
  date: {
    type: Date,
    required: true
  },
  exercise: {
    type: String,
    enum: ['RUNNING', 'PUSH_UPS', 'SIT_UPS', 'PULL_UPS', 'LONG_JUMP', 'HIGH_JUMP', 'OTHER'],
    required: true
  },
  target: {
    type: String
  },
  result: {
    type: String
  },
  instructorRemark: {
    type: String
  },
  recordedBy: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'User'
  },
  corrections: [{
    adminId: { type: mongoose.Schema.Types.ObjectId, ref: 'User' },
    oldValue: mongoose.Schema.Types.Mixed,
    newValue: mongoose.Schema.Types.Mixed,
    reason: String,
    correctedAt: { type: Date, default: Date.now }
  }]
}, {
  timestamps: true
});

physicalTrainingSchema.index({ student: 1, date: -1 });
physicalTrainingSchema.index({ studentId: 1 });

module.exports = mongoose.model('PhysicalTraining', physicalTrainingSchema);
