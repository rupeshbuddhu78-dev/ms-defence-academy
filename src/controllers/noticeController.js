const Notice = require('../models/Notice');
const { logAudit } = require('../utils/auditLogger');
const cloudinary = require('../config/cloudinary');
const streamifier = require('streamifier');

exports.getNotices = async (req, res, next) => {
  try {
    const query = { isPublished: true };
    // Role-based audience filter
    if (!req.user) {
      query.$or = [
        { audience: { $in: ['PUBLIC', 'EVERYONE'] } },
        { audience: { $exists: false } },
        { audience: null }
      ];
    } else if (req.user.role === 'USER') {
      query.$or = [
        { audience: { $in: ['PUBLIC', 'EVERYONE'] } },
        { audience: { $exists: false } },
        { audience: null }
      ];
    } else if (req.user.role === 'STUDENT') {
      query.$or = [
        { audience: { $in: ['PUBLIC', 'EVERYONE', 'STUDENTS', 'ALL_STUDENTS'] } },
        { audience: { $exists: false } },
        { audience: null }
      ];
    }
    // ADMIN sees all published if no filter, or all if query.admin=1
    if (req.user && req.user.role === 'ADMIN' && req.query.all === '1') {
      delete query.isPublished;
      delete query.$or;
    }
    const notices = await require('../models/Notice').find(query).sort({ priority: -1, createdAt: -1 }).limit(50);
    res.status(200).json({ success: true, data: notices });
  } catch (error) { next(error); }
};


exports.createNotice = async (req, res, next) => {
  try {
    const { title, description, category, priority, isPublished } = req.body;
    if (!title || !description) {
      return res.status(400).json({ success: false, message: 'Title and description required', code: 'VALIDATION_ERROR' });
    }
    let imageUrl, imagePublicId;
    if (req.file) {
      const result = await new Promise((resolve, reject) => {
        const stream = cloudinary.uploader.upload_stream(
          { folder: 'ms_defence/notices' },
          (err, res) => err ? reject(err) : resolve(res)
        );
        streamifier.createReadStream(req.file.buffer).pipe(stream);
      });
      imageUrl = result.secure_url;
      imagePublicId = result.public_id;
    }
    const notice = await Notice.create({
      title, description, category: category || 'GENERAL', priority: priority || 'NORMAL',
      imageUrl, imagePublicId, isPublished: isPublished === true || isPublished === 'true',
      publishedAt: (isPublished === true || isPublished === 'true') ? new Date() : undefined,
      createdBy: req.user._id
    });
    await logAudit({ adminId: req.user._id, action: 'NOTICE_CREATED', entityType: 'Notice', entityId: notice._id, req });
    res.status(201).json({ success: true, message: 'Notice created', data: notice });
  } catch (e) { next(e); }
};

exports.updateNotice = async (req, res, next) => {
  try {
    const notice = await Notice.findByIdAndUpdate(req.params.id, req.body, { new: true, runValidators: true });
    if (!notice) return res.status(404).json({ success: false, message: 'Notice not found', code: 'NOT_FOUND' });
    res.status(200).json({ success: true, message: 'Notice updated', data: notice });
  } catch (e) { next(e); }
};

exports.deleteNotice = async (req, res, next) => {
  try {
    const notice = await Notice.findById(req.params.id);
    if (!notice) return res.status(404).json({ success: false, message: 'Notice not found', code: 'NOT_FOUND' });
    if (notice.imagePublicId) {
      try { await cloudinary.uploader.destroy(notice.imagePublicId); } catch (e) {}
    }
    await notice.deleteOne();
    await logAudit({ adminId: req.user._id, action: 'NOTICE_DELETED', entityType: 'Notice', entityId: req.params.id, req });
    res.status(200).json({ success: true, message: 'Notice deleted' });
  } catch (e) { next(e); }
};

exports.publishNotice = async (req, res, next) => {
  try {
    const notice = await Notice.findByIdAndUpdate(req.params.id, { isPublished: true, publishedAt: new Date() }, { new: true });
    if (!notice) return res.status(404).json({ success: false, message: 'Notice not found', code: 'NOT_FOUND' });
    await logAudit({ adminId: req.user._id, action: 'NOTICE_PUBLISHED', entityType: 'Notice', entityId: notice._id, req });
    res.status(200).json({ success: true, message: 'Notice published', data: notice });
  } catch (e) { next(e); }
};

exports.unpublishNotice = async (req, res, next) => {
  try {
    const notice = await Notice.findByIdAndUpdate(req.params.id, { isPublished: false }, { new: true });
    if (!notice) return res.status(404).json({ success: false, message: 'Notice not found', code: 'NOT_FOUND' });
    res.status(200).json({ success: true, message: 'Notice unpublished', data: notice });
  } catch (e) { next(e); }
};
