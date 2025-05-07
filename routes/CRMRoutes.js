// routes/crmRoutes.js

import express from 'express';
import axios from 'axios';
import { readtable } from '../General/DBactions/readtable.js';
import { authenticate } from '../middleware/auth.js';
import { decrypt } from '../utils/crypto.js';

const router = express.Router();

// Конфигурация сервера
const SERVER_CONFIG = {
  getcompaignsurl: 'https://advert-api.wildberries.ru/adv/v1/promotion/count', // URL получения данных о кампаниях
  getcrmdetailsurl: 'https://advert-api.wildberries.ru/adv/v1/promotion/adverts',
  // Другие URL могут быть добавлены здесь
 

};

// Получение API ключа из БД
async function getcrmAPIKey(userId) {
  try {
    const apiKeys = await readtable('user_api_keys', [
      { colname: 'user_id', sign: 'EQ', low: userId },
      { colname: 'key_type', sign: 'EQ', low: 1 } // key_type = 1 для CRM API
    ]);

    if (!apiKeys || apiKeys.length === 0) {
      throw new Error('Content API key not found for this user');
    }

       // Дешифруем ключ перед использованием
        const decryptedKey = decrypt(apiKeys[0].api_key);
    return decryptedKey;
  } catch (error) {
    console.error('Error getting CRM API key:', error);
    throw error;
  }
}

function parseAdverts(responseData) {
  const result = [];
  
  if (!responseData.adverts || !Array.isArray(responseData.adverts)) {
      return result;
  }
  
  // Сначала собираем все данные
  for (const advertGroup of responseData.adverts) {
      const { type, status, advert_list } = advertGroup;
      
      if (!advert_list || !Array.isArray(advert_list)) {
          continue;
      }
      
      for (const advert of advert_list) {
          if (advert.advertId) {
              result.push({
                  advertId: advert.advertId,
                  type: type,
                  status: status
              });
          }
      }
  }
  
  // Сортируем по статусу (по возрастанию), затем по типу (по возрастанию)
  result.sort((a, b) => {
      if (a.status !== b.status) {
          return a.status - b.status;
      }
      return a.type - b.type;
  });
  
  return result;
}
async function enrichAdvertData(parsedData, getcrmdetailsurl, crmAPIKEY) {
  const enrichedData = parsedData.map(item => ({
    ...item,
    pause_time: null,
    restart_time: null,
    pause_active: false
  }));

  const batchSize = 50;
  const maxRetries = 2;
  const failedBatches = [];
  
  // Разбиваем данные на пакеты по 50 элементов
  for (let i = 0; i < enrichedData.length; i += batchSize) {
    const batch = enrichedData.slice(i, i + batchSize);
    const advertIds = batch.map(item => Number(item.advertId));
    const batchNumber = i / batchSize + 1;
    
    let retryCount = 0;
    let lastError = null;
    let success = false;

    // Повторяем попытки до maxRetries раз
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
            name: detail.name,
            paymentType: detail.paymentType,
            searchPluseState: detail.searchPluseState
          };
        });
        
        batch.forEach(item => {
          const details = detailsMap[item.advertId];
          if (details) {
            item.name = details.name;
            item.paymentType = details.paymentType;
            item.searchPluseState = details.searchPluseState;
          }
        });
        
        success = true;
      } catch (error) {
        lastError = error;
        retryCount++;
        if (retryCount <= maxRetries) {
          console.warn(`Retrying batch ${batchNumber}, attempt ${retryCount}/${maxRetries}`);
          // Добавляем небольшую задержку перед повторной попыткой
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

router.get('/getcompaigns', authenticate, async (req, res) => {
  try {
    const userId = req.user.id;

    // Получаем API ключ из БД
    const crmAPIKEY = await getcrmAPIKey(userId);

    // Выполняем запрос к внешнему API
    const response = await axios.get(SERVER_CONFIG.getcompaignsurl,  {
      headers: { 'Authorization': `Bearer ${crmAPIKEY}` }
    });

    // Проверяем и преобразуем данные
    let responseData = response.data;
    
    const parsedData = parseAdverts(responseData);  // Прогоним через парсер 

    //Обагатим данными (имя, тип оплаты,Активность фиксированных фраз)
    const enrichedData = await enrichAdvertData(parsedData, SERVER_CONFIG.getcrmdetailsurl, crmAPIKEY);
    // Теперь enrichedData содержит все исходные поля + name, paymentType, searchPluseState
    

    // Явно возвращаем массив данных
    res.status(200).json(enrichedData);
    
  } catch (error) {
    console.error('Error in /getcompaigns:', error);
    
    const status = error.response?.status || 500;
    const message = error.response?.data?.message || error.message;
    
    res.status(status).json({ 
      error: 'Failed to fetch crm data',
      details: message,
      stack: process.env.NODE_ENV === 'development' ? error.stack : undefined
    });
  }
});

export default router;