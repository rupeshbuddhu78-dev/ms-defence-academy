const Notification = require('../models/Notification');

exports.createNotification = async ({ userId, title, message, type = 'SYSTEM', data, deepLink }) => {
  try {
    return await Notification.create({
      user: userId,
      title,
      message,
      type,
      data,
      deepLink
    });
  } catch (e) {
    console.error('notify error', e.message);
    return null;
  }
};

exports.notifyMany = async (userIds, payload) => {
  const docs = userIds.map(uid => ({
    user: uid,
    title: payload.title,
    message: payload.message,
    type: payload.type || 'SYSTEM',
    data: payload.data,
    deepLink: payload.deepLink
  }));
  if (docs.length) await Notification.insertMany(docs);
};
