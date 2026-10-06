const mongoose = require('mongoose');
const schema = new mongoose.Schema({
  testId: { type: mongoose.Schema.Types.ObjectId, ref: 'Test', required: true, index: true },
  questionText: { type: String, required: true, trim: true }, options: { type: [String], validate: v => v.length === 4 },
  correctAnswer: { type: Number, required: true, min: 0, max: 3, select: false }, marks: { type: Number, required: true, min: 0.5, default: 1 }, order: { type: Number, default: 0 }
}, { timestamps: true });
module.exports = mongoose.model('Question', schema);
