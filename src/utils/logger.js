// src/utils/logger.js
import { sendlogTG } from '../../General/logger.js';  // путь к твоему текущему логгеру

const LOG_LEVELS = {
  ERROR: 0,
  WARN: 1,
  INFO: 2,
  DEBUG: 3
};

const currentLevel = process.env.LOG_LEVEL || 'INFO';

const shouldLog = (level) => {
  return LOG_LEVELS[level] <= LOG_LEVELS[currentLevel];
};

export const logger = {
  error: (message, ...args) => {
    if (shouldLog('ERROR')) {
      console.error(`[ERROR]`, message, ...args);
    }
  },

  warn: (message, ...args) => {
    if (shouldLog('WARN')) {
      console.warn(`[WARN]`, message, ...args);
    }
  },

  info: (message, ...args) => {
    if (shouldLog('INFO')) {
      console.log(`[INFO]`, message, ...args);
    }
  },

  debug: (message, ...args) => {
    if (shouldLog('DEBUG')) {
      console.debug(`[DEBUG]`, message, ...args);
    }
  }
};