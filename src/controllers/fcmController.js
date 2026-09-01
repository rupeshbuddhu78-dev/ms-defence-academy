const User = require('../models/User');

exports.registerToken = async (req, res, next) => {
  try {
    const { token, device } = req.body;
    if (!token) {
      return res.status(400).json({ success: false, message: 'Token required' });
    }
    const user = await User.findById(req.user._id);
    if (!user) return res.status(404).json({ success: false, message: 'User not found' });

    user.fcmTokens = (user.fcmTokens || []).filter(t => t.token !== token);
    user.fcmTokens.push({ token, device: device || 'android', createdAt: new Date() });
    // keep last 5
    if (user.fcmTokens.length > 5) user.fcmTokens = user.fcmTokens.slice(-5);
    await user.save();

    res.json({ success: true, message: 'FCM token registered' });
  } catch (e) { next(e); }
};

exports.removeToken = async (req, res, next) => {
  try {
    const { token } = req.body;
    await User.updateOne(
      { _id: req.user._id },
      { $pull: { fcmTokens: { token } } }
    );
    res.json({ success: true, message: 'Token removed' });
  } catch (e) { next(e); }
};
