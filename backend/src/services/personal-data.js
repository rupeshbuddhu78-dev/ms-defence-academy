const crypto = require('crypto');
const { HttpError } = require('../middleware/errors');

function encryptionKey() {
  const value = String(process.env.AADHAAR_ENCRYPTION_KEY || '').trim();
  if (!/^[a-f0-9]{64}$/i.test(value)) {
    throw new HttpError(503, 'Secure ID storage is not configured on the server');
  }
  return Buffer.from(value, 'hex');
}

function normalizeAadhaar(value) {
  return String(value || '').replace(/\D/g, '');
}

function encryptAadhaar(value) {
  const normalized = normalizeAadhaar(value);
  if (!normalized) return '';
  const key = encryptionKey();
  const iv = crypto.randomBytes(12);
  const cipher = crypto.createCipheriv('aes-256-gcm', key, iv);
  const ciphertext = Buffer.concat([cipher.update(normalized, 'utf8'), cipher.final()]);
  const tag = cipher.getAuthTag();
  return `v1:${iv.toString('base64url')}:${tag.toString('base64url')}:${ciphertext.toString('base64url')}`;
}

function decryptAadhaar(payload) {
  if (!payload) return '';
  const [version, ivPart, tagPart, dataPart] = String(payload).split(':');
  if (version !== 'v1' || !ivPart || !tagPart || !dataPart) {
    throw new HttpError(500, 'Stored secure ID data could not be read');
  }
  try {
    const decipher = crypto.createDecipheriv('aes-256-gcm', encryptionKey(), Buffer.from(ivPart, 'base64url'));
    decipher.setAuthTag(Buffer.from(tagPart, 'base64url'));
    return Buffer.concat([
      decipher.update(Buffer.from(dataPart, 'base64url')),
      decipher.final(),
    ]).toString('utf8');
  } catch (error) {
    if (error instanceof HttpError) throw error;
    throw new HttpError(500, 'Stored secure ID data could not be read');
  }
}

module.exports = { encryptAadhaar, decryptAadhaar, normalizeAadhaar };
