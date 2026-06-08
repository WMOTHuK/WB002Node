// src/services/fi/ohcat.service.js
import { pool } from '../../config/db.config.js';
import { AppError } from '../../utils/errors.js';

/**
 * Получить активные категории накладных расходов
 * @param {string} locale - 'ru' или 'en' (влияет на порядок полей в ответе, но VIEW возвращает всё)
 * @returns {Promise<Array>}
 */
export async function getOverheadTypes(locale = 'ru') {
  const { rows } = await pool.query(
    'SELECT id, active, name_ru, description_ru, name_en, description_en FROM fi_ohcat_active_multilang ORDER BY id'
  );

  return rows.map(row => ({
    id: row.id,
    oh_name: locale === 'en' ? row.name_en : row.name_ru,
    oh_desc: locale === 'en' ? row.description_en : row.description_ru
  }));
}
/**
 * Создать новую категорию накладных расходов
 * @param {string} name - Название на текущем языке
 * @param {string} description - Описание на текущем языке
 * @param {string} locale - Язык ввода ('ru' или 'en')
 * @returns {Promise<Object>} - Созданная категория
 */
export async function addOverheadType(name, description, locale) {
  if (!name || !locale) {
    throw new AppError('name and locale are required', 400);
  }

  const isRu = locale === 'RU';
  
  const { rows } = await pool.query(
    'SELECT * FROM create_ohcat($1, $2, $3, $4, $5)',
    [
      isRu ? name : null,           // name_ru
      isRu ? description : null,    // description_ru
      isRu ? null : name,           // name_en
      isRu ? null : description,    // description_en
      true                           // active
    ]
  );

  if (!rows.length) {
    throw new AppError('Failed to create overhead type', 500);
  }

  const result = rows[0];
  return {
    id: result.id,
    oh_name: locale === 'en' ? result.name_en : result.name_ru,
    oh_desc: locale === 'en' ? result.description_en : result.description_ru
  };
}