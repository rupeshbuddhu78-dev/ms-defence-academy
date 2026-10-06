const express = require('express');
const controller = require('../controllers/academy-workflow');
const { asyncHandler } = require('../middleware/errors');
const { authenticate, allowRoles } = require('../middleware/auth');

const router = express.Router();
router.use(authenticate);
router.get('/', asyncHandler(controller.listTests));
router.post('/', allowRoles('admin'), asyncHandler(controller.createTest));
router.get('/results', asyncHandler(controller.listResults));
router.delete('/:id', allowRoles('admin'), asyncHandler(require('../controllers/test-admin').deleteTest));
router.get('/:id', asyncHandler(controller.getTest));
router.post('/:id/questions', allowRoles('admin'), asyncHandler(controller.addQuestion));
router.patch('/:id/publish', allowRoles('admin'), asyncHandler(controller.publishTest));
router.post('/:id/start', allowRoles('student'), asyncHandler(controller.startTest));
router.post('/:id/submit', allowRoles('student'), asyncHandler(controller.submitTest));
module.exports = router;
