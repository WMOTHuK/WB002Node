// src/services/scheduler/simplescheduler.js
import schedule from 'node-schedule';
import { pauseActiveCampaigns } from './jobs/crmjobs.js';
import { logger } from '../../utils/logger.js';

const DEFAULT_CRON = '02 01 * * *'; // Каждый день в 01:02

export const initSimpleScheduler = () => {
  const cronExpression = process.env.PAUSE_CRON || DEFAULT_CRON;
  
  schedule.scheduleJob(cronExpression, async () => {
    try {
      await pauseActiveCampaigns.run();
    } catch (error) {
      logger.error('Ошибка выполнения pauseActiveCampaigns:', error.message);
    }
  });
  
  logger.info(`Планировщик задач запущен (cron: ${cronExpression})`);
};