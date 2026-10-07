const AppSettings = require('../models/AppSettings');
const AcademyMedia = require('../models/AcademyMedia');
const StudentProfile = require('../models/StudentProfile');
const User = require('../models/User');
const Notification = require('../models/Notification');
const cloudinary = require('../services/cloudinary');
const { HttpError } = require('../middleware/errors');

const respond = (res, data, status = 200) => res.status(status).json({ ok: true, data });

async function getSettings(_req, res) {
  const settings = await AppSettings.findOneAndUpdate({ key: 'academy' }, {}, { upsert: true, new: true, setDefaultsOnInsert: true });
  return respond(res, settings);
}

async function updateBranding(req, res) {
  const name = String(req.body.name || '').trim();
  if (name.length < 2 || name.length > 100) throw new HttpError(400, 'App name must be between 2 and 100 characters');
  const settings = await AppSettings.findOneAndUpdate({ key: 'academy' }, { $set: { name } }, { upsert: true, new: true, setDefaultsOnInsert: true });
  return respond(res, settings);
}

async function uploadBrandAsset(req, res) {
  const type = String(req.body.type || '').toLowerCase();
  if (!['logo', 'background'].includes(type)) throw new HttpError(400, 'Brand asset type must be logo or background');
  if (!req.file.mimetype.startsWith('image/')) throw new HttpError(415, 'Logo and background must be an image');
  const uploaded = await cloudinary.uploadImage(req.file.buffer, `ms-defence-academy/branding/${type}`);
  const field = type === 'logo' ? 'logoUrl' : 'backgroundUrl';
  const idField = type === 'logo' ? 'logoPublicId' : 'backgroundPublicId';
  const settings = await AppSettings.findOneAndUpdate({ key: 'academy' }, { $set: { [field]: uploaded.url, [idField]: uploaded.publicId } }, { upsert: true, new: true, setDefaultsOnInsert: true });
  return respond(res, settings);
}

async function listMedia(req, res) {
  const filter = req.user.role === 'admin' ? {} : {};
  const kind = String(req.query.kind || '').trim();
  if (kind === 'file' || kind === 'video') filter.kind = kind;
  return respond(res, await AcademyMedia.find(filter).populate('createdBy', 'name').sort({ publishedAt: -1 }).limit(200));
}

async function uploadMedia(req, res) {
  const title = String(req.body.title || '').trim();
  const description = String(req.body.description || '').trim();
  const requestedKind = String(req.body.kind || '').toLowerCase();
  if (title.length < 2) throw new HttpError(400, 'Enter a heading/title');
  const kind = requestedKind === 'video' || req.file.mimetype.startsWith('video/') ? 'video' : 'file';
  if (kind === 'video' && !req.file.mimetype.startsWith('video/')) throw new HttpError(415, 'Select a video for the video section');
  const uploaded = await cloudinary.uploadAuto(req.file.buffer, `ms-defence-academy/${kind}`);
  const media = await AcademyMedia.create({ title, description, kind, url: uploaded.url, publicId: uploaded.publicId, resourceType: uploaded.resourceType, format: uploaded.format, mimeType: req.file.mimetype, bytes: req.file.size, originalName: req.file.originalname, createdBy: req.user._id });
  const users = await User.find({ role: 'student', isActive: true }).select('_id').lean();
  if (users.length) await Notification.insertMany(users.map(user => ({ userId: user._id, title: kind === 'video' ? `New video: ${title}` : `New file: ${title}`, message: description || `A new ${kind} has been uploaded by the academy.`, type: 'system', data: { mediaId: media._id, kind } })), { ordered: false });
  return respond(res, { media, notificationsSent: users.length }, 201);
}

module.exports = { getSettings, updateBranding, uploadBrandAsset, listMedia, uploadMedia };
