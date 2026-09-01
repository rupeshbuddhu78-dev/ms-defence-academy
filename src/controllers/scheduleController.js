const Schedule = require('../models/Schedule');
const Student = require('../models/Student');

exports.getSchedule = async (req, res, next) => {
  try {
    let query = { isActive: true };
    if (req.user.role === 'STUDENT') {
      const student = await Student.findOne({ user: req.user._id });
      if (student?.batch) query.batch = student.batch;
      else return res.status(200).json({ success: true, data: [] });
    } else if (req.query.batchId) {
      query.batch = req.query.batchId;
    }
    const schedules = await Schedule.find(query).populate('batch', 'name').sort({ day: 1, startTime: 1 });
    res.status(200).json({ success: true, data: schedules });
  } catch (e) { next(e); }
};

exports.createSchedule = async (req, res, next) => {
  try {
    const schedule = await Schedule.create(req.body);
    res.status(201).json({ success: true, message: 'Schedule created', data: schedule });
  } catch (e) { next(e); }
};

exports.updateSchedule = async (req, res, next) => {
  try {
    const schedule = await Schedule.findByIdAndUpdate(req.params.id, req.body, { new: true });
    if (!schedule) return res.status(404).json({ success: false, message: 'Not found', code: 'NOT_FOUND' });
    res.status(200).json({ success: true, data: schedule });
  } catch (e) { next(e); }
};

exports.deleteSchedule = async (req, res, next) => {
  try {
    await Schedule.findByIdAndUpdate(req.params.id, { isActive: false });
    res.status(200).json({ success: true, message: 'Schedule deactivated' });
  } catch (e) { next(e); }
};
