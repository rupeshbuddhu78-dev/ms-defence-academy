const test = require('node:test');
const assert = require('node:assert/strict');
const request = require('supertest');
process.env.JWT_SECRET = 'test-secret-that-is-at-least-32-characters-long';
const app = require('../src/app');

test('trusts the single reverse proxy used by Render', () => {
  assert.equal(app.get('trust proxy'), 1);
});

test('Aadhaar service encrypts data at rest and supports authenticated decryption', () => {
  const previous = process.env.AADHAAR_ENCRYPTION_KEY;
  process.env.AADHAAR_ENCRYPTION_KEY = '8'.repeat(64);
  const { encryptAadhaar, decryptAadhaar } = require('../src/services/personal-data');
  const aadhaar = '123456789012';
  const ciphertext = encryptAadhaar(aadhaar);
  assert.ok(ciphertext.startsWith('v1:'));
  assert.notEqual(ciphertext, aadhaar);
  assert.equal(decryptAadhaar(ciphertext), aadhaar);
  if (previous === undefined) delete process.env.AADHAAR_ENCRYPTION_KEY;
  else process.env.AADHAAR_ENCRYPTION_KEY = previous;
});

test('service root provides API information', async () => {
  const response = await request(app).get('/');
  assert.equal(response.status, 200);
  assert.equal(response.body.ok, true);
  assert.equal(response.body.health, '/health');
});

test('API root provides endpoint information', async () => {
  const response = await request(app).get('/api');
  assert.equal(response.status, 200);
  assert.equal(response.body.ok, true);
  assert.equal(response.body.endpoints.login, 'POST /api/auth/login');
});

test('health endpoint responds without database access', async () => {
  const response = await request(app).get('/health');
  assert.equal(response.status, 200);
  assert.equal(response.body.ok, true);
});

test('unknown routes use a consistent JSON 404', async () => {
  const response = await request(app).get('/api/not-a-route');
  assert.equal(response.status, 404);
  assert.equal(response.body.ok, false);
  assert.ok(response.body.error.message);
});

test('login rejects an empty payload', async () => {
  const response = await request(app).post('/api/auth/login').send({});
  assert.equal(response.status, 400);
  assert.equal(response.body.ok, false);
});

test('protected APIs reject requests without a bearer token', async () => {
  const response = await request(app).get('/api/students/profile');
  assert.equal(response.status, 401);
  assert.equal(response.body.ok, false);
});

test('student onboarding endpoint is admin-authenticated', async () => {
  const response = await request(app).post('/api/students').field('name', 'Test Student');
  assert.equal(response.status, 401);
  assert.equal(response.body.ok, false);
});

test('student application review remains admin-authenticated', async () => {
  const id = '507f1f77bcf86cd799439011';
  const response = await request(app).post(`/api/admin/applications/${id}/review`).send({ action: 'approve' });
  assert.equal(response.status, 401);
  assert.equal(response.body.ok, false);
});

test('student applications support a recoverable approval claim state', () => {
  const StudentApplication = require('../src/models/StudentApplication');
  assert.deepEqual(StudentApplication.schema.path('status').enumValues, ['pending', 'approving', 'approved', 'rejected']);
});

test('exam authoring endpoint rejects unauthenticated callers', async () => {
  const response = await request(app).post('/api/tests').send({ title: 'Unauthorized test' });
  assert.equal(response.status, 401);
  assert.equal(response.body.ok, false);
});

test('notice publishing endpoint rejects unauthenticated callers', async () => {
  const response = await request(app).post('/api/notices').send({ title: 'Unauthorized notice' });
  assert.equal(response.status, 401);
  assert.equal(response.body.ok, false);
});

test('student hard-delete endpoint rejects unauthenticated callers', async () => {
  const response = await request(app).delete('/api/students/507f1f77bcf86cd799439011');
  assert.equal(response.status, 401);
  assert.equal(response.body.ok, false);
});

test('student password reset endpoint rejects unauthenticated callers', async () => {
  const response = await request(app)
    .patch('/api/students/507f1f77bcf86cd799439011/password')
    .send({ temporaryPassword: 'temporary-pass-2026' });
  assert.equal(response.status, 401);
  assert.equal(response.body.ok, false);
});

test('test deletion endpoint rejects unauthenticated callers', async () => {
  const response = await request(app).delete('/api/tests/507f1f77bcf86cd799439011');
  assert.equal(response.status, 401);
  assert.equal(response.body.ok, false);
});

test('admin fee and batch update endpoints reject unauthenticated callers', async () => {
  const fee = await request(app).patch('/api/fees/507f1f77bcf86cd799439011').send({ totalFees: 100 });
  assert.equal(fee.status, 401);
  const batch = await request(app).patch('/api/batches/507f1f77bcf86cd799439011').send({ name: 'Updated batch' });
  assert.equal(batch.status, 401);
  const removeBatch = await request(app).delete('/api/batches/507f1f77bcf86cd799439011');
  assert.equal(removeBatch.status, 401);
});

test('fee delete endpoint rejects unauthenticated callers', async () => {
  const response = await request(app).delete('/api/fees/507f1f77bcf86cd799439011');
  assert.equal(response.status, 401);
  assert.equal(response.body.ok, false);
});

test('exam edit, bulk-question, answer-save and result endpoints require authentication', async () => {
  const id = '507f1f77bcf86cd799439011';
  const edit = await request(app).patch(`/api/tests/${id}`).send({ title: 'Edited' });
  const bulk = await request(app).patch(`/api/tests/${id}/questions/bulk`).send({ questions: [] });
  const save = await request(app).patch(`/api/tests/${id}/answers`).send({ answers: [] });
  const results = await request(app).get('/api/tests/results');
  for (const response of [edit, bulk, save, results]) {
    assert.equal(response.status, 401);
    assert.equal(response.body.ok, false);
  }
});

test('training edit and delete endpoints reject unauthenticated callers', async () => {
  const update = await request(app).patch('/api/training/507f1f77bcf86cd799439011').send({ title: 'Updated training' });
  assert.equal(update.status, 401);
  const remove = await request(app).delete('/api/training/507f1f77bcf86cd799439011');
  assert.equal(remove.status, 401);
});

test('photo uploader recognizes a JPEG file signature independent of the filename', () => {
  const { matchesImageSignature } = require('../src/middleware/photoUpload');
  assert.equal(matchesImageSignature(Buffer.from([0xff, 0xd8, 0xff, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00])), true);
  assert.equal(matchesImageSignature(Buffer.from('not-an-image-file')), false);
});

test('password change requires a valid authenticated session', async () => {
  const response = await request(app).post('/api/auth/change-password').send({ newPassword: 'a-secure-test-password' });
  assert.equal(response.status, 401);
  assert.equal(response.body.ok, false);
});
