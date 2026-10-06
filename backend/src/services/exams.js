const Test = require('../models/Test');
const Question = require('../models/Question');
const TestAttempt = require('../models/TestAttempt');
const { HttpError } = require('../middleware/errors');

async function startAttempt(testId, studentId, now = new Date()) {
  const test = await Test.findById(testId);
  if (!test || test.status !== 'published' || now < test.startTime || now > test.endTime) throw new HttpError(404, 'Test is not available');
  const attempt = await TestAttempt.findOne({ testId, studentId });
  if (attempt && (!test.allowRetake || attempt.status === 'in_progress')) {
    if (attempt.status === 'in_progress') {
      const questions = await Question.find({ testId }).sort({ order: 1, _id: 1 }).select('questionText options marks order');
      return { attempt, questions };
    }
    throw new HttpError(409, 'You have already attempted this test');
  }
  const questions = await Question.find({ testId }).sort({ order: 1, _id: 1 }).select('questionText options marks order');
  if (!questions.length) throw new HttpError(409, 'This test has no questions yet');
  const created = await TestAttempt.create({ testId, studentId, startedAt: now, totalQuestions: questions.length });
  return { attempt: created, questions };
}
async function submitAttempt(testId, studentId, answers = [], now = new Date()) {
  const attempt = await TestAttempt.findOne({ testId, studentId });
  if (!attempt || attempt.status === 'submitted') throw new HttpError(409, 'No active attempt is available');
  const test = await Test.findById(testId);
  if (!test) throw new HttpError(404, 'Test not found');
  const questions = await Question.find({ testId }).select('+correctAnswer');
  const byId = new Map(questions.map(q => [String(q._id), q]));
  let attempted = 0, correct = 0, obtainedMarks = 0;
  const sanitized = [];
  for (const answer of answers) {
    const q = byId.get(String(answer.questionId));
    if (!q || !Number.isInteger(answer.selected) || answer.selected < 0 || answer.selected > 3) continue;
    attempted++;
    if (answer.selected === q.correctAnswer) { correct++; obtainedMarks += q.marks; }
    sanitized.push({ questionId: q._id, selected: answer.selected });
  }
  const totalMarks = questions.reduce((sum, q) => sum + q.marks, 0);
  const spent = Math.max(0, Math.floor((now - attempt.startedAt) / 1000));
  const allowed = test.duration * 60;
  if (spent > allowed + 30) throw new HttpError(409, 'The test time has expired');
  attempt.answers = sanitized; attempt.totalQuestions = questions.length; attempt.attempted = attempted;
  attempt.correct = correct; attempt.wrong = attempted - correct; attempt.totalMarks = totalMarks;
  attempt.obtainedMarks = obtainedMarks; attempt.percentage = totalMarks ? Math.round(obtainedMarks / totalMarks * 10000) / 100 : 0;
  attempt.timeTaken = Math.min(spent, allowed); attempt.submittedAt = now; attempt.status = 'submitted';
  await attempt.save();
  return attempt;
}
module.exports = { startAttempt, submitAttempt };
