// dbViews.js - ES Modules версия

/**
 * Получение всех данных из указанного VIEW
 * @param {Object} pool - Пул соединений с PostgreSQL
 * @param {string} viewName - Название VIEW
 * @returns {Promise<Array>} - Массив записей из VIEW
 */
export const getViewData = async (pool, viewName) => {
  try {
    // Валидация имени VIEW
    const validViews = ['product_data']; // список разрешенных VIEW
    if (!validViews.includes(viewName)) {
      throw new Error(`VIEW ${viewName} не разрешен для прямого доступа`);
    }
    
    const { rows } = await pool.query(`SELECT * FROM ${viewName}`);
    return rows;
  } catch (error) {
    console.error(`Ошибка при получении данных из ${viewName}:`, error);
    throw error;
  }
};

/**
 * Получение данных с пагинацией
 * @param {Object} pool - Пул соединений с PostgreSQL
 * @param {string} viewName - Название VIEW
 * @param {Object} options - Опции (limit, offset)
 * @returns {Promise<Object>} - Объект с данными и пагинацией
 */
export const getViewDataPaginated = async (pool, viewName, options = {}) => {
  try {
    const { limit = 100, offset = 0 } = options;
    
    const validViews = ['product_data'];
    if (!validViews.includes(viewName)) {
      throw new Error(`VIEW ${viewName} не разрешен для прямого доступа`);
    }
    
    const query = `SELECT * FROM ${viewName} LIMIT $1 OFFSET $2`;
    const countQuery = `SELECT COUNT(*) as total FROM ${viewName}`;
    
    const [dataResult, countResult] = await Promise.all([
      pool.query(query, [limit, offset]),
      pool.query(countQuery)
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
    console.error(`Ошибка при получении данных из ${viewName}:`, error);
    throw error;
  }
};

/**
 * Получение конкретной записи по vendorcode
 * @param {Object} pool - Пул соединений с PostgreSQL
 * @param {string} vendorcode - Артикул товара
 * @returns {Promise<Object|null>} - Объект товара или null
 */
export const getProductByVendorCode = async (pool, vendorcode) => {
  try {
    const query = `SELECT * FROM product_data WHERE vendorcode = $1`;
    const { rows } = await pool.query(query, [vendorcode]);
    return rows[0] || null;
  } catch (error) {
    console.error(`Ошибка при получении товара ${vendorcode}:`, error);
    throw error;
  }
};

// Экспорт по умолчанию (опционально)
export default {
  getViewData,
  getViewDataPaginated,
  getProductByVendorCode
};