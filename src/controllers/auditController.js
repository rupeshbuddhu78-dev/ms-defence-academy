const AuditLog = require('../models/AuditLog');

exports.list = async (req, res, next) => {
  try {
    const page = Math.max(1, parseInt(req.query.page) || 1);
    const limit = Math.min(100, parseInt(req.query.limit) || 30);
    const filter = {};
    if (req.query.action) filter.action = req.query.action;
    if (req.query.entityType) filter.entityType = req.query.entityType;
    const [logs, total] = await Promise.all([
      AuditLog.find(filter).sort({ createdAt: -1 }).skip((page - 1) * limit).limit(limit)
        .populate('admin', 'fullName email'),
      AuditLog.countDocuments(filter)
    ]);
    res.json({
      success: true,
      data: { logs, pagination: { page, limit, total, pages: Math.ceil(total / limit) } }
    });
  } catch (e) { next(e); }
};
