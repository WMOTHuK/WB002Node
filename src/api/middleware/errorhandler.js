// src/api/middlewares/errorHandler.js
import { logger } from '../../utils/logger.js';
import { AppError } from '../../utils/errors.js';

export const errorHandler = (err, req, res, next) => {
  // Операционные ошибки (наши)
  if (err instanceof AppError) {
    return res.status(err.statusCode).json({ error: err.message });
  }

  // Неизвестные ошибки
  logger.error('Unhandled error:', {
    message: err.message,
    stack: process.env.NODE_ENV === 'development' ? err.stack : undefined
  });

  res.status(500).json({ 
    error: process.env.NODE_ENV === 'production' 
      ? 'Internal server error' 
      : err.message 
  });
};