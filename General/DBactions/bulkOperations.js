// utils/db/bulkOperations.js
import { pool } from '../globals.js';

/**
 * Пакетная вставка/обновление с поддержкой составных ключей
 * @param {string} tableName - Имя таблицы
 * @param {Array} data - Массив объектов данных
 * @param {string|Array} conflictFields - Поле или массив полей ключа
 * @returns {Promise<{success: boolean, rowsAffected?: number, error?: string}>}
 */
export async function bulkUpsert(tableName, data, conflictFields) {
  if (!data?.length) return { success: true, rowsAffected: 0 };
  
  const conflictFieldList = Array.isArray(conflictFields) 
    ? conflictFields 
    : [conflictFields];

  try {
    const columns = Object.keys(data[0]);
    const values = [];
    const valuePlaceholders = [];
    
    // Подготовка данных
    data.forEach((row, rowIdx) => {
      const rowValues = columns.map((col, colIdx) => {
        values.push(row[col]);
        return `$${rowIdx * columns.length + colIdx + 1}`;
      });
      valuePlaceholders.push(`(${rowValues.join(', ')})`);
    });

    // Поля для обновления (исключая ключевые)
    const updateSet = columns
      .filter(col => !conflictFieldList.includes(col))
      .map(col => `${col} = EXCLUDED.${col}`)
      .join(', ');

    const query = `
      INSERT INTO ${tableName} (${columns.join(', ')})
      VALUES ${valuePlaceholders.join(', ')}
      ON CONFLICT (${conflictFieldList.join(', ')})
      DO UPDATE SET ${updateSet}
    `;

    const result = await pool.query(query, values);
    return { 
      success: true, 
      rowsAffected: result.rowCount 
    };
  } catch (error) {
    console.error('Bulk upsert error:', error);
    return { 
      success: false, 
      error: error.message 
    };
  }
}

/**
 * Пакетное обновление данных
 * @param {string} tableName - Имя таблицы
 * @param {Array} data - Массив объектов данных
 * @param {string|Array} keyFields - Поле или массив полей ключа
 * @returns {Promise<{success: boolean, rowsAffected?: number, error?: string}>}
 */
export async function bulkUpdate(tableName, data, keyFields) {
  if (!data?.length) return { success: true, rowsAffected: 0 };

  const keyFieldList = Array.isArray(keyFields) 
    ? keyFields 
    : [keyFields];

  try {
    let updatedCount = 0;
    
    // Используем транзакцию для атомарности
    await pool.query('BEGIN');

    for (const row of data) {
      const updateFields = Object.keys(row)
        .filter(key => !keyFieldList.includes(key))
        .map(key => `${key} = $${Object.keys(row).indexOf(key) + 1}`);

      const whereClause = keyFieldList
        .map((key, idx) => `${key} = $${idx + updateFields.length + 1}`)
        .join(' AND ');

      const query = `
        UPDATE ${tableName}
        SET ${updateFields.join(', ')}
        WHERE ${whereClause}
      `;

      const values = [
        ...Object.values(row).filter((_, idx) => 
          !keyFieldList.includes(Object.keys(row)[idx])
        ),
        ...keyFieldList.map(key => row[key])
      ];

      const result = await pool.query(query, values);
      updatedCount += result.rowCount;
    }

    await pool.query('COMMIT');
    return { 
      success: true, 
      rowsAffected: updatedCount 
    };
  } catch (error) {
    await pool.query('ROLLBACK');
    console.error('Bulk update error:', error);
    return { 
      success: false, 
      error: error.message 
    };
  }
}