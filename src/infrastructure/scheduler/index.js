// src/infrastructure/scheduler/index.js
import { SchedulerService } from '../../services/scheduler/scheduler.service.js';
import { logger } from '../../utils/logger.js';

let schedulerInstance = null;

export function initScheduler() {
  if (schedulerInstance) return schedulerInstance;
  
  schedulerInstance = new SchedulerService();
  schedulerInstance.restoreScheduledJobs();
  
  logger.info('Планировщик инициализирован');
  return schedulerInstance;
}

export function getScheduler() {
  if (!schedulerInstance) {
    throw new Error('Планировщик не инициализирован');
  }
  return schedulerInstance;
}