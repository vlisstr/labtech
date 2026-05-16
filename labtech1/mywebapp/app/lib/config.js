

const { parseArgs } = require('node:util');

function parseConfig() {
  const { values } = parseArgs({
    options: {
      host:          { type: 'string', default: '127.0.0.1' },
      port:          { type: 'string', default: '5200' },
      'db-host':     { type: 'string', default: '127.0.0.1' },
      'db-port':     { type: 'string', default: '3306' },
      'db-user':     { type: 'string', default: 'mywebapp' },
      'db-password': { type: 'string', default: '' },
      'db-name':     { type: 'string', default: 'mywebapp' },
    },
    strict: false,
    allowPositionals: true,
  });

  const port = parseInt(values.port, 10);
  const dbPort = parseInt(values['db-port'], 10);
  if (!Number.isFinite(port))   throw new Error(`Invalid --port: ${values.port}`);
  if (!Number.isFinite(dbPort)) throw new Error(`Invalid --db-port: ${values['db-port']}`);

  return {
    host: values.host,
    port,
    db: {
      host:     values['db-host'],
      port:     dbPort,
      user:     values['db-user'],
      password: values['db-password'],
      database: values['db-name'],
    },
  };
}

module.exports = { parseConfig };
