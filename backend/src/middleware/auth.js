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
  const path = req.originalUrl.split('?')[0];
  const passwordFlow = path.endsWith('/auth/me') || path.endsWith('/auth/change-password');
  if (user.mustChangePassword && !passwordFlow) {
    throw new HttpError(403, 'Change your temporary password before using the app');
  }
  req.user = user;
  next();
});
const allowRoles = (...roles) => (req, _res, next) => roles.includes(req.user?.role) ? next() : next(new HttpError(403, 'You do not have permission for this action'));
module.exports = { authenticate, allowRoles };
