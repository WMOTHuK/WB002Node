// src/infrastructure/scheduler/index.js
import { initSimpleScheduler } from '../../../services/scheduler/simplescheduler.js';
import { logger } from '../../utils/logger.js';

export const initSchedulers = () => {
  try {
    initSimpleScheduler();
    logger.info('Планировщик инициализирован');
  } catch (error) {
    logger.error('Ошибка инициализации планировщика:', error);
    throw error;
  }
};