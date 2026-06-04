// src/app.js
import express from 'express';
import cors from 'cors';
import authRoutes from '../routes/auth.js';
import apiKeysRoutes from '../routes/apiKeys.js';
import contentRoutes from '../routes/contentRoutes.js';
import CRMRoutes from '../routes/CRMRoutes.js';
import dbRoutes from '../routes/dbRoutes.js';
import { authenticate } from './api/middleware/auth.middleware.js';
import { errorHandler } from './api/middleware/errorHandler.js';

const app = express();

// Глобальные middleware
app.use(cors());
app.use(express.json());

// Публичные маршруты (без аутентификации)
app.use('/api/auth', authRoutes);  // login, register — без auth

// Защищённые маршруты
app.use('/api/apikeys', authenticate, apiKeysRoutes);    // /getapikeytypes, /getuserapikeysdata, /saveuserapikey
app.use('/api/content', authenticate, contentRoutes);
app.use('/api/CRM', authenticate, CRMRoutes);
app.use('/api/DB', authenticate, dbRoutes);

// Обработка ошибок
app.use(errorHandler);

export { app };