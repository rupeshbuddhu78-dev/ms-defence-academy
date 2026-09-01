const express = require('express');
const router = express.Router();
const { createOrder, verifyPayment } = require('../controllers/paymentController');
const { protect } = require('../middleware/authMiddleware');
const { authorize } = require('../middleware/roleMiddleware');
const { paymentLimiter } = require('../middleware/rateLimiter');

router.post('/create-order', protect, authorize('STUDENT'), paymentLimiter, createOrder);
router.post('/verify', protect, authorize('STUDENT'), paymentLimiter, verifyPayment);
module.exports = router;
