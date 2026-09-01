const AuditLog = require('../models/AuditLog');

const logAudit = async ({
  adminId,
  action,
  entityType,
  entityId,
  oldValue,
  newValue,
  reason,
  req
}) => {
  try {
    await AuditLog.create({
      adminId,
      action,
      entityType,
      entityId: entityId ? String(entityId) : undefined,
      oldValue,
      newValue,
      reason,
      ip: req ? (req.headers['x-forwarded-for'] || req.connection?.remoteAddress) : undefined,
      userAgent: req ? req.headers['user-agent'] : undefined
    });
  } catch (err) {
    console.error('Audit log failed:', err.message);
  }
};

module.exports = { logAudit };
