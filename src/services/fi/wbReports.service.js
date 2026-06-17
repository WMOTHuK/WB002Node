import axios from 'axios';
import { pool } from '../../config/db.config.js';
import apiConfig from '../../config/api.config.js';
import { getApiKeyByUser } from '../apiKey.service.js';
import { syncTableToDB } from '../../utils/tableSync.utils.js';
import { toSnakeCase } from '../../utils/common.utils.js';
import { cleanData } from '../../utils/array.utils.js';

/**
 * Загрузить и синхронизировать список финансовых отчётов WB
 */
export async function syncWBFinReports(userId, dateFrom, dateTo) {
  const apiKey = await getApiKeyByUser(userId, apiConfig.wbfinancekey);

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
 * Получить список отчётов WB из БД
 */
export async function getWBFinReports(userId, limit = 30) {
  const { rows } = await pool.query(
    'SELECT * FROM wb_fi_report_headers_view WHERE user_id = $1 LIMIT $2',
    [userId, limit]
  );
  return rows;
}
/**
 * Загрузить и синхронизировать детализацию финотчёта WB
 */
export async function syncWBFinReportDetails(userId, reportId) {
  const apiKey = await getApiKeyByUser(userId, apiConfig.wbfinancekey);
  const url = `${apiConfig.wbFinReportDetails}/${reportId}`;
  const { data } = await axios.post(url,
    {
      limit: 100000,
      rrdId: 0
    },
    {
      headers: { Authorization: `Bearer ${apiKey}` }
    }
  );

  const filtered = cleanData(Array.isArray(data) ? data : [], {
    exclude: ['title'],
    nullIfEmpty: ['fixTariffDateFrom', 'fixTariffDateTo']
  });

  const { rows } = await pool.query(
    'SELECT * FROM sync_wb_fi_report_details($1, $2)',
    [userId, JSON.stringify(toSnakeCase(filtered))]
  );

  return rows[0];
}

