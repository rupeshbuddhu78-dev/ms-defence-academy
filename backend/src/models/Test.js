const mongoose = require('mongoose');
const schema = new mongoose.Schema({
  title: { type: String, required: true, trim: true }, description: { type: String, default: '' },
  batchId: { type: mongoose.Schema.Types.ObjectId, ref: 'Batch', default: null, index: true },
  duration: { type: Number, required: true, min: 1, max: 300 }, startTime: { type: Date, required: true, index: true }, endTime: { type: Date, required: true },
  totalMarks: { type: Number, default: 0 }, status: { type: String, enum: ['draft', 'published', 'closed'], default: 'draft', index: true },
  allowRetake: { type: Boolean, default: false }, instructions: { type: String, default: '' }, createdBy: { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true }
}, { timestamps: true });
module.exports = mongoose.model('Test', schema);
