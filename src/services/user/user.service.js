// src/services/user/user.service.js
import { pool } from '../../config/db.config.js';

/**
 * Обновить налоговые ставки пользователя
 */
export async function changeUserTaxRates(userId, { sellerTax, vatTax, validFrom }) {
  const { rows } = await pool.query(
    'SELECT * FROM upsert_user_tax_rate($1, $2, $3, $4)',
    [userId, sellerTax ?? null, vatTax ?? null, validFrom]
  );
  return rows[0];
}

/**
 * Сменить локаль пользователя
 */
export async function changeUserLocale(userId, locale, changedBy = null) {
  const { rows } = await pool.query(
    'SELECT * FROM update_user_locale($1, $2, $3)',
    [userId, locale, changedBy]
  );
  return rows[0];
}

/**
 * Получить настройки пользователя на дату
 */
export async function getUserSettings(userId, date) {
  const { rows } = await pool.query(
    'SELECT * FROM get_user_settings($1, $2)',
    [userId, date]
  );
  return rows;
}