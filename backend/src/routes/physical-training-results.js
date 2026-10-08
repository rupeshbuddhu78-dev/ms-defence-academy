const express = require('express');
const controller = require('../controllers/physical-training-results');
const { asyncHandler } = require('../middleware/errors');
const { authenticate, allowRoles } = require('../middleware/auth');

const router = express.Router();
router.use(authenticate);
router.get('/', allowRoles('admin', 'student'), asyncHandler(controller.listResults));
router.post('/', allowRoles('admin'), asyncHandler(controller.createResult));
module.exports = router;
