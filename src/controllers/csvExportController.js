const Student = require('../models/Student');
const Attendance = require('../models/Attendance');
const Fee = require('../models/Fee');
const Payment = require('../models/Payment');

const toCsv = (headers, rows) => {
  const esc = (v) => {
    const s = v == null ? '' : String(v);
    if (s.includes(',') || s.includes('"') || s.includes('\n')) {
      return '"' + s.replace(/"/g, '""') + '"';
    }
    return s;
  };
  return [headers.join(',')].concat(rows.map(r => r.map(esc).join(','))).join('\n');
};

exports.exportStudentsCsv = async (req, res, next) => {
  try {
    const students = await Student.find().populate('batch', 'name').limit(5000);
    const headers = ['Student ID', 'Name', 'Mobile', 'Course', 'Batch', 'Status', 'Total Fee', 'Paid Fee'];
    const rows = students.map(s => [
      s.studentId, s.fullName, s.mobile, s.course,
      s.batch?.name || '', s.status, s.totalFee || 0, s.paidFee || 0
    ]);
    const csv = toCsv(headers, rows);
    res.setHeader('Content-Type', 'text/csv');
    res.setHeader('Content-Disposition', 'attachment; filename=students.csv');
    res.send(csv);
  } catch (e) { next(e); }
};

exports.exportAttendanceCsv = async (req, res, next) => {
  try {
    const { from, to } = req.query;
    const q = {};
    if (from || to) {
      q.date = {};
      if (from) q.date.$gte = from;
      if (to) q.date.$lte = to;
    }
    const records = await Attendance.find(q).populate('student', 'fullName studentId').limit(10000);
    const headers = ['Date', 'Student ID', 'Name', 'Status', 'Entry', 'Exit'];
    const rows = records.map(r => [
      r.date, r.studentId, r.student?.fullName || '', r.status,
      r.entryTime ? new Date(r.entryTime).toISOString() : '',
      r.exitTime ? new Date(r.exitTime).toISOString() : ''
    ]);
    const csv = toCsv(headers, rows);
    res.setHeader('Content-Type', 'text/csv');
    res.setHeader('Content-Disposition', 'attachment; filename=attendance.csv');
    res.send(csv);
  } catch (e) { next(e); }
};

exports.exportFeesCsv = async (req, res, next) => {
  try {
    const fees = await Fee.find().populate('student', 'fullName studentId mobile').limit(5000);
    const headers = ['Student ID', 'Name', 'Mobile', 'Total', 'Paid', 'Pending', 'Status'];
    const rows = fees.map(f => [
      f.studentId, f.student?.fullName || '', f.student?.mobile || '',
      f.totalFee, f.paidAmount, f.pendingAmount, f.status
    ]);
    const csv = toCsv(headers, rows);
    res.setHeader('Content-Type', 'text/csv');
    res.setHeader('Content-Disposition', 'attachment; filename=fees.csv');
    res.send(csv);
  } catch (e) { next(e); }
};
