const Batch = require('../models/Batch');
const Student = require('../models/Student');
const { logAudit } = require('../utils/auditLogger');

exports.getBatches = async (req, res, next) => {
  try {
    const batches = await Batch.find().sort({ createdAt: -1 });
    res.status(200).json({ success: true, data: batches });
  } catch (e) { next(e); }
};

exports.createBatch = async (req, res, next) => {
  try {
    const batch = await Batch.create(req.body);
    await logAudit({ adminId: req.user._id, action: 'BATCH_CREATED', entityType: 'Batch', entityId: batch._id, req });
    res.status(201).json({ success: true, message: 'Batch created', data: batch });
  } catch (e) { next(e); }
};

exports.updateBatch = async (req, res, next) => {
  try {
    const batch = await Batch.findByIdAndUpdate(req.params.id, req.body, { new: true, runValidators: true });
    if (!batch) return res.status(404).json({ success: false, message: 'Batch not found', code: 'NOT_FOUND' });
    res.status(200).json({ success: true, message: 'Batch updated', data: batch });
  } catch (e) { next(e); }
};

exports.deleteBatch = async (req, res, next) => {
  try {
    const batch = await Batch.findByIdAndUpdate(req.params.id, { status: 'INACTIVE' }, { new: true });
    if (!batch) return res.status(404).json({ success: false, message: 'Batch not found', code: 'NOT_FOUND' });
    res.status(200).json({ success: true, message: 'Batch deactivated', data: batch });
  } catch (e) { next(e); }
};
