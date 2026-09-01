const Student = require('../models/Student');
const User = require('../models/User');
const Fee = require('../models/Fee');
const Payment = require('../models/Payment');
const Notice = require('../models/Notice');
const Schedule = require('../models/Schedule');
const Media = require('../models/Media');
const PhysicalTraining = require('../models/PhysicalTraining');
const Test = require('../models/Test');
const TestResult = require('../models/TestResult');
const cloudinary = require('../config/cloudinary');
const streamifier = require('streamifier');
const { logAudit } = require('../utils/auditLogger');

exports.getProfile = async (req, res, next) => {
  try {
    const student = await Student.findOne({ user: req.user._id })
      .populate('batch', 'name course instructor startTime endTime days');
    if (!student) {
      return res.status(404).json({ success: false, message: 'Student not found', code: 'NOT_FOUND' });
    }
    res.status(200).json({ success: true, data: student });
  } catch (error) { next(error); }
};

exports.updateProfile = async (req, res, next) => {
  try {
    const allowed = ['fatherName', 'motherName', 'alternateMobile', 'address', 'district', 'state'];
    const updates = {};
    allowed.forEach(f => { if (req.body[f] !== undefined) updates[f] = req.body[f]; });
    const student = await Student.findOneAndUpdate(
      { user: req.user._id },
      updates,
      { new: true, runValidators: true }
    ).populate('batch', 'name course');
    if (!student) {
      return res.status(404).json({ success: false, message: 'Student not found', code: 'NOT_FOUND' });
    }
    res.status(200).json({ success: true, message: 'Profile updated', data: student });
  } catch (error) { next(error); }
};

exports.getQR = async (req, res, next) => {
  try {
    const student = await Student.findOne({ user: req.user._id })
      .populate('batch', 'name course');
    if (!student) {
      return res.status(404).json({ success: false, message: 'Student not found', code: 'NOT_FOUND' });
    }
    res.status(200).json({
      success: true,
      data: {
        studentId: student.studentId,
        fullName: student.fullName,
        photoUrl: student.photoUrl,
        batch: student.batch,
        course: student.course,
        qrIdentifier: student.qrIdentifier,
        qrActive: student.qrActive
      }
    });
  } catch (error) { next(error); }
};

exports.getFees = async (req, res, next) => {
  try {
    const student = await Student.findOne({ user: req.user._id });
    if (!student) {
      return res.status(404).json({ success: false, message: 'Student not found', code: 'NOT_FOUND' });
    }
    const fee = await Fee.findOne({ student: student._id });
    const payments = await Payment.find({ student: student._id, status: 'PAID' }).sort({ paymentDate: -1 });
    res.status(200).json({
      success: true,
      data: {
        totalFee: student.totalFee || (fee?.totalFee || 0),
        paid: student.paidFee || (fee?.paidAmount || 0),
        pending: Math.max(0, (student.totalFee || 0) - (student.paidFee || 0)),
        nextDueDate: fee?.nextDueDate,
        history: payments
      }
    });
  } catch (error) { next(error); }
};

exports.getNotices = async (req, res, next) => {
  try {
    const notices = await Notice.find({ isPublished: true })
      .sort({ priority: -1, createdAt: -1 })
      .limit(50);
    res.status(200).json({ success: true, data: notices });
  } catch (error) { next(error); }
};

exports.getSchedule = async (req, res, next) => {
  try {
    const student = await Student.findOne({ user: req.user._id });
    if (!student || !student.batch) {
      return res.status(200).json({ success: true, data: [] });
    }
    const schedules = await Schedule.find({ batch: student.batch, isActive: true })
      .sort({ day: 1, startTime: 1 });
    res.status(200).json({ success: true, data: schedules });
  } catch (error) { next(error); }
};

exports.getPhysicalTraining = async (req, res, next) => {
  try {
    const student = await Student.findOne({ user: req.user._id });
    if (!student) {
      return res.status(404).json({ success: false, message: 'Student not found', code: 'NOT_FOUND' });
    }
    const records = await PhysicalTraining.find({ student: student._id }).sort({ date: -1 }).limit(100);
    res.status(200).json({ success: true, data: records });
  } catch (error) { next(error); }
};

exports.getTests = async (req, res, next) => {
  try {
    const tests = await Test.find({ isPublished: true }).select('-__v').sort({ createdAt: -1 });
    res.status(200).json({ success: true, data: tests });
  } catch (error) { next(error); }
};

exports.getResults = async (req, res, next) => {
  try {
    const student = await Student.findOne({ user: req.user._id });
    if (!student) {
      return res.status(404).json({ success: false, message: 'Student not found', code: 'NOT_FOUND' });
    }
    const results = await TestResult.find({ student: student._id })
      .populate('test', 'title subject totalMarks')
      .sort({ submittedAt: -1 });
    res.status(200).json({ success: true, data: results });
  } catch (error) { next(error); }
};

exports.getMedia = async (req, res, next) => {
  try {
    const { category, type, page = 1, limit = 20 } = req.query;
    const query = { isPublished: true };
    if (category) query.category = category;
    if (type) query.type = type;
    const skip = (Math.max(1, parseInt(page)) - 1) * Math.min(50, parseInt(limit) || 20);
    const lim = Math.min(50, parseInt(limit) || 20);
    const [media, total] = await Promise.all([
      Media.find(query).sort({ createdAt: -1 }).skip(skip).limit(lim),
      Media.countDocuments(query)
    ]);
    res.status(200).json({
      success: true,
      data: { media, pagination: { page: parseInt(page) || 1, limit: lim, total, pages: Math.ceil(total / lim) } }
    });
  } catch (error) { next(error); }
};

exports.uploadPhoto = async (req, res, next) => {
  try {
    if (!req.file) {
      return res.status(400).json({ success: false, message: 'No image uploaded', code: 'NO_FILE' });
    }
    const student = await Student.findOne({ user: req.user._id });
    if (!student) {
      return res.status(404).json({ success: false, message: 'Student not found', code: 'NOT_FOUND' });
    }

    const uploadFromBuffer = (buffer) => {
      return new Promise((resolve, reject) => {
        const stream = cloudinary.uploader.upload_stream(
          { folder: 'ms_defence/students', transformation: [{ width: 500, height: 500, crop: 'fill', gravity: 'face' }] },
          (error, result) => { if (error) reject(error); else resolve(result); }
        );
        streamifier.createReadStream(buffer).pipe(stream);
      });
    };

    if (student.photoPublicId) {
      try { await cloudinary.uploader.destroy(student.photoPublicId); } catch (e) {}
    }

    const result = await uploadFromBuffer(req.file.buffer);
    student.photoUrl = result.secure_url;
    student.photoPublicId = result.public_id;
    await student.save();

    res.status(200).json({ success: true, message: 'Photo updated', data: { photoUrl: student.photoUrl } });
  } catch (error) { next(error); }
};

exports.getDashboard = async (req, res, next) => {
  try {
    const student = await Student.findOne({ user: req.user._id })
      .populate('batch', 'name course instructor startTime endTime days');
    if (!student) {
      return res.status(404).json({ success: false, message: 'Student not found', code: 'NOT_FOUND' });
    }

    const Attendance = require('../models/Attendance');
    const attendanceRecords = await Attendance.find({ student: student._id });
    const present = attendanceRecords.filter(r => r.entryTime).length;
    const total = attendanceRecords.length;
    const percentage = total > 0 ? ((present / total) * 100).toFixed(2) : 0;

    const notices = await Notice.find({ isPublished: true }).sort({ createdAt: -1 }).limit(5);
    const videos = await Media.find({ isPublished: true, type: 'VIDEO' }).sort({ createdAt: -1 }).limit(3);
    const images = await Media.find({ isPublished: true, type: 'IMAGE' }).sort({ createdAt: -1 }).limit(6);

    res.status(200).json({
      success: true,
      data: {
        student: {
          studentId: student.studentId,
          fullName: student.fullName,
          photoUrl: student.photoUrl,
          batch: student.batch,
          course: student.course
        },
        attendance: { present, total, percentage: parseFloat(percentage) },
        fees: {
          totalFee: student.totalFee || 0,
          paid: student.paidFee || 0,
          pending: Math.max(0, (student.totalFee || 0) - (student.paidFee || 0))
        },
        notices,
        latestVideos: videos,
        gallery: images
      }
    });
  } catch (error) { next(error); }
};
