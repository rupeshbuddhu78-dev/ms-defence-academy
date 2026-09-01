const mongoose = require('mongoose');

const questionSchema = new mongoose.Schema({
  test: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'Test',
    required: true
  },
  questionText: {
    type: String,
    required: true
  },
  optionA: {
    type: String,
    required: true
  },
  optionB: {
    type: String,
    required: true
  },
  optionC: {
    type: String,
    required: true
  },
  optionD: {
    type: String,
    required: true
  },
  correctAnswer: {
    type: String,
    enum: ['A', 'B', 'C', 'D'],
    required: true
  },
  marks: {
    type: Number,
    default: 1
  },
  order: {
    type: Number,
    default: 0
  }
}, {
  timestamps: true
});

questionSchema.index({ test: 1 });

module.exports = mongoose.model('Question', questionSchema);
