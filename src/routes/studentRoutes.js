const express = require('express');
const router = express.Router();
const {
  getProfile,
  updateProfile,
  getQR,
  getFees,
  getNotices,
  getSchedule,
  getPhysicalTraining,
  getTests,
  getResults,
  getMedia,
  uploadPhoto,
  getDashboard
} = require('../controllers/studentController');
const { getStudentAttendance } = require('../controllers/attendanceController');
const { protect } = require('../middleware/authMiddleware');
const { authorize } = require('../middleware/roleMiddleware');
const { uploadImage } = require('../middleware/uploadMiddleware');

router.use(protect);
router.use(authorize('STUDENT'));

router.get('/dashboard', getDashboard);
router.get('/profile', getProfile);
router.put('/profile', updateProfile);
router.post('/profile/photo', uploadImage.single('photo'), uploadPhoto);
router.get('/qr', getQR);
router.get('/attendance', getStudentAttendance);
router.get('/fees', getFees);
router.get('/notices', getNotices);
router.get('/schedule', getSchedule);
router.get('/physical-training', getPhysicalTraining);
router.get('/tests', getTests);
router.get('/results', getResults);
router.get('/media', getMedia);

module.exports = router;
