const express = require('express');
const controller = require('../controllers/physical-training-sheets');
const { asyncHandler } = require('../middleware/errors');
const { authenticate, allowRoles } = require('../middleware/auth');

const router = express.Router();
router.use(authenticate);
router.get('/', allowRoles('admin', 'student'), asyncHandler(controller.listSheets));
router.post('/', allowRoles('admin'), asyncHandler(controller.createSheet));
router.patch('/:id/rows', allowRoles('admin'), asyncHandler(controller.saveRows));
router.delete('/:id', allowRoles('admin'), asyncHandler(controller.deleteSheet));
module.exports = router;
