const mongoose = require('mongoose');
const Attendance = require('../models/Attendance');
const { HttpError } = require('../middleware/errors');

async function calendar(req, res) {
  const from = new Date(req.query.from || '');
  const to = new Date(req.query.to || '');
  if (Number.isNaN(from.getTime()) || Number.isNaN(to.getTime()) || to <= from) {
    throw new HttpError(400, 'A valid calendar date range is required');
  }
  if (to - from > 62 * 24 * 60 * 60 * 1000) {
    throw new HttpError(400, 'Calendar range cannot exceed 62 days');
  }
  const match = { date: { $gte: from, $lt: to } };
  if (req.query.batchId) {
    if (!mongoose.isValidObjectId(req.query.batchId)) throw new HttpError(400, 'Batch ID is invalid');
    match.batchId = new mongoose.Types.ObjectId(req.query.batchId);
  }
  const grouped = await Attendance.aggregate([
    { $match: match },
    {
      $group: {
        _id: { $dateToString: { format: '%Y-%m-%d', date: '$date', timezone: 'UTC' } },
        total: { $sum: 1 },
        present: { $sum: { $cond: [{ $eq: ['$status', 'present'] }, 1, 0] } },
        absent: { $sum: { $cond: [{ $eq: ['$status', 'absent'] }, 1, 0] } },
      },
    },
    { $sort: { _id: 1 } },
  ]);
  const summary = grouped.reduce((totals, day) => ({
    total: totals.total + day.total,
    present: totals.present + day.present,
    absent: totals.absent + day.absent,
  }), { total: 0, present: 0, absent: 0 });
  summary.percentage = summary.total ? Math.round(summary.present / summary.total * 10000) / 100 : 0;
  res.json({ ok: true, data: { days: grouped.map(day => ({ date: day._id, total: day.total, present: day.present, absent: day.absent })), summary } });
}

module.exports = { calendar };
