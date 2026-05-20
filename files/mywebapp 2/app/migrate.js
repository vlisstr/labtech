// Database migration script.
//
// Contract (per the spec):
//   The script accepts a connection that points either to an empty schema
//   or to a schema previously initialised by this same script (current or
//   previous version), and brings it to the current version. Therefore each
//   statement must be idempotent.
//
// For this lab we have a single table (items) and a single index. We use
// "CREATE TABLE IF NOT EXISTS" for the table and a SHOW INDEX guard for the
// index (MariaDB does not support "CREATE INDEX IF NOT EXISTS" in all
// versions).

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
    // items table
    await conn.query(`
      CREATE TABLE IF NOT EXISTS items (
        id         INT AUTO_INCREMENT PRIMARY KEY,
        name       VARCHAR(255) NOT NULL,
        quantity   INT NOT NULL DEFAULT 0,
        created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
      ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
    `);
    console.log('  = ensured table items');

    // index on name (helps the future "search by name" use case)
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
