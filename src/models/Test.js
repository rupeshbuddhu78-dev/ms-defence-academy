const mongoose = require('mongoose');

const testSchema = new mongoose.Schema({
  title: {
    type: String,
    required: true,
    trim: true
  },
  subject: {
    type: String,
    required: true
  },
  duration: {
    type: Number, // minutes
    required: true
  },
  totalMarks: {
    type: Number,
    default: 0
  },
  negativeMarking: {
    type: Boolean,
    default: false
  },
  negativeMarks: {
    type: Number,
    default: 0
  },
  isPublished: {
    type: Boolean,
    default: false
  },
  instructions: {
    type: String
  },
  createdBy: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'User'
  }
}, {
  timestamps: true
});

testSchema.index({ isPublished: 1 });
testSchema.index({ subject: 1 });

module.exports = mongoose.model('Test', testSchema);
