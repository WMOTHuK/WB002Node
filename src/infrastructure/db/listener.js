// src/infrastructure/db/listener.js
import { Client } from 'pg';
import { logger } from '../../utils/logger.js';

let dbListener = null;

export const initDbListener = async (scheduler) => {
  if (dbListener) return dbListener;

  dbListener = new Client({
    connectionString: process.env.DB_URL,
  });

  await dbListener.connect();
  dbListener.query('LISTEN campaign_updated');
  
  dbListener.on('notification', async (msg) => {
    try {
      const data = JSON.parse(msg.payload);
      if (data.active) {
        await scheduler.scheduleCampaign({
          advertid: data.advertid,
          crmname: data.crmname,
          pause_time: data.pause_time,
          restart_time: data.restart_time
        });
        logger.info(`Обновлено планирование для компании ${data.advertid} (${data.crmname})`);
      } else {
        scheduler.cancelCampaignJobs(data.advertid);
        logger.info(`Отменено планирование для компании ${data.advertid} (${data.crmname})`);
      }
    } catch (error) {
      logger.error('Error handling campaign update:', error);
    }
  });

  logger.info('DB Listener инициализирован');
  return dbListener;
};

export const closeDbListener = async () => {
  if (dbListener) {
    await dbListener.end();
    dbListener = null;
  }
};