const cloudinary = require('cloudinary').v2;
const { HttpError } = require('../middleware/errors');

function isConfigured() {
  return Boolean(
    process.env.CLOUDINARY_CLOUD_NAME &&
      process.env.CLOUDINARY_API_KEY &&
      process.env.CLOUDINARY_API_SECRET,
  );
}

function configure() {
  if (!isConfigured()) {
    throw new HttpError(503, 'Profile-photo storage is not configured');
  }
  cloudinary.config({
    cloud_name: process.env.CLOUDINARY_CLOUD_NAME,
    api_key: process.env.CLOUDINARY_API_KEY,
    api_secret: process.env.CLOUDINARY_API_SECRET,
    secure: true,
  });
}

function safeProviderFailure(error) {
  let reason = String(error?.message || error?.error?.message || 'Provider returned no error details');
  for (const secret of [
    process.env.CLOUDINARY_API_SECRET,
    process.env.CLOUDINARY_API_KEY,
    process.env.CLOUDINARY_CLOUD_NAME,
  ].filter(Boolean)) {
    reason = reason.split(secret).join('[redacted]');
  }
  reason = reason
    .replace(/(api[_ -]?secret|api[_ -]?key|authorization|signature)\s*[:=]\s*[^\s,;]+/gi, '$1=[redacted]')
    .replace(/\b[a-f0-9]{32,}\b/gi, '[redacted]')
    .replace(/[\r\n\t]+/g, ' ')
    .slice(0, 180);
  const code = error?.http_code ?? error?.statusCode ?? error?.error?.http_code ?? error?.error?.code;
  return { code: code == null ? null : String(code).slice(0, 24), reason };
}

async function uploadImage(buffer, folder = 'ms-defence-academy/students') {
  configure();
  return new Promise((resolve, reject) => {
    const stream = cloudinary.uploader.upload_stream(
      {
        folder,
        resource_type: 'image',
        allowed_formats: ['jpg', 'jpeg', 'png', 'webp'],
        transformation: [
          { width: 1280, height: 1280, crop: 'limit', quality: 'auto', fetch_format: 'auto' },
        ],
      },
      (error, result) => {
        if (error || !result?.secure_url || !result?.public_id) {
          const diagnostic = safeProviderFailure(
            error || new Error('Provider returned an incomplete upload result'),
          );
          console.error('[cloudinary-upload-error]', JSON.stringify(diagnostic));
          return reject(new HttpError(502, 'Cloud image upload failed', diagnostic));
        }
        resolve({ url: result.secure_url, publicId: result.public_id });
      },
    );
    stream.end(buffer);
  });
}

async function deleteImage(publicId) {
  if (!publicId || !isConfigured()) return;
  configure();
  try {
    await cloudinary.uploader.destroy(publicId, { resource_type: 'image', invalidate: true });
  } catch (_) {
    // A failed cleanup must not expose Cloudinary details or overwrite the primary API result.
  }
}

module.exports = { isConfigured, uploadImage, deleteImage, safeProviderFailure };
