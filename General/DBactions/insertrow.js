//.General/DBactions/insertrow.js
import { pool } from "../globals.js";
/**
 * Вставка строки в таблицу PostgreSQL
 * @param {object} pool - Пул подключений к PostgreSQL
 * @param {string} tableName - Имя таблицы
 * @param {Array} data - Массив объектов с данными для вставки
 * @returns {Promise<object>} - Статус операции и информация о вставленной строке
 */
export async function insertRow( tableName, data = []) {
  if (!pool) throw new Error('Pool is required');
  if (!tableName || typeof tableName !== 'string') throw new Error('Valid table name is required');
  if (!Array.isArray(data)) throw new Error('Data must be an array');

  try {
      // Если нет данных для вставки
      if (data.length === 0) {
          return {
              success: false,
              message: 'No data provided for insertion'
          };
      }

      // Строим параметризованный INSERT запрос
      const { queryText, values } = buildInsertQuery(tableName, data);

      // Выполняем запрос
      const result = await pool.query(queryText, values);

      return {
          success: true,
          rowsAffected: result.rowCount,
          message: `Successfully inserted ${result.rowCount} row(s)`,
          data: result.rows[0] || null
      };
  } catch (error) {
      console.error('Error in insertRow:', error);
      return {
          success: false,
          message: error.message
      };
  }
}

/**
* Строит параметризованный INSERT запрос
* @param {string} tableName - Имя таблицы
* @param {Array} data - Массив объектов с данными
* @returns {object} - { queryText: string, values: Array }
*/
function buildInsertQuery(tableName, data) {
  const columns = [];
  const paramPlaceholders = [];
  const values = [];

  data.forEach((item, index) => {
      if (!item.column) throw new Error(`Missing 'column' property in data item at index ${index}`);
      if (item.value === undefined) throw new Error(`Missing 'value' for column ${item.column}`);

      columns.push(item.column);
      paramPlaceholders.push(`$${index + 1}`);
      values.push(item.value);
  });

  const queryText = `
      INSERT INTO ${tableName} (${columns.join(', ')})
      VALUES (${paramPlaceholders.join(', ')})
      RETURNING *
  `;

  return { queryText, values };
}

export default {
  insertRow
};