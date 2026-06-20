import axios from 'axios';
import { pool } from '../../config/db.config.js';
import apiConfig from '../../config/api.config.js';
import { getApiKeyByUser } from '../apiKey.service.js';
import { syncTableToDB } from '../../utils/tableSync.utils.js';
import { toSnakeCase } from '../../utils/common.utils.js';
import { getWeekNumber, formatDateRange } from '../../utils/date.utils.js';
import { transposeByKey, addFields, cleanData, formatCurrency } from '../../utils/array.utils.js';
import { getUserLocale, getLocaleStrings } from '../db/db.service.js';
import { translateField } from '../../utils/array.utils.js';
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
    nullIfEmpty: ['fixTariffDateFrom', 'fixTariffDateTo', 'vendorCode']
  });

  const { rows } = await pool.query(
    'SELECT * FROM sync_wb_fi_report_details($1, $2)',
    [userId, JSON.stringify(toSnakeCase(filtered))]
  );

  return rows[0];
}


/**
 * Get WB FI report summaries
 */
export async function getWBFinReportSummary(userId, { reportId, limit } = {}) {
  let rows;

  if (reportId) {
    const { rows: result } = await pool.query(
      `SELECT * FROM wb_fi_report_summary_view WHERE user_id = $1 AND report_id = $2`,
      [userId, reportId]
    );
    rows = result;
  } else if (limit) {
    const { rows: result } = await pool.query(
      `SELECT * FROM wb_fi_report_summary_view WHERE user_id = $1 ORDER BY report_id DESC LIMIT $2`,
      [userId, limit]
    );
    rows = result;
  } else {
    throw new AppError('Either reportId or limit is required', 400);
  }

  // 1. Добавляем вычисляемые поля
  const enriched = rows.map(row => ({
    ...row,
    report_week: `WEEK${getWeekNumber(row.date_from)}`,
    report_dates: formatDateRange(row.date_from, row.date_to)
  }));

  // 2. Удаляем служебные поля
  const cleaned = cleanData(enriched, {
    exclude: ['user_id', 'date_from', 'date_to', 'created_at', 'updated_at']
  });

  // 3. Форматируем числа в валюту (кроме report_id — он ключ)
  const formatted = cleaned.map(row => {
    const result = {};
    for (const key in row) {
      result[key] = key === 'report_id' || key === 'report_week' || key === 'report_dates'
        ? row[key]
        : formatCurrency(row[key]);
    }
    return result;
  });

  // 4. Транспонируем
  const transposed = transposeByKey(formatted, 'report_id', 'field', ['report_week', 'report_dates']);

  // 5. Получаем локаль пользователя и переводим field
  const locale = await getUserLocale(userId);
  const fieldNames = transposed.map(row => row.field);
  const translations = await getLocaleStrings(fieldNames, locale);
  const translated = translateField(transposed, 'field', translations);

  return translated;
}

/**
 * Обработать финотчёт WB (расчёт распределения затрат)
 */
export async function calculateWBReport(userId, reportId) {
  const { rows } = await pool.query(
    'SELECT * FROM process_wb_report_details($1, $2)',
    [userId, reportId]
  );

  const { processed_count, summary_updated, unmatched_count, unmatched_sample } = rows[0];

  return {
    success: true,
    processedCount: processed_count,
    summaryUpdated: summary_updated,
    unmatchedCount: unmatched_count,
    unmatchedSample: unmatched_sample || []
  };
}