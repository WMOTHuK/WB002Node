// src/services/apiKey.service.js
import { pool } from '../../General/globals.js';
import { decrypt } from '../../utils/crypto.js';
import { AppError } from '../utils/errors.js'

// Типы ключей
export const KEY_TYPE = {
  WB_CRM_API: 1,
  OZON_CRM_API: 2,
  // Добавь остальные по мере необходимости
};

/**
 * Получить и расшифровать API-ключ по кампании (advertId)
 * Используется планировщиком для паузы/рестарта кампаний
 */
export async function getCrmApiKey(advertId) {
  const { rows } = await pool.query(`
    SELECT uak.api_key 
    FROM user_api_keys uak
    JOIN crm_headers ch ON ch.user_id = uak.user_id
    WHERE ch.advertid = $1 AND uak.key_type = $2
  `, [advertId, KEY_TYPE.WB_CRM_API]);

  if (!rows.length) {
    throw new AppError(`CRM API key not found for campaign ${advertId}`, 404);
  }
  
  return decrypt(rows[0].api_key);
}

/**
 * Получить и расшифровать API-ключ по пользователю и типу
 * Используется cron-задачами и другими сервисами
 */
export async function getApiKeyByUser(userId, keyType) {
  const { rows } = await pool.query(
    `SELECT api_key FROM user_api_keys WHERE user_id = $1 AND key_type = $2`,
    [userId, keyType]
  );

  if (!rows.length) {
    throw new AppError(`API key not found for user ${userId}, type ${keyType}`, 404);
  }

  return decrypt(rows[0].api_key);
}