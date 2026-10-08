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

test('approval finds the same Indian phone despite legacy separators and country-code formats', () => {
  const { flexiblePhoneRegex } = require('../src/controllers/applications');
  const pattern = flexiblePhoneRegex('8651142739');
  for (const value of ['8651142739', '+91 8651142739', '91-86511-42739', '0091 86511 42739', '08651142739']) {
    assert.match(value, pattern);
  }
  assert.doesNotMatch('8651142738', pattern);
  assert.equal(flexiblePhoneRegex('12345'), null);
});

test('duplicate-key errors identify the conflicting field without exposing its value', () => {
  const { errorHandler } = require('../src/middleware/errors');
  const previousWarn = console.warn;
  const warnings = [];
  console.warn = (...args) => warnings.push(args.join(' '));
  let status;
  let body;
  const response = {
    status(code) { status = code; return this; },
    json(payload) { body = payload; return this; },
  };
  try {
    errorHandler({
      code: 11000,
      keyPattern: { studentId: 1 },
      keyValue: { studentId: 'MSDA998877' },
      collection: { collectionName: 'studentprofiles' },
    }, { originalUrl: '/api/admin/applications/test/review' }, response, () => {});
  } finally {
    console.warn = previousWarn;
  }
  assert.equal(status, 409);
  assert.equal(body.error.message, 'A record with this student ID already exists');
  assert.doesNotMatch(JSON.stringify(body), /MSDA998877/);
  assert.doesNotMatch(warnings.join(' '), /MSDA998877/);
  assert.match(warnings.join(' '), /studentId/);
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

test('physical training result endpoints require authentication and writes require admin', async () => {
  const list = await request(app).get('/api/physical-training-results');
  const create = await request(app).post('/api/physical-training-results').send({});
  assert.equal(list.status, 401);
  assert.equal(create.status, 401);
});

test('physical training result schema stores batch, individual metrics, date and recorder', () => {
  const PhysicalTrainingResult = require('../src/models/PhysicalTrainingResult');
  for (const field of ['studentId', 'batchId', 'testDate', 'runTimeSeconds', 'beamReps', 'longJumpCm', 'highJumpCm', 'pushUps', 'sitUps', 'shuttleRunSeconds', 'recordedBy']) {
    assert.ok(PhysicalTrainingResult.schema.path(field), `missing ${field}`);
  }
});

test('batch physical marks sheets are authenticated and write operations are admin-only', async () => {
  const list = await request(app).get('/api/physical-training-sheets');
  const create = await request(app).post('/api/physical-training-sheets').send({});
  const save = await request(app).patch('/api/physical-training-sheets/507f1f77bcf86cd799439011/rows').send({ rows: [] });
  const remove = await request(app).delete('/api/physical-training-sheets/507f1f77bcf86cd799439011');
  assert.equal(list.status, 401);
  assert.equal(create.status, 401);
  assert.equal(save.status, 401);
  assert.equal(remove.status, 401);
});

test('deleting a batch marks sheet removes only the selected shared sheet', async () => {
  const PhysicalTrainingSheet = require('../src/models/PhysicalTrainingSheet');
  const controller = require('../src/controllers/physical-training-sheets');
  const id = '507f1f77bcf86cd799439011';
  const previousDelete = PhysicalTrainingSheet.findByIdAndDelete;
  let deletedId;
  PhysicalTrainingSheet.findByIdAndDelete = async value => {
    deletedId = String(value);
    return { _id: value, title: 'Army physical test' };
  };
  const response = {
    statusCode: 200,
    status(code) { this.statusCode = code; return this; },
    json(payload) { this.body = payload; return this; },
  };
  try {
    await controller.deleteSheet({ params: { id } }, response);
    assert.equal(deletedId, id);
    assert.equal(response.statusCode, 200);
    assert.deepEqual(response.body.data, {
      deleted: true, id, title: 'Army physical test',
    });
  } finally {
    PhysicalTrainingSheet.findByIdAndDelete = previousDelete;
  }
});

test('batch physical sheet schema stores enabled columns and one student row with total marks', () => {
  const PhysicalTrainingSheet = require('../src/models/PhysicalTrainingSheet');
  for (const field of ['batchId', 'title', 'template', 'testDate', 'columns', 'rows', 'createdBy']) {
    assert.ok(PhysicalTrainingSheet.schema.path(field), `missing ${field}`);
  }
});

test('batch sheet has distance/time measurements and one overall Total Marks field', () => {
  const { createSheetColumns, normalizeRowValues } = require('../src/controllers/physical-training-sheets');
  const columns = createSheetColumns([
    { key: 'run_distance_km', label: 'दौड़ दूरी (KM)', type: 'measurement' },
    { key: 'run_time', label: 'दौड़ का समय', type: 'measurement' },
    { key: 'ditch', label: '9 feet ditch', type: 'passfail' },
  ]);
  assert.deepEqual(columns.at(-1), { key: 'total_marks', label: 'Total Marks', type: 'marks' });
  const row = normalizeRowValues(columns, {
    run_distance_km: '1.6', run_time: '5:30', ditch: '✓', total_marks: '72',
  });
  assert.deepEqual(row.values, {
    run_distance_km: '1.6', run_time: '5:30', ditch: 'pass', total_marks: 72,
  });
  assert.equal(row.totalMarks, 72);
  assert.throws(() => createSheetColumns([
    { key: 'run', label: 'Run', type: 'measurement' },
    { key: 'run_marks', label: 'Run Marks', type: 'marks' },
  ]), /Event marks are not separate/);
  assert.throws(() => normalizeRowValues(columns, { total_marks: '-1' }), /0 to 1000/);
  assert.throws(() => normalizeRowValues(columns, { ditch: 'maybe' }), /Pass or Fail/);
});

test('practice unlocks 24 hours after the first official result and official attempt deadline respects schedule duration', () => {
  const { retryAvailableAt, deadlineFor, RETAKE_DELAY_MS } = require('../src/services/exams');
  const submittedAt = new Date('2026-10-08T10:00:00.000Z');
  assert.equal(retryAvailableAt({ submittedAt }).toISOString(), '2026-10-09T10:00:00.000Z');
  assert.equal(RETAKE_DELAY_MS, 24 * 60 * 60 * 1000);
  const test = { duration: 10, endTime: new Date('2026-10-08T10:10:00.000Z') };
  const first = { attemptNumber: 1, startedAt: new Date('2026-10-08T10:08:00.000Z') };
  assert.equal(deadlineFor(test, first).toISOString(), '2026-10-08T10:10:00.000Z');
});

test('practice scoring returns a score without creating a persisted test attempt', async () => {
  const exams = require('../src/services/exams');
  const Test = require('../src/models/Test');
  const Question = require('../src/models/Question');
  const TestAttempt = require('../src/models/TestAttempt');
  const jwt = require('jsonwebtoken');
  const testId = '507f1f77bcf86cd799439011';
  const studentId = '507f1f77bcf86cd799439012';
  const questionId = '507f1f77bcf86cd799439013';
  const now = new Date();
  const deadlineAt = new Date(now.getTime() + 60_000);
  const token = jwt.sign({ mode: 'practice', testId, studentId, startedAt: now.getTime(), deadlineAt: deadlineAt.getTime() }, process.env.JWT_SECRET, { expiresIn: 300 });
  const previousTestFindOne = Test.findOne;
  const previousQuestionFind = Question.find;
  const previousAttemptCreate = TestAttempt.create;
  let persisted = false;
  Test.findOne = async () => ({ duration: 10 });
  Question.find = () => ({ select: async () => [{ _id: questionId, correctAnswer: 2, marks: 5 }] });
  TestAttempt.create = async () => { persisted = true; throw new Error('practice must not persist'); };
  try {
    const result = await exams.submitPractice(testId, studentId, token, [{ questionId, selected: 2 }], now);
    assert.equal(result.isPractice, true);
    assert.equal(result.notSaved, true);
    assert.equal(result.obtainedMarks, 5);
    assert.equal(persisted, false);
  } finally {
    Test.findOne = previousTestFindOne;
    Question.find = previousQuestionFind;
    TestAttempt.create = previousAttemptCreate;
  }
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
  const practiceStart = await request(app).post(`/api/tests/${id}/practice/start`).send({});
  const practiceSubmit = await request(app).post(`/api/tests/${id}/practice/submit`).send({ practiceToken: 'bad', answers: [] });
  const results = await request(app).get('/api/tests/results');
  for (const response of [edit, bulk, save, practiceStart, practiceSubmit, results]) {
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
  assert.equal(matchesImageSignature(Buffer.from([137, 80, 78, 71, 13, 10, 26, 10, 0, 0, 0, 0])), true);
  assert.equal(matchesImageSignature(Buffer.from('RIFF0000WEBP')), true);
  assert.equal(matchesImageSignature(Buffer.from('not-an-image-file')), false);
});

test('branding uploader accepts supported image bytes independent of reported MIME type', async () => {
  const express = require('express');
  const { uploadBrandAsset } = require('../src/middleware/brandUpload');
  const probe = express();
  probe.post('/asset', uploadBrandAsset, (_req, res) => res.sendStatus(204));
  probe.use((error, _req, res, _next) => res.status(error.status || 500).json({ error: error.message }));
  const jpeg = await request(probe).post('/asset').attach(
    'file', Buffer.from([0xff, 0xd8, 0xff, 0, 0, 0, 0, 0, 0, 0, 0, 0]),
    { filename: 'logo.jpeg', contentType: 'application/octet-stream' },
  );
  const png = await request(probe).post('/asset').attach(
    'file', Buffer.from([137, 80, 78, 71, 13, 10, 26, 10, 0, 0, 0, 0]),
    { filename: 'hero.png', contentType: 'application/octet-stream' },
  );
  const invalid = await request(probe).post('/asset').attach(
    'file', Buffer.from('not an image'), { filename: 'logo.jpeg', contentType: 'image/jpeg' },
  );
  assert.equal(jpeg.status, 204);
  assert.equal(png.status, 204);
  assert.equal(invalid.status, 415);
});

test('published tests can be moved to a new date until a student attempt exists', () => {
  const { canEditTestSchedule } = require('../src/services/test-scheduling');
  assert.equal(canEditTestSchedule({ status: 'draft', hasAttempts: false }), true);
  assert.equal(canEditTestSchedule({ status: 'published', hasAttempts: false }), true);
  assert.equal(canEditTestSchedule({ status: 'published', hasAttempts: true }), false);
  assert.equal(canEditTestSchedule({ status: 'closed', hasAttempts: false }), false);
});

test('password change requires a valid authenticated session', async () => {
  const response = await request(app).post('/api/auth/change-password').send({ newPassword: 'a-secure-test-password' });
  assert.equal(response.status, 401);
  assert.equal(response.body.ok, false);
});
