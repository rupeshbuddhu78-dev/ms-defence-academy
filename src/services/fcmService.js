/**
 * FCM push via firebase-admin.
 * Configure with either:
 *  - GOOGLE_APPLICATION_CREDENTIALS path to service account JSON
 *  - or FCM_PROJECT_ID + FCM_CLIENT_EMAIL + FCM_PRIVATE_KEY env vars
 * If not configured, send is a no-op (never fails business logic).
 */
let admin = null;
let initTried = false;
let initOk = false;

function initFirebase() {
  if (initTried) return initOk;
  initTried = true;
  try {
    admin = require('firebase-admin');
    if (admin.apps.length) {
      initOk = true;
      return true;
    }
    if (process.env.GOOGLE_APPLICATION_CREDENTIALS) {
      admin.initializeApp({ credential: admin.credential.applicationDefault() });
      initOk = true;
      console.log('FCM: initialized via GOOGLE_APPLICATION_CREDENTIALS');
      return true;
    }
    if (process.env.FCM_PROJECT_ID && process.env.FCM_CLIENT_EMAIL && process.env.FCM_PRIVATE_KEY) {
      const privateKey = process.env.FCM_PRIVATE_KEY.replace(/\\n/g, '\n');
      admin.initializeApp({
        credential: admin.credential.cert({
          projectId: process.env.FCM_PROJECT_ID,
          clientEmail: process.env.FCM_CLIENT_EMAIL,
          privateKey
        })
      });
      initOk = true;
      console.log('FCM: initialized via env service account fields');
      return true;
    }
    console.log('FCM: not configured — push disabled (in-app notifications still work)');
    return false;
  } catch (e) {
    console.error('FCM init error:', e.message);
    return false;
  }
}

const User = require('../models/User');

async function sendPushToUser(userId, { title, body, data = {} }) {
  try {
    if (!initFirebase()) return { sent: 0, skipped: true };
    const user = await User.findById(userId).select('fcmTokens');
    if (!user || !user.fcmTokens || !user.fcmTokens.length) {
      return { sent: 0, noTokens: true };
    }
    const tokens = user.fcmTokens.map(t => t.token).filter(Boolean);
    if (!tokens.length) return { sent: 0, noTokens: true };

    const message = {
      notification: { title, body },
      data: Object.fromEntries(
        Object.entries({ ...data, title, body }).map(([k, v]) => [k, String(v == null ? '' : v)])
      ),
      tokens
    };

    const response = await admin.messaging().sendEachForMulticast(message);
    // cleanup invalid tokens
    const invalid = [];
    response.responses.forEach((r, i) => {
      if (!r.success) {
        const code = r.error && r.error.code;
        if (code === 'messaging/registration-token-not-registered'
          || code === 'messaging/invalid-registration-token') {
          invalid.push(tokens[i]);
        }
      }
    });
    if (invalid.length) {
      await User.updateOne(
        { _id: userId },
        { $pull: { fcmTokens: { token: { $in: invalid } } } }
      );
    }
    return { sent: response.successCount, failed: response.failureCount };
  } catch (e) {
    console.error('FCM send error:', e.message);
    return { sent: 0, error: e.message };
  }
}

async function notifyUser(userId, { title, message, type = 'SYSTEM', data, deepLink }) {
  const { createNotification } = require('../utils/notify');
  try {
    await createNotification({ userId, title, message, type, data, deepLink });
  } catch (e) {
    console.error('in-app notify fail', e.message);
  }
  // never await failure to block
  sendPushToUser(userId, {
    title,
    body: message,
    data: { type, screen: deepLink || type, ...(data || {}) }
  }).catch(() => {});
}

module.exports = { sendPushToUser, notifyUser, initFirebase };
