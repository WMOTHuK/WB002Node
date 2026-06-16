// src/services/crm/crm.service.js
import axios from 'axios';
import apiConfig from '../../config/api.config.js';
import { pool } from '../../config/db.config.js';
import { getApiKeyByUser } from '../apiKey.service.js';
import { parseAdverts, enrichAdvertData } from '../../utils/crm.utils.js';
import { syncTableToDB, syncTableFromDB } from '../../utils/tableSync.utils.js';
import { addDescriptionColumns } from '../../utils/descriptionsMapper.js';
import { AppError } from '../../utils/errors.js';
import { toSnakeCase } from '../../utils/common.utils.js';


const wbcrmkey = 1;
const EXCLUDE_KEYS = ['campName', 'advertType', 'advertStatus'];

/**
 * Получить и синхронизировать кампании пользователя
 */
export async function syncCampaigns(userId) {
  const apiKey = await getApiKeyByUser(userId, wbcrmkey);

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
export async function getActiveCampaigns(userId, active_only) {
  const status = active_only === 'true' ? '7' : null; // 7 - Finished campaigns, - unexisting status(select all)
  
  const { rows } = await pool.query(
      `SELECT * FROM crm_headers_simple_view 
      WHERE user_id = $1 
        AND crmstatus IS DISTINCT FROM $2
      ORDER BY advertid`,
      [userId, status]
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

export async function addGroupToCampaign (advertid, goodsGrpId) {
    const result = await pool.query(
        'SELECT * FROM add_group_cards_to_campaign($1, $2)',
        [advertid, goodsGrpId]
    );
    return result.rows[0];
};

export async function getGoodsGroupsWithTypes() {
  const { rows: groups } = await pool.query(
      'SELECT * FROM goods_grp_with_types ORDER BY goods_grp_id'
  );
  return groups;
}

/**
 * Синхронизировать затраты на кампании из WB API
 */
export async function syncCampaignCosts(userId, dateFrom, dateTo) {
  const apiKey = await getApiKeyByUser(userId, wbcrmkey);

  const { data } = await axios.get(apiConfig.wbCampaignCostsUrl, {
    params: { from: dateFrom, to: dateTo },
    headers: { Authorization: `Bearer ${apiKey}` }
  });

  const filtered = data
    .filter(item => item.updNum !== 0)
    .map(item => {
      const clean = {};
      for (const key in item) {
        if (!EXCLUDE_KEYS.includes(key)) {
          clean[key] = item[key];
        }
      }
      return clean;
    });

  const { rows } = await pool.query(
    'SELECT * FROM sync_crm_campaign_costs($1)',
    [JSON.stringify(toSnakeCase(filtered))]
  );

  return rows[0];
}

/**
 * Получить затраты по ID кампании
 */
export async function getCostsByAdvertId(advertId) {
  const { rows } = await pool.query(
    'SELECT * FROM crm_campaign_costs_view WHERE advert_id = $1 ORDER BY upd_time DESC',
    [advertId]
  );
  return rows;
}