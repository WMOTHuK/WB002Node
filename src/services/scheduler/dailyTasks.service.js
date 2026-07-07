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
 * Основная ежедневная задача
 */
export async function runDailyTasks() {
  logger.info('[DAILY] Запуск ежедневных задач');

  const userIds = await getAllUserIds();
  logger.info(`[DAILY] Найдено пользователей: ${userIds.length}`);

  const dateFrom = daysAgo(14);
  const dateTo = daysAgo(0);

  for (const userId of userIds) {
    logger.info(`[DAILY] Обработка пользователя ${userId}`);

    try {
      // 1. Синхронизация товаров
      logger.info(`[DAILY] syncUserGoods для ${userId}`);
      await syncUserGoods(userId);

      // 2. Синхронизация кампаний
      logger.info(`[DAILY] syncCampaigns для ${userId}`);
      await syncCampaigns(userId);

      // 3. Затраты на кампании за 2 недели
      logger.info(`[DAILY] syncCampaignCosts для ${userId} (${dateFrom} – ${dateTo})`);
      await syncCampaignCosts(userId, dateFrom, dateTo);

      // 4. Финотчёты за 2 недели
      logger.info(`[DAILY] syncWBFinReports для ${userId} (${dateFrom} – ${dateTo})`);
      const result = await syncWBFinReports(userId, dateFrom, dateTo);

      // 5. Проверяем детали и догружаем
      if (result?.reportIds?.length) {
        logger.info(`[DAILY] Проверка деталей для ${result.reportIds.length} отчётов`);
        await syncMissingReportDetails(userId, result.reportIds);
      }
    } catch (error) {
      logger.error(`[DAILY] Ошибка обработки пользователя ${userId}:`, error.message);
    }
  }

  logger.info('[DAILY] Ежедневные задачи завершены');
}
