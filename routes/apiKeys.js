// routes/apiKeys.js
import express from 'express';
import { authenticate } from '../src/api/middleware/auth.middleware.js';
import { pool } from '../src/config/db.config.js';
import { encrypt } from '../utils/crypto.js';

const router = express.Router();

router.get('/getapikeytypes', async (req, res) => {
  try {
    const { rows: keyTypes } = await pool.query('SELECT * FROM api_key_types');
    
    const formattedData = keyTypes.map(item => ({
      key_type: item.key_type,
      key_text: item.key_text
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

    const { rows } = await pool.query(`
      SELECT 
        uak.key_type, 
        uak.updated_at
      FROM 
        public.user_api_keys uak
      JOIN 
        public.users u ON uak.user_id = u.id
      WHERE 
        u.login = $1
    `, [userId]);

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

router.post('/saveuserapikey', authenticate, async (req, res) => {
  try {
    const { user_id, key_type, api_key } = req.body;

    if (!user_id || !key_type || api_key === undefined) {
      return res.status(400).json({ error: 'Missing required fields' });
    }

    const encryptedKey = encrypt(api_key);

    // Проверяем существование ключа
    const { rows: existingKeys } = await pool.query(
      'SELECT id FROM user_api_keys WHERE user_id = $1 AND key_type = $2',
      [user_id, key_type]
    );

    if (existingKeys.length === 0) {
      // Вставка
      await pool.query(
        `INSERT INTO user_api_keys (user_id, key_type, api_key, created_at, updated_at)
         VALUES ($1, $2, $3, NOW(), NOW())`,
        [user_id, key_type, encryptedKey]
      );
    } else {
      // Обновление
      await pool.query(
        `UPDATE user_api_keys 
         SET api_key = $1, updated_at = NOW()
         WHERE user_id = $2 AND key_type = $3`,
        [encryptedKey, user_id, key_type]
      );
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