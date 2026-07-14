// src/services/fi/ozonReports.service.js
import axios from 'axios';
import { pool } from '../../config/db.config.js';
import apiConfig from '../../config/api.config.js';
import { getApiKeyByUser } from '../apiKey.service.js';

/**
 * Синхронизировать типы начислений Ozon
 */
export async function syncOzonAccrualTypes(userId) {
  const apiKey = await getApiKeyByUser(userId, apiConfig.ozonfinancekey);
  const clientId = await getApiKeyByUser(userId, apiConfig.ozonclientid);

  const { data } = await axios.post(
    apiConfig.ozonAccrualTypesUrl,
    { language: 'RU' },
    {
      headers: {
        'Client-Id': clientId,
        'Api-Key': apiKey,
        'Content-Type': 'application/json'
      }
    }
  );

;

  const { rows } = await pool.query(
    'SELECT * FROM sync_ozon_accural_types($1)',
    [JSON.stringify(data.accrual_types)]
  );

  return rows[0];
}