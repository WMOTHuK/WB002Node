// routes/contentRoutes.js

import express from 'express';
import axios from 'axios';
import { readtable } from '../General/DBactions/readtable.js';
import { authenticate } from '../middleware/auth.js';
import { decrypt } from '../utils/crypto.js';

const router = express.Router();

// Конфигурация сервера
const SERVER_CONFIG = {
  getcardsurl: 'https://content-api.wildberries.ru/content/v2/get/cards/list', // URL получения данных о карточках
  // Другие URL могут быть добавлены здесь
 

};

// Получение API ключа из БД
async function getContentAPIKey(userId) {
  try {
    const apiKeys = await readtable('user_api_keys', [
      { colname: 'user_id', sign: 'EQ', low: userId },
      { colname: 'key_type', sign: 'EQ', low: 2 } // key_type = 2 для content API
    ]);

    if (!apiKeys || apiKeys.length === 0) {
      throw new Error('Content API key not found for this user');
    }

       // Дешифруем ключ перед использованием
        const decryptedKey = decrypt(apiKeys[0].api_key);
    return decryptedKey;
  } catch (error) {
    console.error('Error getting Content API key:', error);
    throw error;
  }
}

router.get('/getgoodsdata', authenticate, async (req, res) => {
  try {
    const userId = req.user.id;

    // Получаем API ключ из БД
    const contentAPIKEY = await getContentAPIKey(userId);

    // Выполняем запрос к внешнему API
    const response = await axios.post(SERVER_CONFIG.getcardsurl, {
      settings: {
        sort: { ascending: false },
        filter: {
          textSearch: "",
          allowedCategoriesOnly: true,
          tagIDs: [],
          objectIDs: [],
          brands: [],
          imtID: 0,
          withPhoto: -1
        },
        cursor: {
          updatedAt: null,
          nmID: 0,
          limit: 99
        }
      }
    }, {
      headers: { 'Authorization': `Bearer ${contentAPIKEY}` }
    });

    // Проверяем и преобразуем данные
    let responseData = response.data;
    
    // Если данные не массив - преобразуем (пример для разных форматов ответа)
    if (!Array.isArray(responseData)) {
      if (responseData.cards && Array.isArray(responseData.cards)) {
        responseData = responseData.cards;
      } else if (responseData.data && Array.isArray(responseData.data)) {
        responseData = responseData.data;
      } else {
        // Если структура неизвестна, возвращаем как есть с предупреждением
        console.warn('Unexpected API response format:', responseData);
      }
    }

    // Явно возвращаем массив данных
    res.status(200).json(Array.isArray(responseData) ? responseData : [responseData]);
    
  } catch (error) {
    console.error('Error in /getgoodsdata:', error);
    
    const status = error.response?.status || 500;
    const message = error.response?.data?.message || error.message;
    
    res.status(status).json({ 
      error: 'Failed to fetch goods data',
      details: message,
      stack: process.env.NODE_ENV === 'development' ? error.stack : undefined
    });
  }
});

export default router;