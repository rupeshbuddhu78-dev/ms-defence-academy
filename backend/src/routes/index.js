const express = require('express');
const { asyncHandler } = require('../middleware/errors');
const auth = require('../controllers/auth');
const notifications = require('../controllers/notifications');
const controller = require('../controllers/academy-workflow');
const { authenticate, allowRoles } = require('../middleware/auth');
const adminManagement = require('../controllers/admin-management');

const router = express.Router();
router.post('/auth/login', asyncHandler(auth.login));
router.get('/auth/me', authenticate, asyncHandler(auth.me));
router.post('/auth/change-password', authenticate, asyncHandler(auth.changePassword));
router.use('/students', require('./students'));
router.use('/attendance', require('./attendance'));
router.use('/', require('./academy'));
router.use('/tests', require('./tests'));
router.get('/notices', authenticate, asyncHandler(controller.listNotices));
router.post('/notices', authenticate, allowRoles('admin'), asyncHandler(controller.createNotice));
router.get('/fees', authenticate, asyncHandler(controller.getFees));
router.post('/fees', authenticate, allowRoles('admin'), asyncHandler(controller.createFee));
router.patch('/fees/:id', authenticate, allowRoles('admin'), asyncHandler(adminManagement.updateFee));
router.post('/fees/:id/payments', authenticate, allowRoles('admin'), asyncHandler(controller.recordPayment));
router.get('/notifications', authenticate, asyncHandler(notifications.list));
router.patch('/notifications/:id/read', authenticate, asyncHandler(notifications.markRead));

module.exports = router;
