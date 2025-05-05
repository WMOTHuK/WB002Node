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