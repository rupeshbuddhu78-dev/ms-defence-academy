const Course = require('../models/Course');

exports.list = async (req, res, next) => {
  try {
    const courses = await Course.find({ status: 'ACTIVE' }).sort({ name: 1 });
    res.json({ success: true, data: courses });
  } catch (e) { next(e); }
};

exports.adminList = async (req, res, next) => {
  try {
    const courses = await Course.find().sort({ name: 1 });
    res.json({ success: true, data: courses });
  } catch (e) { next(e); }
};

exports.create = async (req, res, next) => {
  try {
    const course = await Course.create(req.body);
    res.status(201).json({ success: true, data: course });
  } catch (e) { next(e); }
};

exports.update = async (req, res, next) => {
  try {
    const course = await Course.findByIdAndUpdate(req.params.id, req.body, { new: true, runValidators: true });
    if (!course) return res.status(404).json({ success: false, message: 'Not found' });
    res.json({ success: true, data: course });
  } catch (e) { next(e); }
};
