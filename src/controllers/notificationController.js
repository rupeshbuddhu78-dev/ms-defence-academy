const Notification = require('../models/Notification');

exports.myNotifications = async (req, res, next) => {
  try {
    const page = Math.max(1, parseInt(req.query.page) || 1);
    const limit = Math.min(50, parseInt(req.query.limit) || 20);
    const [items, total, unread] = await Promise.all([
      Notification.find({ user: req.user._id }).sort({ createdAt: -1 }).skip((page - 1) * limit).limit(limit),
      Notification.countDocuments({ user: req.user._id }),
      Notification.countDocuments({ user: req.user._id, read: false })
    ]);
    res.json({
      success: true,
      data: { notifications: items, unread, pagination: { page, limit, total, pages: Math.ceil(total / limit) } }
    });
  } catch (e) { next(e); }
};

exports.markRead = async (req, res, next) => {
  try {
    await Notification.updateOne({ _id: req.params.id, user: req.user._id }, { read: true });
    res.json({ success: true, message: 'Marked read' });
  } catch (e) { next(e); }
};

exports.markAllRead = async (req, res, next) => {
  try {
    await Notification.updateMany({ user: req.user._id, read: false }, { read: true });
    res.json({ success: true, message: 'All marked read' });
  } catch (e) { next(e); }
};
