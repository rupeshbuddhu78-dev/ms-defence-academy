const express = require('express');
const router = express.Router();
const {
  markEntry,
  markExit,
  currentlyInside,
  getAttendance,
  correctAttendance,
  adminCalendar
} = require('../controllers/attendanceController');
const { protect } = require('../middleware/authMiddleware');
const { authorize } = require('../middleware/roleMiddleware');
const { attendanceLimiter } = require('../middleware/rateLimiter');

router.use(protect);
router.use(authorize('ADMIN'));

router.post('/entry', attendanceLimiter, markEntry);
router.post('/exit', attendanceLimiter, markExit);
router.get('/currently-inside', currentlyInside);
router.get('/', getAttendance);
router.get('/calendar', adminCalendar);
router.patch('/:id/correct', correctAttendance);

module.exports = router;
