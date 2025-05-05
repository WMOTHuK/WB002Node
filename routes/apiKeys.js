//routes/apiKeys.js
import express from 'express';
import { authenticate } from '../middleware/auth.js';
import { readtable } from '../General/DBactions/readtable.js';
import { insertRow } from '../General/DBactions/insertrow.js';
import { updateRow } from '../General/DBactions/updaterow.js';
import bcrypt from 'bcryptjs';
import { pool } from '../General/globals.js';
import { encrypt, decrypt } from '../utils/crypto.js';

const router = express.Router();
/* 
router.get('/api-keys', authenticate, getApiKeys);
router.post('/api-keys', authenticate, updateApiKey); */


router.get('/getapikeytypes', async (req, res) => {
  try {
    // Читаем все записи из таблицы api_key_types
    const keyTypes = await readtable('api_key_types');
    
    // Форматируем ответ согласно требованиям фронтенда
    const formattedData = keyTypes.map(item => ({
      key_type: item.key_type,       // Идентификатор типа ключа
      key_text: item.key_text     // Описание типа ключа
    }));
    
    res.json(formattedData);
  } catch (error) {
    console.error('Error fetching API key types:', error);
    res.status(500).json({ 
      error: 'Internal server error',
      details: error.message 
    });
  }
});

router.get('/getuserapikeysdata', authenticate, async (req, res) => {
  try {
    const userId = req.query.user_id;

    if (!userId) {
      return res.status(400).json({ error: 'user_id is required' });
    }

    // Прямой запрос к БД с JOIN
    const query = `
      SELECT 
        uak.key_type, 
        uak.updated_at
      FROM 
        public.user_api_keys uak
      JOIN 
        public.users u ON uak.user_id = u.id
      WHERE 
        u.login = $1
    `;

    // pool.query возвращает объект { rows, fields, ... }
    const result = await pool.query(query, [userId]);
    const rows = result.rows; // Массив результатов находится в свойстве rows

    // Форматируем ответ
    const formattedData = rows.map(item => ({
      key_type: item.key_type,
      updated_at: item.updated_at.toISOString()
    }));

    res.json(formattedData);
  } catch (error) {
    console.error('Error fetching user API keys:', error);
    res.status(500).json({ 
      error: 'Internal server error',
      details: error.message 
    });
  }
});

const saltRounds = 10; // Количество раундов хеширования

router.post('/saveuserapikey', authenticate, async (req, res) => {
try {
  const { user_id, key_type, api_key } = req.body;

  // Валидация входных данных
  if (!user_id || !key_type || api_key === undefined) {
    return res.status(400).json({ error: 'Missing required fields' });
  }

   // Шифрование ключа перед сохранением
   const encryptedKey = encrypt(api_key);

  // Проверяем существование ключа
  const existingKeys = await readtable('user_api_keys', [
    { colname: 'user_id', sign: 'EQ', low: user_id },
    { colname: 'key_type', sign: 'EQ', low: key_type }
  ]);

  let result;
  if (existingKeys.length === 0) {
    // Вставка новой записи
    result = await insertRow('user_api_keys', [
      { column: 'user_id', value: user_id },
      { column: 'key_type', value: key_type },
      { column: 'api_key', value: encryptedKey },
      { column: 'created_at', value: new Date() },
      { column: 'updated_at', value: new Date() }
    ]);
  } else {
    // Обновление существующей записи
    result = await updateRow('user_api_keys', 
      [
        { column: 'user_id', value: user_id },
        { column: 'key_type', value: key_type }
      ],
      [
        { column: 'api_key', value: encryptedKey },
        { column: 'updated_at', value: new Date() }
      ]
    );
  }

  if (!result.success) {
    throw new Error(result.message || 'Database operation failed');
  }

  res.json({ 
    success: true,
    message: existingKeys.length ? 'API key updated' : 'API key created',
    updated_at: new Date().toISOString()
  });

} catch (error) {
  console.error('Error saving API key:', error);
  res.status(500).json({ 
    error: 'Internal server error',
    details: error.message 
  });
}
});

export default router;