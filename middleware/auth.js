// middleware/auth.js
import jwt from 'jsonwebtoken';
import { pool } from '../General/globals.js';

export const authenticate = async (req, res, next) => {
  try {
    const token = req.headers.authorization?.split(' ')[1];
    if (!token) return res.sendStatus(401);

    const decoded = jwt.verify(token, process.env.JWT_SECRET);
    
    // Проверяем существование пользователя в БД
    const { rows } = await pool.query(
      'SELECT id FROM users WHERE id = $1',
      [decoded.userId]
    );
    
    if (!rows[0]) return res.sendStatus(403);
    
    req.user = { id: decoded.userId };
    next();
  } catch (error) {
    console.error('Authentication error:', error);
    res.sendStatus(401);
  }
};