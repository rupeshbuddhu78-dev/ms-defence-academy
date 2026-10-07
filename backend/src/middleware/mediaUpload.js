const path = require('path');
const multer = require('multer');
const { HttpError } = require('./errors');

const MAX_MEDIA_SIZE = 200 * 1024 * 1024;
const parser = multer({
  storage: multer.memoryStorage(),
  limits: { fileSize: MAX_MEDIA_SIZE, files: 1, fields: 8 },
  fileFilter: (_req, file, callback) => {
    const ext = path.extname(file.originalname || '').toLowerCase();
    if (!file.mimetype || !ext) return callback(new HttpError(415, 'Select a valid file'));
    callback(null, true);
  },
});

function uploadMedia(req, res, next) {
  parser.single('file')(req, res, error => {
    if (error) {
      if (error instanceof multer.MulterError && error.code === 'LIMIT_FILE_SIZE') {
        return next(new HttpError(413, 'File or video must be 200 MB or smaller'));
      }
      return next(error instanceof multer.MulterError ? new HttpError(400, 'Invalid upload') : error);
    }
    if (!req.file) return next(new HttpError(400, 'Select a file to upload'));
    next();
  });
}

module.exports = { uploadMedia, MAX_MEDIA_SIZE };
