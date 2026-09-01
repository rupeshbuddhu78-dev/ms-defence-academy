const mongoose = require('mongoose');

const testResultSchema = new mongoose.Schema({
  test: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'Test',
    required: true
  },
  student: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'Student',
    required: true
  },
  studentId: {
    type: String,
    required: true
  },
  answers: [{
    question: { type: mongoose.Schema.Types.ObjectId, ref: 'Question' },
    selectedAnswer: { type: String, enum: ['A', 'B', 'C', 'D', null] },
    isCorrect: Boolean,
    marksObtained: Number
  }],
  totalQuestions: {
    type: Number
  },
  correct: {
    type: Number,
    default: 0
  },
  wrong: {
    type: Number,
    default: 0
  },
  skipped: {
    type: Number,
    default: 0
  },
  score: {
    type: Number,
    default: 0
  },
  percentage: {
    type: Number,
    default: 0
  },
  submittedAt: {
    type: Date,
    default: Date.now
  }
}, {
  timestamps: true
});

testResultSchema.index({ test: 1, student: 1 }, { unique: true });
testResultSchema.index({ studentId: 1 });

module.exports = mongoose.model('TestResult', testResultSchema);
