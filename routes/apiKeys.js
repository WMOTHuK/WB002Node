//routes/apiKeys.js
import express from 'express';
import { authenticate } from '../middleware/auth.js';
import { readtable } from '../General/DBactions/readtable.js';
import insertrow from '../General/DBactions/insertrow.js';
import updaterow from '../General/DBactions/updaterow.js';
import bcrypt from 'bcryptjs';
import { pool } from '../General/globals.js';
const router = express.Router();
/* 
router.get('/api-keys', authenticate, getApiKeys);
router.post('/api-keys', authenticate, updateApiKey); */
router.get('/getuserapikeysdata', authenticate, async (req, res) => {
  try {
    const { userId } = req.query;

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

    const { rows } = await pool.query(query, [userId]);

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

  // Хеширование ключа
  const hashedKey = await bcrypt.hash(api_key, saltRounds);

  // Проверяем существование ключа
  const existingKeys = await readtable('user_api_keys', [
    { colname: 'user_id', sign: 'EQ', low: user_id },
    { colname: 'key_type', sign: 'EQ', low: key_type }
  ]);

  let result;
  if (existingKeys.length === 0) {
    // Вставка новой записи
    result = await insertrow(pool, 'user_api_keys', [
      { column: 'user_id', value: user_id },
      { column: 'key_type', value: key_type },
      { column: 'api_key', value: hashedKey },
      { column: 'created_at', value: new Date() },
      { column: 'updated_at', value: new Date() }
    ]);
  } else {
    // Обновление существующей записи
    result = await updaterow(pool, 'user_api_keys', 
      [
        { column: 'user_id', value: user_id },
        { column: 'key_type', value: key_type }
      ],
      [
        { column: 'api_key', value: hashedKey },
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