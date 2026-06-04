// src/utils/db/dbViews.utils.js
import { pool } from '../../../General/globals.js';
import { db } from '../sql.utils.js';
import { logger } from '../logger.js';

const ALLOWED_VIEWS = ['product_data'];

function validateView(viewName) {
  if (!ALLOWED_VIEWS.includes(viewName)) {
    throw new Error(`VIEW "${viewName}" не разрешён для прямого доступа`);
  }
}

/**
 * Получить все данные из VIEW
 * @param {string} viewName - Название VIEW
 * @returns {Promise<Array>}
 */
export async function getViewData(viewName) {
  try {
    validateView(viewName);
    const { rows } = await db.select(viewName);
    return rows;
  } catch (error) {
    logger.error(`Ошибка получения данных из ${viewName}:`, error.message);
    throw error;
  }
}

/**
 * Получить данные из VIEW с пагинацией
 * @param {string} viewName
 * @param {Object} [options] - { limit, offset }
 * @returns {Promise<{data: Array, pagination: Object}>}
 */
export async function getViewDataPaginated(viewName, options = {}) {
  try {
    validateView(viewName);
    const { limit = 100, offset = 0 } = options;

    const [dataResult, countResult] = await Promise.all([
      pool.query(`SELECT * FROM ${viewName} LIMIT $1 OFFSET $2`, [limit, offset]),
      pool.query(`SELECT COUNT(*) as total FROM ${viewName}`)
    ]);

    return {
      data: dataResult.rows,
      pagination: {
        total: parseInt(countResult.rows[0].total),
        limit,
        offset,
        hasMore: offset + limit < parseInt(countResult.rows[0].total)
      }
    };
  } catch (error) {
    logger.error(`Ошибка получения данных из ${viewName}:`, error.message);
    throw error;
  }
}

/**
 * Получить товар по vendorcode
 * @param {string} vendorcode
 * @returns {Promise<Object|null>}
 */
export async function getProductByVendorCode(vendorcode) {
  try {
    const { rows } = await pool.query(
      `SELECT * FROM product_data WHERE vendorcode = $1`,
      [vendorcode]
    );
    return rows[0] || null;
  } catch (error) {
    logger.error(`Ошибка получения товара ${vendorcode}:`, error.message);
    throw error;
  }
}