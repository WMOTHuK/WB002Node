// src/utils/crm.utils.js
import axios from 'axios';
import { pauseCampaign } from '../services/scheduler/campaign.actions.js';
import { logger } from './logger.js';

// Конфигурация
const BATCH_SIZE = 50;
const MAX_RETRIES = 2;
const REQUEST_TIMEOUT = 30000;
const DELAY_BETWEEN_CAMPAIGNS = 1000;

// ---------------------------------------------------------------------------
// parseAdverts — парсинг списка кампаний из ответа API
// ---------------------------------------------------------------------------
export function parseAdverts(responseData, filterStatus = null) {
  const result = [];

  if (!responseData?.adverts || !Array.isArray(responseData.adverts)) {
    return result;
  }

  const numericFilterStatus = filterStatus !== null ? Number(filterStatus) : null;

  for (const advertGroup of responseData.adverts) {
    const { type, status, advert_list } = advertGroup;

    if (!advert_list || !Array.isArray(advert_list)) continue;

    const groupStatus = Number(status);
    if (numericFilterStatus !== null && groupStatus !== numericFilterStatus) continue;

    for (const advert of advert_list) {
      if (!advert.advertId) continue;

      result.push({
        advertid: Number(advert.advertId),
        crmtype: Number(type),
        crmstatus: groupStatus,
      });
    }
  }

  if (numericFilterStatus === null) {
    result.sort((a, b) => a.crmstatus - b.crmstatus || a.crmtype - b.crmtype);
  } else {
    result.sort((a, b) => a.crmtype - b.crmtype);
  }

  return result;
}

// ---------------------------------------------------------------------------
// enrichAdvertData — обогащает данные кампаний деталями из API
// ---------------------------------------------------------------------------
export async function enrichAdvertData(parsedData, getCrmDetailsUrl, crmApiKey, userId) {
  const enriched = parsedData.map(item => ({
    ...item,
    user_id: userId,
    crmname: null,
    crmsps: null,
    crmpt: null,
    pause_time: null,
    restart_time: null,
    active: false
  }));

  for (let i = 0; i < enriched.length; i += BATCH_SIZE) {
    const batch = enriched.slice(i, i + BATCH_SIZE);
    const advertIds = batch.map(item => item.advertid);
    const batchNumber = i / BATCH_SIZE + 1;

    let success = false;
    for (let retry = 0; retry <= MAX_RETRIES && !success; retry++) {
      try {
        const { data } = await axios.get(getCrmDetailsUrl, {
          params: { ids: advertIds.join(',') },
          headers: {
            Authorization: `Bearer ${crmApiKey}`,
            'Content-Type': 'application/json',
            Accept: 'application/json'
          },
          timeout: REQUEST_TIMEOUT
        });

        const detailsMap = {};
        data.adverts.forEach(campaign => {
          detailsMap[campaign.id] = {
            crmname: campaign.settings?.name || null,
            crmpt: campaign.settings?.payment_type || null,
            crmsps: campaign.settings?.placements?.search === true
          };
        });

        batch.forEach(item => {
          const details = detailsMap[item.advertid];
          if (details) Object.assign(item, details);
        });

        success = true;
      } catch (error) {
        if (retry < MAX_RETRIES) {
          logger.warn(`Retrying batch ${batchNumber}, attempt ${retry + 1}/${MAX_RETRIES}`);
          await delay(1000 * (retry + 1));
        } else {
          logger.error(`Failed batch ${batchNumber} after ${MAX_RETRIES} retries: ${error.message}`);
          throw new Error(`Failed to process batch ${batchNumber}: ${error.message}`);
        }
      }
    }
  }

  return enriched;
}

// ---------------------------------------------------------------------------
// pauseCampaignsList — последовательная пауза списка кампаний
// ---------------------------------------------------------------------------
export async function pauseCampaignsList(advertIds, crmApiKey) {
  const results = [];
  let message = `🔄 Начато выполнение для ${advertIds.length} кампаний:\n\n`;

  for (let i = 0; i < advertIds.length; i++) {
    const id = advertIds[i];
    message += `⏳ Обрабатываю кампанию ${id}...\n`;

    try {
      await pauseCampaign(id, crmApiKey);
      results.push({ id, success: true });
      message += `✅ Успех\n\n`;
    } catch (error) {
      results.push({ id, success: false, error: error.message });
      message += `❌ Ошибка: ${error.message}\n\n`;
    }

    // Задержка между кампаниями, кроме последней
    if (i < advertIds.length - 1) {
      await delay(DELAY_BETWEEN_CAMPAIGNS);
    }
  }

  // Итоговый отчёт
  const successCount = results.filter(r => r.success).length;
  const failCount = results.filter(r => !r.success).length;

  message += '\n📊 Итоговый отчет:\n';
  message += results.map(r => `▫️ ${r.id}: ${r.success ? '✅' : '❌'}`).join('\n');
  message += `\n\n✔️ Успешно: ${successCount}`;
  message += `\n✖️ Ошибки: ${failCount}`;
  message += `\nВсего: ${results.length}`;

  return message;
}

// ---------------------------------------------------------------------------
// Утилита задержки
// ---------------------------------------------------------------------------
function delay(ms) {
  return new Promise(resolve => setTimeout(resolve, ms));
}