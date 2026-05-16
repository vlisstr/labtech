const express = require('express');
const { parseConfig } = require('./lib/config');
const { initPool } = require('./lib/db');

const rootRouter   = require('./routes/root');
const healthRouter = require('./routes/health');
const itemsRouter  = require('./routes/items');

const cfg = parseConfig();
initPool(cfg.db);

const app = express();
app.disable('x-powered-by');
app.use(express.json());
app.use(express.urlencoded({ extended: false }));

app.use('/',       rootRouter);
app.use('/health', healthRouter);
app.use('/items',  itemsRouter);

app.use((req, res) => {
  res.status(404).type('text/plain').send('Not Found');
});


app.use((err, req, res, next) => {
  console.error('[error]', err);
  res.status(500).type('text/plain').send('Internal Server Error');
});


const SD_LISTEN_FDS_START = 3;
const listenFds = parseInt(process.env.LISTEN_FDS || '0', 10);

if (listenFds > 0) {
  const fd = SD_LISTEN_FDS_START;
  app.listen({ fd }, () => {
    console.log(`mywebapp ready on systemd-provided socket (fd=${fd})`);
  });
} else {
  app.listen(cfg.port, cfg.host, () => {
    console.log(`mywebapp ready on http://${cfg.host}:${cfg.port}`);
  });
}

function shutdown(signal) {
  console.log(`received ${signal}, shutting down`);
  process.exit(0);
}
process.on('SIGTERM', () => shutdown('SIGTERM'));
process.on('SIGINT',  () => shutdown('SIGINT'));
