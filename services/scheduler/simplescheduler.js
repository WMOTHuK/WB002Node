//services/scheduker/simplesheduler.js
import schedule from 'node-schedule';
import { pauseactivecompaigns } from './jobs/crmjobs.js';
import { sendlogTG } from '../../General/logger.js';

export const initScheduler = () => {
 sendlogTG*('Планировщик задач запущен');
  // Ежедневно в 01:02
 schedule.scheduleJob('2 1 * * *', pauseactivecompaigns.run);
}