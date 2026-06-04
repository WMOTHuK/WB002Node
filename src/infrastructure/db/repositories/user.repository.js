// src/infrastructure/db/repositories/user.repository.js
import { pool } from '../../../../General/globals.js';

export const userRepository = {
  /**
   * Найти пользователя по ID
   * @param {string} id
   * @returns {Promise<{id: string}|null>}
   */
  findById: async (id) => {
    const { rows } = await pool.query(
      'SELECT id FROM users WHERE id = $1',
      [id]
    );
    return rows[0] || null;
  },

  /**
   * Проверить существование пользователя
   * @param {string} id
   * @returns {Promise<boolean>}
   */
  exists: async (id) => {
    const { rows } = await pool.query(
      'SELECT EXISTS(SELECT 1 FROM users WHERE id = $1) as exists',
      [id]
    );
    return rows[0]?.exists || false;
  }
};