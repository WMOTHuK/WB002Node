// src/app.js
import express from 'express';
import cors from 'cors';
import { router as apiRouter } from './api/routes/index.js';
import { errorHandler } from './api/middleware/errorhandler.js';

const app = express();

// Глобальные middleware
app.use(cors());
app.use(express.json()); // Только ОДИН раз!

// Все маршруты
app.use('/api', apiRouter);

// Централизованная обработка ошибок (должна быть последней)
app.use(errorHandler);

export { app };