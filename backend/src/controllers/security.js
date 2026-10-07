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
  let response;
  try {
    response = await fetch(endpoint, {
      method: 'POST',
      headers: { 'content-type': 'application/json' },
      body: JSON.stringify({
        action: 'send_otp',
        to: email,
        name: name || 'Academy user',
        otp,
        expiresInMinutes: 10,
        secret: String(process.env.GOOGLE_OTP_SCRIPT_SECRET || '').trim(),
      }),
      signal: AbortSignal.timeout(15000),
    });
  } catch (_) {
    throw new HttpError(502, 'OTP email service could not be reached');
  }
  const body = await response.text();
  if (!response.ok) throw new HttpError(502, 'OTP email service rejected the request');
  try {
    const parsed = JSON.parse(body);
    if (parsed.ok === false) throw new Error('OTP service returned an error');
  } catch (_) {
    // Apps Script may return a text response; HTTP 2xx is still accepted.
  }
}

module.exports = { listLogs, record, cleanEmail, sendOtpEmail };
