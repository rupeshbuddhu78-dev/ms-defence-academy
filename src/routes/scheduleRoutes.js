const express = require('express');
const router = express.Router();
const { getSchedule, createSchedule, updateSchedule, deleteSchedule } = require('../controllers/scheduleController');
const { protect } = require('../middleware/authMiddleware');
const { authorize } = require('../middleware/roleMiddleware');

router.get('/', protect, getSchedule);
router.post('/', protect, authorize('ADMIN'), createSchedule);
router.put('/:id', protect, authorize('ADMIN'), updateSchedule);
router.delete('/:id', protect, authorize('ADMIN'), deleteSchedule);
module.exports = router;
