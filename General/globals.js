import pkg from 'pg';
const { Pool } = pkg;

const allowedTableNames = ['prices', 'goods', 'photos']; // Список разрешённых имен таблиц

// Конфигурация подключения к базе данных
const pool = new Pool({
  user: 'postgres',
  host: 'localhost',
  database: 'wbshop002',
  password: 'oQhN9Edp',
  port: 5432,
});

export { allowedTableNames, pool };