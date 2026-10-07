const mongoose = require('mongoose');

const schema = new mongoose.Schema({
  _id: { type: String, default: 'studentId' },
  value: { type: Number, required: true, min: 0 },
}, {
  versionKey: false,
  collection: 'student_id_counters',
});

module.exports = mongoose.model('StudentIdCounter', schema);
