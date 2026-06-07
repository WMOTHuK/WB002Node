// src/services/crm/crm.service.js
import axios from 'axios';
import apiConfig from '../../config/api.config.js';
import { getApiKeyByUser } from '../apiKey.service.js';
import { parseAdverts, enrichAdvertData } from '../../utils/crm.utils.js';
import { syncTableToDB, syncTableFromDB } from '../../utils/tableSync.utils.js';
import { addDescriptionColumns } from '../../utils/descriptionsMapper.js';
import { AppError } from '../../utils/errors.js';

/**
 * Получить и синхронизировать кампании пользователя
 */
export async function getCampaigns(userId) {
  const apiKey = await getApiKeyByUser(userId, '1');

  // 1. Получаем список кампаний
  const { data } = await axios.get(apiConfig.wbCampaignsUrl, {
    headers: { Authorization: `Bearer ${apiKey}` }
  });

  // 2. Парсим и обогащаем
  const parsed = parseAdverts(data);
  const enriched = await enrichAdvertData(parsed, apiConfig.wbCampaignDetailsUrl, apiKey, userId);

  // 3. Синхронизируем с БД
  const keyFields = ['advertid', 'user_id'];
  const syncResult = await syncTableToDB(enriched, 'crm_headers', keyFields, {
    batchSize: 500,
    ignoreFields: ['pause_time', 'restart_time', 'active']
  });

  // 4. Обогащаем из БД и фильтруем
  const updated = await syncTableFromDB(enriched, 'crm_headers', keyFields);
  const filtered = updated.filter(item => item.crmstatus !== 7);

  // 5. Добавляем описания
  const result = await addDescriptionColumns(filtered, [
    { field: 'crmstatus', tableName: 'crm_status' },
    { field: 'crmtype', tableName: 'crm_type' }
  ]);

  return { data: result, dbSync: syncResult };
}
