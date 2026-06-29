// src/services/goods/pricing.service.js
import { pool } from '../../config/db.config.js';
import { checkAndInsertPrice } from '../../utils/pricing.utils.js';

/**
 * Обновить цены из данных WB
 */
export async function updatePricesFromWB(rawData) {
  const transformed = rawData.map(item => {
    const firstSize = item.sizes?.[0];
    return {
      nmId: item.nmID,
      price: firstSize?.price || 0,
      discount: item.discount,
      promoCode: 0,
      currentprice: firstSize?.discountedPrice || 0,
      dayprice: 0, nightprice: 0,
      daydisc: 0, nightdisc: 0,
      active: ''
    };
  });

  return checkAndInsertPrice(transformed);
}

/**
 * Обновить себестоимость товара
 */
export async function updateCostPrice(vendorcode, platform, newCost, startDate) {
  const { rows } = await pool.query(
    'SELECT * FROM update_cost_price($1, $2, $3, $4)',
    [vendorcode, platform, newCost, startDate]
  );
  return rows[0];
}