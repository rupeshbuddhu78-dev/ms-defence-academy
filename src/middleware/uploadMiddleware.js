const multer = require('multer');
const path = require('path');

const storage = multer.memoryStorage();

const fileFilter = (req, file, cb) => {
  const allowedImages = ['image/jpeg', 'image/jpg', 'image/png', 'image/webp'];
  const allowedVideos = ['video/mp4', 'video/quicktime', 'video/webm'];
  const allAllowed = [...allowedImages, ...allowedVideos];

  if (allAllowed.includes(file.mimetype)) {
    cb(null, true);
  } else {
    cb(new Error('Invalid file type. Only JPG, PNG, WEBP, MP4, MOV, WEBM allowed.'), false);
  }
};

const upload = multer({
  storage,
  fileFilter,
  limits: {
    fileSize: (process.env.MAX_VIDEO_SIZE_MB || 500) * 1024 * 1024
  }
});

const uploadImage = multer({
  storage,
  fileFilter: (req, file, cb) => {
    const allowed = ['image/jpeg', 'image/jpg', 'image/png', 'image/webp'];
    if (allowed.includes(file.mimetype)) {
      cb(null, true);
    } else {
      cb(new Error('Only image files (JPG, PNG, WEBP) allowed.'), false);
    }
  },
  limits: {
    fileSize: (process.env.MAX_IMAGE_SIZE_MB || 10) * 1024 * 1024
  }
});

module.exports = { upload, uploadImage };
