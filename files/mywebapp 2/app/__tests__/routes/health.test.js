const request = require('supertest');
jest.mock('../../lib/db');
const db = require('../../lib/db');
const { createApp } = require('../../lib/app');

test('GET /health/alive always returns 200 OK', async () => {
  const app = createApp();
  const res = await request(app).get('/health/alive');
  expect(res.status).toBe(200);
  expect(res.text).toBe('OK');
});

test('GET /health/ready returns 200 when DB ping succeeds', async () => {
  db.ping.mockResolvedValueOnce(undefined);
  const app = createApp();
  const res = await request(app).get('/health/ready');
  expect(res.status).toBe(200);
  expect(res.text).toBe('OK');
});

test('GET /health/ready returns 500 with reason when DB ping fails', async () => {
  db.ping.mockRejectedValueOnce(new Error('connection refused'));
  const app = createApp();
  const res = await request(app).get('/health/ready');
  expect(res.status).toBe(500);
  expect(res.text).toContain('connection refused');
});
