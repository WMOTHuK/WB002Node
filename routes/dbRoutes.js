// routes/dbRoutes.js
import express from 'express';
import { syncTableToDB } from '../General/DBactions/tableSync.js';
import { authenticate } from '../middleware/auth.js';

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

export default router;