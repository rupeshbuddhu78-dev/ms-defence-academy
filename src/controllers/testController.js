const Test = require('../models/Test');
const Question = require('../models/Question');
const TestResult = require('../models/TestResult');
const Student = require('../models/Student');

exports.getTests = async (req, res, next) => {
  try {
    const query = req.user.role === 'ADMIN' ? {} : { isPublished: true };
    const tests = await Test.find(query).sort({ createdAt: -1 });
    res.status(200).json({ success: true, data: tests });
  } catch (e) { next(e); }
};

exports.createTest = async (req, res, next) => {
  try {
    const test = await Test.create({ ...req.body, createdBy: req.user._id });
    res.status(201).json({ success: true, message: 'Test created', data: test });
  } catch (e) { next(e); }
};

exports.updateTest = async (req, res, next) => {
  try {
    const test = await Test.findByIdAndUpdate(req.params.id, req.body, { new: true });
    if (!test) return res.status(404).json({ success: false, message: 'Not found', code: 'NOT_FOUND' });
    res.status(200).json({ success: true, data: test });
  } catch (e) { next(e); }
};

exports.deleteTest = async (req, res, next) => {
  try {
    await Question.deleteMany({ test: req.params.id });
    await Test.findByIdAndDelete(req.params.id);
    res.status(200).json({ success: true, message: 'Test deleted' });
  } catch (e) { next(e); }
};

exports.addQuestion = async (req, res, next) => {
  try {
    const question = await Question.create({ ...req.body, test: req.params.id });
    const count = await Question.countDocuments({ test: req.params.id });
    const totalMarks = await Question.aggregate([
      { $match: { test: require('mongoose').Types.ObjectId.createFromHexString(req.params.id) } },
      { $group: { _id: null, total: { $sum: '$marks' } } }
    ]);
    await Test.findByIdAndUpdate(req.params.id, {
      totalMarks: totalMarks[0]?.total || 0
    });
    res.status(201).json({ success: true, data: question });
  } catch (e) { next(e); }
};

exports.getQuestions = async (req, res, next) => {
  try {
    const questions = await Question.find({ test: req.params.id }).sort({ order: 1 });
    // Hide correct answers for students
    if (req.user.role === 'STUDENT') {
      const safe = questions.map(q => ({
        _id: q._id, questionText: q.questionText, optionA: q.optionA, optionB: q.optionB,
        optionC: q.optionC, optionD: q.optionD, marks: q.marks, order: q.order
      }));
      return res.status(200).json({ success: true, data: safe });
    }
    res.status(200).json({ success: true, data: questions });
  } catch (e) { next(e); }
};

exports.submitTest = async (req, res, next) => {
  try {
    const student = await Student.findOne({ user: req.user._id });
    if (!student) return res.status(404).json({ success: false, message: 'Student not found', code: 'NOT_FOUND' });

    const existing = await TestResult.findOne({ test: req.params.id, student: student._id });
    if (existing) return res.status(409).json({ success: false, message: 'Test already submitted', code: 'ALREADY_SUBMITTED' });

    const test = await Test.findById(req.params.id);
    if (!test || !test.isPublished) return res.status(404).json({ success: false, message: 'Test not found', code: 'NOT_FOUND' });

    const questions = await Question.find({ test: req.params.id });
    const answers = req.body.answers || [];
    let correct = 0, wrong = 0, skipped = 0, score = 0;

    const answerDetails = questions.map(q => {
      const ans = answers.find(a => String(a.questionId) === String(q._id));
      const selected = ans?.selectedAnswer || null;
      let isCorrect = false, marksObtained = 0;
      if (!selected) {
        skipped++;
      } else if (selected === q.correctAnswer) {
        correct++;
        isCorrect = true;
        marksObtained = q.marks;
        score += q.marks;
      } else {
        wrong++;
        if (test.negativeMarking) {
          marksObtained = -(test.negativeMarks || 0);
          score += marksObtained;
        }
      }
      return { question: q._id, selectedAnswer: selected, isCorrect, marksObtained };
    });

    const percentage = test.totalMarks > 0 ? ((score / test.totalMarks) * 100).toFixed(2) : 0;

    const result = await TestResult.create({
      test: test._id, student: student._id, studentId: student.studentId,
      answers: answerDetails, totalQuestions: questions.length,
      correct, wrong, skipped, score, percentage: parseFloat(percentage)
    });

    res.status(201).json({
      success: true,
      message: 'Test submitted',
      data: {
        totalQuestions: questions.length, correct, wrong, skipped, score, percentage: parseFloat(percentage)
      }
    });
  } catch (e) { next(e); }
};
