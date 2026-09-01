const express = require('express');
const router = express.Router();
const { getBatches, createBatch, updateBatch, deleteBatch } = require('../controllers/batchController');
const { protect } = require('../middleware/authMiddleware');
const { authorize } = require('../middleware/roleMiddleware');

router.use(protect);
router.use(authorize('ADMIN'));
router.get('/', getBatches);
router.post('/', createBatch);
router.put('/:id', updateBatch);
router.delete('/:id', deleteBatch);
module.exports = router;
