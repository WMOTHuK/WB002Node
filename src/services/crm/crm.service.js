// src/services/crm/crm.service.js
import axios from 'axios';
import apiConfig from '../../config/api.config.js';
import { pool } from '../../config/db.config.js';
import { getApiKeyByUser } from '../apiKey.service.js';
import { parseAdverts, enrichAdvertData } from '../../utils/crm.utils.js';
import { syncTableToDB, syncTableFromDB } from '../../utils/tableSync.utils.js';
import { addDescriptionColumns } from '../../utils/descriptionsMapper.js';
import { AppError } from '../../utils/errors.js';

/**
 * Получить и синхронизировать кампании пользователя
 */
export async function syncCampaigns(userId) {
  const apiKey = await getApiKeyByUser(userId, '1');

  const { data } = await axios.get(apiConfig.wbCampaignsUrl, {
    headers: { Authorization: `Bearer ${apiKey}` }
  });

  const parsed = parseAdverts(data);
  const enriched = await enrichAdvertData(parsed, apiConfig.wbCampaignDetailsUrl, apiKey, userId);

  const keyFields = ['advertid', 'user_id'];
  const syncResult = await syncTableToDB(enriched, 'crm_headers', keyFields, {
    batchSize: 500,
    ignoreFields: ['pause_time', 'restart_time', 'active']
  });

  return {
    inserted: syncResult.inserted,
    updated: syncResult.updated,
    unchanged: syncResult.unchanged,
    total: syncResult.totalProcessed
  };
}

/**
 * Get active campaigns for current user 
 * @param {number} userId
 */
export async function getActiveCampaigns(userId) {
  const finished = '7'; // 7 - Finished campaigns
  const { rows } = await pool.query(
      `SELECT * FROM crm_headers_simple_view 
      WHERE user_id = $1 
        AND crmstatus IS DISTINCT FROM $2
      ORDER BY advertid`,
      [userId, finished]
  );

  return rows;
}

/**
 * Get all assignable cards (both linked and not linked)
 * @param {number} userId
 */
export async function getAllCardsForCampaign(campaignId) {
  const rows = await pool.query(
      'SELECT * FROM get_campaign_assignable_cards($1)',
      [campaignId]
  );

  return rows.rows;
}

/**
 * Get only linked cards (has_link = true)
 * @param {number} userId
 */
export async function getAssignedCardsForCampaign(campaignId) {
  const rows = await pool.query(
        `SELECT * FROM get_campaign_assignable_cards($1) 
        WHERE has_link = true`,
        [campaignId]
  );

  return rows.rows;
}


export async function syncCampaignSubcards(advertid, cards) {
  if (!Array.isArray(cards) || cards.length === 0) {
    throw new AppError('Cards must be a non-empty array', 400);
  }
  const result = await pool.query(
      'SELECT * FROM sync_campaign_subcards($1, $2)',
      [advertid, JSON.stringify(cards)]
  );
  return result.rows[0];
};