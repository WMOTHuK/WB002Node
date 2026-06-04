//routes/auth.js

import express from 'express';
import { login, register } from '../src/api/controllers/auth.controller.js';
import { authenticate } from '../src/api/middleware/auth.middleware.js';

const router = express.Router();

router.post('/login', login);
router.post('/register', register);
/* router.get('/keys', authenticate, getApiKeys); // Новый маршрут */

//Получение типов API ключей

export default router;