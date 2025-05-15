// utils/apiutils.js
import { readtable } from "../General/DBactions/readtable.js";
import { decrypt } from "./crypto.js";

export async function getAPIKey(userId, keytype) {
  try {
    const apiKeys = await readtable('user_api_keys', [
      { colname: 'user_id', sign: 'EQ', low: userId },
      { colname: 'key_type', sign: 'EQ', low: keytype } // key_type = 2 для content API
    ]);

    if (!apiKeys || apiKeys.length === 0) {
      throw new Error('Content API key not found for this user');
    }

       // Дешифруем ключ перед использованием
        const decryptedKey = decrypt(apiKeys[0].api_key);
    return decryptedKey;
  } catch (error) {
    console.error('Error getting Content API key:', error);
    throw error;
  }
}