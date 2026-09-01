const express = require('express');
const router = express.Router();
const n = require('../controllers/notificationController');
const fcm = require('../controllers/fcmController');
const { protect } = require('../middleware/authMiddleware');

router.use(protect);
router.get('/', n.myNotifications);
router.patch('/:id/read', n.markRead);
router.post('/read-all', n.markAllRead);
router.post('/fcm-token', fcm.registerToken);
router.delete('/fcm-token', fcm.removeToken);

module.exports = router;
