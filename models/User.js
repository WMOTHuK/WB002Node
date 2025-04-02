//./Models/User.js
import { pool } from '../General/globals.js';
import bcrypt from 'bcryptjs';
import { encrypt } from '../utils/crypto.js';

export default class User {
  static async findByLogin(login) {
    const { rows } = await pool.query(
      'SELECT * FROM users WHERE login = $1', 
      [login]
    );
    return rows[0] || null;
  }

  static async getApiKeys(userId) {
    const { rows } = await pool.query(
      `SELECT service_type, api_key 
       FROM user_api_keys 
       WHERE user_id = $1`,
      [userId]
    );
    
    return rows.reduce((acc, row) => {
      acc[row.service_type] = decrypt(row.api_key);
      return acc;
    }, {});
  }

  static async updateApiKey(userId, serviceType, apiKey) {
    await pool.query(
      `INSERT INTO user_api_keys (user_id, service_type, api_key)
       VALUES ($1, $2, $3)
       ON CONFLICT (user_id, service_type) 
       DO UPDATE SET api_key = EXCLUDED.api_key`,
      [userId, serviceType, encrypt(apiKey)]
    );
  }
  static async comparePasswords(plainPassword, hashedPassword) {
    try {
      // Сравниваем введённый пароль с хэшированным паролем
      const isMatch = await bcrypt.compare(plainPassword, hashedPassword);
      return isMatch; // Возвращаем true или false
    } catch (error) {
      console.error('Ошибка при сравнении паролей:', error);
      throw new Error('Ошибка при проверке пароля');
    }
  }
}