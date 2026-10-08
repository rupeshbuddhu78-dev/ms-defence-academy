const mongoose = require('mongoose');
const Batch = require('../models/Batch');
const StudentProfile = require('../models/StudentProfile');
const PhysicalTrainingResult = require('../models/PhysicalTrainingResult');
const { HttpError } = require('../middleware/errors');

const respond = (res, data, status = 200) => res.status(status).json({ ok: true, data });
const numericFields = {
  runTimeSeconds: { label: 'Running time', max: 86400, integer: false },
  beamReps: { label: 'Beam / pull-ups', max: 1000, integer: true },
  longJumpCm: { label: 'Long jump', max: 1000, integer: false },
  highJumpCm: { label: 'High jump', max: 1000, integer: false },
  pushUps: { label: 'Push-ups', max: 1000, integer: true },
  sitUps: { label: 'Sit-ups', max: 1000, integer: true },
  shuttleRunSeconds: { label: 'Shuttle run', max: 86400, integer: false },
};

async function listResults(req, res) {
  const filter = {};
  if (req.user.role === 'student') {
    const profile = await StudentProfile.findOne({ userId: req.user.id }).select('_id');
    if (!profile) return respond(res, []);
    filter.studentId = profile._id;
  } else {
    if (req.query.batchId) {
      if (!mongoose.isValidObjectId(req.query.batchId)) throw new HttpError(400, 'Batch ID is invalid');
      filter.batchId = req.query.batchId;
    }
    if (req.query.studentId) {
      if (!mongoose.isValidObjectId(req.query.studentId)) throw new HttpError(400, 'Student ID is invalid');
      filter.studentId = req.query.studentId;
    }
  }
  const records = await PhysicalTrainingResult.find(filter)
    .populate({ path: 'studentId', select: 'studentId photo course batchId', populate: [
      { path: 'userId', select: 'name phone' },
      { path: 'batchId', select: 'name course' },
    ] })
    .populate('batchId', 'name course')
    .populate('recordedBy', 'name')
    .sort({ testDate: -1, createdAt: -1 }).limit(500);
  return respond(res, records);
}

async function createResult(req, res) {
  const body = req.body || {};
  const studentId = String(body.studentId || '');
  const batchId = String(body.batchId || '');
  if (!mongoose.isValidObjectId(studentId)) throw new HttpError(400, 'Select a valid student');
  if (!mongoose.isValidObjectId(batchId)) throw new HttpError(400, 'Select a valid batch');
  const [batch, student] = await Promise.all([
    Batch.findOne({ _id: batchId, status: 'active' }),
    StudentProfile.findById(studentId).select('_id batchId'),
  ]);
  if (!batch) throw new HttpError(404, 'Active batch not found');
  if (!student || String(student.batchId || '') !== String(batch._id)) {
    throw new HttpError(400, 'The selected student does not belong to this batch');
  }
  const metrics = {};
  let hasMetric = false;
  for (const [key, rule] of Object.entries(numericFields)) {
    const raw = body[key];
    if (raw === undefined || raw === null || raw === '') continue;
    const value = Number(raw);
    if (!Number.isFinite(value) || value < 0 || value > rule.max || (rule.integer && !Number.isInteger(value))) {
      throw new HttpError(400, `${rule.label} must be a valid non-negative ${rule.integer ? 'whole number' : 'measurement'}`);
    }
    metrics[key] = value;
    hasMetric = true;
  }
  if (!hasMetric) throw new HttpError(400, 'Enter at least one physical test result');
  const testDate = body.testDate ? new Date(body.testDate) : new Date();
  if (Number.isNaN(testDate.getTime())) throw new HttpError(400, 'Test date is invalid');
  const remarks = String(body.remarks || '').trim();
  if (remarks.length > 1000) throw new HttpError(400, 'Remarks must be 1000 characters or fewer');
  const result = await PhysicalTrainingResult.create({
    studentId: student._id,
    batchId: batch._id,
    testDate,
    ...metrics,
    remarks,
    recordedBy: req.user._id,
  });
  await result.populate([
    { path: 'studentId', select: 'studentId photo course batchId', populate: [{ path: 'userId', select: 'name phone' }, { path: 'batchId', select: 'name course' }] },
    { path: 'batchId', select: 'name course' },
    { path: 'recordedBy', select: 'name' },
  ]);
  return respond(res, result, 201);
}

module.exports = { listResults, createResult };
