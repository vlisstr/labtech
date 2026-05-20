// Health endpoints required by the spec.
//   GET /health/alive  — always 200 OK
//   GET /health/ready  — 200 OK iff DB is reachable, otherwise 500 with reason
// These endpoints are intentionally NOT exposed by nginx.

const express = require('express');
const { ping } = require('../lib/db');

const router = express.Router();

router.get('/alive', (req, res) => {
  res.type('text/plain').status(200).send('OK');
});

router.get('/ready', async (req, res) => {
  try {
    await ping();
    res.type('text/plain').status(200).send('OK');
  } catch (err) {
    res
      .type('text/plain')
      .status(500)
      .send(`database not ready: ${err.message}`);
  }
});

module.exports = router;
