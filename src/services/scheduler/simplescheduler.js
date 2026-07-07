import schedule from 'node-schedule';
import { pauseActiveCampaigns } from './jobs/crmjobs.js';
import { logger } from '../../utils/logger.js';
import { runDailyTasks } from './dailyTasks.service.js';

const DEFAULT_PAUSE_CRON = '02 01 * * *';
const DEFAULT_DAILY_CRON = '0 12 * * *'; // 12:00 МСК

export const initSimpleScheduler = () => {
  const pauseCron = process.env.PAUSE_CRON || DEFAULT_PAUSE_CRON;
  const dailyCron = process.env.DAILY_CRON || DEFAULT_DAILY_CRON;

  // Ежедневная пауза кампаний
  schedule.scheduleJob(pauseCron, async () => {
    try {
      await pauseActiveCampaigns.run();
    } catch (error) {
      logger.error('Ошибка выполнения pauseActiveCampaigns:', error.message);
    }
  });

  // Ежедневные задачи синхронизации (12:00 МСК)
  schedule.scheduleJob(dailyCron, async () => {
    try {
      await runDailyTasks();
    } catch (error) {
      logger.error('Ошибка выполнения dailyTasks:', error.message);
    }
  });

  logger.info(`Планировщик запущен: пауза "${pauseCron}", синхронизация "${dailyCron}"`);
};