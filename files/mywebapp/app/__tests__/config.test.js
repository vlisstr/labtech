const { parseConfig } = require('../lib/config');

const ORIG_ARGV = process.argv;
afterEach(() => {
  process.argv = ORIG_ARGV;
});

function setArgs(arr) {
  process.argv = ['node', 'script.js', ...arr];
}

test('returns sensible defaults with no args', () => {
  setArgs([]);
  const cfg = parseConfig();
  expect(cfg.host).toBe('127.0.0.1');
  expect(cfg.port).toBe(5200);
  expect(cfg.db.host).toBe('127.0.0.1');
  expect(cfg.db.port).toBe(3306);
  expect(cfg.db.user).toBe('mywebapp');
  expect(cfg.db.database).toBe('mywebapp');
});

test('parses all custom values', () => {
  setArgs([
    '--host', '0.0.0.0',
    '--port', '8080',
    '--db-host', 'db.example',
    '--db-port', '5432',
    '--db-user', 'u',
    '--db-password', 'p',
    '--db-name', 'foo',
  ]);
  const cfg = parseConfig();
  expect(cfg.host).toBe('0.0.0.0');
  expect(cfg.port).toBe(8080);
  expect(cfg.db).toEqual({
    host:     'db.example',
    port:     5432,
    user:     'u',
    password: 'p',
    database: 'foo',
  });
});

test('throws on non-numeric --port', () => {
  setArgs(['--port', 'not-a-number']);
  expect(() => parseConfig()).toThrow(/Invalid --port/);
});

test('throws on non-numeric --db-port', () => {
  setArgs(['--db-port', 'xyz']);
  expect(() => parseConfig()).toThrow(/Invalid --db-port/);
});
