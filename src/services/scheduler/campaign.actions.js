// services/scheduler/campaign.actions.js
import axios from 'axios';
import { getCrmApiKey } from '../apiKey.service.js';
import { AppError } from '../../utils/errors.js';
import { logger } from '../../utils/logger.js';
import server_config from '../../config/api.config.js'


/**
 * Поставить кампанию на паузу
 * @param {string} advertId
 * @param {string} [apiKey] — если не передан, берётся из БД
 * @returns {Promise<Object>} данные ответа от WB
 * @throws {AppError} при ошибке API или отсутствии ключа
 */
export async function pauseCampaign(advertId, apiKey = null) {
  try {
    const key = apiKey || await getCrmApiKey(advertId);
    
    const { data } = await axios.get(`${server_config.wb_crmurl}/pause`, {
      params: { id: advertId },
      headers: { Authorization: `Bearer ${key}` }
    });

    logger.info(`Кампания ${advertId} поставлена на паузу`);
    return data;
    
  } catch (error) {
    logger.error(`Ошибка паузы кампании ${advertId}:`, error.response?.data || error.message);
    throw new AppError(
      `Ошибка паузы: ${error.response?.data?.message || error.message}`,
      error.response?.status || 500
    );
  }
}

/**
 * Перезапустить кампанию
 * @param {string} advertId
 * @param {string} [apiKey]
 * @returns {Promise<Object>}
 * @throws {AppError}
 */
export async function restartCampaign(advertId, apiKey = null) {
  try {
    const key = apiKey || await getCrmApiKey(advertId);
    
    const { data } = await axios.get(`${server_config.wb_crmurl}/start`, {
      params: { id: advertId },
      headers: { Authorization: `Bearer ${key}` }
    });

    logger.info(`Кампания ${advertId} перезапущена`);
    return data;
    
  } catch (error) {
    logger.error(`Ошибка рестарта кампании ${advertId}:`, error.response?.data || error.message);
    throw new AppError(
      `Ошибка рестарта: ${error.response?.data?.message || error.message}`,
      error.response?.status || 500
    );
  }
}