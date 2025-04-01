import pkg from 'pg';
const { Pool } = pkg;

const allowedTableNames = ['prices', 'goods', 'photos','users']; // Список разрешённых имен таблиц

// Конфигурация подключения к базе данных
const pool = new Pool({
  user: 'postgres',
  host: 'localhost',
  database: 'wbshop002',
  password: 'oQhN9Edp',
  port: 5432,
});


// Для ES модулей (если нужно)
export { allowedTableNames, pool };