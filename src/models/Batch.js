const mongoose = require('mongoose');

const batchSchema = new mongoose.Schema({
  name: {
    type: String,
    required: true,
    trim: true
  },
  course: {
    type: String,
    required: true
  },
  instructor: {
    type: String
  },
  startDate: {
    type: Date
  },
  endDate: {
    type: Date
  },
  days: [{
    type: String,
    enum: ['MONDAY', 'TUESDAY', 'WEDNESDAY', 'THURSDAY', 'FRIDAY', 'SATURDAY', 'SUNDAY']
  }],
  startTime: {
    type: String
  },
  endTime: {
    type: String
  },
  maximumStudents: {
    type: Number,
    default: 50
  },
  status: {
    type: String,
    enum: ['ACTIVE', 'INACTIVE', 'COMPLETED'],
    default: 'ACTIVE'
  },
  description: {
    type: String
  }
}, {
  timestamps: true
});

batchSchema.index({ name: 1 });
batchSchema.index({ status: 1 });
batchSchema.index({ course: 1 });

module.exports = mongoose.model('Batch', batchSchema);
