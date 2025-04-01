import express from 'express';
import { 
  getApiKeys, 
  updateApiKey 
} from '../controllers/apiKeysController.js';
import { authenticate } from '../middleware/auth.js';

const router = express.Router();

router.get('/api-keys', authenticate, getApiKeys);
router.post('/api-keys', authenticate, updateApiKey);

export default router;