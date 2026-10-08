const mongoose = require('mongoose');
const Batch = require('../models/Batch');
const StudentProfile = require('../models/StudentProfile');
const PhysicalTrainingSheet = require('../models/PhysicalTrainingSheet');
const { HttpError } = require('../middleware/errors');

const respond = (res, data, status = 200) => res.status(status).json({ ok: true, data });
const MAX_ROWS = 500;
const MAX_COLUMNS = 24;
const allowedTypes = new Set(['measurement', 'marks', 'passfail']);

function normalizeColumns(columns) {
  if (!Array.isArray(columns) || columns.length < 1 || columns.length > 24) {
    throw new HttpError(400, 'Select between 1 and 24 physical test columns');
  }
  const used = new Set();
  return columns.map((column, index) => {
    const key = String(column?.key || '').trim();
    const label = String(column?.label || '').trim();
    const type = String(column?.type || '');
    if (!/^[a-z][a-z0-9_]{0,39}$/.test(key) || used.has(key)) {
      throw new HttpError(400, `Physical test column ${index + 1} has an invalid or duplicate key`);
    }
    if (!label || label.length > 60 || !allowedTypes.has(type)) {
      throw new HttpError(400, `Physical test column ${index + 1} has an invalid label or type`);
    }
    used.add(key);
    return { key, label, type };
  });
}

function normalizeRowValues(columns, rawValues = {}) {
  if (!rawValues || typeof rawValues !== 'object' || Array.isArray(rawValues)) {
    throw new HttpError(400, 'Student marks must be an object');
  }
  const values = {};
  let totalMarks = 0;
  for (const column of columns) {
    const raw = rawValues[column.key];
    if (raw === undefined || raw === null || String(raw).trim() === '') continue;
    if (column.type === 'measurement') {
      const value = String(raw).trim();
      if (value.length > 80) throw new HttpError(400, `${column.label} must be 80 characters or fewer`);
      values[column.key] = value;
    } else if (column.type === 'marks') {
      const value = Number(raw);
      if (!Number.isFinite(value) || value < 0 || value > 1000) {
        throw new HttpError(400, `${column.label} must be a number from 0 to 1000`);
      }
      values[column.key] = value;
      totalMarks += value;
    } else {
      const value = String(raw).trim().toLowerCase();
      const normalized = ['pass', 'passed', 'yes', 'true', '✓'].includes(value)
        ? 'pass'
        : ['fail', 'failed', 'no', 'false', '✗', '✘'].includes(value)
          ? 'fail'
          : null;
      if (!normalized) throw new HttpError(400, `${column.label} must be Pass or Fail`);
      values[column.key] = normalized;
    }
  }
  return { values, totalMarks: Math.round(totalMarks * 100) / 100 };
}

function createSheetColumns(input) {
  const columns = normalizeColumns(input);
  if (columns.some(column => column.type === 'marks' || column.key === 'total_marks')) {
    throw new HttpError(400, 'Event marks are not separate; each student gets one overall Total Marks field');
  }
  if (columns.length >= MAX_COLUMNS) {
    throw new HttpError(400, `Select at most ${MAX_COLUMNS - 1} physical test columns; one overall marks column is added automatically`);
  }
  return [...columns, { key: 'total_marks', label: 'Total Marks', type: 'marks' }];
}

const populate = [
  { path: 'batchId', select: 'name course' },
  { path: 'createdBy', select: 'name' },
  {
    path: 'rows.studentId',
    select: 'studentId photo course batchId',
    populate: { path: 'userId', select: 'name' },
  },
];

async function listSheets(req, res) {
  const filter = {};
  if (req.user.role === 'student') {
    const profile = await StudentProfile.findOne({ userId: req.user.id }).select('batchId');
    if (!profile?.batchId) return respond(res, []);
    if (req.query.batchId && String(req.query.batchId) !== String(profile.batchId)) {
      throw new HttpError(403, 'Students can only view their own batch marks sheets');
    }
    filter.batchId = profile.batchId;
  } else if (req.query.batchId) {
    if (!mongoose.isValidObjectId(req.query.batchId)) throw new HttpError(400, 'Batch ID is invalid');
    filter.batchId = req.query.batchId;
  }
  const sheets = await PhysicalTrainingSheet.find(filter)
    .populate(populate)
    .sort({ testDate: -1, createdAt: -1 })
    .limit(100);
  return respond(res, sheets);
}

async function createSheet(req, res) {
  const body = req.body || {};
  const batchId = String(body.batchId || '');
  const title = String(body.title || '').trim();
  const template = String(body.template || '').trim();
  if (!mongoose.isValidObjectId(batchId)) throw new HttpError(400, 'Select a valid batch');
  if (!title || title.length > 100) throw new HttpError(400, 'Sheet title is required and must be 100 characters or fewer');
  if (!template || template.length > 60) throw new HttpError(400, 'Select a physical test template');
  const columns = createSheetColumns(body.columns);
  const testDate = body.testDate ? new Date(body.testDate) : new Date();
  if (Number.isNaN(testDate.getTime())) throw new HttpError(400, 'Test date is invalid');
  const batch = await Batch.findOne({ _id: batchId, status: 'active' });
  if (!batch) throw new HttpError(404, 'Active batch not found');
  const students = await StudentProfile.find({ batchId: batch._id })
    .select('_id')
    .sort({ studentId: 1 })
    .limit(MAX_ROWS + 1);
  if (!students.length) throw new HttpError(409, 'This batch has no students');
  if (students.length > MAX_ROWS) throw new HttpError(413, `A marks sheet can contain at most ${MAX_ROWS} students`);
  const sheet = await PhysicalTrainingSheet.create({
    batchId: batch._id,
    title,
    template,
    testDate,
    columns,
    rows: students.map(student => ({ studentId: student._id, values: {}, totalMarks: 0 })),
    createdBy: req.user._id,
  });
  await sheet.populate(populate);
  return respond(res, sheet, 201);
}

async function saveRows(req, res) {
  if (!mongoose.isValidObjectId(req.params.id)) throw new HttpError(400, 'Marks sheet ID is invalid');
  const rows = req.body?.rows;
  if (!Array.isArray(rows) || rows.length > MAX_ROWS) throw new HttpError(400, 'Student rows must be a valid list');
  const sheet = await PhysicalTrainingSheet.findById(req.params.id);
  if (!sheet) throw new HttpError(404, 'Marks sheet not found');
  const knownRows = new Map(sheet.rows.map(row => [String(row.studentId), row]));
  const seen = new Set();
  for (const input of rows) {
    const studentId = String(input?.studentId || '');
    if (!knownRows.has(studentId) || seen.has(studentId)) {
      throw new HttpError(400, 'A row contains an unknown or duplicate student');
    }
    seen.add(studentId);
    const normalized = normalizeRowValues(sheet.columns, input.values);
    const target = knownRows.get(studentId);
    target.values = normalized.values;
    target.totalMarks = normalized.totalMarks;
  }
  sheet.markModified('rows');
  await sheet.save();
  await sheet.populate(populate);
  return respond(res, sheet);
}

module.exports = { listSheets, createSheet, saveRows, normalizeColumns, normalizeRowValues, createSheetColumns, MAX_ROWS, MAX_COLUMNS };
