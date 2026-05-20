// mywebapp — entry point.
// Listens either on the host:port passed via CLI args, or — when started
// through systemd socket activation — on the file descriptor that systemd
// hands us. systemd passes sockets starting at FD 3 and sets LISTEN_FDS
// to the count of sockets passed (see sd_listen_fds(3)).

const { parseConfig } = require('./lib/config');
const { initPool }    = require('./lib/db');
const { createApp }   = require('./lib/app');

const cfg = parseConfig();
initPool(cfg.db);
const app = createApp();

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
