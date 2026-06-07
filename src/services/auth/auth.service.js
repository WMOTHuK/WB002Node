// src/services/auth/auth.service.js
import bcrypt from 'bcryptjs';
import { pool } from '../../config/db.config.js';
import { tokenService } from './token.service.js';
import { AppError } from '../../utils/errors.js';
import { db } from '../../utils/sql.utils.js';

const SALT_ROUNDS = 12;

export const authService = {
  /**
   * Аутентификация пользователя
   * @param {string} login
   * @param {string} password
   * @returns {Promise<{token: string, user: {id, login}}>}
   * @throws {AppError} 401 если неверные учетные данные
   */
  login: async (login, password) => {
    // 1. Находим пользователя
    const { rows } = await db.select('users', { login }, 'id, login, password_hash');
    if (!rows[0]) {
      throw new AppError('Неверные учетные данные', 401);
    }

    const user = rows[0];

    // 2. Проверяем пароль
    const isMatch = await bcrypt.compare(password, user.password_hash);
    if (!isMatch) {
      throw new AppError('Неверные учетные данные', 401);
    }

    // 3. Генерируем токен
    const token = tokenService.sign({
      userId: user.id,
      login: user.login
    });

    return {
      token,
      user: {
        id: user.id,
        login: user.login
      }
    };
  },

  /**
   * Регистрация нового пользователя
   * @param {string} login
   * @param {string} password
   * @returns {Promise<{user: {id, login}}>}
   * @throws {AppError} 400/409 при ошибках валидации
   */
  register: async (login, password) => {
    // Валидация
    if (!login || !password) {
      throw new AppError('Логин и пароль обязательны', 400);
    }

    if (login.length < 3) {
      throw new AppError('Логин должен быть не менее 3 символов', 400);
    }

    if (password.length < 6) {
      throw new AppError('Пароль должен быть не менее 6 символов', 400);
    }

    // Проверка уникальности
    const { rows: existing } = await db.select('users', { login }, 'id');
    
    if (existing.rows.length > 0) {
      throw new AppError('Пользователь с таким логином уже существует', 409);
    }

    // Хеширование и сохранение
    const hashedPassword = await bcrypt.hash(password, SALT_ROUNDS);
    
    const { rows } = await pool.query(  
      `INSERT INTO users (login, password_hash) VALUES ($1, $2) RETURNING id, login`,
      [login, hashedPassword]
    );

    return {
      user: {
        id: rows[0].id,
        login: rows[0].login
      }
    };
  }
};