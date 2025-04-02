  //./controllers/authController.js
  import jwt from 'jsonwebtoken';
  import User from '../models/User.js';
  import { pool } from '../General/globals.js';
  import bcrypt from 'bcryptjs';

  export const login = async (req, res) => {
    try {
      const { login, password } = req.body;

      // 1. Находим пользователя в PostgreSQL
      const user = await User.findByLogin(login);
      if (!user) {
        return res.status(401).json({ message: 'Неверные учетные данные' });
      }

      // 2. Проверяем пароль
      const isMatch = await User.comparePasswords(password, user.password_hash);
      if (!isMatch) {
        return res.status(401).json({ message: 'Неверные учетные данные' });
      }

      // 3. Генерируем JWT токен
      const token = jwt.sign(
        { userId: user.id, login: user.login }, 
        process.env.JWT_SECRET,
        { expiresIn: process.env.JWT_EXPIRES_IN }
      );
  
      res.json({ 
        token, 
        login: user.login 
      });
      console.error(error);
      res.status(500).json({ message: 'Ошибка сервера' });
    }
   catch (error) {
    // ... обработка ошибок
  }
  };

  export const register = async (req, res) => {
    try {
      const { login, password } = req.body;

      // Валидация
      if (!login || !password) {
        return res.status(400).json({ 
          message: 'Логин и пароль обязательны' 
        });
      }

      if (login.length < 3) {
        return res.status(400).json({ 
          message: 'Логин должен быть не менее 3 символов' 
        });
      }

      if (password.length < 6) {
        return res.status(400).json({ 
          message: 'Пароль должен быть не менее 6 символов' 
        });
      }

      // Проверка существования пользователя
      const existingUser = await pool.query(
        'SELECT * FROM users WHERE login = $1', 
        [login]
      );
      
      if (existingUser.rows.length > 0) {
        return res.status(409).json({ 
          message: 'Пользователь с таким логином уже существует' 
        });
      }

      // Хеширование пароля
      const hashedPassword = await bcrypt.hash(password, 12);
      
      // Создание пользователя
      const newUser = await pool.query(
        `INSERT INTO users (login, password_hash) 
        VALUES ($1, $2) RETURNING id, login`,
        [login, hashedPassword]
      );

      res.status(201).json({ 
        message: 'Пользователь успешно зарегистрирован',
        user: newUser.rows[0]
      });
    } catch (error) {
      console.error('Registration error:', error);
      res.status(500).json({ 
        message: 'Внутренняя ошибка сервера при регистрации' 
      });
    }
  };
  export const getApiKeys = async (req, res) => {
    try {
      const apiKeys = await User.getApiKeys(req.user.id);
      res.json(apiKeys);
    } catch (error) {
      console.error(error);
      res.status(500).json({ message: 'Ошибка сервера' });
    }
  };