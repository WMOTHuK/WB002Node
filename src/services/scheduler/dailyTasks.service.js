// src/services/scheduler/dailyTasks.service.js
import { pool } from '../../config/db.config.js';
import { logger } from '../../utils/logger.js';
import { syncOzonGoods, syncWBGoods} from '../goods/goods.service.js';
import { syncCampaigns, syncCampaignCosts } from '../crm/crm.service.js';
import { syncWBFinReports, syncWBFinReportDetails, calculateWBReport } from '../fi/wbReports.service.js';
import { syncOzonAccrualTypes } from '../fi/ozonReports.service.js';


async function runTask(userId, taskName, fn, ...args) {
  logger.info(`[${userId}] Запуск: ${taskName}`);
  try {
    const resolvedArgs = args.map(arg => typeof arg === 'function' ? arg() : arg);
    const result = await fn(userId, ...resolvedArgs);
    logger.info(`[${userId}] ${taskName}: ${JSON.stringify(result)}`);
    return result;
  } catch (error) {
    logger.error(`[${userId}] Ошибка: ${taskName}`, error.message);
    return { success: false, error: error.message };
  }
}

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
 * Получить дату 2 недель назад в формате YYYY-MM-DD
 */
function twoWeeksAgo() {
  const d = new Date();
  d.setDate(d.getDate() - 14);
  return d.toISOString().split('T')[0];
}

/**
 * Получить текущую дату в формате YYYY-MM-DD
 */
function today() {
  return new Date().toISOString().split('T')[0];
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

  const results = {};

  results['Товары WB'] = await runTask(userId, 'Товары WB', syncWBGoods);
  results['Товары Ozon'] = await runTask(userId, 'Товары Ozon', syncOzonGoods);
  results['Кампании'] = await runTask(userId, 'Кампании', syncCampaigns);
  results['Затраты'] = await runTask(userId, 'Затраты', syncCampaignCosts, twoWeeksAgo, today);
  results['Финотчёты'] = await runTask(userId, 'Финотчёты', processUserFinReports);
  results['Начисления Ozon'] = await runTask(userId, 'Начисления Ozon', syncOzonAccrualTypes);

  const succeeded = [];
  const failed = [];

  for (const [task, result] of Object.entries(results)) {
    if (result?.success === false) {
      failed.push({ task, error: result.error });
    } else {
      succeeded.push({ task, result });
    }
  }

  logger.info(`--- Синхронизация для пользователя ${userId} завершена ---`);

  return {
    success: failed.length === 0,
    succeeded,
    failed: failed.length > 0 ? failed : undefined
  };
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