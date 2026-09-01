const express = require('express');
const router = express.Router();
const c = require('../controllers/courseController');
const { protect } = require('../middleware/authMiddleware');
const { authorize } = require('../middleware/roleMiddleware');

router.get('/', c.list);
router.get('/admin', protect, authorize('ADMIN'), c.adminList);
router.post('/', protect, authorize('ADMIN'), c.create);
router.put('/:id', protect, authorize('ADMIN'), c.update);

module.exports = router;
