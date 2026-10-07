const mongoose = require('mongoose');

const schema = new mongoose.Schema({
  key: { type: String, unique: true, default: 'academy', index: true },
  name: { type: String, default: 'MS Defence Academy', trim: true, maxlength: 100 },
  logoUrl: { type: String, default: '' },
  logoPublicId: { type: String, default: '' },
  backgroundUrl: { type: String, default: '' },
  backgroundPublicId: { type: String, default: '' },
}, { timestamps: true });

module.exports = mongoose.model('AppSettings', schema);
