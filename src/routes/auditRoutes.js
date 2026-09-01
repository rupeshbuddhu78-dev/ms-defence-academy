const express = require('express');
const router = express.Router();
const a = require('../controllers/auditController');
const { protect } = require('../middleware/authMiddleware');
const { authorize } = require('../middleware/roleMiddleware');

router.get('/', protect, authorize('ADMIN'), a.list);
module.exports = router;
