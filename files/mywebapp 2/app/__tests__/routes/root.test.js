const request = require('supertest');
jest.mock('../../lib/db');
const { createApp } = require('../../lib/app');

test('GET / returns HTML when Accept: text/html', async () => {
  const app = createApp();
  const res = await request(app).get('/').set('Accept', 'text/html');
  expect(res.status).toBe(200);
  expect(res.type).toBe('text/html');
  expect(res.text).toContain('mywebapp');
  expect(res.text).toContain('/items');
});

test('GET / returns 406 when only JSON is acceptable', async () => {
  const app = createApp();
  const res = await request(app).get('/').set('Accept', 'application/json');
  expect(res.status).toBe(406);
});

test('unknown route returns 404', async () => {
  const app = createApp();
  const res = await request(app).get('/no-such-thing');
  expect(res.status).toBe(404);
});
