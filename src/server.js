// src/server.js
import 'dotenv/config';
import { app } from './app.js';
import { initScheduler } from './infrastructure/scheduler/index.js';
import { initDbListener } from './infrastructure/db/listener.js';
import { logger } from './utils/logger.js';

const PORT = process.env.PORT || 5000;

const startServer = async () => {
  try {
    // Инициализация планировщиков
    initScheduler();

    // Инициализация DB Listener (раскомментируй, когда нужно)
    // await initDbListener(scheduler);

    // Запуск сервера
    const server = app.listen(PORT, () => {
      logger.info(`Сервер запущен. Порт: ${PORT}`);
    });

    // Graceful shutdown
    const shutdown = async (signal) => {
      logger.info(`Получен сигнал ${signal}, завершаем работу...`);
      server.close(async () => {
        await closeDbListener();
        logger.info('Сервер остановлен');
        process.exit(0);
      });
    };

    process.on('SIGTERM', () => shutdown('SIGTERM'));
    process.on('SIGINT', () => shutdown('SIGINT'));

  } catch (error) {
    logger.error('Ошибка запуска сервера:', error);
    process.exit(1);
  }
};

startServer();