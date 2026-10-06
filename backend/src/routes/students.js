const express = require('express');
const academy = require('../controllers/academy');
const students = require('../controllers/students');
const { asyncHandler } = require('../middleware/errors');
const { authenticate, allowRoles } = require('../middleware/auth');
const { uploadPhoto } = require('../middleware/photoUpload');

const router = express.Router();
router.use(authenticate);

router.get('/profile', allowRoles('student'), asyncHandler(students.getOwnProfile));
router.post('/profile/photo', allowRoles('student'), uploadPhoto, asyncHandler(students.uploadOwnPhoto));
router.get('/profile/qr', allowRoles('student'), asyncHandler(academy.studentQr));

router.get('/', allowRoles('admin'), asyncHandler(students.listStudents));
router.post('/', allowRoles('admin'), uploadPhoto, asyncHandler(students.createStudent));
router.get('/:id', allowRoles('admin'), asyncHandler(students.getStudent));
router.patch('/:id/password', allowRoles('admin'), asyncHandler(students.resetStudentPassword));
router.patch('/:id', allowRoles('admin'), asyncHandler(students.updateStudent));
router.post('/:id/photo', allowRoles('admin'), uploadPhoto, asyncHandler(students.uploadStudentPhoto));
router.delete('/:id', allowRoles('admin'), asyncHandler(students.deleteStudent));

module.exports = router;
