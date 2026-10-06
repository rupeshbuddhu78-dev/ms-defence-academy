const test=require('node:test');
const assert=require('node:assert/strict');
const request=require('supertest');
process.env.JWT_SECRET='test-secret-that-is-at-least-32-characters-long';
const app=require('../src/app');

test('health endpoint responds without database access',async()=>{const r=await request(app).get('/health');assert.equal(r.status,200);assert.equal(r.body.ok,true);});
test('unknown routes use a consistent JSON 404',async()=>{const r=await request(app).get('/api/not-a-route');assert.equal(r.status,404);assert.equal(r.body.ok,false);assert.ok(r.body.error.message);});
test('login rejects an empty payload',async()=>{const r=await request(app).post('/api/auth/login').send({});assert.equal(r.status,400);assert.equal(r.body.ok,false);});
test('protected APIs reject requests without a bearer token',async()=>{const r=await request(app).get('/api/students/profile');assert.equal(r.status,401);assert.equal(r.body.ok,false);});
