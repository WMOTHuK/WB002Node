// services/apiKey.service.js
import { pool } from '../../General/globals.js';
import { decrypt } from '../../utils/crypto.js';
import { AppError } from '../utils/errors.js';

const KEY_TYPE = {
  WB_CRM_API: 1
};

export async function getCrmApiKey(campaignId) {
  const { rows } = await pool.query(`
    SELECT uak.api_key 
    FROM user_api_keys uak
    JOIN crm_headers ch ON ch.user_id = uak.user_id
    WHERE ch.advertid = $1 AND uak.key_type = $2
  `, [campaignId, KEY_TYPE.WB_CRM_API]);

  if (!rows.length) {
    throw new AppError(`CRM API key not found for campaign ${campaignId}`, 404);
  }
  
  return decrypt(rows[0].api_key);
}