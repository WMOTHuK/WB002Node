// src/utils/tableSync.utils.js
import { db } from './sql.utils.js';
import { pool } from '../../General/globals.js';
import { logger } from './logger.js';

/**
 * Синхронизация данных с таблицей БД (insert новых, update изменившихся)
 * @param {Array} sourceData - Данные для синхронизации
 * @param {string} tableName - Имя таблицы
 * @param {string|Array} keyFields - Поле/поля первичного ключа
 * @param {Object} [options]
 * @param {number} [options.batchSize=500] - Размер пакета
 * @param {Array} [options.ignoreFields=[]] - Поля, исключённые из сравнения и вставки
 * @returns {Promise<{inserted: number, updated: number, unchanged: number, errors: Array}>}
 */
export async function syncTableToDB(sourceData, tableName, keyFields, options = {}) {
  const { ignoreFields = [] } = options;
  const keyList = Array.isArray(keyFields) ? keyFields : [keyFields];

  // Очищаем от игнорируемых полей
  const dataToSync = sourceData.map(item => {
    const clean = { ...item };
    ignoreFields.forEach(f => delete clean[f]);
    return clean;
  });

  // Получаем существующие записи
  const { rows: existingRows } = await db.select(tableName);
  const existingMap = new Map(
    existingRows.map(row => [keyList.map(k => row[k]).join('|'), row])
  );

  const toInsert = [];
  const toUpdate = [];
  let unchanged = 0;

  for (const record of dataToSync) {
    const key = keyList.map(k => record[k]).join('|');
    const existing = existingMap.get(key);

    if (!existing) {
      toInsert.push(record);
    } else if (hasChanges(record, existing, keyList, ignoreFields)) {
      toUpdate.push(record);
    } else {
      unchanged++;
    }
  }

  let inserted = 0;
  let updated = 0;
  const errors = [];

  // Пакетная вставка
  if (toInsert.length > 0) {
    try {
      inserted = await bulkInsert(tableName, toInsert);
    } catch (error) {
      errors.push({ operation: 'insert', error: error.message });
      logger.error('Bulk insert error:', error.message);
    }
  }

  // Построчное обновление
  if (toUpdate.length > 0) {
    for (const record of toUpdate) {
      try {
        const where = {};
        keyList.forEach(k => where[k] = record[k]);
        const data = {};
        Object.keys(record).forEach(k => {
          if (!keyList.includes(k)) data[k] = record[k];
        });
        await db.update(tableName, data, where);
        updated++;
      } catch (error) {
        errors.push({ operation: 'update', record: record[keyList[0]], error: error.message });
        logger.error('Update error:', error.message);
      }
    }
  }

  return { inserted, updated, unchanged, errors, totalProcessed: sourceData.length };
}

/**
 * Обогатить данные полями из БД (приоритет у данных из БД)
 * @param {Array} sourceData - Исходные данные
 * @param {string} tableName - Имя таблицы
 * @param {string|Array} keyFields - Поля ключа
 * @param {Object} [options]
 * @param {Array} [options.ignoreFields=[]] - Поля, которые не нужно перезаписывать из БД
 * @returns {Promise<Array>} - Обогащённый массив
 */
export async function syncTableFromDB(sourceData, tableName, keyFields, options = {}) {
  const { ignoreFields = [] } = options;
  const keyList = Array.isArray(keyFields) ? keyFields : [keyFields];

  const { rows: dbRows } = await db.select(tableName);
  const dbMap = new Map(
    dbRows.map(row => [keyList.map(k => row[k]).join('|'), row])
  );

  return sourceData.map(item => {
    const key = keyList.map(k => item[k]).join('|');
    const dbRecord = dbMap.get(key);

    if (!dbRecord) return item;

    const merged = { ...item };
    for (const field in dbRecord) {
      if (!keyList.includes(field) && !ignoreFields.includes(field)) {
        merged[field] = dbRecord[field];
      }
    }
    return merged;
  });
}

// ---------------------------------------------------------------------------
// Вспомогательные
// ---------------------------------------------------------------------------

function hasChanges(newRecord, oldRecord, keyFields, ignoreFields) {
  return Object.keys(newRecord).some(
    key => !keyFields.includes(key) && !ignoreFields.includes(key) && newRecord[key] !== oldRecord[key]
  );
}

async function bulkInsert(tableName, rows) {
  if (rows.length === 0) return 0;
  const columns = Object.keys(rows[0]);
  const placeholders = rows.map((_, rowIdx) =>
    `(${columns.map((_, colIdx) => `$${rowIdx * columns.length + colIdx + 1}`).join(', ')})`
  );
  const values = rows.flatMap(Object.values);
  const result = await pool.query(
    `INSERT INTO ${tableName} (${columns.join(', ')}) VALUES ${placeholders.join(', ')}`,
    values
  );
  return result.rowCount;
}