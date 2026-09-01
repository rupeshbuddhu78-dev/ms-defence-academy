const express = require('express');
const router = express.Router();
const {
  getDashboard,
  getStudents,
  getStudentById,
  createStudent,
  updateStudent,
  updateStudentStatus,
  regenerateQR,
  resetStudentPassword
} = require('../controllers/adminController');
const { protect } = require('../middleware/authMiddleware');
const { authorize } = require('../middleware/roleMiddleware');

router.use(protect);
router.use(authorize('ADMIN'));

router.get('/dashboard', getDashboard);
router.get('/students', getStudents);
router.post('/students', createStudent);
router.get('/students/:id', getStudentById);
router.put('/students/:id', updateStudent);
router.patch('/students/:id/status', updateStudentStatus);
router.post('/students/:id/regenerate-qr', regenerateQR);
router.post('/students/:id/reset-password', resetStudentPassword);

module.exports = router;
