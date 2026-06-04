// src/services/auth/token.service.js
import jwt from 'jsonwebtoken';

const JWT_SECRET = process.env.JWT_SECRET;
const JWT_EXPIRES_IN = process.env.JWT_EXPIRES_IN || '24h';

if (!JWT_SECRET) {
  throw new Error('JWT_SECRET is not defined in environment variables');
}

export const tokenService = {
  extractFromHeader: (authHeader) => {
    if (!authHeader?.startsWith('Bearer ')) return null;
    return authHeader.split(' ')[1];
  },

  verify: (token) => {
    try {
      const decoded = jwt.verify(token, JWT_SECRET);
      if (!decoded.userId) return null;
      return { userId: decoded.userId };
    } catch {
      return null;
    }
  },

  /**
   * Создать токен
   * @param {{userId: string, login?: string}} payload
   * @returns {string}
   */
  sign: (payload) => {
    return jwt.sign(payload, JWT_SECRET, { expiresIn: JWT_EXPIRES_IN });
  }
};