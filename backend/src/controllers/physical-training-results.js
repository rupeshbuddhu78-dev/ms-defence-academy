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

function applyDateRange(filter, query = {}) {
  const fromText = String(query.from || '').trim();
  const toText = String(query.to || '').trim();
  const from = fromText ? new Date(fromText) : null;
  const to = toText ? new Date(toText) : null;
  if ((fromText && Number.isNaN(from.getTime())) || (toText && Number.isNaN(to.getTime()))) {
    throw new HttpError(400, 'Physical result date range is invalid');
  }
  if (from && to && from >= to) {
    throw new HttpError(400, 'Physical result date range must end after it starts');
  }
  if (from || to) {
    filter.testDate = {};
    if (from) filter.testDate.$gte = from;
    if (to) filter.testDate.$lt = to;
  }
  return filter;
}

function normalizeMetrics(body, existing = null) {
  const metrics = {};
  for (const [key, rule] of Object.entries(numericFields)) {
    if (!Object.prototype.hasOwnProperty.call(body, key)) continue;
    const raw = body[key];
    if (raw === null || (typeof raw === 'string' && raw.trim() === '')) {
      metrics[key] = null;
      continue;
    }
    const value = Number(raw);
    if (!Number.isFinite(value) || value < 0 || value > rule.max || (rule.integer && !Number.isInteger(value))) {
      throw new HttpError(400, `${rule.label} must be a valid non-negative ${rule.integer ? 'whole number' : 'measurement'}`);
    }
    metrics[key] = value;
  }
  const hasMetric = Object.keys(numericFields).some(key =>
    Object.prototype.hasOwnProperty.call(metrics, key)
      ? metrics[key] !== null
      : existing?.[key] !== null && existing?.[key] !== undefined);
  if (!hasMetric) throw new HttpError(400, 'Enter at least one physical test result');
  return metrics;
}

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
  applyDateRange(filter, req.query);
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
  const metrics = normalizeMetrics(body);
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

async function updateResult(req, res) {
  if (!mongoose.isValidObjectId(req.params.id)) throw new HttpError(400, 'Physical result ID is invalid');
  const result = await PhysicalTrainingResult.findById(req.params.id);
  if (!result) throw new HttpError(404, 'Physical training result not found');
  const body = req.body || {};
  const metrics = normalizeMetrics(body, result);
  Object.assign(result, metrics);
  if (Object.prototype.hasOwnProperty.call(body, 'testDate')) {
    const testDate = new Date(body.testDate);
    if (Number.isNaN(testDate.getTime())) throw new HttpError(400, 'Test date is invalid');
    result.testDate = testDate;
  }
  if (Object.prototype.hasOwnProperty.call(body, 'remarks')) {
    const remarks = String(body.remarks || '').trim();
    if (remarks.length > 1000) throw new HttpError(400, 'Remarks must be 1000 characters or fewer');
    result.remarks = remarks;
  }
  await result.save();
  await result.populate([
    { path: 'studentId', select: 'studentId photo course batchId', populate: [{ path: 'userId', select: 'name phone' }, { path: 'batchId', select: 'name course' }] },
    { path: 'batchId', select: 'name course' },
    { path: 'recordedBy', select: 'name' },
  ]);
  return respond(res, result);
}

module.exports = { listResults, createResult, updateResult, applyDateRange, normalizeMetrics };
