const PhysicalTraining = require('../models/PhysicalTraining');
const Student = require('../models/Student');

exports.getPT = async (req, res, next) => {
  try {
    let query = {};
    if (req.user.role === 'STUDENT') {
      const student = await Student.findOne({ user: req.user._id });
      if (!student) return res.status(404).json({ success: false, message: 'Not found', code: 'NOT_FOUND' });
      query.student = student._id;
    } else if (req.query.studentId) {
      query.studentId = req.query.studentId.toUpperCase();
    }
    const records = await PhysicalTraining.find(query).sort({ date: -1 }).limit(100);
    res.status(200).json({ success: true, data: records });
  } catch (e) { next(e); }
};

exports.createPT = async (req, res, next) => {
  try {
    const { studentId, date, exercise, target, result, instructorRemark } = req.body;
    const student = await Student.findOne({ studentId: studentId?.toUpperCase() });
    if (!student) return res.status(404).json({ success: false, message: 'Student not found', code: 'NOT_FOUND' });
    const record = await PhysicalTraining.create({
      student: student._id, studentId: student.studentId, date: date || new Date(),
      exercise, target, result, instructorRemark, recordedBy: req.user._id
    });
    res.status(201).json({ success: true, message: 'PT record added', data: record });
  } catch (e) { next(e); }
};

exports.updatePT = async (req, res, next) => {
  try {
    const record = await PhysicalTraining.findById(req.params.id);
    if (!record) return res.status(404).json({ success: false, message: 'Not found', code: 'NOT_FOUND' });
    const old = { target: record.target, result: record.result, instructorRemark: record.instructorRemark };
    Object.assign(record, req.body);
    record.corrections = record.corrections || [];
    record.corrections.push({
      adminId: req.user._id, oldValue: old, newValue: req.body, reason: req.body.reason || 'Correction', correctedAt: new Date()
    });
    await record.save();
    res.status(200).json({ success: true, message: 'PT updated', data: record });
  } catch (e) { next(e); }
};
