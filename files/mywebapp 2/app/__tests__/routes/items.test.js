const request = require('supertest');
jest.mock('../../lib/db');
const db = require('../../lib/db');
const { createApp } = require('../../lib/app');

let mockQuery;
beforeEach(() => {
  mockQuery = jest.fn();
  db.getPool.mockReturnValue({ query: mockQuery });
});

describe('GET /items', () => {
  test('returns JSON array', async () => {
    mockQuery.mockResolvedValueOnce([[
      { id: 1, name: 'screwdriver' },
      { id: 2, name: 'hammer' },
    ]]);
    const app = createApp();
    const res = await request(app).get('/items').set('Accept', 'application/json');
    expect(res.status).toBe(200);
    expect(res.body).toEqual([
      { id: 1, name: 'screwdriver' },
      { id: 2, name: 'hammer' },
    ]);
  });

  test('returns HTML table when Accept: text/html', async () => {
    mockQuery.mockResolvedValueOnce([[{ id: 1, name: 'hammer' }]]);
    const app = createApp();
    const res = await request(app).get('/items').set('Accept', 'text/html');
    expect(res.status).toBe(200);
    expect(res.type).toBe('text/html');
    expect(res.text).toContain('<table');
    expect(res.text).toContain('hammer');
  });

  test('returns 406 for unsupported Accept', async () => {
    mockQuery.mockResolvedValueOnce([[]]);
    const app = createApp();
    const res = await request(app).get('/items').set('Accept', 'text/csv');
    expect(res.status).toBe(406);
  });
});

describe('POST /items', () => {
  test('creates an item and returns 201 + body', async () => {
    mockQuery
      .mockResolvedValueOnce([{ insertId: 7 }])
      .mockResolvedValueOnce([[
        { id: 7, name: 'wrench', quantity: 3, created_at: 'date' },
      ]]);
    const app = createApp();
    const res = await request(app)
      .post('/items')
      .set('Accept', 'application/json')
      .send({ name: 'wrench', quantity: 3 });
    expect(res.status).toBe(201);
    expect(res.body).toEqual({
      id: 7, name: 'wrench', quantity: 3, created_at: 'date',
    });
  });

  test('400 when name is missing', async () => {
    const app = createApp();
    const res = await request(app)
      .post('/items')
      .set('Accept', 'application/json')
      .send({ quantity: 5 });
    expect(res.status).toBe(400);
  });

  test('400 when quantity is negative', async () => {
    const app = createApp();
    const res = await request(app)
      .post('/items')
      .send({ name: 'x', quantity: -1 });
    expect(res.status).toBe(400);
  });

  test('400 when name is whitespace only', async () => {
    const app = createApp();
    const res = await request(app)
      .post('/items')
      .send({ name: '   ', quantity: 1 });
    expect(res.status).toBe(400);
  });
});

describe('GET /items/:id', () => {
  test('returns item JSON when found', async () => {
    mockQuery.mockResolvedValueOnce([[
      { id: 1, name: 'foo', quantity: 1, created_at: 'date' },
    ]]);
    const app = createApp();
    const res = await request(app).get('/items/1').set('Accept', 'application/json');
    expect(res.status).toBe(200);
    expect(res.body.id).toBe(1);
    expect(res.body.name).toBe('foo');
  });

  test('returns 404 when not found', async () => {
    mockQuery.mockResolvedValueOnce([[]]);
    const app = createApp();
    const res = await request(app).get('/items/999').set('Accept', 'application/json');
    expect(res.status).toBe(404);
  });

  test('returns 400 on non-numeric id', async () => {
    const app = createApp();
    const res = await request(app).get('/items/abc').set('Accept', 'application/json');
    expect(res.status).toBe(400);
  });

  test('returns HTML when Accept: text/html', async () => {
    mockQuery.mockResolvedValueOnce([[
      { id: 5, name: 'spanner', quantity: 2, created_at: 'date' },
    ]]);
    const app = createApp();
    const res = await request(app).get('/items/5').set('Accept', 'text/html');
    expect(res.status).toBe(200);
    expect(res.type).toBe('text/html');
    expect(res.text).toContain('spanner');
  });
});
