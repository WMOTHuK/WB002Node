// src/api/controllers/auth.controller.js
import { authService } from '../../services/auth/auth.service.js';
import { AppError } from '../../utils/errors.js';

export const login = async (req, res, next) => {
  try {
    const { login, password } = req.body;
    
    const result = await authService.login(login, password);
    
    res.json(result);
  } catch (error) {
    next(error); // Пробрасываем в errorHandler
  }
};

export const register = async (req, res, next) => {
  try {
    const { login, password } = req.body;
    
    const result = await authService.register(login, password);
    
    res.status(201).json(result);
  } catch (error) {
    next(error);
  }
};