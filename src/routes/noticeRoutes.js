const express = require('express');
const router = express.Router();
const {
  getNotices, createNotice, updateNotice, deleteNotice, publishNotice, unpublishNotice
} = require('../controllers/noticeController');
const { protect } = require('../middleware/authMiddleware');
const { authorize } = require('../middleware/roleMiddleware');
const { uploadImage } = require('../middleware/uploadMiddleware');

router.get('/', protect, getNotices);
router.post('/', protect, authorize('ADMIN'), uploadImage.single('image'), createNotice);
router.put('/:id', protect, authorize('ADMIN'), updateNotice);
router.delete('/:id', protect, authorize('ADMIN'), deleteNotice);
router.patch('/:id/publish', protect, authorize('ADMIN'), publishNotice);
router.patch('/:id/unpublish', protect, authorize('ADMIN'), unpublishNotice);
module.exports = router;
