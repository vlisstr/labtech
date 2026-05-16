const mysql = require('mysql2/promise');
const { parseConfig } = require('./lib/config');

async function ensureIndex(conn, tableName, indexName, columnSql) {
  const [rows] = await conn.query(
    'SHOW INDEX FROM `' + tableName + '` WHERE Key_name = ?',
    [indexName]
  );
  if (rows.length === 0) {
    await conn.query(
      `CREATE INDEX \`${indexName}\` ON \`${tableName}\` (${columnSql})`
    );
    console.log(`  + created index ${indexName} on ${tableName}(${columnSql})`);
  } else {
    console.log(`  = index ${indexName} on ${tableName} already exists`);
  }
}

async function main() {
  const cfg = parseConfig();
  console.log(
    `[migrate] connecting to ${cfg.db.host}:${cfg.db.port}/${cfg.db.database} ` +
      `as ${cfg.db.user}`
  );

  const conn = await mysql.createConnection({
    host: cfg.db.host,
    port: cfg.db.port,
    user: cfg.db.user,
    password: cfg.db.password,
    database: cfg.db.database,
    multipleStatements: false,
  });

  try {
    await conn.query(`
      CREATE TABLE IF NOT EXISTS items (
        id         INT AUTO_INCREMENT PRIMARY KEY,
        name       VARCHAR(255) NOT NULL,
        quantity   INT NOT NULL DEFAULT 0,
        created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
      ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
    `);
    console.log('  = ensured table items');

    await ensureIndex(conn, 'items', 'idx_items_name', '`name`');

    console.log('[migrate] OK');
  } finally {
    await conn.end();
  }
}

main().catch((err) => {
  console.error('[migrate] FAILED:', err.message);
  process.exit(1);
});
