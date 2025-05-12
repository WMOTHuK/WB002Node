import { pool } from '../General/globals.js';
import { decrypt } from '../utils/crypto.js';

export async function getApiKey(campaignId) {
  const { rows } = await pool.query(`
    SELECT u.api_key 
    FROM user_api_keys u
    JOIN crm_headers c ON c.user_id = u.user_id
    WHERE c.advertid = $1 AND u.key_type = 1
  `, [campaignId]);

  if (!rows.length) throw new Error('API key not found');
  return decrypt(rows[0].api_key);
}