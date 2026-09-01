const mongoose = require('mongoose');

const noticeSchema = new mongoose.Schema({
  title: {
    type: String,
    required: true,
    trim: true
  },
  description: {
    type: String,
    required: true
  },
  category: {
    type: String,
    default: 'GENERAL'
  },
  priority: {
    type: String,
    enum: ['NORMAL', 'IMPORTANT', 'URGENT'],
    default: 'NORMAL'
  },
  imageUrl: {
    type: String
  },
  imagePublicId: {
    type: String
  },
  isPublished: {
    type: Boolean,
    default: false
  },
  audience: {
    type: String,
    enum: ['EVERYONE', 'STUDENTS', 'BATCH', 'PUBLIC'],
    default: 'EVERYONE'
  },

  publishedAt: {
    type: Date
  },
  createdBy: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'User'
  }
}, {
  timestamps: true
});

noticeSchema.index({ isPublished: 1, createdAt: -1 });
noticeSchema.index({ priority: 1 });

module.exports = mongoose.model('Notice', noticeSchema);
