import axios from 'axios';
import { pool } from '../../config/db.config.js';
import apiConfig from '../../config/api.config.js';
import { getApiKeyByUser } from '../apiKey.service.js';
import { syncTableToDB } from '../../utils/tableSync.utils.js';
import { toSnakeCase } from '../../utils/common.utils.js';


/**
 * Загрузить и синхронизировать список финансовых отчётов WB
 */
export async function syncWBFinReports(userId, dateFrom, dateTo) {
  const apiKey = await getApiKeyByUser(userId, '5');

  const { data } = await axios.post(apiConfig.wbFinReportsList, {
    dateFrom,
    dateTo,
    period: 'weekly'
  }, {
    headers: { Authorization: `Bearer ${apiKey}` }
  });

  const { rows } = await pool.query(
    'SELECT * FROM sync_wb_fi_report_headers($1, $2)',
    [userId, JSON.stringify(toSnakeCase(data))]
  );

  return rows[0];
}


/**
 * Загрузить и синхронизировать список финансовых отчётов WB
 */
export async function syncCampaignCosts(userId, dateFrom, dateTo) {
  const apiKey = await getApiKeyByUser(userId, 'wbcrmkey');

  const { data } = await axios.get(apiConfig.wbCampaignCostsUrl, {
    params: { from: dateFrom, to: dateTo },
    headers: { Authorization: `Bearer ${apiKey}` }
  });

  const filtered = data.map(item => {
    const clean = {};
    for (const key in item) {
      if (!EXCLUDE_KEYS.includes(key)) {
        clean[key] = item[key];
      }
    }
    return clean;
  });

  const { rows } = await pool.query(
    'SELECT * FROM sync_crm_campaign_costs($1)',
    [JSON.stringify(toSnakeCase(filtered))]
  );

  return rows[0];
}

/**
 * Получить список отчётов WB из БД
 */
export async function getWBFinReports(userId, limit = 30) {
  const { rows } = await pool.query(
    'SELECT * FROM wb_fi_report_headers_view WHERE user_id = $1 LIMIT $2',
    [userId, limit]
  );
  return rows;
}