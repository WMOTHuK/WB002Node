  // server.js

  import 'dotenv/config';
  import express, { json } from 'express';
  import './services/scheduler/repricer.js';
  import cors from 'cors';
  import authRoutes from './routes/auth.js';
  import apiKeysRoutes from './routes/apiKeys.js'; 
  import { authenticate } from './middleware/auth.js';
  import contentRoutes from './routes/contentRoutes.js';
  import CRMRoutes from './routes/CRMRoutes.js';
  import dbRoutes from './routes/dbRoutes.js';
  import scheduler from './services/scheduler/scheduler.service.js';
  import { Client } from 'pg';
  import { initScheduler } from './services/scheduler/simplescheduler.js';
import { sendlogTG } from './General/logger.js';

// Отключил, пока не используем (ОСТАНОВКА КАМПАНИЙ)
/*   scheduler; // Инициализирует сложный планировщик */


  initScheduler(); // Инициализирует простой планировщик


  const app = express();
  const PORT = process.env.PORT || 5000;

  // Middleware
  app.use(cors());
  app.use(express.json());

  // Routes

  app.use(json()); // Для парсинга JSON в запросах

  app.use('/api/auth', authRoutes);
  app.use('/api/auth', authenticate, apiKeysRoutes); // Защищенный маршрут
  app.use('/api/content', authenticate, contentRoutes); // Защищенный маршрут
  app.use('/api/CRM', authenticate, CRMRoutes); // Защищенный маршрут
  app.use('/api/DB', authenticate, dbRoutes); // Защищенный маршрут




    app.listen(PORT, () => {
      const logMes = (`Сервер запущен. Порт: ${PORT}`)
      sendlogTG(logMes);
      console.log(logMes);
// Отключил, пока не используем (ОСТАНОВКА КАМПАНИЙ)
/*       // Запускаем периодическую проверку
      setInterval(async () => {
        const activeCampaigns = await pool.query(`
          SELECT advertid, crmname, pause_time, restart_time 
          FROM crm_headers 
          WHERE active = true
        `);
        
        activeCampaigns.rows.forEach(campaign => {
          scheduler.scheduleCampaign(campaign);
        });
      }, 5 * 60 * 1000); */
    });
    const dbListener = new Client({
      connectionString: process.env.DB_URL,
    });



// Отключил, пока не используем (ОСТАНОВКА КАМПАНИЙ)
/*   // Для периодической синхронизации
  setInterval(async () => {
    const activeCampaigns = await pool.query(`
      SELECT advertid, pause_time, restart_time 
      FROM crm_headers 
      WHERE active = true
    `);
    
    for (const campaign of activeCampaigns.rows) {
      await scheduler.scheduleCampaign(campaign);
    }
  }, 5 * 60 * 1000); // Каждые 5 минут
 */

/*     await dbListener.connect();
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
          let loggingMessage = `Обновлено планирование для компании ${data.advertid} (${data.crmname})`;
          logMessage('DBLISTENER', '1', loggingMessage);
          sendlogTG(loggingMessage)
        } else {
          scheduler.cancelCampaignJobs(data.advertid);
          let loggingMessage = `Отменено планирование для компании ${data.advertid} (${data.crmname})`;
          logMessage('DBLISTENER', '1', loggingMessage);
          sendlogTG(loggingMessage)
        }
      } catch (error) {
        let loggingMessage = 'Error handling campaign update: ${error}';
        logMessage('DBLISTENER', '1', loggingMessage);
        sendlogTG(loggingMessage)
      }
    }); */