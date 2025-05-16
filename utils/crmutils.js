
import { pauseCampaign } from "../services/scheduler/campaign.actions.js";


export function parseAdverts(responseData, filterStatus = null) {
  const result = [];
  
  // Проверка входных данных
  if (!responseData?.adverts || !Array.isArray(responseData.adverts)) {
    return result;
  }

  // Конвертируем filterStatus в число (если передан)
  const numericFilterStatus = filterStatus !== null ? Number(filterStatus) : null;

  // Обработка данных
  for (const advertGroup of responseData.adverts) {
    const { type, status, advert_list } = advertGroup;
    
    if (!advert_list || !Array.isArray(advert_list)) continue;
    
    // Быстрая проверка статуса группы (оптимизация)
    const groupStatus = Number(status);
    if (numericFilterStatus !== null && groupStatus !== numericFilterStatus) continue;

    for (const advert of advert_list) {
      if (!advert.advertId) continue;
      
      result.push({
        advertid: Number(advert.advertId),
        crmtype: Number(type),
        crmstatus: groupStatus, // Используем уже конвертированное значение
        // Другие поля...
      });
    }
  }

  // Умная сортировка (пропускаем если фильтр по статусу активен)
  if (numericFilterStatus === null) {
    result.sort((a, b) => {
      // Сначала по статусу, затем по типу (оба по возрастанию)
      return a.crmstatus - b.crmstatus || a.crmtype - b.crmtype;
    });
  } else {
    // При фильтрации сортируем только по типу
    result.sort((a, b) => a.crmtype - b.crmtype);
  }

  return result;
}

export async function enrichAdvertData(parsedData, getcrmdetailsurl, crmAPIKEY, userId) {
    const enrichedData = parsedData.map(item => ({
      ...item,
      user_id: userId,
      crmname: null,        
      crmsps: null,         
      crmpt: null,         
      pause_time: null,     
      restart_time: null,   
      active: false         
    }));
  
    const batchSize = 50;
    const maxRetries = 2;
    const failedBatches = [];
    
    for (let i = 0; i < enrichedData.length; i += batchSize) {
      const batch = enrichedData.slice(i, i + batchSize);
      const advertIds = batch.map(item => item.advertid);
      const batchNumber = i / batchSize + 1;
      
      let retryCount = 0;
      let lastError = null;
      let success = false;
  
      while (retryCount <= maxRetries && !success) {
        try {
          const response = await axios.post(getcrmdetailsurl, advertIds, {
            headers: { 
              'Authorization': `Bearer ${crmAPIKEY}`,
              'Content-Type': 'application/json',
              'Accept': 'application/json'
            },
            timeout: 30000
          });
  
          const detailsMap = {};
          
          response.data.forEach(detail => {
            detailsMap[detail.advertId] = {
              crmname: detail.name || null,
              crmpt: detail.paymentType || null,
              crmsps: detail.searchPluseState === 'on' ? true : false
            };
          });
          
          batch.forEach(item => {
            const details = detailsMap[item.advertid];
            if (details) {
              item.crmname = details.crmname;
              item.crmpt = details.crmpt;
              item.crmsps = details.crmsps;
            }
          });
          
          success = true;
        } catch (error) {
          lastError = error;
          retryCount++;
          if (retryCount <= maxRetries) {
            console.warn(`Retrying batch ${batchNumber}, attempt ${retryCount}/${maxRetries}`);
            await new Promise(resolve => setTimeout(resolve, 1000 * retryCount));
          }
        }
      }
  
      if (!success) {
        console.error(`Failed to process batch ${batchNumber} after ${maxRetries} retries:`, lastError.message);
        failedBatches.push({
          batchNumber,
          error: lastError
        });
      }
    }
  
    if (failedBatches.length > 0) {
      const errorMessage = `Failed to process ${failedBatches.length} batch(es): ${failedBatches.map(b => b.batchNumber).join(', ')}`;
      console.error(errorMessage);
      throw new Error(errorMessage);
    }
    
    return enrichedData;
}

export async function pausecampaignslist(advertids, crmapikey) {
const results = [];

// Добавляем информацию о начале процесса
let message = `🔄 Начато выполнение для ${advertids.length} кампаний:\n\n`;

for (const id of advertids) {
    try {
    // Добавляем в лог информацию о текущей кампании
    message += `⏳ Обрабатываю кампанию ${id}...\n`;
    
    const operationResult = await pauseCampaign(id, crmapikey);
    
    results.push({
        id,
        success: operationResult.success,
        status: operationResult.status,
        data: operationResult.data
    });
    
    // Добавляем результат в лог
    message += operationResult.success 
        ? `✅ Успех: ${operationResult.status}\n\n`
        : `❌ Ошибка: ${operationResult.status}\n\n`;
    
    if (id !== advertids[advertids.length - 1]) {
        await new Promise(resolve => setTimeout(resolve, 1000));
    }
    
    } catch (error) {
    const errorStatus = `Фатальная ошибка при обработке кампании ${id}: ${error.message}`;
    results.push({
        id,
        success: false,
        error: error.message,
        status: errorStatus
    });
    message += `❌ ${errorStatus}\n\n`;
    }
}

// Формируем итоговое сообщение
message += '\n📊 Итоговый отчет:\n';
message += results.map(r => 
    `▫️ ${r.id}: ${r.success ? '✅' : '❌'} ${r.status}`
).join('\n');

message += `\n\n✔️ Успешно: ${results.filter(r => r.success).length}`;
message += `\n✖️ Ошибки: ${results.filter(r => !r.success).length}`;
message += `\nВсего: ${results.length}`;

return message;
}

