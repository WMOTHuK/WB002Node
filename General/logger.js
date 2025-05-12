// logger.js


import { pool } from './globals.js';
import fs from 'fs/promises';
import path from 'path';
import { fileURLToPath } from 'url';
import axios from 'axios';
const TELEGRAM_TOKEN = '7095039676:AAH9dSZOsoQWcw_U2Qfd-KLimh5JGW8ZzLs';
const CHAT_ID = '-1002034663703';
const TELEGRAM_URL = `https://api.telegram.org/bot${TELEGRAM_TOKEN}/sendMessage`;

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

// Функция логирования
async function logMessage(functionName, end, message) {
  const timestamp = new Date();
  const dateString = timestamp.toLocaleDateString('en-GB').replace(/\//g, '.');
  const timeString = timestamp.toLocaleTimeString('en-GB');
  const endString = end === 1 ? 'frontend' : 'backend';

  // Форматируем сообщение для файла
  const logMessageText = Array.isArray(message) ? message.join(', ') : message;
  const fileLog = `${dateString} ${timeString}, ${endString}, ${functionName}, ${logMessageText}\n`;

  // Запись в файл
  const logFilePath = path.join(__dirname, '..', 'logs', 'log.txt');
  try {
    await fs.appendFile(logFilePath, fileLog);
  } catch (error) {
    console.error(`Error appending to log file: ${error}`);
  }

  // Запись в базу данных
  try {
    const dbLog = {
      date: timestamp.toISOString().split('T')[0], // YYYY-MM-DD
      time: timestamp.toISOString().split('T')[1].split('.')[0], // HH:MM:SS
      end, // 1 или 2, без подмены
      func: functionName,
      message: logMessageText,
    };

    await pool.query(
      'INSERT INTO logs (date, time, "end", func, message) VALUES ($1, $2, $3, $4, $5)',
      [dbLog.date, dbLog.time, dbLog.end, dbLog.func, dbLog.message]
    );
  } catch (err) {
    console.error('Error inserting log into database:', err);
  }
}

export { logMessage };




async function sendlogTG(message) {
  try {
    const response = await axios.post(TELEGRAM_URL, {
      chat_id: CHAT_ID,
      text: message,
    });
  } catch (error) {
    console.error('Ошибка при отправке сообщения', error);
  }
}
export { sendlogTG };