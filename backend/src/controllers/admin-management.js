const mongoose = require('mongoose');
const Batch = require('../models/Batch');
const TrainingSession = require('../models/TrainingSession');
const Fee = require('../models/Fee');
const StudentProfile = require('../models/StudentProfile');
const User = require('../models/User');
const Notification = require('../models/Notification');
const { HttpError } = require('../middleware/errors');

const respond = (res, data, status = 200) => res.status(status).json({ ok: true, data });
const objectId = (value, label) => {
  if (!mongoose.isValidObjectId(value)) throw new HttpError(404, `${label} not found`);
  return value;
};
const validDate = (value, label) => {
  const date = new Date(value);
  if (!value || Number.isNaN(date.getTime())) throw new HttpError(400, `${label} is invalid`);
  return date;
};
const validTime = (value, label) => {
  const time = String(value || '').trim();
  if (time && !/^([01]\d|2[0-3]):[0-5]\d$/.test(time)) {
    throw new HttpError(400, `${label} must use HH:mm`);
  }
  return time;
};

async function activeBatch(batchId) {
  objectId(batchId, 'Batch');
  const batch = await Batch.findOne({ _id: batchId, status: 'active' });
  if (!batch) throw new HttpError(400, 'Selected batch is not active');
  return batch;
}

async function updateBatch(req, res) {
  const id = objectId(req.params.id, 'Batch');
  const batch = await Batch.findById(id);
  if (!batch) throw new HttpError(404, 'Batch not found');
  const body = req.body || {};
  if (body.name !== undefined) {
    const name = String(body.name).trim();
    if (name.length < 2) throw new HttpError(400, 'Batch name is required');
    if (await Batch.exists({ _id: { $ne: batch._id }, name })) throw new HttpError(409, 'A batch already uses this name');
    batch.name = name;
  }
  for (const key of ['course', 'trainer', 'location']) {
    if (body[key] !== undefined) batch[key] = String(body[key] || '').trim();
  }
  for (const key of ['startTime', 'endTime']) {
    if (body[key] !== undefined) batch[key] = validTime(body[key], key === 'startTime' ? 'Start time' : 'End time');
  }
  if (body.status !== undefined) {
    if (!['active', 'inactive'].includes(body.status)) throw new HttpError(400, 'Batch status must be active or inactive');
    batch.status = body.status;
  }
  await batch.save();
  return respond(res, batch);
}

async function deleteBatch(req, res) {
  const id = objectId(req.params.id, 'Batch');
  const batch = await Batch.findById(id);
  if (!batch) throw new HttpError(404, 'Batch not found');
  batch.status = 'inactive';
  await batch.save();
  return respond(res, { message: 'Batch archived; existing student and schedule history was preserved', batch });
}

async function activeBatchStudents(batchId) {
  const profiles = await StudentProfile.find({ batchId }).select('userId').lean();
  if (!profiles.length) return [];
  return User.find({ _id: { $in: profiles.map(profile => profile.userId) }, role: 'student', isActive: true })
    .select('_id').lean();
}

async function createTrainingNotice(session, batch, titlePrefix) {
  const users = await activeBatchStudents(session.batchId);
  if (!users.length) return 0;
  await Notification.insertMany(users.map(user => ({
    userId: user._id,
    title: `${titlePrefix}: ${session.title}`,
    message: `${session.date.toISOString()} • ${session.startTime || ''}–${session.endTime || ''} • ${session.location || batch.name}`,
    type: 'training',
    data: { trainingId: session._id, batchId: session.batchId, date: session.date, startTime: session.startTime, endTime: session.endTime },
  })), { ordered: false });
  return users.length;
}

async function updateTraining(req, res) {
  const id = objectId(req.params.id, 'Training session');
  const session = await TrainingSession.findById(id);
  if (!session) throw new HttpError(404, 'Training session not found');
  const body = req.body || {};
  let batch;
  if (body.batchId !== undefined) {
    batch = String(body.batchId) === String(session.batchId)
      ? await Batch.findById(session.batchId)
      : await activeBatch(body.batchId);
    if (!batch) throw new HttpError(404, 'Training batch not found');
    session.batchId = batch._id;
  } else {
    batch = await Batch.findById(session.batchId);
    if (!batch) throw new HttpError(404, 'Training batch not found');
  }
  if (body.title !== undefined) {
    const title = String(body.title).trim();
    if (title.length < 2) throw new HttpError(400, 'Training title is required');
    session.title = title;
  }
  for (const key of ['type', 'description', 'instructions', 'trainer', 'location']) {
    if (body[key] !== undefined) session[key] = String(body[key] || '').trim();
  }
  if (body.date !== undefined) session.date = validDate(body.date, 'Training date');
  if (body.startTime !== undefined) session.startTime = validTime(body.startTime, 'Start time');
  if (body.endTime !== undefined) session.endTime = validTime(body.endTime, 'End time');
  if (body.status !== undefined) {
    if (!['scheduled', 'cancelled', 'completed'].includes(body.status)) throw new HttpError(400, 'Training status is invalid');
    session.status = body.status;
  }
  await session.save();
  let notificationsSent = 0;
  let notificationWarning = null;
  if (session.status === 'scheduled') {
    try {
      notificationsSent = await createTrainingNotice(session, batch, 'Training updated');
    } catch (_) {
      notificationWarning = 'Training was saved, but the update notification could not be sent.';
    }
  }
  await session.populate('batchId', 'name');
  return respond(res, { session, notificationsSent, notificationWarning });
}

async function deleteTraining(req, res) {
  const id = objectId(req.params.id, 'Training session');
  const session = await TrainingSession.findById(id).populate('batchId', 'name');
  if (!session) throw new HttpError(404, 'Training session not found');
  if (session.status !== 'cancelled') {
    session.status = 'cancelled';
    await session.save();
  }
  return respond(res, { message: 'Training was cancelled and hidden from active schedules', session });
}

async function updateFee(req, res) {
  const id = objectId(req.params.id, 'Fee record');
  const fee = await Fee.findById(id);
  if (!fee) throw new HttpError(404, 'Fee record not found');
  const body = req.body || {};
  const totalFees = body.totalFees === undefined ? Number(fee.totalFees) : Number(body.totalFees);
  const paidAmount = body.paidAmount === undefined ? Number(fee.paidAmount) : Number(body.paidAmount);
  if (!Number.isFinite(totalFees) || totalFees < 0 || !Number.isFinite(paidAmount) || paidAmount < 0) {
    throw new HttpError(400, 'Total fee and paid amount must be valid non-negative values');
  }
  if (paidAmount > totalFees) throw new HttpError(400, 'Paid amount cannot exceed total fee');
  if (totalFees !== Number(fee.totalFees) || paidAmount !== Number(fee.paidAmount)) {
    fee.adjustments.push({
      previousTotal: fee.totalFees,
      newTotal: totalFees,
      previousPaid: fee.paidAmount,
      newPaid: paidAmount,
      note: String(body.note || 'Admin fee correction').trim(),
      recordedBy: req.user._id,
    });
    fee.totalFees = totalFees;
    fee.paidAmount = paidAmount;
    fee.status = totalFees === 0 ? 'due' : paidAmount >= totalFees ? 'paid' : paidAmount > 0 ? 'partial' : 'due';
    await fee.save();
  }
  return respond(res, fee);
}

module.exports = { updateBatch, deleteBatch, updateTraining, deleteTraining, updateFee };
