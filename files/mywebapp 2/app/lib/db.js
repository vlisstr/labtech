// MariaDB connection pool wrapper using mysql2/promise.

const mysql = require('mysql2/promise');

let pool = null;

function initPool(dbConfig) {
  pool = mysql.createPool({
    host: dbConfig.host,
    port: dbConfig.port,
    user: dbConfig.user,
    password: dbConfig.password,
    database: dbConfig.database,
    waitForConnections: true,
    connectionLimit: 10,
    queueLimit: 0,
  });
  return pool;
}

function getPool() {
  if (!pool) throw new Error('DB pool is not initialized');
  return pool;
}

// ping() is used by GET /health/ready
async function ping() {
  const conn = await getPool().getConnection();
  try {
    await conn.ping();
  } finally {
    conn.release();
  }
}

module.exports = { initPool, getPool, ping };
