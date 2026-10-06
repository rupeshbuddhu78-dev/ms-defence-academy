const express = require('express');
const academy = require('../controllers/academy');
const calendar = require('../controllers/attendance-calendar');
const { asyncHandler } = require('../middleware/errors');
const { authenticate, allowRoles } = require('../middleware/auth');

const router = express.Router();
router.use(authenticate);
router.get('/calendar', allowRoles('admin'), asyncHandler(calendar.calendar));
router.get('/', asyncHandler(academy.listAttendance));
router.post('/lookup-qr', allowRoles('admin'), asyncHandler(academy.lookupQr));
router.post('/mark', allowRoles('admin'), asyncHandler(academy.markAttendance));

module.exports = router;
