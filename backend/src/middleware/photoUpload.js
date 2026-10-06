const path = require('path');
const multer = require('multer');
const { HttpError } = require('./errors');

const MAX_PHOTO_SIZE = 12 * 1024 * 1024;
const extensions = new Set(['.jpg', '.jpeg', '.png', '.webp']);
const mimeTypes = new Set(['image/jpeg', 'image/jpg', 'image/png', 'image/webp']);

const parser = multer({
  storage: multer.memoryStorage(),
  limits: { fileSize: MAX_PHOTO_SIZE, files: 1, fields: 24 },
  fileFilter: (_req, file, callback) => {
    const extension = path.extname(file.originalname || '').toLowerCase();
    if (!mimeTypes.has(String(file.mimetype || '').toLowerCase()) && !extensions.has(extension)) {
      return callback(new HttpError(415, 'Photo must be a JPG/JPEG, PNG, or WebP image'));
    }
    callback(null, true);
  },
});

function matchesImageSignature(buffer) {
  if (!Buffer.isBuffer(buffer) || buffer.length < 12) return false;
  const jpeg = buffer[0] === 0xff && buffer[1] === 0xd8 && buffer[2] === 0xff;
  const png = buffer.subarray(0, 8).equals(Buffer.from([137, 80, 78, 71, 13, 10, 26, 10]));
  const webp = buffer.toString('ascii', 0, 4) === 'RIFF' && buffer.toString('ascii', 8, 12) === 'WEBP';
  return jpeg || png || webp;
}

function uploadPhoto(req, res, next) {
  parser.single('photo')(req, res, error => {
    if (error) {
      if (error instanceof multer.MulterError) {
        const status = error.code === 'LIMIT_FILE_SIZE' ? 413 : 400;
        return next(new HttpError(status, error.code === 'LIMIT_FILE_SIZE'
          ? 'Photo must be 12 MB or smaller'
          : 'Invalid photo upload'));
      }
      return next(error);
    }
    if (req.file && !matchesImageSignature(req.file.buffer)) {
      return next(new HttpError(415, 'The selected file is not a valid JPG/JPEG, PNG, or WebP image'));
    }
    next();
  });
}

module.exports = { uploadPhoto, MAX_PHOTO_SIZE, matchesImageSignature };
