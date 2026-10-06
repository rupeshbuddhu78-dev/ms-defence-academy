const jwt = require('jsonwebtoken');
const User = require('../models/User');
const { HttpError, asyncHandler } = require('./errors');
const authenticate = asyncHandler(async (req, _res, next) => {
  const header = req.get('authorization') || '';
  if (!header.startsWith('Bearer ')) throw new HttpError(401, 'Authentication required');
  let payload;
  try { payload = jwt.verify(header.slice(7), process.env.JWT_SECRET); } catch { throw new HttpError(401, 'Invalid or expired session'); }
  const user = await User.findById(payload.sub).select('-passwordHash');
  if (!user || !user.isActive) throw new HttpError(401, 'Account is unavailable');
  req.user = user;
  next();
});
const allowRoles = (...roles) => (req, _res, next) => roles.includes(req.user?.role) ? next() : next(new HttpError(403, 'You do not have permission for this action'));
module.exports = { authenticate, allowRoles };
