const Test = require('../models/Test');
const Question = require('../models/Question');
const TestAttempt = require('../models/TestAttempt');
const { HttpError } = require('../middleware/errors');
const jwt = require('jsonwebtoken');
const RETAKE_DELAY_MS = 24 * 60 * 60 * 1000;

function retryAvailableAt(attempt) {
  if (!attempt?.submittedAt || Number(attempt.attemptNumber || 1) > 1) return null;
  return new Date(new Date(attempt.submittedAt).getTime() + RETAKE_DELAY_MS);
}

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
  if (!test || test.status !== 'published' || now < test.startTime) {
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
  if (existing && existing.status === 'submitted') {
    throw new HttpError(409, 'The real result is already recorded. Use practice mode after it unlocks.');
  }
  if (!existing && now > test.endTime) {
    throw new HttpError(404, 'The scheduled time for the first attempt has ended');
  }
  const questions = await Question.find({ testId }).sort({ order: 1, _id: 1 }).select('questionText options marks order');
  if (!questions.length) throw new HttpError(409, 'This test has no questions yet');
  const attempt = await TestAttempt.create({
    testId,
    studentId,
    startedAt: now,
    totalQuestions: questions.length,
    attemptNumber: 1,
  });
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

async function startPractice(testId, studentId, now = new Date()) {
  const test = await Test.findById(testId);
  if (!test || test.status !== 'published' || now < test.startTime) throw new HttpError(404, 'Practice is not available');
  const firstResult = await TestAttempt.findOne({ testId, studentId, status: 'submitted' })
    .sort({ submittedAt: 1 }).select('submittedAt');
  if (!firstResult?.submittedAt) throw new HttpError(409, 'Complete the first real attempt before practice is unlocked');
  const availableAt = new Date(new Date(firstResult.submittedAt).getTime() + RETAKE_DELAY_MS);
  if (now < availableAt) throw new HttpError(409, `Practice unlocks after ${availableAt.toISOString()}`);
  const questions = await Question.find({ testId }).sort({ order: 1, _id: 1 }).select('questionText options marks order');
  if (!questions.length) throw new HttpError(409, 'This test has no questions yet');
  const deadlineAt = new Date(now.getTime() + Number(test.duration) * 60 * 1000);
  const practiceToken = jwt.sign({
    mode: 'practice', testId: String(test._id), studentId: String(studentId),
    startedAt: now.getTime(), deadlineAt: deadlineAt.getTime(),
  }, process.env.JWT_SECRET, { expiresIn: Number(test.duration) * 60 + 180 });
  return { questions, deadlineAt, practiceToken, isPractice: true };
}

async function submitPractice(testId, studentId, practiceToken, answers = [], now = new Date()) {
  let claims;
  try {
    claims = jwt.verify(String(practiceToken || ''), process.env.JWT_SECRET);
  } catch (_) {
    throw new HttpError(409, 'This practice session has expired. Start practice again.');
  }
  if (claims.mode !== 'practice' || String(claims.testId) !== String(testId) || String(claims.studentId) !== String(studentId)) {
    throw new HttpError(403, 'Practice session does not match this student and test');
  }
  const startedAt = new Date(Number(claims.startedAt));
  const deadlineAt = new Date(Number(claims.deadlineAt));
  if (Number.isNaN(startedAt.getTime()) || Number.isNaN(deadlineAt.getTime()) || now.getTime() > deadlineAt.getTime() + 120000) {
    throw new HttpError(409, 'Practice time has expired. Start another practice attempt.');
  }
  const test = await Test.findOne({ _id: testId, status: 'published' });
  if (!test) throw new HttpError(404, 'Test not found');
  const questions = await Question.find({ testId }).select('+correctAnswer');
  const sanitized = sanitizeAnswers(answers, questions);
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
  const submittedAt = now >= deadlineAt ? deadlineAt : now;
  return {
    isPractice: true,
    notSaved: true,
    totalQuestions: questions.length,
    attempted,
    correct,
    wrong: attempted - correct,
    totalMarks,
    obtainedMarks,
    percentage: totalMarks ? Math.round(obtainedMarks / totalMarks * 10000) / 100 : 0,
    timeTaken: Math.max(0, Math.min(Number(test.duration) * 60, Math.floor((submittedAt.getTime() - startedAt.getTime()) / 1000))),
    submittedAt,
    autoSubmitted: now >= deadlineAt,
  };
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

module.exports = { startAttempt, saveAnswers, submitAttempt, startPractice, submitPractice, autoSubmitExpiredAttempts, deadlineFor, retryAvailableAt, RETAKE_DELAY_MS };
