const express = require('express');
const controller = require('../controllers/academy-workflow');
const { asyncHandler } = require('../middleware/errors');
const { authenticate, allowRoles } = require('../middleware/auth');
const adminManagement = require('../controllers/admin-management');

const router = express.Router();
router.get('/dashboard', authenticate, asyncHandler(controller.dashboard));
router.get('/settings', authenticate, asyncHandler(controller.academySettings));
router.get('/batches', authenticate, asyncHandler(controller.listBatches));
router.post('/batches', authenticate, allowRoles('admin'), asyncHandler(controller.createBatch));
router.patch('/batches/:id', authenticate, allowRoles('admin'), asyncHandler(adminManagement.updateBatch));
router.delete('/batches/:id', authenticate, allowRoles('admin'), asyncHandler(adminManagement.deleteBatch));
router.get('/training', authenticate, asyncHandler(controller.listTraining));
router.post('/training', authenticate, allowRoles('admin'), asyncHandler(controller.createTraining));
router.patch('/training/:id', authenticate, allowRoles('admin'), asyncHandler(adminManagement.updateTraining));
router.delete('/training/:id', authenticate, allowRoles('admin'), asyncHandler(adminManagement.deleteTraining));

module.exports = router;
