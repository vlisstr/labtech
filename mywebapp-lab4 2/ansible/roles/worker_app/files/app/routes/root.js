// GET / — root endpoint.
// Returns ONLY text/html; lists business endpoints of the application.

const express = require('express');
const { htmlDoc } = require('../lib/render');

const router = express.Router();

router.get('/', (req, res) => {
  if (!req.accepts('text/html')) {
    return res.status(406).type('text/plain').send('Only text/html is supported on /');
  }
  const body = `<h1>mywebapp — Simple Inventory</h1>
<p>Business endpoints:</p>
<ul>
  <li><a href="/items">GET /items</a> — list all inventory items (id, name)</li>
  <li>POST /items — create a new item (fields: name, quantity)</li>
  <li>GET /items/&lt;id&gt; — view full item details (id, name, quantity, created_at)</li>
</ul>`;
  res.type('text/html').send(htmlDoc('mywebapp', body));
});

module.exports = router;
