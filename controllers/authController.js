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
    const existingUser = await User.findByLogin(login);
    if (existingUser) {
      return res.status(400).json({ message: 'Пользователь уже существует' });
    }
    
    // Создание нового пользователя
    const user = await User.create(login, password);
    
    res.status(201).json({ 
      message: 'Пользователь создан',
      userId: user.id 
    });
  } catch (error) {
    console.error(error);
    res.status(500).json({ message: 'Ошибка сервера' });
  }
};
