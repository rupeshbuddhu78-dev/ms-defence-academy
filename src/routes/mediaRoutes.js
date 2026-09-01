const express = require('express');
const router = express.Router();
const {
  getMedia, getMediaById, uploadMedia, createFromUrl, updateMedia, deleteMedia, publishMedia, unpublishMedia
} = require('../controllers/mediaController');
const { protect } = require('../middleware/authMiddleware');
const { authorize } = require('../middleware/roleMiddleware');
const { upload } = require('../middleware/uploadMiddleware');

router.get('/', protect, getMedia);
router.get('/:id', protect, getMediaById);
router.post('/', protect, authorize('ADMIN'), upload.single('file'), uploadMedia);
router.post('/from-url', protect, authorize('ADMIN'), createFromUrl);
router.put('/:id', protect, authorize('ADMIN'), updateMedia);
router.delete('/:id', protect, authorize('ADMIN'), deleteMedia);
router.patch('/:id/publish', protect, authorize('ADMIN'), publishMedia);
router.patch('/:id/unpublish', protect, authorize('ADMIN'), unpublishMedia);
module.exports = router;
