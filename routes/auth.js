//routes/auth.js

import express from 'express';
import { login, register, getApiKeys } from '../controllers/authController.js';
import { authenticate } from '../middleware/auth.js';

const router = express.Router();

router.post('/login', login);
router.post('/register', register);
router.get('/keys', authenticate, getApiKeys); // Новый маршрут

export default router;