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
