// Builds the Express app. Separated from server.js so unit tests can
// instantiate the app without binding to a port or initialising the DB
// pool from CLI args.

const express = require('express');

const rootRouter   = require('../routes/root');
const healthRouter = require('../routes/health');
const itemsRouter  = require('../routes/items');

function createApp() {
  const app = express();
  app.disable('x-powered-by');
  app.use(express.json());
  app.use(express.urlencoded({ extended: false }));

  app.use('/',       rootRouter);
  app.use('/health', healthRouter);
  app.use('/items',  itemsRouter);

  // 404 fallback
  app.use((req, res) => {
    res.status(404).type('text/plain').send('Not Found');
  });

  // Error handler
  // eslint-disable-next-line no-unused-vars
  app.use((err, req, res, next) => {
    console.error('[error]', err);
    res.status(500).type('text/plain').send('Internal Server Error');
  });

  return app;
}

module.exports = { createApp };
