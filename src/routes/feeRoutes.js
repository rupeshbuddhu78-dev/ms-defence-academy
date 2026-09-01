const express = require('express');
const router = express.Router();
const { getFees, recordOfflinePayment } = require('../controllers/feeController');
const { protect } = require('../middleware/authMiddleware');
const { authorize } = require('../middleware/roleMiddleware');

router.use(protect);
router.use(authorize('ADMIN'));
router.get('/', getFees);
router.post('/offline', recordOfflinePayment);
module.exports = router;
