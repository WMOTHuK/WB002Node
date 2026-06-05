import { pool } from '../../../General/globals.js';
import { tokenService } from '../../services/auth/token.service.js';
import { AppError, AuthenticationError, ForbiddenError } from '../../utils/errors.js';
import { logger } from '../../utils/logger.js';

export const authenticate = async (req, res, next) => {
  try {
    const token = tokenService.extractFromHeader(req.headers.authorization);
    if (!token) {
      throw new AuthenticationError('No token provided');
    }

    const payload = tokenService.verify(token);
    if (!payload) {
      throw new AuthenticationError('Invalid or expired token');
    }

    // Проверяем, что пользователь существует (один простой запрос)
    const { rows } = await pool.query(
      'SELECT EXISTS(SELECT 1 FROM users WHERE id = $1)',
      [payload.userId]
    );
    
    if (!rows[0]?.exists) {
      throw new ForbiddenError('User not found');
    }

    req.user = { id: payload.userId };
    next();
    
  } catch (error) {
    if (!error.isOperational) {
      logger.error('Auth middleware error:', error);
    }
    
    if (error instanceof AppError) {
      return res.status(error.statusCode).json({ error: error.message });
    }
    
    res.status(500).json({ error: 'Internal server error' });
  }
};