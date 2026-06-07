// src/utils/pricing.utils.js
import { pool } from '../config/db.config.js';
import { db } from './sql.utils.js';
import { logger } from './logger.js';

/**
 * Проверить существование записи и вставить/обновить цену
 * @param {Array} data - Массив объектов с полями nmId, price, discount и др.
 * @returns {Promise<Array>} Сообщения о результатах
 */
export async function checkAndInsertPrice(data) {
  const results = [];

  for (const item of data) {
    try {
      const { rows } = await db.select('prices', { nmid: item.nmId });

      if (rows.length > 0) {
        // Обновление
        const currentPrice = item.price * (1 - item.discount / 100);
        await db.update('prices', {
          price: item.price,
          discount: item.discount,
          promocode: item.promoCode,
          currentprice: currentPrice
        }, { nmid: item.nmId });

        const msg = `Данные о ценах товара ${item.nmId} обновлены в БД`;
        logger.debug(msg);
        results.push(msg);
      } else {
        // Вставка
        await db.insert('prices', {
          nmid: item.nmId,
          price: item.price,
          discount: item.discount,
          promocode: item.promoCode,
          currentprice: item.price * (1 - item.discount / 100),
          dayprice: item.dayprice,
          nightprice: item.nightprice,
          daydisc: item.daydisc,
          nightdisc: item.nightdisc,
          active: item.active
        });

        const msg = `Данные о ценах товара ${item.nmId} записаны в БД`;
        logger.debug(msg);
        results.push(msg);
      }
    } catch (error) {
      logger.error(`Ошибка обработки товара ${item.nmId}:`, error.message);
      results.push(`Ошибка: ${item.nmId} — ${error.message}`);
    }
  }

  return results;
}