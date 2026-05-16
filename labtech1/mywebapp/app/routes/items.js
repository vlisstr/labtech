

const express = require('express');
const { getPool } = require('../lib/db');
const { htmlDoc, renderTable, escapeHtml } = require('../lib/render');

const router = express.Router();

function detailHtml(item) {
  return `<h1>Item ${escapeHtml(item.id)}</h1>
<p><b>id:</b> ${escapeHtml(item.id)}</p>
<p><b>name:</b> ${escapeHtml(item.name)}</p>
<p><b>quantity:</b> ${escapeHtml(item.quantity)}</p>
<p><b>created_at:</b> ${escapeHtml(item.created_at)}</p>
<p><a href="/items">&larr; back to list</a></p>`;
}

// GET /items — list all
router.get('/', async (req, res, next) => {
  try {
    const [rows] = await getPool().query(
      'SELECT id, name FROM items ORDER BY id'
    );

    res.format({
      'application/json': () => res.json(rows),
      'text/html': () => {
        const tableRows = rows.map((r) => [r.id, r.name]);
        const body = `<h1>Inventory items</h1>
${renderTable(['id', 'name'], tableRows)}
<p><a href="/">&larr; home</a></p>`;
        res.type('text/html').send(htmlDoc('Items', body));
      },
      default: () => res.status(406).type('text/plain').send('Not Acceptable'),
    });
  } catch (err) {
    next(err);
  }
});

// POST /items — create
router.post('/', async (req, res, next) => {
  try {
    const name = req.body && req.body.name;
    const quantityRaw = req.body && req.body.quantity;

    if (!name || typeof name !== 'string' || name.trim() === '') {
      return res
        .status(400)
        .type('text/plain')
        .send('"name" is required and must be a non-empty string');
    }
    const quantity = parseInt(quantityRaw, 10);
    if (!Number.isFinite(quantity) || quantity < 0) {
      return res
        .status(400)
        .type('text/plain')
        .send('"quantity" must be a non-negative integer');
    }

    const [result] = await getPool().query(
      'INSERT INTO items (name, quantity) VALUES (?, ?)',
      [name.trim(), quantity]
    );
    const id = result.insertId;

    const [rows] = await getPool().query(
      'SELECT id, name, quantity, created_at FROM items WHERE id = ?',
      [id]
    );
    const item = rows[0];

    res.status(201);
    res.format({
      'application/json': () => res.json(item),
      'text/html': () => {
        res
          .type('text/html')
          .send(htmlDoc('Item created', detailHtml(item)));
      },
      default: () => res.type('text/plain').send(`Created id=${id}`),
    });
  } catch (err) {
    next(err);
  }
});

// GET /items/:id — detail
router.get('/:id', async (req, res, next) => {
  try {
    const id = parseInt(req.params.id, 10);
    if (!Number.isFinite(id)) {
      return res.status(400).type('text/plain').send('Invalid id');
    }

    const [rows] = await getPool().query(
      'SELECT id, name, quantity, created_at FROM items WHERE id = ?',
      [id]
    );
    if (rows.length === 0) {
      return res.status(404).type('text/plain').send('Not Found');
    }
    const item = rows[0];

    res.format({
      'application/json': () => res.json(item),
      'text/html': () => {
        res.type('text/html').send(htmlDoc(`Item ${item.id}`, detailHtml(item)));
      },
      default: () => res.status(406).type('text/plain').send('Not Acceptable'),
    });
  } catch (err) {
    next(err);
  }
});

module.exports = router;
