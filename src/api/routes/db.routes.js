// src/api/routes/db.routes.js
import { Router } from 'express';
import { authenticate } from '../middleware/auth.middleware.js';
import { updateTable, getTable, updateRow, insertRow, getLocaleStrings } from '../../services/db/db.service.js';

const router = Router();

router.post('/updatetable', authenticate, async (req, res, next) => {
  try {
    const { rows, tableName, keyFields } = req.body;
    if (!rows || !tableName || !keyFields) {
      return res.status(400).json({ error: 'rows, tableName, keyFields required' });
    }
    const result = await updateTable(rows, tableName, keyFields);
    res.json({ success: true, result, message: `Processed ${rows.length} rows` });
  } catch (error) {
    next(error);
  }
});

router.get('/gettable', async (req, res, next) => {
  try {
    const rows = await getTable(req.query.tablename);
    res.json(rows);
  } catch (error) {
    next(error);
  }
});

router.post('/updaterow', async (req, res, next) => {
  try {
    const { tablename, tablekey, fieldsToUpdate } = req.body;
    await updateRow(tablename, tablekey, fieldsToUpdate);
    res.json({ success: true });
  } catch (error) {
    next(error);
  }
});

router.post('/insertrow', async (req, res, next) => {
  try {
    const { tablename, rowData } = req.body;
    await insertRow(tablename, rowData);
    res.json({ success: true });
  } catch (error) {
    next(error);
  }
});

router.get('/gettablelocale', async (req, res, next) => {
  try {
    const fields = req.query.tablekeys?.split(',') || [];
    const rows = await getLocaleStrings(fields, req.query.locale);
    res.json(rows);
  } catch (error) {
    next(error);
  }
});

export default router;