const express = require('express');
const router = express.Router();
const { listPending, approveStudent, rejectStudent } = require('../controllers/pendingStudentController');
const { protect } = require('../middleware/authMiddleware');
const { authorize } = require('../middleware/roleMiddleware');

router.use(protect);
router.use(authorize('ADMIN'));

router.get('/', listPending);
router.post('/:id/approve', approveStudent);
router.post('/:id/reject', rejectStudent);

module.exports = router;
