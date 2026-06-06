// src/utils/logger.js
import { pool } from '../config/db.config.js';
import fs from 'fs/promises';
import path from 'path';
import axios from 'axios';

const TELEGRAM_TOKEN = process.env.TELEGRAM_TOKEN;
const TELEGRAM_CHAT_ID = process.env.TELEGRAM_CHAT_ID;
const TELEGRAM_URL = TELEGRAM_TOKEN
  ? `https://api.telegram.org/bot${TELEGRAM_TOKEN}/sendMessage`
  : null;

const LOG_LEVELS = { ERROR: 0, WARN: 1, INFO: 2, DEBUG: 3 };
const currentLevel = process.env.LOG_LEVEL || 'INFO';

const shouldLog = (level) => LOG_LEVELS[level] <= LOG_LEVELS[currentLevel];

// ---------------------------------------------------------------------------
// Ядро
// ---------------------------------------------------------------------------

async function writeLog(level, message, details = {}) {
  if (!shouldLog(level)) return;

  const timestamp = new Date();
  const dateString = timestamp.toLocaleDateString('en-GB').replace(/\//g, '.');
  const timeString = timestamp.toLocaleTimeString('en-GB');
  const logText = `${dateString} ${timeString}, ${level}, ${message}\n`;

  // Консоль
  const consoleMethod = level === 'ERROR' ? 'error' : level === 'WARN' ? 'warn' : 'log';
  console[consoleMethod](`[${level}]`, message, details);

  // Файл
  try {
    const logDir = path.join(process.cwd(), 'logs');
    await fs.mkdir(logDir, { recursive: true });
    await fs.appendFile(path.join(logDir, 'log.txt'), logText);
  } catch (error) {
    console.error('Error writing to log file:', error.message);
  }

  // БД
  try {
    await pool.query(
      `INSERT INTO logs (date, time, "end", func, message) VALUES ($1, $2, $3, $4, $5)`,
      [
        timestamp.toISOString().split('T')[0],
        timeString,
        '2',              // ← было 'backend', стало '2' (backend)
        level,
        typeof message === 'object' ? JSON.stringify(message) : String(message)
      ]
    );
  } catch (error) {
    console.error('Error inserting log into DB:', error.message);
  }

  // Telegram (только ошибки)
  if (level === 'ERROR' && TELEGRAM_URL) {
    try {
      await axios.post(TELEGRAM_URL, {
        chat_id: TELEGRAM_CHAT_ID,
        text: `[${level}] ${message}`,
      });
    } catch (error) {
      console.error('Error sending to Telegram:', error.message);
    }
  }
}

// ---------------------------------------------------------------------------
// Публичный API
// ---------------------------------------------------------------------------

export const logger = {
  error: (message, details) => writeLog('ERROR', message, details),
  warn: (message, details) => writeLog('WARN', message, details),
  info: (message, details) => writeLog('INFO', message, details),
  debug: (message, details) => writeLog('DEBUG', message, details),
};

// Для обратной совместимости со старым кодом (если где-то ещё используется)
export async function sendlogTG(message) {
  logger.info(message);
}

export async function logMessage(functionName, end, message) {
  const prefix = end === 1 ? '[FRONTEND]' : '[BACKEND]';
  logger.info(`${prefix} ${functionName}: ${message}`);
}