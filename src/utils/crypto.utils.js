// src/utils/crypto.utils.js
import crypto from 'crypto';

const ALGORITHM = 'aes-256-cbc';
const KEY_LENGTH = 32; // байт для AES-256

function getSecretKey() {
  const hex = process.env.CRYPTO_SECRET;
  if (!hex) {
    throw new Error('CRYPTO_SECRET is not set in environment');
  }
  const key = Buffer.from(hex, 'hex');
  if (key.length !== KEY_LENGTH) {
    throw new Error(`CRYPTO_SECRET must be ${KEY_LENGTH * 2} hex characters (${KEY_LENGTH} bytes)`);
  }
  return key;
}

/**
 * Зашифровать текст (AES-256-CBC)
 * @param {string} text
 * @returns {string} iv:encrypted (hex)
 */
export function encrypt(text) {
  const key = getSecretKey();
  const iv = crypto.randomBytes(16); // Новый IV для каждой операции
  const cipher = crypto.createCipheriv(ALGORITHM, key, iv);
  let encrypted = cipher.update(text, 'utf8', 'hex');
  encrypted += cipher.final('hex');
  return `${iv.toString('hex')}:${encrypted}`;
}

/**
 * Расшифровать текст
 * @param {string} text - строка в формате iv:encrypted
 * @returns {string}
 */
export function decrypt(text) {
  const key = getSecretKey();
  const [ivHex, encrypted] = text.split(':');
  if (!ivHex || !encrypted) {
    throw new Error('Invalid encrypted text format');
  }
  const decipher = crypto.createDecipheriv(
    ALGORITHM,
    key,
    Buffer.from(ivHex, 'hex')
  );
  let decrypted = decipher.update(encrypted, 'hex', 'utf8');
  decrypted += decipher.final('utf8');
  return decrypted;
}
