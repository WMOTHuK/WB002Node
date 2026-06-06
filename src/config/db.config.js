// src/config/db.config.js
import pkg from 'pg';
const { Pool } = pkg;

// Белый список таблиц для прямого доступа через API
const allowedTableNames = ['prices', 'goods', 'photos', 'users'];

const pool = new Pool({
  connectionString: process.env.DB_URL,
  max: 20,
  idleTimeoutMillis: 30000,
  connectionTimeoutMillis: 5000,
});

export { allowedTableNames, pool };