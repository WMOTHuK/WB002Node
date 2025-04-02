import jwt from 'jsonwebtoken';
import User from '../models/User.js';

export const login = async (req, res) => {
  try {
    const { login, password } = req.body;

    // 1. Находим пользователя в PostgreSQL
    const user = await User.findByLogin(login);
    if (!user) {
      return res.status(401).json({ message: 'Неверные учетные данные' });
    }

    // 2. Проверяем пароль
    const isMatch = await User.comparePasswords(password, user.password);
    if (!isMatch) {
      return res.status(401).json({ message: 'Неверные учетные данные' });
    }

    // 3. Генерируем JWT токен
    const token = jwt.sign(
      { userId: user.id, login: user.login },
      process.env.JWT_SECRET,
      { expiresIn: process.env.JWT_EXPIRES_IN }
    );

    res.json({ token });
  } catch (error) {
    console.error(error);
    res.status(500).json({ message: 'Ошибка сервера' });
  }
};

export const register = async (req, res) => {
  try {
    const { login, password } = req.body;
    
    // Проверка существования пользователя
    const existingUser = await pool.query(
      'SELECT * FROM users WHERE login = $1', 
      [login]
    );
    
    if (existingUser.rows.length > 0) {
      return res.status(400).json({ message: 'Пользователь уже существует' });
    }
    if (password.length < 6) {
      return res.status(400).json({ message: 'Пароль должен быть не менее 6 символов' });
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
      message: 'Пользователь создан',
      user: newUser.rows[0]
    });
  } catch (error) {
    console.error('Registration error:', error);
    res.status(500).json({ message: 'Ошибка регистрации' });
  }
};