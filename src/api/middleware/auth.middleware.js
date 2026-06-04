// src/api/middlewares/auth.middleware.js
import { tokenService } from '../../services/auth/token.service.js';
import { userService } from '../../services/auth/user.service.js';
import { AuthenticationError, ForbiddenError } from '../../utils/errors.js';
import { logger } from '../../utils/logger.js';

export const authenticate = async (req, res, next) => {
  try {
    // 1. Извлекаем токен
    const token = tokenService.extractFromHeader(req.headers.authorization);
    if (!token) {
      throw new AuthenticationError('No token provided');
    }

    // 2. Верифицируем токен
    const payload = tokenService.verify(token);
    if (!payload) {
      throw new AuthenticationError('Invalid or expired token');
    }

    // 3. Проверяем существование пользователя
    await userService.ensureExists(payload.userId);

    // 4. Прокидываем пользователя дальше
    req.user = { id: payload.userId };
    next();
    
  } catch (error) {
    // Логируем только серверные ошибки
    if (!error.isOperational) {
      logger.error('Auth middleware error:', error);
    }
    
    // Пробрасываем операционные ошибки в errorHandler
    if (error instanceof AppError) {
      return res.status(error.statusCode).json({ error: error.message });
    }
    
    // Неизвестные ошибки
    res.status(500).json({ error: 'Internal server error' });
  }
};