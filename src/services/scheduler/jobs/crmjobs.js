// src/services/scheduler/jobs/crmjobs.js
import axios from 'axios';
import { logger } from '../../../utils/logger.js';
import { getApiKeyByUser, KEY_TYPE } from '../../apiKey.service.js';
import { parseAdverts, pauseCampaignsList } from '../../../utils/crm.utils.js';
import { getUniqueKeys } from '../../../utils/array.utils.js';
import server_config from '../../../config/api.config.js';

const STATUS_ACTIVE = '9';
const SYSTEM_USER_ID = '2'; // Технический пользователь для cron-задач

export const pauseActiveCampaigns = {
  async run() {
    try {
      logger.info('[CRON] Запуск задачи pauseActiveCampaigns');

      const crmApiKey = await getApiKeyByUser(SYSTEM_USER_ID, KEY_TYPE.WB_CRM_API);
      
      const response = await axios.get(server_config.getCampaignsUrl, {
        headers: { 'Authorization': `Bearer ${crmApiKey}` }
      });

      const activeAdverts = parseAdverts(response.data, STATUS_ACTIVE);
      const advertIds = getUniqueKeys(activeAdverts, 'advertid');

      const message = await pauseCampaignsList(advertIds, crmApiKey);
      logger.info(message);

    } catch (error) {
      logger.error(formatCrmError(error));
    }
  }
};

function formatCrmError(error) {
  if (error.response) {
    return `⚠️ Ошибка API: ${error.response.status} — ${error.response.data?.message || 'Нет деталей'}`;
  }
  if (error.request) {
    return `⚠️ Нет ответа от сервера: ${error.message}`;
  }
  return `⚠️ Ошибка: ${error.message}`;
}