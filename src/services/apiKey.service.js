// src/services/apiKey.service.js
import { pool } from '../config/db.config.js';
import { db } from '../utils/sql.utils.js';
import { encrypt, decrypt } from '../utils/crypto.utils.js';
import { AppError } from '../utils/errors.js';


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


/**
 * Получить справочник типов ключей
 */
export async function getKeyTypes() {
  const { rows } = await db.select('api_key_types');
  return rows.map(item => ({
    key_type: item.key_type,
    key_text: item.key_text
  }));
}

/**
 * Получить ключи пользователя
 */
export async function getUserApiKeys(userLogin) {
  const { rows } = await pool.query(`
    SELECT uak.key_type, uak.updated_at
    FROM user_api_keys uak
    JOIN users u ON uak.user_id = u.id
    WHERE u.login = $1
  `, [userLogin]);

  return rows.map(item => ({
    key_type: item.key_type,
    updated_at: item.updated_at.toISOString()
  }));
}

/**
 * Сохранить API-ключ пользователя (insert или update)
 */
export async function saveUserApiKey(userId, keyType, apiKey) {
  const encryptedKey = encrypt(apiKey);

  const { rows } = await db.select('user_api_keys', { user_id: userId, key_type: keyType });

  if (rows.length === 0) {
    await db.insert('user_api_keys', {
      user_id: userId,
      key_type: keyType,
      api_key: encryptedKey,
      created_at: new Date(),
      updated_at: new Date()
    });
    return { created: true };
  } else {
    await db.update('user_api_keys',
      { api_key: encryptedKey, updated_at: new Date() },
      { user_id: userId, key_type: keyType }
    );
    return { created: false };
  }
}
