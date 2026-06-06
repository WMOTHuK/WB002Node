// src/utils/db/bulkOperations.utils.js
import { pool } from '../../config/db.config.js';
import { logger } from '../utils/logger.js';

/**
 * Пакетный upsert (INSERT ON CONFLICT DO UPDATE)
 * @param {string} tableName
 * @param {Array<Object>} data - Массив объектов для вставки
 * @param {string|Array} conflictFields - Поля, по которым определяется конфликт
 * @returns {Promise<number>} - Количество затронутых строк
 * @throws {Error} при ошибке БД
 */
export async function bulkUpsert(tableName, data, conflictFields) {
  if (!data?.length) return 0;

  const conflictList = Array.isArray(conflictFields) ? conflictFields : [conflictFields];
  const columns = Object.keys(data[0]);
  const values = [];
  const placeholders = [];

  data.forEach((row, rowIdx) => {
    const rowPlaceholders = columns.map((_, colIdx) => {
      values.push(row[columns[colIdx]]);
      return `$${rowIdx * columns.length + colIdx + 1}`;
    });
    placeholders.push(`(${rowPlaceholders.join(', ')})`);
  });

  const updateSet = columns
    .filter(col => !conflictList.includes(col))
    .map(col => `${col} = EXCLUDED.${col}`)
    .join(', ');

  const query = `
    INSERT INTO ${tableName} (${columns.join(', ')})
    VALUES ${placeholders.join(', ')}
    ON CONFLICT (${conflictList.join(', ')})
    DO UPDATE SET ${updateSet}
  `;

  try {
    const result = await pool.query(query, values);
    logger.debug(`Bulk upsert: ${result.rowCount} rows affected`);
    return result.rowCount;
  } catch (error) {
    logger.error('Bulk upsert error:', error.message);
    throw error;
  }
}