// src/services/auth/user.service.js
import { userRepository } from '../../infrastructure/db/repositories/user.repository.js';
import { AppError } from '../../utils/errors.js';

export const userService = {
  /**
   * Проверить, что пользователь существует
   * @param {string} userId
   * @throws {AppError} если пользователь не найден
   */
  ensureExists: async (userId) => {
    const exists = await userRepository.exists(userId);
    if (!exists) {
      throw new AppError('User not found', 403);
    }
  }
};