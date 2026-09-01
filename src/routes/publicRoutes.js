const express = require('express');
const router = express.Router();
const {
  registerUser,
  userLogin,
  publicHome,
  getUserProfile,
  updateUserProfile,
  adminListUsers,
  adminPendingStudents
} = require('../controllers/publicUserController');
const { protect } = require('../middleware/authMiddleware');
const { authorize } = require('../middleware/roleMiddleware');
const { authLimiter } = require('../middleware/rateLimiter');

// Public
router.get('/home', publicHome);
router.post('/auth/register', authLimiter, registerUser);
router.post('/auth/login', authLimiter, userLogin);

// USER authenticated
router.get('/profile', protect, authorize('USER'), getUserProfile);
router.put('/profile', protect, authorize('USER'), updateUserProfile);

// Admin views public users + pending students
router.get('/admin/users', protect, authorize('ADMIN'), adminListUsers);
router.get('/admin/pending-students', protect, authorize('ADMIN'), adminPendingStudents);

module.exports = router;
