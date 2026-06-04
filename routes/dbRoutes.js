// routes/dbRoutes.js
import express from 'express';
import { syncTableToDB } from '../src/utils/tableSync.utils.js';
import { authenticate } from '../src/api/middleware/auth.middleware.js';
import { db } from '../src/utils/sql.utils.js';
import { pool } from "../General/globals.js";
import { logger } from '../src/utils/logger.js';

const router = express.Router();

// Белый список таблиц для прямого доступа
const allowedTableNames = []; // TODO: заполнить список разрешённых таблиц

/**
 * Обновление данных в таблице БД через syncTableToDB
 */
router.post('/updatetable', authenticate, async (req, res) => {
  try {
    const { rows, tableName, keyFields } = req.body;

    if (!rows || !tableName || !keyFields) {
      return res.status(400).json({
        error: 'Missing required parameters: rows, tableName or keyFields'
      });
    }

    const syncResult = await syncTableToDB(rows, tableName, keyFields, {
      batchSize: 500
    });

    res.status(200).json({
      success: true,
      result: syncResult,
      message: `Processed ${rows.length} rows`
    });
  } catch (error) {
    logger.error('Error in /updatetable:', error.message);
    res.status(500).json({
      success: false,
      error: error.message,
      details: process.env.NODE_ENV === 'development' ? error.stack : undefined
    });
  }
});

/**
 * Получить все записи из таблицы (только из белого списка)
 */
router.get('/gettable', async (req, res) => {
  try {
    const table = req.query.tablename;

    if (!allowedTableNames.includes(table)) {
      return res.status(400).json({ error: `Table "${table}" is not allowed` });
    }

    const { rows } = await db.select(table);
    res.json(rows);
  } catch (error) {
    logger.error('Error in /gettable:', error.message);
    res.status(500).json({ error: error.message });
  }
});

/**
 * Обновить одну строку
 */
router.post('/updaterow', async (req, res) => {
  try {
    const { tablename, tablekey, fieldsToUpdate, rowData } = req.body;

    // tablekey: { column: value } — где условие
    // fieldsToUpdate: { column: value } — что обновить
    await db.update(tablename, fieldsToUpdate, tablekey);

    res.json({ success: true });
  } catch (error) {
    logger.error('Error in /updaterow:', error.message);
    res.status(500).json({ success: false, error: error.message });
  }
});

/**
 * Вставить одну строку
 */
router.post('/insertrow', async (req, res) => {
  try {
    const { tablename, rowData } = req.body;

    // rowData: { column: value }
    await db.insert(tablename, rowData);

    res.json({ success: true });
  } catch (error) {
    logger.error('Error in /insertrow:', error.message);
    res.status(500).json({ success: false, error: error.message });
  }
});

/**
 * Получить локализованные строки
 */
router.get('/gettablelocale', async (req, res) => {
  try {
    const fields = req.query.tablekeys ? req.query.tablekeys.split(',') : [];
    const locale = req.query.locale;

    const { rows } = await pool.query(
      `SELECT * FROM localization
       WHERE loctype = '1'
       AND locale = $1
       AND colname = ANY($2)`,
      [locale, fields]
    );

    res.json(rows);
  } catch (error) {
    logger.error('Error in /gettablelocale:', error.message);
    res.status(500).json({ error: error.message });
  }
});

export default router;