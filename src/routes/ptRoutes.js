const express = require('express');
const router = express.Router();
const { getPT, createPT, updatePT } = require('../controllers/ptController');
const { protect } = require('../middleware/authMiddleware');
const { authorize } = require('../middleware/roleMiddleware');

router.get('/', protect, getPT);
router.post('/', protect, authorize('ADMIN'), createPT);
router.put('/:id', protect, authorize('ADMIN'), updatePT);
module.exports = router;
