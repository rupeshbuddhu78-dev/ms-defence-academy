const multer = require('multer');
const { HttpError } = require('./errors');

const parser = multer({
  storage: multer.memoryStorage(),
  limits: { fileSize: 5 * 1024 * 1024, files: 1, fields: 20 },
  fileFilter: (_req, file, callback) => {
    const allowed = ['image/jpeg', 'image/png', 'image/webp'];
    if (!allowed.includes(file.mimetype)) {
      return callback(new HttpError(415, 'Photo must be a JPG, PNG, or WebP image'));
    }
    callback(null, true);
  },
});

function uploadPhoto(req, res, next) {
  parser.single('photo')(req, res, error => {
    if (!error) return next();
    if (error instanceof multer.MulterError) {
      const status = error.code === 'LIMIT_FILE_SIZE' ? 413 : 400;
      return next(new HttpError(status, error.code === 'LIMIT_FILE_SIZE'
        ? 'Photo must be 5 MB or smaller'
        : 'Invalid photo upload'));
    }
    next(error);
  });
}

module.exports = { uploadPhoto };
