const express = require('express');
const router = express.Router();
const {
  getTests, createTest, updateTest, deleteTest, addQuestion, getQuestions, submitTest
} = require('../controllers/testController');
const { protect } = require('../middleware/authMiddleware');
const { authorize } = require('../middleware/roleMiddleware');

router.get('/', protect, getTests);
router.post('/', protect, authorize('ADMIN'), createTest);
router.put('/:id', protect, authorize('ADMIN'), updateTest);
router.delete('/:id', protect, authorize('ADMIN'), deleteTest);
router.post('/:id/questions', protect, authorize('ADMIN'), addQuestion);
router.get('/:id/questions', protect, getQuestions);
router.post('/:id/submit', protect, authorize('STUDENT'), submitTest);
module.exports = router;
