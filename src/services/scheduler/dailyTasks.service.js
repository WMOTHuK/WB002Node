// src/services/scheduler/dailyTasks.service.js
import { pool } from '../../config/db.config.js';
import { logger } from '../../utils/logger.js';
import { syncUserGoods } from '../goods/goods.service.js';
import { syncCampaigns, syncCampaignCosts } from '../crm/crm.service.js';
import { syncWBFinReports, syncWBFinReportDetails, calculateWBReport } from '../fi/wbReports.service.js';

/**
 * Получить всех пользователей
 */
async function getAllUserIds() {
  const { rows } = await pool.query('SELECT id FROM users');
  return rows.map(r => r.id);
}

/**
 * Получить дату N дней назад в формате YYYY-MM-DD
 */
function daysAgo(n) {
  const d = new Date();
  d.setDate(d.getDate() - n);
  return d.toISOString().split('T')[0];
}

/**
 * Проверить, есть ли детали отчёта в БД
 */
async function hasReportDetails(userId, reportId) {
  const { rows } = await pool.query(
    'SELECT EXISTS (SELECT 1 FROM wb_fi_report_details WHERE user_id = $1 AND report_id = $2) AS has_details',
    [userId, reportId]
  );
  return rows[0].has_details;
}

/**
 * Задержка
 */
function delay(ms) {
  return new Promise(resolve => setTimeout(resolve, ms));
}

/**
 * Загрузить детали и выполнить расчёт для отчётов без деталей
 */
async function syncMissingReportDetails(userId, reportIds) {
  for (const reportId of reportIds) {
    const hasDetails = await hasReportDetails(userId, reportId);
    if (!hasDetails) {
      logger.info(`[DAILY] Загружаем детали отчёта ${reportId} для пользователя ${userId}`);
      await syncWBFinReportDetails(userId, reportId);
      logger.info(`[DAILY] Выполняем расчёт отчёта ${reportId} для пользователя ${userId}`);
      await calculateWBReport(userId, reportId);
      await delay(2 * 60 * 1000); // 2 минуты
    } else {
      logger.info(`[DAILY] Детали отчёта ${reportId} уже есть, пропускаем`);
    }
  }
}

/**
 * Выполнить все задачи синхронизации для одного пользователя
 */
export async function runDailyTasksForUser(userId) {
  logger.info(`--- Запуск синхронизации для пользователя ${userId} ---`);

  const results = {
    goods: null,
    campaigns: null,
    campaignCosts: null,
    finReports: null
  };

  // 1. Товары
  try {
    logger.info(`[${userId}] Синхронизация товаров`);
    results.goods = await syncUserGoods(userId);
    logger.info(`[${userId}] Товары: WB ${JSON.stringify(results.goods.wb)}, OZON ${JSON.stringify(results.goods.ozon)}`);
  } catch (error) {
    logger.error(`[${userId}] Ошибка синхронизации товаров:`, error.message);
    results.goods = { error: error.message };
  }

  // 2. Кампании
  try {
    logger.info(`[${userId}] Синхронизация кампаний`);
    results.campaigns = await syncCampaigns(userId);
    logger.info(`[${userId}] Кампании: ${JSON.stringify(results.campaigns)}`);
  } catch (error) {
    logger.error(`[${userId}] Ошибка синхронизации кампаний:`, error.message);
    results.campaigns = { error: error.message };
  }

  // 3. Затраты на кампании
  try {
    logger.info(`[${userId}] Синхронизация затрат на кампании`);
    results.campaignCosts = await syncCampaignCosts(userId, twoWeeksAgo(), today());
    logger.info(`[${userId}] Затраты на кампании: ${JSON.stringify(results.campaignCosts)}`);
  } catch (error) {
    logger.error(`[${userId}] Ошибка синхронизации затрат:`, error.message);
    results.campaignCosts = { error: error.message };
  }

  // 4. Финотчёты
  try {
    results.finReports = await processUserFinReports(userId);
  } catch (error) {
    logger.error(`[${userId}] Ошибка обработки финотчётов:`, error.message);
    results.finReports = { error: error.message };
  }

  logger.info(`--- Синхронизация для пользователя ${userId} завершена ---`);
  return results;
}
/**
 * Основная ежедневная задача (для всех пользователей)
 */
export async function runDailyTasks() {
  logger.info('=== Запуск ежедневных задач ===');
  const startTime = Date.now();

  try {
    const userIds = await getUserIds();
    logger.info(`Найдено пользователей: ${userIds.length}`);

    for (const userId of userIds) {
      await runDailyTasksForUser(userId);
    }

    const elapsed = ((Date.now() - startTime) / 1000).toFixed(1);
    logger.info(`=== Ежедневные задачи завершены за ${elapsed} сек ===`);
  } catch (error) {
    logger.error('Критическая ошибка ежедневных задач:', error.message);
  }
}

async function processUserFinReports(userId) {
  const dateFrom = twoWeeksAgo();
  const dateTo = today();

  logger.info(`Синхронизация финотчётов для пользователя ${userId} с ${dateFrom} по ${dateTo}`);
  const syncResult = await syncWBFinReports(userId, dateFrom, dateTo);

  const { rows: reports } = await pool.query(
    `SELECT report_id FROM wb_fi_report_headers 
     WHERE user_id = $1 AND date_from >= $2 AND date_to <= $3`,
    [userId, dateFrom, dateTo]
  );

  const missingDetails = [];
  for (const report of reports) {
    const hasDetails = await hasReportDetails(userId, report.report_id);
    if (!hasDetails) {
      missingDetails.push(report);
    }
  }

  if (missingDetails.length > 0) {
    logger.info(`У пользователя ${userId} ${missingDetails.length} отчётов без деталей`);
    await loadReportDetails(userId, missingDetails);
  }

  return {
    reportsCount: reports.length,
    missingDetails: missingDetails.length,
    processed: missingDetails.length
  };
}