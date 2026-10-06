const Test = require('../models/Test');
const Question = require('../models/Question');
const TestAttempt = require('../models/TestAttempt');
const { HttpError } = require('../middleware/errors');

function deadlineFor(test, attempt) {
  const durationEnd = new Date(attempt.startedAt).getTime() + Number(test.duration) * 60 * 1000;
  return new Date(Math.min(new Date(test.endTime).getTime(), durationEnd));
}

function sanitizeAnswers(answers, questions) {
  const validIds = new Set(questions.map(question => String(question._id)));
  const selectedByQuestion = new Map();
  for (const answer of Array.isArray(answers) ? answers : []) {
    const questionId = String(answer?.questionId || '');
    const selected = Number(answer?.selected);
    if (validIds.has(questionId) && Number.isInteger(selected) && selected >= 0 && selected <= 3) {
      selectedByQuestion.set(questionId, selected);
    }
  }
  return [...selectedByQuestion.entries()].map(([questionId, selected]) => ({ questionId, selected }));
}

async function startAttempt(testId, studentId, now = new Date()) {
  const test = await Test.findById(testId);
  if (!test || test.status !== 'published' || now < test.startTime || now > test.endTime) {
    throw new HttpError(404, 'Test is not available');
  }
  const existing = await TestAttempt.findOne({ testId, studentId }).sort({ createdAt: -1 });
  if (existing && existing.status === 'in_progress') {
    const deadlineAt = deadlineFor(test, existing);
    if (now >= deadlineAt) {
      await submitAttempt(testId, studentId, existing.answers, now, true);
      throw new HttpError(409, 'The test time has expired and the saved answers were submitted');
    }
    const questions = await Question.find({ testId }).sort({ order: 1, _id: 1 }).select('questionText options marks order');
    return { attempt: existing, questions, deadlineAt };
  }
  if (existing && !test.allowRetake) throw new HttpError(409, 'You have already attempted this test');
  const questions = await Question.find({ testId }).sort({ order: 1, _id: 1 }).select('questionText options marks order');
  if (!questions.length) throw new HttpError(409, 'This test has no questions yet');
  const attempt = await TestAttempt.create({ testId, studentId, startedAt: now, totalQuestions: questions.length });
  return { attempt, questions, deadlineAt: deadlineFor(test, attempt) };
}

async function saveAnswers(testId, studentId, answers = [], now = new Date()) {
  const attempt = await TestAttempt.findOne({ testId, studentId, status: 'in_progress' });
  if (!attempt) throw new HttpError(409, 'No active attempt is available');
  const test = await Test.findById(testId);
  if (!test || test.status !== 'published') throw new HttpError(409, 'This test is no longer open');
  const deadlineAt = deadlineFor(test, attempt);
  if (now >= deadlineAt) {
    await submitAttempt(testId, studentId, answers, now, true);
    throw new HttpError(409, 'The test time has expired and the saved answers were submitted');
  }
  const questions = await Question.find({ testId }).select('_id');
  const sanitized = sanitizeAnswers(answers, questions);
  const saved = await TestAttempt.findOneAndUpdate(
    { _id: attempt._id, status: 'in_progress' },
    { $set: { answers: sanitized } },
    { new: true, runValidators: true },
  );
  if (!saved) throw new HttpError(409, 'The attempt was already submitted');
  return { saved: true, answerCount: sanitized.length, deadlineAt };
}

async function submitAttempt(testId, studentId, answers = [], now = new Date(), auto = false) {
  let attempt = await TestAttempt.findOne({ testId, studentId, status: 'in_progress' });
  if (!attempt) {
    const completed = await TestAttempt.findOne({ testId, studentId, status: 'submitted' }).sort({ submittedAt: -1 });
    if (completed) return completed;
    throw new HttpError(409, 'No active attempt is available');
  }
  const test = await Test.findById(testId);
  if (!test) throw new HttpError(404, 'Test not found');
  const deadlineAt = deadlineFor(test, attempt);
  const expired = now >= deadlineAt;
  const questions = await Question.find({ testId }).select('+correctAnswer');
  const answerSource = Array.isArray(answers) && answers.length ? answers : attempt.answers;
  const sanitized = sanitizeAnswers(answerSource, questions);
  const answerMap = new Map(sanitized.map(answer => [String(answer.questionId), answer.selected]));
  let attempted = 0;
  let correct = 0;
  let obtainedMarks = 0;
  for (const question of questions) {
    if (!answerMap.has(String(question._id))) continue;
    attempted += 1;
    if (answerMap.get(String(question._id)) === question.correctAnswer) {
      correct += 1;
      obtainedMarks += Number(question.marks || 0);
    }
  }
  const totalMarks = questions.reduce((sum, question) => sum + Number(question.marks || 0), 0);
  const submittedAt = expired ? deadlineAt : now;
  const timeTaken = Math.max(0, Math.min(
    Number(test.duration) * 60,
    Math.floor((submittedAt.getTime() - new Date(attempt.startedAt).getTime()) / 1000),
    Math.floor((deadlineAt.getTime() - new Date(attempt.startedAt).getTime()) / 1000),
  ));
  const values = {
    answers: sanitized,
    totalQuestions: questions.length,
    attempted,
    correct,
    wrong: attempted - correct,
    totalMarks,
    obtainedMarks,
    percentage: totalMarks ? Math.round(obtainedMarks / totalMarks * 10000) / 100 : 0,
    timeTaken,
    submittedAt,
    status: 'submitted',
    autoSubmitted: auto || expired,
  };
  const saved = await TestAttempt.findOneAndUpdate(
    { _id: attempt._id, status: 'in_progress' },
    { $set: values },
    { new: true, runValidators: true },
  );
  if (saved) return saved;
  attempt = await TestAttempt.findById(attempt._id);
  if (attempt?.status === 'submitted') return attempt;
  throw new HttpError(409, 'The attempt could not be submitted');
}

async function autoSubmitExpiredAttempts(now = new Date()) {
  const attempts = await TestAttempt.find({ status: 'in_progress' })
    .sort({ startedAt: 1 }).limit(500).populate('testId', 'duration endTime');
  let submitted = 0;
  for (const attempt of attempts) {
    if (!attempt.testId) continue;
    const deadlineAt = deadlineFor(attempt.testId, attempt);
    if (now >= deadlineAt) {
      await submitAttempt(attempt.testId._id, attempt.studentId, attempt.answers, now, true);
      submitted += 1;
    }
  }
  return submitted;
}

module.exports = { startAttempt, saveAnswers, submitAttempt, autoSubmitExpiredAttempts, deadlineFor };
