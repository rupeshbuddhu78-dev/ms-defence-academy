const Media = require('../models/Media');
const cloudinary = require('../config/cloudinary');
const streamifier = require('streamifier');
const { logAudit } = require('../utils/auditLogger');

exports.getMedia = async (req, res, next) => {
  try {
    const { category, type, page = 1, limit = 20 } = req.query;
    const isAdmin = req.user?.role === 'ADMIN';
    const query = isAdmin ? {} : { isPublished: true };
    if (category) query.category = category;
    if (type) query.type = type;
    const skip = (Math.max(1, parseInt(page)) - 1) * Math.min(50, parseInt(limit) || 20);
    const lim = Math.min(50, parseInt(limit) || 20);
    const [media, total] = await Promise.all([
      Media.find(query).sort({ createdAt: -1 }).skip(skip).limit(lim),
      Media.countDocuments(query)
    ]);
    res.status(200).json({ success: true, data: { media, pagination: { page: parseInt(page)||1, limit: lim, total, pages: Math.ceil(total/lim) } } });
  } catch (e) { next(e); }
};

exports.getMediaById = async (req, res, next) => {
  try {
    const media = await Media.findById(req.params.id);
    if (!media) return res.status(404).json({ success: false, message: 'Media not found', code: 'NOT_FOUND' });
    if (!media.isPublished && req.user?.role !== 'ADMIN') {
      return res.status(403).json({ success: false, message: 'Access denied', code: 'FORBIDDEN' });
    }
    res.status(200).json({ success: true, data: media });
  } catch (e) { next(e); }
};


exports.createFromUrl = async (req, res, next) => {
  try {
    const { title, description, category, type, secureUrl, url, isPublished, visibility, thumbnailUrl } = req.body;
    if (!title || !(secureUrl || url)) {
      return res.status(400).json({ success: false, message: 'Title and URL required', code: 'VALIDATION_ERROR' });
    }
    const Media = require('../models/Media');
    const media = await Media.create({
      title,
      description,
      category: category || 'GENERAL',
      type: type || 'VIDEO',
      secureUrl: secureUrl || url,
      url: url || secureUrl,
      thumbnailUrl,
      isPublished: isPublished !== false,
      visibility: visibility || 'PUBLIC',
      uploadedBy: req.user._id
    });
    res.status(201).json({ success: true, message: 'Media created', data: media });
  } catch (error) { next(error); }
};

exports.uploadMedia = async (req, res, next) => {
  try {
    if (!req.file) return res.status(400).json({ success: false, message: 'No file uploaded', code: 'NO_FILE' });
    const { title, description, category, isPublished } = req.body;
    if (!title) return res.status(400).json({ success: false, message: 'Title required', code: 'VALIDATION_ERROR' });

    const isVideo = req.file.mimetype.startsWith('video/');
    const resourceType = isVideo ? 'video' : 'image';

    const result = await new Promise((resolve, reject) => {
      const stream = cloudinary.uploader.upload_stream(
        {
          folder: isVideo ? 'ms_defence/videos' : 'ms_defence/images',
          resource_type: resourceType,
          ...(isVideo ? {} : { transformation: [{ width: 1200, crop: 'limit' }] })
        },
        (err, res) => err ? reject(err) : resolve(res)
      );
      streamifier.createReadStream(req.file.buffer).pipe(stream);
    });

    const media = await Media.create({
      title,
      description,
      category: category || 'GENERAL',
      type: isVideo ? 'VIDEO' : 'IMAGE',
      cloudinaryPublicId: result.public_id,
      secureUrl: result.secure_url,
      thumbnailUrl: isVideo ? result.secure_url.replace('/upload/', '/upload/so_0/') : result.secure_url,
      duration: result.duration,
      width: result.width,
      height: result.height,
      fileSize: result.bytes,
      uploadedBy: req.user._id,
      isPublished: isPublished === true || isPublished === 'true'
    });

    await logAudit({ adminId: req.user._id, action: 'MEDIA_UPLOADED', entityType: 'Media', entityId: media._id, newValue: { title, type: media.type }, req });
    res.status(201).json({ success: true, message: 'Media uploaded', data: media });
  } catch (e) { next(e); }
};

exports.updateMedia = async (req, res, next) => {
  try {
    const allowed = ['title', 'description', 'category', 'isPublished'];
    const updates = {};
    allowed.forEach(f => { if (req.body[f] !== undefined) updates[f] = req.body[f]; });
    const media = await Media.findByIdAndUpdate(req.params.id, updates, { new: true });
    if (!media) return res.status(404).json({ success: false, message: 'Media not found', code: 'NOT_FOUND' });
    res.status(200).json({ success: true, message: 'Media updated', data: media });
  } catch (e) { next(e); }
};

exports.deleteMedia = async (req, res, next) => {
  try {
    const media = await Media.findById(req.params.id);
    if (!media) return res.status(404).json({ success: false, message: 'Media not found', code: 'NOT_FOUND' });

    const resourceType = media.type === 'VIDEO' ? 'video' : 'image';
    try {
      await cloudinary.uploader.destroy(media.cloudinaryPublicId, { resource_type: resourceType });
    } catch (cloudErr) {
      return res.status(500).json({ success: false, message: 'Failed to delete from Cloudinary. Database record retained.', code: 'CLOUDINARY_DELETE_FAILED' });
    }
    await media.deleteOne();
    await logAudit({ adminId: req.user._id, action: 'MEDIA_DELETED', entityType: 'Media', entityId: req.params.id, req });
    res.status(200).json({ success: true, message: 'Media deleted' });
  } catch (e) { next(e); }
};

exports.publishMedia = async (req, res, next) => {
  try {
    const media = await Media.findByIdAndUpdate(req.params.id, { isPublished: true }, { new: true });
    if (!media) return res.status(404).json({ success: false, message: 'Media not found', code: 'NOT_FOUND' });
    res.status(200).json({ success: true, message: 'Media published', data: media });
  } catch (e) { next(e); }
};

exports.unpublishMedia = async (req, res, next) => {
  try {
    const media = await Media.findByIdAndUpdate(req.params.id, { isPublished: false }, { new: true });
    if (!media) return res.status(404).json({ success: false, message: 'Media not found', code: 'NOT_FOUND' });
    res.status(200).json({ success: true, message: 'Media unpublished', data: media });
  } catch (e) { next(e); }
};
