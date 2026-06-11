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
    'SELECT id, active, name_ru, description_ru, name_en, description_en, oh_grp_id FROM fi_ohcat_active_multilang ORDER BY id'
  );

  return rows.map(row => ({
    id: row.id,
    oh_name: locale === 'en' ? row.name_en : row.name_ru,
    oh_desc: locale === 'en' ? row.description_en : row.description_ru,
    oh_grp_id: row.oh_grp_id
  }));
}

/**
 * Создать новую категорию накладных расходов
 * @param {string} name - Название на текущем языке
 * @param {string} description - Описание на текущем языке
 * @param {string} locale - Язык ввода ('ru' или 'en')
 * @returns {Promise<Object>} - Созданная категория
 */
export async function addOverheadType(name, description, oh_grp_id, locale) {
  if (!name || !locale) {
    throw new AppError('name and locale are required', 400);
  }

  const isRu = locale === 'RU';
  
  const { rows } = await pool.query(
    'SELECT * FROM create_ohcat($1, $2, $3, $4, $5, $6)',
    [
      isRu ? name : null,           // name_ru
      isRu ? description : null,    // description_ru
      isRu ? null : name,           // name_en
      isRu ? null : description,    // description_en
      true,                         // active
      oh_grp_id                     // group
    ]
  );

  if (!rows.length) {
    throw new AppError('Failed to create overhead type', 500);
  }

  const result = rows[0];
  return {
    id: result.id,
    oh_name: locale === 'en' ? result.name_en : result.name_ru,
    oh_desc: locale === 'en' ? result.description_en : result.description_ru,
    oh_grp_id: result.oh_grp_id
  };
}

export async function getOverheadGroups(locale = 'ru') {
  const { rows } = await pool.query(
    'SELECT id, active, name_ru, description_ru, name_en, description_en FROM fi_ohgrp_active_multilang ORDER BY id'
  );

  return rows.map(row => ({
    id: row.id,
    oh_grp_name: locale === 'en' ? row.name_en : row.name_ru,
    oh_grp_desc: locale === 'en' ? row.description_en : row.description_ru
  }));
}

/**
 * Создать новую группу накладных расходов
 * @param {string} name - Название на текущем языке
 * @param {string} description - Описание на текущем языке
 * @param {string} locale - Язык ввода ('ru' или 'en')
 * @returns {Promise<Object>} - Созданная категория
 */
export async function addOverheadGroup(name, description, locale) {
  if (!name || !locale) {
    throw new AppError('name and locale are required', 400);
  }

  const isRu = locale === 'RU';
  
  const { rows } = await pool.query(
    'SELECT * FROM create_ohgrp($1, $2, $3, $4, $5)',
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

/** Изменить группу накладных расходов
 * @param {integer} id - Overheads category id
 * @param {integer} oh_grp_id - Overheads category new group id
 * @returns {Promise<Object>} - Созданная категория
 */
export async function changeOverheadTypeGroup(id, oh_grp_id) {
  if (!id || !oh_grp_id) {
    throw new AppError('both id are required', 400);
  }

  const { rows } = await pool.query(
    'UPDATE fi_ohcat SET oh_grp_id = $2 WHERE id = $1 RETURNING id, oh_grp_id',
    [id, oh_grp_id]
  );

  if (!rows.length) {
    throw new AppError('Failed to create overhead type', 500);
  }

  const result = rows[0];
  return {
    id: result.id,
    oh_grp_id: result.oh_grp_id
  };
}



/** Изменить группу накладных расходов
 * @param {integer} user_id - id пользователя
 * @param {date} date - center date for request
 */
export async function getMonthlyOverheads(user_id, date) {

  const { rows } = await pool.query(
    'SELECT * FROM get_overheads_4months($1, $2);',
    [user_id, date]
  );

  return rows;
}
