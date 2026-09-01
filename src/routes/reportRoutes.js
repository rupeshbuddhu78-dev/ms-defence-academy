const express = require('express');
const router = express.Router();
const r = require('../controllers/reportController');
const csv = require('../controllers/csvExportController');
const { protect } = require('../middleware/authMiddleware');
const { authorize } = require('../middleware/roleMiddleware');

router.use(protect, authorize('ADMIN'));
router.get('/attendance', r.attendanceReport);
router.get('/fees', r.feeReport);
router.get('/students', r.studentReport);
router.get('/low-attendance', r.lowAttendance);
router.get('/export/students.csv', csv.exportStudentsCsv);
router.get('/export/attendance.csv', csv.exportAttendanceCsv);
router.get('/export/fees.csv', csv.exportFeesCsv);

module.exports = router;
