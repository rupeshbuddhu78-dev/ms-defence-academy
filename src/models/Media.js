const mongoose = require('mongoose');

const mediaSchema = new mongoose.Schema({
  title: {
    type: String,
    required: true,
    trim: true
  },
  description: {
    type: String
  },
  category: {
    type: String,
    enum: [
      'PHYSICAL_TRAINING',
      'DEFENCE_TRAINING',
      'ACADEMY_EVENT',
      'MOTIVATION',
      'STUDY',
      'NDA_PREPARATION',
      'ARMY_PREPARATION',
      'PARADE',
      'GENERAL',
      'OTHER'
    ],
    default: 'GENERAL'
  },
  type: {
    type: String,
    enum: ['IMAGE', 'VIDEO'],
    required: true
  },
  cloudinaryPublicId: {
    type: String,
    required: true
  },
  secureUrl: {
    type: String,
    required: true
  },
  thumbnailUrl: {
    type: String
  },
  duration: {
    type: Number // seconds for video
  },
  width: {
    type: Number
  },
  height: {
    type: Number
  },
  fileSize: {
    type: Number
  },
  uploadedBy: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'User'
  },
  isPublished: {
    type: Boolean,
    default: false
  },
  isFeatured: {
    type: Boolean,
    default: false
  },
  visibility: {
    type: String,
    enum: ['PUBLIC', 'STUDENT', 'ADMIN'],
    default: 'PUBLIC'
  },
  sortOrder: {
    type: Number,
    default: 0
  }
}, {
  timestamps: true
});

mediaSchema.index({ category: 1 });
mediaSchema.index({ isPublished: 1, createdAt: -1 });
mediaSchema.index({ type: 1 });
mediaSchema.index({ title: 'text' });

module.exports = mongoose.model('Media', mediaSchema);
