const mongoose = require('mongoose');
const Test = require('../models/Test');
const Question = require('../models/Question');
const TestAttempt = require('../models/TestAttempt');
const Notification = require('../models/Notification');
const { HttpError } = require('../middleware/errors');

async function deleteTest(req, res) {
  if (!mongoose.isValidObjectId(req.params.id)) throw new HttpError(404, 'Test not found');
  const test = await Test.findById(req.params.id);
  if (!test) throw new HttpError(404, 'Test not found');
  const session = await mongoose.startSession();
  try {
    await session.withTransaction(async () => {
      const testId = test._id;
      await Question.deleteMany({ testId }).session(session);
      await TestAttempt.deleteMany({ testId }).session(session);
      await Notification.deleteMany({ $or: [{ 'data.testId': testId }, { 'data.testId': String(testId) }] }).session(session);
      await Test.deleteOne({ _id: testId }).session(session);
    });
  } finally {
    await session.endSession();
  }
  res.json({ ok: true, data: { message: 'Test, questions, attempts, results and its notifications were permanently deleted' } });
}

module.exports = { deleteTest };
