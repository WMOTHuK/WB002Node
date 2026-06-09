// src/services/goods/goods.service.js
import { getApiKeyByUser } from '../apiKey.service.js';
import { fetchWBGoods, processWBCards } from '../../utils/wb.utils.js';
import { processOzonGoods } from '../../utils/ozon.utils.js';
import { syncTableToDB, syncTableFromDB } from '../../utils/tableSync.utils.js';
import { getViewData } from '../../utils/db/dbViews.utils.js';
import { removeByKeyValue } from '../../utils/array.utils.js';
import { pool } from '../../config/db.config.js';
import { AppError } from '../../utils/errors.js';


/**
 * Синхронизировать товары WB
 */
async function syncWBGoods(userId) {
  const apiKey = await getApiKeyByUser(userId, '2');
  const cards = await fetchWBGoods(apiKey);
  const goods = processWBCards(cards);
  return syncTableToDB(goods, 'goods', 'vendorcode');
}

/**
 * Синхронизировать товары Ozon
 */
async function syncOzonGoods(userId) {
  const apiKey = await getApiKeyByUser(userId, '3');
  const clientId = await getApiKeyByUser(userId, '4');
  const goods = await processOzonGoods(apiKey, clientId);
  return syncTableToDB(goods, 'goods', 'vendorcode');
}

/**
 * Получить активные товары из БД
 */
export async function getActiveProducts(userId) {
  await syncWBGoods(userId);
  await syncOzonGoods(userId);

  const productData = await getViewData('product_data');
  return removeByKeyValue(productData, 'deleted', true);
}




/**
 * Создать новый тип товаров
 * @param {string} name - Название на текущем языке
 * @param {string} description - Описание на текущем языке
 * @param {string} locale - Язык ввода ('ru' или 'en')
 * @returns {Promise<Object>} - Созданная Группа
 */
export async function addGoodsType(name, description, locale) {
  if (!name || !locale) {
    throw new AppError('name and locale are required', 400);
  }

  const isRu = locale === 'RU';
  
  const { rows } = await pool.query(
    'SELECT * FROM create_goods_type($1, $2, $3, $4, $5)',
    [
      isRu ? name : null,           // name_ru
      isRu ? description : null,    // description_ru
      isRu ? null : name,           // name_en
      isRu ? null : description,    // description_en
      true                           // active
    ]
  );

  if (!rows.length) {
    throw new AppError('Failed to create goods type', 500);
  }

  const result = rows[0];
  return {
    id: result.id,
    goods_type_name: locale === 'en' ? result.name_en : result.name_ru,
    goods_type_desc: locale === 'en' ? result.description_en : result.description_ru
  };
}


export async function getGoodsGroups(locale = 'ru') {
  const { rows } = await pool.query(
    'SELECT id, active, name_ru, description_ru, name_en, description_en, goods_type_id FROM goods_grp_active_multilang ORDER BY id'
  );

  return rows.map(row => ({
    id: row.id,
    goods_grp_name: locale === 'en' ? row.name_en : row.name_ru,
    goods_grp_desc: locale === 'en' ? row.description_en : row.description_ru,
    goods_type_id: row.goods_type_id
  }));
}

/**
 * Создать новую группу товаров
 * @param {string} name - Название на текущем языке
 * @param {string} description - Описание на текущем языке
 * @param {string} locale - Язык ввода ('ru' или 'en')
 * @returns {Promise<Object>} - Созданная Группа
 */
export async function addGoodsGroup(name, description, goods_type_id, locale) {
  if (!name || !locale) {
    throw new AppError('name and locale are required', 400);
  }

  const isRu = locale === 'RU';
  
  const { rows } = await pool.query(
    'SELECT * FROM create_goods_grp($1, $2, $3, $4, $5, $6)',
    [
      isRu ? name : null,           // name_ru
      isRu ? description : null,    // description_ru
      isRu ? null : name,           // name_en
      isRu ? null : description,    // description_en
      true,                         // active
      goods_type_id                 // Type of goods
    ]
  );

  if (!rows.length) {
    throw new AppError('Failed to create goods group', 500);
  }

  const result = rows[0];
  return {
    id: result.id,
    goods_grp_name: locale === 'en' ? result.name_en : result.name_ru,
    goods_grp_desc: locale === 'en' ? result.description_en : result.description_ru,
    goods_type_id: result.goods_type_id
  };
}

/** Изменить Тип группы товаров
 * @param {integer} id - Overheads category id
 * @param {integer} goods_type_id - Overheads category new group id
 * @returns {Promise<Object>} - Созданная категория
 */
export async function changeGoodsGroupType(id, goods_type_id) {
  if (!id || !goods_type_id) {
    throw new AppError('both id are required', 400);
  }

  const { rows } = await pool.query(
    'UPDATE goods_grp SET goods_type_id = $2 WHERE id = $1 RETURNING id, goods_type_id',
    [id, goods_type_id]
  );

  if (!rows.length) {
    throw new AppError('Failed to create overhead type', 500);
  }

  const result = rows[0];
  return {
    id: result.id,
    goods_type_id: result.goods_type_id
  };
}



/** Изменить группу товаров
 * @param {integer} vendorcode - Goods category id
 * @param {integer} goods_grp_id - goods  new group id
 * @returns {Promise<Object>} - Changed group
 */
export async function changeGoodsGroup(vendorcode, goods_grp_id) {
  if (!vendorcode || !goods_grp_id) {
    throw new AppError('both id are required', 400);
  }

  const { rows } = await pool.query(
    'UPDATE goods SET goods_grp_id = $2 WHERE vendorcode = $1 RETURNING vendorcode, goods_grp_id',
    [vendorcode, goods_grp_id]
  );

  if (!rows.length) {
    throw new AppError('Failed to update group for goods', 500);
  }

  const result = rows[0];
  return {
    vendorcode: result.vendorcode,
    goods_grp_id: result.goods_grp_id
  };
}

export async function getGoodsTypes(locale = 'ru') {
  const { rows } = await pool.query(
    'SELECT id, active, name_ru, description_ru, name_en, description_en FROM goods_type_active_multilang ORDER BY id'
  );

  return rows.map(row => ({
    id: row.id,
    goods_type_name: locale === 'en' ? row.name_en : row.name_ru,
    goods_type_desc: locale === 'en' ? row.description_en : row.description_ru
  }));
}