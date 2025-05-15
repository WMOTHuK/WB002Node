// routes/dbRoutes.js
import express from 'express';
import { syncTableToDB } from '../General/DBactions/tableSync.js';
import { authenticate } from '../middleware/auth.js';
import insertrow from '../General/DBactions/insertrow.js';
import updaterow from '../General/DBactions/updaterow.js';

const router = express.Router();

/**
 * Обновление данных в таблице БД
 * @body {Object} {
 *   rows: Array,      // Данные для обновления
 *   tableName: string,// Имя таблицы
 *   keyFields: string|Array, // Ключевые поля
 *   fieldsToUpdate: Array // Поля для обновления (опционально)
 * }
 */
router.post('/updatetable', authenticate, async (req, res) => {
  try {
    const { rows, tableName, keyFields } = req.body;

    if (!rows || !tableName || !keyFields) {
      return res.status(400).json({
        error: 'Missing required parameters: rows, tableName or keyFields'
      });
    }

    const syncResult = await syncTableToDB(
      rows,
      tableName,
      keyFields,
      {
        batchSize: 500 // Можно настроить по необходимости
      }
    );

    res.status(200).json({
      success: true,
      result: syncResult,
      message: `Processed ${rows.length} rows`
    });
  } catch (error) {
    console.error('Error in /api/DB/updatetable:', error);
    res.status(500).json({
      success: false,
      error: error.message,
      details: process.env.NODE_ENV === 'development' ? error.stack : undefined
    });
  }
});


router.get('/gettable', async (req, res) => {
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

router.post('/updaterow', async (req, res) => {
  try {
    const { tablename, tablekey, fieldsToUpdate, rowData } = req.body;
    const result = await updaterow( tablename, tablekey, fieldsToUpdate, rowData);
    res.json({ success: true, message: result });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});

router.post('/insertrow', async (req, res) => {
  try {
    const { tablename, rowData } = req.body;
    const result = await insertrow( tablename, rowData);
    res.json({ success: true, message: result });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});


router.get('/gettablelocale', async (req, res) => {
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

export default router;