const SecurityLog = require('../models/SecurityLog');
const { HttpError } = require('../middleware/errors');

async function listLogs(req, res) {
  const limit = Math.min(Math.max(Number(req.query.limit) || 100, 1), 500);
  const logs = await SecurityLog.find()
    .populate('userId', 'name email phone role')
    .sort({ createdAt: -1 })
    .limit(limit);
  res.json({ ok: true, data: logs });
}

async function record(req, event, extra = {}) {
  try {
    await SecurityLog.create({
      ...extra,
      userId: extra.userId || null,
      event,
      ip: req.ip || req.socket?.remoteAddress || '',
      userAgent: String(req.get('user-agent') || '').slice(0, 500),
    });
  } catch (_) {
    // Audit logging must never make login or password reset unavailable.
  }
}

function cleanEmail(value) {
  return String(value || '').trim().toLowerCase();
}

async function sendOtpEmail({ email, name, otp }) {
  const endpoint = String(process.env.GOOGLE_OTP_SCRIPT_URL || '').trim();
  if (!endpoint) throw new HttpError(503, 'Password reset is not configured on the server');
  if (!/^https:\/\/script\.google\.com\/macros\/s\/[^/]+\/exec(?:\?.*)?$/.test(endpoint)) {
    throw new HttpError(503, 'OTP email service URL is invalid; use the Google Apps Script /exec URL');
  }
  const request = {
    action: 'send_otp', to: email, name: name || 'Academy user', otp,
    expiresInMinutes: 10,
    secret: String(process.env.GOOGLE_OTP_SCRIPT_SECRET || '').trim(),
  };
  let lastError;
  for (let attempt = 0; attempt < 3; attempt += 1) {
    try {
      const response = await fetch(endpoint, {
        method: 'POST', redirect: 'follow',
        headers: { 'content-type': 'application/json' },
        body: JSON.stringify(request), signal: AbortSignal.timeout(20000),
      });
      const body = await response.text();
      if (!response.ok) throw new Error(`HTTP ${response.status}`);
      let parsed;
      try { parsed = JSON.parse(body); } catch (_) { parsed = null; }
      if (parsed && parsed.ok === false) throw new Error(parsed.error || 'Google Apps Script rejected the request');
      return;
    } catch (error) {
      lastError = error;
      if (attempt < 2) await new Promise(resolve => setTimeout(resolve, 800 * (attempt + 1)));
    }
  }
  console.error('[otp-email-service-error]', lastError?.message || 'unknown error');
  throw new HttpError(502, 'OTP email service could not be reached. Check the Render Google OTP URL and Apps Script deployment.');
}

module.exports = { listLogs, record, cleanEmail, sendOtpEmail };
