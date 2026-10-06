const academy = require('./academy');
const mongoose = require('mongoose');
const StudentProfile = require('../models/StudentProfile');
const User = require('../models/User');
const Batch = require('../models/Batch');
const TrainingSession = require('../models/TrainingSession');
const Test = require('../models/Test');
const Question = require('../models/Question');
const TestAttempt = require('../models/TestAttempt');
const Notice = require('../models/Notice');
const Notification = require('../models/Notification');
const Fee = require('../models/Fee');
const { HttpError } = require('../middleware/errors');
const exams = require('../services/exams');

const respond = (res, data, status = 200) => res.status(status).json({ ok: true, data });

async function notifyBatch(batchId, { title, message, type, data = {} }) {
  const profiles = await StudentProfile.find(batchId ? { batchId } : {}).select('userId').lean();
  if (!profiles.length) return 0;
  const users = await User.find({
    _id: { $in: profiles.map(profile => profile.userId) },
    role: 'student',
    isActive: true,
  }).select('_id').lean();
  if (!users.length) return 0;
  await Notification.insertMany(users.map(user => ({
    userId: user._id,
    title,
    message,
    type,
    data,
  })), { ordered: false });
  return users.length;
}

function validDate(value, label) {
  const date = new Date(value);
  if (!value || Number.isNaN(date.getTime())) throw new HttpError(400, `${label} is invalid`);
  return date;
}

async function activeBatch(batchId) {
  if (!batchId || !mongoose.isValidObjectId(batchId)) throw new HttpError(400, 'Select a valid batch');
  const batch = await Batch.findOne({ _id: batchId, status: 'active' });
  if (!batch) throw new HttpError(400, 'Selected batch is not active');
  return batch;
}

async function createTraining(req, res) {
  const body = req.body || {};
  const title = String(body.title || '').trim();
  if (title.length < 2) throw new HttpError(400, 'Training title is required');
  const batch = await activeBatch(body.batchId);
  const date = validDate(body.date, 'Training date');
  const session = await TrainingSession.create({
    title,
    type: String(body.type || 'Physical Training'),
    description: String(body.description || ''),
    instructions: String(body.instructions || ''),
    batchId: batch._id,
    trainer: String(body.trainer || batch.trainer || ''),
    date,
    startTime: String(body.startTime || ''),
    endTime: String(body.endTime || ''),
    location: String(body.location || batch.location || ''),
    createdBy: req.user._id,
  });
  let notificationsSent = 0;
  let notificationWarning = null;
  try {
    notificationsSent = await notifyBatch(batch._id, {
      title: `Training scheduled: ${title}`,
      message: `${date.toISOString()} • ${session.startTime || ''}–${session.endTime || ''} • ${session.location || batch.name}`,
      type: 'training',
      data: { trainingId: session._id, batchId: batch._id, date, startTime: session.startTime, endTime: session.endTime },
    });
  } catch (_) {
    notificationWarning = 'Training was saved, but the batch notification could not be sent.';
  }
  return respond(res, { session, notificationsSent, notificationWarning }, 201);
}

async function createTest(req, res) {
  const body = req.body || {};
  const title = String(body.title || '').trim();
  if (title.length < 2) throw new HttpError(400, 'Test title is required');
  const batch = await activeBatch(body.batchId);
  const startTime = validDate(body.startTime, 'Test start time');
  const endTime = validDate(body.endTime, 'Test end time');
  if (endTime <= startTime) throw new HttpError(400, 'Test end time must be after its start time');
  const duration = Number(body.duration);
  if (!Number.isInteger(duration) || duration < 1 || duration > 300) {
    throw new HttpError(400, 'Test duration must be from 1 to 300 minutes');
  }
  const test = await Test.create({
    title,
    description: String(body.description || ''),
    instructions: String(body.instructions || ''),
    batchId: batch._id,
    duration,
    startTime,
    endTime,
    allowRetake: body.allowRetake === true || body.allowRetake === 'true',
    status: 'draft',
    createdBy: req.user._id,
  });
  return respond(res, test, 201);
}

async function updateTest(req, res) {
  if (!mongoose.isValidObjectId(req.params.id)) throw new HttpError(404, 'Test not found');
  const test = await Test.findById(req.params.id);
  if (!test) throw new HttpError(404, 'Test not found');
  if (test.status === 'closed' || new Date() >= test.startTime || await TestAttempt.exists({ testId: test._id })) {
    throw new HttpError(409, 'A test cannot be edited after it starts or has attempts');
  }
  const body = req.body || {};
  if (body.title !== undefined) {
    const title = String(body.title).trim();
    if (title.length < 2) throw new HttpError(400, 'Test title is required');
    test.title = title;
  }
  for (const key of ['description', 'instructions']) {
    if (body[key] !== undefined) test[key] = String(body[key] || '').trim();
  }
  if (body.batchId !== undefined) test.batchId = (await activeBatch(body.batchId))._id;
  if (body.duration !== undefined) {
    const duration = Number(body.duration);
    if (!Number.isInteger(duration) || duration < 1 || duration > 300) {
      throw new HttpError(400, 'Test duration must be from 1 to 300 minutes');
    }
    test.duration = duration;
  }
  if (body.startTime !== undefined) test.startTime = validDate(body.startTime, 'Test start time');
  if (body.endTime !== undefined) test.endTime = validDate(body.endTime, 'Test end time');
  if (test.endTime <= test.startTime) throw new HttpError(400, 'Test end time must be after its start time');
  if (body.allowRetake !== undefined) test.allowRetake = body.allowRetake === true || body.allowRetake === 'true';
  await test.save();
  await test.populate('batchId', 'name');
  return respond(res, test);
}

async function listTests(req, res) {
  await exams.autoSubmitExpiredAttempts();
  const now = new Date();
  let filter = {};
  let studentProfile = null;
  if (req.user.role === 'student') {
    studentProfile = await StudentProfile.findOne({ userId: req.user.id }).select('_id batchId');
    if (!studentProfile || !studentProfile.batchId) return respond(res, []);
    // Keep future and expired published tests visible, but expose their lock state.
    filter = { batchId: studentProfile.batchId, status: 'published' };
  }
  const tests = await Test.find(filter).populate('batchId', 'name').sort({ startTime: 1 }).limit(200);
  const data = await Promise.all(tests.map(async test => {
    const item = { ...test.toJSON(), questionCount: await Question.countDocuments({ testId: test._id }) };
    if (studentProfile) {
      item.attempt = await TestAttempt.findOne({ testId: test._id, studentId: studentProfile._id })
        .sort({ createdAt: -1 }).select('status percentage obtainedMarks submittedAt autoSubmitted');
      item.scheduleState = now < test.startTime ? 'locked' : now > test.endTime ? 'closed' : 'open';
      item.canStart = item.scheduleState === 'open' &&
        (!item.attempt || item.attempt.status !== 'submitted' || test.allowRetake === true);
    }
    return item;
  }));
  return respond(res, data);
}

async function publishTest(req, res) {
  const test = await Test.findById(req.params.id);
  if (!test) throw new HttpError(404, 'Test not found');
  const status = String(req.body.status || 'published');
  if (!['published', 'closed'].includes(status)) throw new HttpError(400, 'Status must be published or closed');
  if (status === 'published' && !await Question.countDocuments({ testId: test._id })) {
    throw new HttpError(409, 'Add at least one question before publishing');
  }
  const shouldNotify = status === 'published' && test.status !== 'published';
  test.status = status;
  await test.save();
  let notificationsSent = 0;
  let notificationWarning = null;
  if (shouldNotify) {
    try {
      notificationsSent = await notifyBatch(test.batchId, {
        title: `New test scheduled: ${test.title}`,
        message: `Starts ${test.startTime.toISOString()} • Ends ${test.endTime.toISOString()} • ${test.duration} minutes`,
        type: 'test',
        data: { testId: test._id, batchId: test.batchId, startTime: test.startTime, endTime: test.endTime },
      });
    } catch (_) {
      notificationWarning = 'Test was published, but the batch notification could not be sent.';
    }
  }
  return respond(res, { test, notificationsSent, notificationWarning });
}

async function addQuestionsBulk(req, res) {
  if (!mongoose.isValidObjectId(req.params.id)) throw new HttpError(404, 'Test not found');
  const test = await Test.findById(req.params.id);
  if (!test) throw new HttpError(404, 'Test not found');
  if (test.status === 'closed' || new Date() >= test.startTime || await TestAttempt.exists({ testId: test._id })) {
    throw new HttpError(409, 'Questions cannot be changed after the test starts or has attempts');
  }
  const input = req.body?.questions;
  if (!Array.isArray(input) || input.length < 1 || input.length > 20) {
    throw new HttpError(400, 'Add between 1 and 20 questions at a time');
  }
  const questions = input.map((item, index) => {
    const questionText = String(item?.questionText || '').trim();
    const options = Array.isArray(item?.options) ? item.options.map(value => String(value || '').trim()) : [];
    const correctAnswer = Number(item?.correctAnswer);
    const marks = item?.marks === undefined ? 1 : Number(item.marks);
    if (!questionText || options.length !== 4 || options.some(option => !option) ||
        !Number.isInteger(correctAnswer) || correctAnswer < 0 || correctAnswer > 3 ||
        !Number.isFinite(marks) || marks < 0.5 || marks > 100) {
      throw new HttpError(400, `Question ${index + 1} needs text, four options, a correct option, and marks from 0.5 to 100`);
    }
    return { testId: test._id, questionText, options, correctAnswer, marks };
  });
  const existing = await Question.find({ testId: test._id }).select('marks order').sort({ order: 1 }).lean();
  questions.forEach((question, index) => { question.order = existing.length + index; });
  const inserted = await Question.insertMany(questions);
  const allMarks = existing.reduce((sum, question) => sum + Number(question.marks || 0), 0) +
    questions.reduce((sum, question) => sum + question.marks, 0);
  test.totalMarks = allMarks;
  await test.save();
  return respond(res, { questions: inserted, totalMarks: allMarks }, 201);
}

async function getTest(req, res) {
  const test = await Test.findById(req.params.id).populate('batchId', 'name');
  if (!test) throw new HttpError(404, 'Test not found');
  if (req.user.role === 'student') {
    const profile = await StudentProfile.findOne({ userId: req.user.id }).select('batchId');
    if (!profile || test.status !== 'published' || String(test.batchId?._id) !== String(profile.batchId)) {
      throw new HttpError(404, 'Test not found');
    }
    const now = new Date();
    if (now < test.startTime) throw new HttpError(409, 'This test has not started yet');
    if (now > test.endTime) throw new HttpError(409, 'This test has ended');
  }
  const questions = await Question.find({ testId: test._id })
    .select('questionText options marks order').sort({ order: 1, _id: 1 });
  return respond(res, { test, questions });
}

async function studentTestProfile(req, testId) {
  if (!mongoose.isValidObjectId(testId)) throw new HttpError(404, 'Test not found');
  const profile = await StudentProfile.findOne({ userId: req.user.id }).select('_id batchId');
  const test = await Test.findById(testId).select('batchId');
  if (!profile || !test || String(test.batchId) !== String(profile.batchId)) {
    throw new HttpError(404, 'Test not found');
  }
  return profile;
}

async function startTest(req, res) {
  const profile = await studentTestProfile(req, req.params.id);
  return respond(res, await exams.startAttempt(req.params.id, profile._id), 201);
}

async function saveTestAnswers(req, res) {
  const profile = await studentTestProfile(req, req.params.id);
  return respond(res, await exams.saveAnswers(req.params.id, profile._id, req.body?.answers || []));
}

async function submitTest(req, res) {
  const profile = await studentTestProfile(req, req.params.id);
  return respond(res, await exams.submitAttempt(req.params.id, profile._id, req.body?.answers || []));
}

async function listResults(req, res) {
  await exams.autoSubmitExpiredAttempts();
  const filter = { status: 'submitted' };
  if (req.user.role === 'student') {
    const profile = await StudentProfile.findOne({ userId: req.user.id }).select('_id');
    if (!profile) return respond(res, []);
    filter.studentId = profile._id;
  } else {
    if (req.query.studentId) {
      if (!mongoose.isValidObjectId(req.query.studentId)) throw new HttpError(400, 'Student ID is invalid');
      filter.studentId = req.query.studentId;
    }
    if (req.query.testId) {
      if (!mongoose.isValidObjectId(req.query.testId)) throw new HttpError(400, 'Test ID is invalid');
      filter.testId = req.query.testId;
    }
    if (req.query.batchId) {
      if (!mongoose.isValidObjectId(req.query.batchId)) throw new HttpError(400, 'Batch ID is invalid');
      const tests = await Test.find({ batchId: req.query.batchId }).select('_id').lean();
      const testIds = tests.map(test => test._id);
      filter.testId = filter.testId
        ? { $in: testIds.filter(id => String(id) === String(filter.testId)) }
        : { $in: testIds };
    }
  }
  const records = await TestAttempt.find(filter)
    .populate({ path: 'testId', select: 'title totalMarks batchId startTime endTime duration', populate: { path: 'batchId', select: 'name' } })
    .populate({
      path: 'studentId',
      select: 'studentId photo course address dateOfBirth joiningDate heightCm weightKg chestCm fatherName motherName parentPhone batchId',
      populate: [
        { path: 'userId', select: 'name phone' },
        { path: 'batchId', select: 'name' },
      ],
    })
    .sort({ submittedAt: -1 }).limit(500);
  return respond(res, records);
}

async function createNotice(req, res) {
  const body = req.body || {};
  const title = String(body.title || '').trim();
  const description = String(body.description || '').trim();
  if (!title || !description) throw new HttpError(400, 'Title and message are required');
  let batchId = null;
  let batch = null;
  if (body.batchId) {
    batch = await activeBatch(body.batchId);
    batchId = batch._id;
  }
  const notice = await Notice.create({
    title,
    description,
    priority: ['normal', 'important', 'urgent'].includes(body.priority) ? body.priority : 'normal',
    attachment: String(body.attachment || ''),
    batchId,
    isPublished: true,
    publishedAt: new Date(),
    createdBy: req.user._id,
  });
  let notificationsSent = 0;
  let notificationWarning = null;
  try {
    notificationsSent = await notifyBatch(batchId, {
      title: `Academy notice: ${title}`,
      message: description,
      type: 'notice',
      data: { noticeId: notice._id, batchId },
    });
  } catch (_) {
    notificationWarning = 'Notice was saved, but notifications could not be sent.';
  }
  return respond(res, { notice, batchName: batch?.name || 'All batches', notificationsSent, notificationWarning }, 201);
}

async function listNotices(req, res) {
  const filter = req.user.role === 'admin' ? {} : { isPublished: true };
  if (req.user.role === 'student') {
    const profile = await StudentProfile.findOne({ userId: req.user.id }).select('batchId');
    filter.$or = [{ batchId: null }, { batchId: profile?.batchId || null }];
  }
  const notices = await Notice.find(filter).populate('batchId', 'name').sort({ publishedAt: -1 }).limit(100);
  return respond(res, notices);
}

async function createFee(req, res) {
  const studentId = String(req.body.studentId || '');
  const batch = await activeBatch(req.body.batchId);
  const totalFees = Number(req.body.totalFees);
  const paidAmount = req.body.paidAmount === undefined ? 0 : Number(req.body.paidAmount);
  if (!mongoose.isValidObjectId(studentId) || !Number.isFinite(totalFees) || totalFees <= 0) {
    throw new HttpError(400, 'Select a student and enter a total fee above zero');
  }
  if (!Number.isFinite(paidAmount) || paidAmount < 0 || paidAmount > totalFees) {
    throw new HttpError(400, 'Initial paid amount must be between zero and the total fee');
  }
  const profile = await StudentProfile.findById(studentId).select('batchId');
  if (!profile) throw new HttpError(404, 'Student profile not found');
  if (String(profile.batchId || '') !== String(batch._id)) {
    throw new HttpError(400, 'Selected student does not belong to the selected batch');
  }
  const fee = await Fee.create({
    studentId,
    batchId: batch._id,
    totalFees,
    paidAmount,
    status: paidAmount >= totalFees ? 'paid' : paidAmount > 0 ? 'partial' : 'due',
    remarks: String(req.body.remarks || ''),
    payments: paidAmount > 0 ? [{ amount: paidAmount, note: 'Initial payment', recordedBy: req.user._id }] : [],
  });
  return respond(res, fee, 201);
}

module.exports = {
  ...academy,
  createTraining,
  createTest,
  updateTest,
  listTests,
  addQuestionsBulk,
  publishTest,
  getTest,
  startTest,
  saveTestAnswers,
  submitTest,
  listResults,
  createNotice,
  listNotices,
  createFee,
};
