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
import CRMRoutes from './routes/CRMRoutes.js'
import dbRoutes from './routes/dbRoutes.js'

const app = express();
const PORT = process.env.PORT || 5000;

/* // Определение маршрута прокси
const apiProxy = createProxyMiddleware({
  target: 'https://suppliers-api.wildberries.ru',
  changeOrigin: true,
  pathRewrite: {'^/api': ''}, // Это опционально, в зависимости от вашей конфигурации
}); */


// Middleware
app.use(cors());
app.use(express.json());




async function updaterow(tablename, tablekey, fieldsToUpdate, rowData) {
  if (!allowedTableNames.includes(tablename)) {
    const errorMessage = `Error: tablename "${tablename}" is not allowed.`;
    logMessage(updaterow.name, 2, errorMessage); // Предположим, что logMessage уже определена и импортирована
    return errorMessage;
  }
  try {
    // Формируем строку запроса для обновления данных
    const setClause = fieldsToUpdate.map((field, index) => `${field} = $${index + 1}`).join(', ');
    const values = fieldsToUpdate.map(field => rowData[field]);

    // Добавляем в values значение ключа для условия WHERE
    values.push(rowData[tablekey]);

    const queryText = `UPDATE ${tablename} SET ${setClause} WHERE ${tablekey} = $${values.length}`;

    // Выполнение запроса к БД
    const res = await pool.query(queryText, values);

    const successMessage = `Row updated successfully: ${res.rowCount} row(s) affected.`;
    logMessage(updaterow.name, 2, successMessage); // Логирование перед возвратом успешного сообщения
    return successMessage;
  } catch (err) {
    // В случае ошибки, сформируем сообщение об ошибке и залогируем его
    const errorMessage = `Error updating  row: ${err.message}`;
    logMessage(updaterow.name, 2, errorMessage);
    return errorMessage;
  }
}
async function insertrow(tablename, rowData) {
  if (!allowedTableNames.includes(tablename)) {
    const errorMessage = `Error: tablename "${tablename}" is not allowed.`;
    logMessage(insertrow.name, 2, errorMessage); // Предполагаем, что logMessage уже определена и импортирована
    return errorMessage;
  }
  try {
    // Строим строку запроса для вставки данных
    const keys = Object.keys(rowData).join(', ');
    const values = Object.values(rowData);
    const valuePlaceholders = values.map((_, index) => `$${index + 1}`).join(', ');

    const queryText = `INSERT INTO ${tablename} (${keys}) VALUES (${valuePlaceholders}) RETURNING *;`;

    // Выполнение запроса к базе данных
    const res = await pool.query(queryText, values);

    // Проверка результата вставки
    const successMessage = res.rowCount > 0 ? `Row inserted into table ${tablename}: ${res.rowCount} row(s) affected.` : `No row inserted.`;
    logMessage(insertrow.name, 2, successMessage); // Логирование успешного результата или отсутствия вставки
    return successMessage;
  } catch (err) {
    // Формируем и логируем сообщение об ошибке
    const errorMessage = `Error inserting row: ${err.message}`;
    logMessage(insertrow.name, 2, errorMessage);
    return errorMessage;
  }
}

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

app.post('/api/updaterow', async (req, res) => {
  try {
    const { tablename, tablekey, fieldsToUpdate, rowData } = req.body;
    const result = await updaterow( tablename, tablekey, fieldsToUpdate, rowData);
    res.json({ success: true, message: result });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});

app.post('/api/insertrow', async (req, res) => {
  try {
    const { tablename, rowData } = req.body;
    const result = await insertrow( tablename, rowData);
    res.json({ success: true, message: result });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});



app.get('/api/gettable', async (req, res) => {
  try {
    const table = req.query.tablename;
    if (!allowedTableNames.includes(table)) {
      const errorMessage = `Error: tablename "${table}" is not allowed.`;
      logMessage(insertrow.name, 2, errorMessage); // Предполагаем, что logMessage уже определена и импортирована
      return errorMessage;
    }

    // Если имя таблицы допустимо, формируем запрос, вставляя имя таблицы напрямую в строку запроса
    const queryText = `SELECT * FROM ${table}`;
    const { rows } = await pool.query(queryText);
    res.json(rows);
  } catch (error) {
    logMessage('/api/gettable', 2, error.message); // Логирование ошибки 
    res.status(500).send(error.message);
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

  app.listen(PORT, () => console.log(`Server running on port ${PORT}`));