  // server.js

  import 'dotenv/config';
  import { pool, allowedTableNames } from './General/globals.js';
  import express, { json } from 'express';
  import { logMessage, sendlogTG} from './General/logger.js';
  import './schedule/repricer.js'
  import cors from 'cors';
  import authRoutes from './routes/auth.js';
  import apiKeysRoutes from './routes/apiKeys.js'; 
  import { authenticate } from './middleware/auth.js';
  import contentRoutes from './routes/contentRoutes.js';
  import CRMRoutes from './routes/CRMRoutes.js';
  import dbRoutes from './routes/dbRoutes.js';
  import scheduler from './services/scheduler/scheduler.service.js';
  import { Client } from 'pg';

  // При старте сервера
  scheduler; // Инициализирует 

  // Для периодической синхронизации
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


  async function checkAndInsertPrice(data) {
  const client = await pool.connect();

  try {
    const results = [];

    for (const item of data) {
      // Проверяем, существует ли запись с таким wbid
      const res = await client.query('SELECT * FROM prices WHERE nmid = $1', [item.nmId]);

      if (res.rows.length > 0) {
        // Если запись существует
        item.currentprice = item.price * (1 - item.discount / 100);
        await client.query(
          'UPDATE prices SET price = $2, discount = $3, promoCode = $4, currentprice = $5 WHERE nmId = $1',
          [item.nmId, item.price, item.discount, item.promoCode, item.currentprice]
        );
        const successMessage = `Данные о ценах товара ${item.nmId} Успешно обновлены в БД`;
  /*       logMessage(checkAndInsertPrice.name, 2, successMessage); // Логирование успешного результата Обновления записи */
        results.push(successMessage);
      } else {
        // Вставляем новую запись, если wbid не найден
        await client.query('INSERT INTO prices(nmId, price, discount, promoCode, currentprice, dayprice, nightprice, daydisc, nightdisc, active) VALUES($1, $2, $3, $4, $5, $6, $7, $8, $9, $10)',
        [item.nmId, item.price, item.discount, item.promoCode, item.currentprice, item.dayprice, item.nightprice, item.daydisc, item.nightdisc, item.active]);
        const successMessage = `Данные о ценах товара ${item.nmId} Успешно записаны в БД`;
        logMessage(checkAndInsertPrice.name, 2, successMessage); // Логирование успешного создания записи
        results.push(successMessage);
      }
    }

    return results;
  } catch (error) {
    return (error.message)  ;
  } finally {
    client.release(); // Освобождаем клиента
  }}

  app.post('/api/save-data/prices', async (req, res) => {
    try {
        let data = req.body.data.listGoods; // Обновление пути до данных
        let transformedData = data.map(item => {
          // Проверка, есть ли размеры в товаре и взятие первого элемента
          let firstSize = item.sizes && item.sizes[0] ? item.sizes[0] : null;

          return {
            nmId: item.nmID,
            price: firstSize ? firstSize.price : 0, // Если размеры есть, берём цену первого размера 
            discount: item.discount,
            promoCode: 0,
            currentprice: firstSize ? firstSize.discountedPrice : 0, // Если размеры есть, берём цену первого размера
            dayprice: 0, // Примерное значение
            nightprice: 0, // Примерное значение
            daydisc: 0, // Примерное значение
            nightdisc: 0, // Примерное значение
            active: ''
          };
        });
        // Сохранение данных в базе данных
        const results = await checkAndInsertPrice(transformedData);
        res.json(results); // Отправляем результаты
        const successMessage = 'API успешно отработал ';
        logMessage('/api/save-data/prices', 2, successMessage); // Логирование успешной отработки запроса API
      } catch (error) {
        sendlogTG(error.message);
        logMessage('/api/save-data/prices', 2, error.message); // Логирование неуспешной отработки запроса API
        res.status(500).send('Ошибка сервера');
      }
      });


  app.get('/api/gettablelocale', async (req, res) => {
    // Извлечение параметров запроса
    const fields = req.query.tablekeys ? req.query.tablekeys.split(',') : []; // Преобразуем строку обратно в массив
    const locale = req.query.locale;

    try {
      
      // Преобразуем список полей в строку для SQL-запроса
      const fieldsString = fields.map(field => `'${field}'`).join(', ');

      // Формируем текст запроса
      const queryText = `
      SELECT  * FROM localization
      WHERE loctype = '1'
      AND locale = '${locale}'
      AND colname IN (${fieldsString});
      `;
      const { rows } = await pool.query(queryText);
      res.json(rows);
    } catch (error) {
      logMessage('/api/gettablelocale', 2, error.message); // Логирование ошибки 
      res.status(500).send(error.message);
    }

  });

    app.listen(PORT, () => {
      console.log(`Server running on port ${PORT}`);
      
      // Запускаем периодическую проверку
      setInterval(async () => {
        const activeCampaigns = await pool.query(`
          SELECT advertid, crmname, pause_time, restart_time 
          FROM crm_headers 
          WHERE active = true
        `);
        
        activeCampaigns.rows.forEach(campaign => {
          scheduler.scheduleCampaign(campaign);
        });
      }, 5 * 60 * 1000);
    });
    const dbListener = new Client({
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
    });