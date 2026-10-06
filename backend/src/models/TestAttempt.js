const mongoose = require('mongoose');
const schema = new mongoose.Schema({
  testId: { type: mongoose.Schema.Types.ObjectId, ref: 'Test', required: true, index: true },
  studentId: { type: mongoose.Schema.Types.ObjectId, ref: 'StudentProfile', required: true, index: true },
  answers: [{ questionId: { type: mongoose.Schema.Types.ObjectId, ref: 'Question' }, selected: { type: Number, min: 0, max: 3 } }],
  totalQuestions: { type: Number, default: 0 }, attempted: { type: Number, default: 0 }, correct: { type: Number, default: 0 }, wrong: { type: Number, default: 0 },
  totalMarks: { type: Number, default: 0 }, obtainedMarks: { type: Number, default: 0 }, percentage: { type: Number, default: 0 },
  startedAt: { type: Date, default: Date.now }, submittedAt: { type: Date }, timeTaken: { type: Number, default: 0 }, autoSubmitted: { type: Boolean, default: false }, status: { type: String, enum: ['in_progress', 'submitted'], default: 'in_progress' }
}, { timestamps: true });
schema.index({ testId: 1, studentId: 1 }, { unique: true, partialFilterExpression: { status: 'in_progress' } });
module.exports = mongoose.model('TestAttempt', schema);
