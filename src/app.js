// src/app.js
import express from 'express';
import cors from 'cors';
import authRoutes from './api/routes/auth.routes.js';
import apiKeysRoutes from './api/routes/apiKeys.routes.js';
import contentRoutes from './api/routes/content.routes.js';
import crmRoutes from './api/routes/crm.routes.js';
import dbRoutes from './api/routes/db.routes.js';
import { authenticate } from './api/middleware/auth.middleware.js';
import { errorHandler } from './api/middleware/errorHandler.js';

const app = express();

// Глобальные middleware
app.use(cors());
app.use(express.json());

// Публичные маршруты (без аутентификации)
app.use('/api/auth', authRoutes);  // login, register — без auth

// Защищённые маршруты
app.use('/api/apikeys', apiKeysRoutes);   
app.use('/api/content', contentRoutes);
app.use('/api/CRM', crmRoutes);
app.use('/api/DB', dbRoutes);

// Обработка ошибок
app.use(errorHandler);

export { app };