const multer = require('multer');
const { HttpError } = require('./errors');
const { matchesImageSignature } = require('./photoUpload');

const MAX_BRAND_IMAGE_SIZE = 12 * 1024 * 1024;
const parser = multer({
  storage: multer.memoryStorage(),
  limits: { fileSize: MAX_BRAND_IMAGE_SIZE, files: 1, fields: 2 },
});

function uploadBrandAsset(req, res, next) {
  parser.single('file')(req, res, error => {
    if (error) {
      if (error instanceof multer.MulterError && error.code === 'LIMIT_FILE_SIZE') {
        return next(new HttpError(413, 'Logo or background image must be 12 MB or smaller'));
      }
      return next(error instanceof multer.MulterError
        ? new HttpError(400, 'Invalid branding image upload')
        : error);
    }
    if (!req.file) return next(new HttpError(400, 'Select a logo or background image'));
    if (!matchesImageSignature(req.file.buffer)) {
      return next(new HttpError(415, 'Use a valid JPG/JPEG, PNG, or WebP image'));
    }
    next();
  });
}

module.exports = { uploadBrandAsset, MAX_BRAND_IMAGE_SIZE };
