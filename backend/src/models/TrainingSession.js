const mongoose = require('mongoose');
const schema = new mongoose.Schema({
  title: { type: String, required: true, trim: true }, type: { type: String, default: 'Physical Training' }, description: { type: String, default: '' }, instructions: { type: String, default: '' },
  batchId: { type: mongoose.Schema.Types.ObjectId, ref: 'Batch', required: true, index: true }, trainer: { type: String, default: '' },
  date: { type: Date, required: true, index: true }, startTime: { type: String, default: '' }, endTime: { type: String, default: '' }, location: { type: String, default: '' },
  createdBy: { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true }, status: { type: String, enum: ['scheduled', 'cancelled', 'completed'], default: 'scheduled' }
}, { timestamps: true });
module.exports = mongoose.model('TrainingSession', schema);
