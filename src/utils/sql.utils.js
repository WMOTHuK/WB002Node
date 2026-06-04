// src/utils/sql.utils.js
import { pool } from '../../General/globals.js';

/**
 * Тонкая утилита для упрощения типовых SQL-запросов.
 * Не заменяет pool.query() — используй его напрямую для сложных запросов (JOIN, агрегации).
 */
export const db = {
  /**
   * SELECT * FROM table [WHERE conditions]
   * @example
   *   const { rows } = await db.select('users', { id: 1 });
   *   const { rows } = await db.select('users');
   */
  select: async (table, where = {}, columns = '*') => {
    const keys = Object.keys(where);
    const values = Object.values(where);
    const whereClause = keys.length
      ? 'WHERE ' + keys.map((k, i) => `${k} = $${i + 1}`).join(' AND ')
      : '';
    return pool.query(
      `SELECT ${columns} FROM ${table} ${whereClause}`,
      values
    );
  },

  /**
   * INSERT INTO table (keys) VALUES (values)
   * @example
   *   await db.insert('users', { login: 'admin', password_hash: '...' });
   */
  insert: async (table, data) => {
    const keys = Object.keys(data);
    const values = Object.values(data);
    const placeholders = keys.map((_, i) => `$${i + 1}`);
    return pool.query(
      `INSERT INTO ${table} (${keys.join(', ')}) VALUES (${placeholders.join(', ')})`,
      values
    );
  },

  /**
   * UPDATE table SET key = value WHERE conditions
   * @example
   *   await db.update('users', { password_hash: '...' }, { id: 1 });
   */
  update: async (table, data, where) => {
    const dataKeys = Object.keys(data);
    const dataValues = Object.values(data);
    const whereKeys = Object.keys(where);
    const whereValues = Object.values(where);
    
    const setClause = dataKeys.map((k, i) => `${k} = $${i + 1}`).join(', ');
    const whereClause = whereKeys.map((k, i) => `${k} = $${dataKeys.length + i + 1}`).join(' AND ');
    
    return pool.query(
      `UPDATE ${table} SET ${setClause} WHERE ${whereClause}`,
      [...dataValues, ...whereValues]
    );
  },

  /**
   * DELETE FROM table WHERE conditions
   * @example
   *   await db.delete('users', { id: 1 });
   */
  delete: async (table, where) => {
    const keys = Object.keys(where);
    const values = Object.values(where);
    const whereClause = keys.map((k, i) => `${k} = $${i + 1}`).join(' AND ');
    return pool.query(
      `DELETE FROM ${table} WHERE ${whereClause}`,
      values
    );
  }
};

/* // Было
const { rows } = await pool.query('SELECT * FROM api_key_types');
const { rows } = await pool.query('SELECT * FROM user_api_keys WHERE user_id = $1 AND key_type = $2', [userId, keyType]);
await pool.query('INSERT INTO user_api_keys (user_id, key_type, api_key, created_at, updated_at) VALUES ($1, $2, $3, NOW(), NOW())', [userId, keyType, encryptedKey]);
await pool.query('UPDATE user_api_keys SET api_key = $1, updated_at = NOW() WHERE user_id = $2 AND key_type = $3', [encryptedKey, userId, keyType]);

// Стало
const { rows } = await db.select('api_key_types');
const { rows } = await db.select('user_api_keys', { user_id: userId, key_type: keyType });
await db.insert('user_api_keys', { user_id: userId, key_type: keyType, api_key: encryptedKey, created_at: new Date(), updated_at: new Date() });
await db.update('user_api_keys', { api_key: encryptedKey, updated_at: new Date() }, { user_id: userId, key_type: keyType }); */