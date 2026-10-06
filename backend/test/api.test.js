const test = require('node:test');
const assert = require('node:assert/strict');
const request = require('supertest');
process.env.JWT_SECRET = 'test-secret-that-is-at-least-32-characters-long';
const app = require('../src/app');

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
