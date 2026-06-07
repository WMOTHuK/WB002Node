// src/api/routes/apiKeys.routes.js
import { Router } from 'express';
import { authenticate } from '../middleware/auth.middleware.js';
import { getKeyTypes, getUserApiKeys, saveUserApiKey } from '../../services/apiKey.service.js';

const router = Router();

// GET /api/apikeys/getapikeytypes
router.get('/getapikeytypes', async (req, res, next) => {
  try {
    const types = await getKeyTypes();
    res.json(types);
  } catch (error) {
    next(error);
  }
});

// GET /api/apikeys/getuserapikeysdata
router.get('/getuserapikeysdata', authenticate, async (req, res, next) => {
  try {
    const { user_id } = req.query;
    if (!user_id) {
      return res.status(400).json({ error: 'user_id is required' });
    }
    const keys = await getUserApiKeys(user_id);
    res.json(keys);
  } catch (error) {
    next(error);
  }
});

// POST /api/apikeys/saveuserapikey
router.post('/saveuserapikey', authenticate, async (req, res, next) => {
  try {
    const { user_id, key_type, api_key } = req.body;
    if (!user_id || !key_type || api_key === undefined) {
      return res.status(400).json({ error: 'Missing required fields' });
    }
    const result = await saveUserApiKey(user_id, key_type, api_key);
    res.json({
      success: true,
      message: result.created ? 'API key created' : 'API key updated',
      updated_at: new Date().toISOString()
    });
  } catch (error) {
    next(error);
  }
});

export default router;