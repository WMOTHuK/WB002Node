// src/services/auth/token.service.js
import jwt from 'jsonwebtoken';

const JWT_SECRET = process.env.JWT_SECRET;

if (!JWT_SECRET) {
  throw new Error('JWT_SECRET is not defined in environment variables');
}

export const tokenService = {
  /**
   * Извлечь токен из заголовка Authorization
   * @param {string} authHeader
   * @returns {string|null}
   */
  extractFromHeader: (authHeader) => {
    if (!authHeader?.startsWith('Bearer ')) return null;
    return authHeader.split(' ')[1];
  },

  /**
   * Верифицировать токен и вернуть payload
   * @param {string} token
   * @returns {{userId: string}|null}
   */
  verify: (token) => {
    try {
      const decoded = jwt.verify(token, JWT_SECRET);
      if (!decoded.userId) return null;
      return { userId: decoded.userId };
    } catch {
      return null; // Токен невалидный или истёк
    }
  },

  /**
   * Создать токен
   * @param {string} userId
   * @returns {string}
   */
  sign: (userId) => {
    return jwt.sign({ userId }, JWT_SECRET, { expiresIn: '24h' });
  }
};