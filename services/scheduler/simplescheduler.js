//services/scheduler/simplesheduler.js
import schedule from 'node-schedule';
import { pauseactivecompaigns } from './jobs/crmjobs.js';
import { sendlogTG } from '../../General/logger.js';

export const initScheduler = () => {
 //sendlogTG*('Планировщик задач запущен');
 console.log('Планировщик задач запущен') 
 // Ежедневно в 01:02
 schedule.scheduleJob('02 01 * * *', pauseactivecompaigns.run);
}