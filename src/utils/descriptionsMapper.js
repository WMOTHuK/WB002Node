// src/utils/descriptionsMapper.js
import { pool } from '../config/db.config.js';
import { logger } from './logger.js';

/**
 * Добавляет столбцы с описаниями к данным, сохраняя исходные значения.
 * Пример: crmstatus: 7 → crmstatus: 7, crmstatus_desc: "Завершена"
 *
 * @param {Array} data - Массив объектов
 * @param {Array<{field: string, tableName: string}>} mappingConfig
 * @returns {Promise<Array>}
 */
export async function addDescriptionColumns(data, mappingConfig) {
  if (!data?.length || !mappingConfig?.length) return data;

  // Собираем словари описаний (один запрос на таблицу)
  const descriptionsCache = {};

  for (const { tableName } of mappingConfig) {
    if (!descriptionsCache[tableName]) {
      try {
        const { rows } = await pool.query(`SELECT * FROM ${tableName}`);
        descriptionsCache[tableName] = new Map(
          rows.map(row => [row[Object.keys(row)[0]], row.description])
        );
      } catch (error) {
        logger.error(`Ошибка загрузки справочника ${tableName}:`, error.message);
        descriptionsCache[tableName] = new Map();
      }
    }
  }

  // Индекс конфигов по имени поля (один раз)
  const configByField = Object.fromEntries(
    mappingConfig.map(c => [c.field, c])
  );

  // Добавляем _desc поля
  return data.map(item => {
    const newItem = {};

    for (const field of Object.keys(item)) {
      newItem[field] = item[field];

      const config = configByField[field];
      if (config) {
        const descriptions = descriptionsCache[config.tableName];
        newItem[`${field}_desc`] = descriptions?.get(item[field]) || '';
      }
    }

    return newItem;
  });
}