// routes/contentRoutes.js
import server_config from '../src/config/api.config.js'
import express from 'express';
import axios from 'axios';
import { createErrorResponse } from '../utils/errorhandling.js'
import { authenticate } from '../src/api/middleware/auth.middleware.js';
import { syncTableToDB, syncTableFromDB } from '../src/utils/tableSync.utils.js';
import { pool } from '../src/config/db.config.js';
import { getApiKeyByUser } from '../src/services/apiKey.service.js';
import { checkAndInsertPrice } from '../utils/pricingutils.js';
import { getViewData } from '../src/utils/db/dbViews.utils.js';
import { removeByKeyValue, filterArrayByKeys, filterDeepArrayByKeys, renameKeysOnlyMapped} from '../utils/arrayutils.js';


const router = express.Router();

// конфигурацию запроса по карточкам товаров
const WB_DEFAULT_REQUEST_CONFIG = {
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
};



/**
 * Вычисляет объем в литрах на основе размеров товара
 * @param {Object} item - Товар с полями height, depth, width, dimension_unit
 * @returns {number|null} - Объем в литрах (округленный вверх) или null
 */
function calculateOzonVolume(item) {
    const { height, depth, width, dimension_unit } = item;
    
    // Проверяем наличие всех необходимых полей
    if (!height || !depth || !width || !dimension_unit) {
        return null;
    }
    
    // Проверяем, что все значения - числа
    if (typeof height !== 'number' || typeof depth !== 'number' || typeof width !== 'number') {
        return null;
    }
    
    let volumeCm3 = 0;
    
    // Переводим размеры в сантиметры в зависимости от единицы измерения
    if (dimension_unit === 'mm') {
        // Миллиметры → сантиметры (делим на 10)
        volumeCm3 = (height / 10) * (depth / 10) * (width / 10);
    } else if (dimension_unit === 'cm') {
        // Сантиметры
        volumeCm3 = height * depth * width;
    } else if (dimension_unit === 'm') {
        // Метры → сантиметры (умножаем на 100)
        volumeCm3 = (height * 100) * (depth * 100) * (width * 100);
    } else {
        console.warn(`Неизвестная единица измерения: ${dimension_unit}`);
        return null;
    }
    
    // Переводим в литры (1 литр = 1000 кубических сантиметров)
    const volumeLiters = volumeCm3 / 1000;
    
    // Округляем вверх до целого числа
    return Math.ceil(volumeLiters);
}

/**
 * Получает информацию о размерах товаров из Ozon API
 * @param {string} apiKey - API-ключ Ozon
 * @param {string} clientId - Client ID Ozon
 * @param {Array<string>} productIds - Массив product_id
 * @returns {Promise<Object>} - Объект с маппингом product_id -> объем
 */
async function fetchOzonProductsAttributes(apiKey, clientId, productIds) {
    if (!Array.isArray(productIds) || productIds.length === 0) {
        return {};
    }
    
    const config = {
        filter: {
            product_id: productIds.map(id => String(id))
        },
        last_id: "",
        limit: Math.min(productIds.length, 1000)
    };
    
    try {
        const response = await axios.post(
            server_config.ozon_product_attr,
            config,
            {
                headers: {
                    'Client-Id': clientId,
                    'Api-Key': apiKey,
                    'Content-Type': 'application/json'
                },
                timeout: 30000
            }
        );
        
        const items = response.data?.result || [];
        
        // Создаем маппинг product_id -> объем
        const volumeMap = {};
        items.forEach(item => {
            const volume = calculateOzonVolume(item);
            if (volume !== null) {
                volumeMap[item.id] = volume;
            }
        });
        
        console.log(`Получены объемы для ${Object.keys(volumeMap).length} товаров`);
        
        return volumeMap;
        
    } catch (error) {
        console.error('Ошибка при получении атрибутов товаров Ozon:', error.response?.data || error.message);
        return {};
    }
}
// запрос к API 
async function fetchWBGoodsData(apiKey) {
  return axios.post(server_config.getcardsurl, WB_DEFAULT_REQUEST_CONFIG, {
    headers: { 'Authorization': `Bearer ${apiKey}` }
  });
}

/**
 * Получение списка товаров Ozon с автоматической пагинацией
 * @param {string} apiKey - API-ключ Ozon
 * @param {string} clientId - Client ID Ozon
 * @param {number} limit - Количество товаров на страницу (по умолчанию 100)
 * @returns {Promise<Array>} Массив всех товаров
 */
async function fetchOZONGoodsList(apiKey, clientId, limit = 100) {
  let allProducts = [];
  let lastId = "";
  let hasMore = true;
  
  while (hasMore) {
    const config = {
      filter: {
        offer_id: [],
        product_id: [],
        visibility: "ALL"
      },
      last_id: lastId,
      limit: limit
    };
    
    try {
      const response = await axios.post(
        server_config.ozon_product_list,
        config,
        {
          headers: {
            'Client-Id': clientId,
            'Api-Key': apiKey,
            'Content-Type': 'application/json'
          }
        }
      );
      
      // Получаем данные из правильной структуры
      const { items, last_id, total } = response.data.result;
      
      if (items && Array.isArray(items) && items.length > 0) {
        allProducts = [...allProducts, ...items];
        console.log(`Загружено товаров: ${allProducts.length} из ${total}`);
      }
      
      // Обновляем lastId для следующей итерации
      lastId = last_id || "";
      
      // Проверяем, есть ли еще товары
      hasMore = items && items.length === limit && allProducts.length < total;
      
      // Если total известен и мы загрузили все, выходим
      if (total && allProducts.length >= total) {
        hasMore = false;
        allProducts = removeByKeyValue(allProducts, 'archived', true)
        allProducts = filterArrayByKeys(allProducts, ['product_id']);
      }
      
    } catch (error) {
      console.error('Ошибка при загрузке страницы:', error.response?.data || error.message);
      throw error;
    }
  }
  
  return allProducts;
}


/**
 * Получение информации о товарах с параллельными запросами атрибутов
 */
async function fetchOzonProductsInfo(apiKey, clientId, productIds, chunkSize = 100) {
    if (!Array.isArray(productIds) || productIds.length === 0) {
        return [];
    }
    
    // Нормализуем ID
    const normalizedIds = productIds
        .map(item => typeof item === 'object' && item !== null ? (item.product_id || item.id) : item)
        .filter(id => id !== null)
        .map(id => String(id));
    
    if (normalizedIds.length === 0) {
        return [];
    }
    
    // Запускаем оба запроса параллельно
    console.log(`Запрос данных для ${normalizedIds.length} товаров...`);
    
    const [volumeMap, allResults] = await Promise.all([
        fetchOzonProductsAttributes(apiKey, clientId, normalizedIds),
        fetchOzonProductsInfoChunks(apiKey, clientId, normalizedIds, chunkSize)
    ]);
    
    // Формируем результат
    const result = allResults
        .filter(item => item.id && item.offer_id)
        .map(item => ({
            ozid: item.sku || item.id,
            vendorcode: item.offer_id,
            title: item.name,
            card_photo: item.primary_image?.[0] || null,
            ozvol: volumeMap[item.id] || null
        }));
    
    console.log(`Успешно получено товаров: ${result.length} (с объемом: ${result.filter(r => r.ozvol).length})`);
    
    return result;
}

/**
 * Вспомогательная функция для получения информации пачками
 */
async function fetchOzonProductsInfoChunks(apiKey, clientId, productIds, chunkSize = 100) {
    const actualChunkSize = Math.min(chunkSize, 100);
    const chunks = [];
    
    for (let i = 0; i < productIds.length; i += actualChunkSize) {
        chunks.push(productIds.slice(i, i + actualChunkSize));
    }
    
    let allResults = [];
    
    for (let i = 0; i < chunks.length; i++) {
        try {
            const result = await fetchOzonProductsInfoChunk(apiKey, clientId, chunks[i]);
            allResults = [...allResults, ...result];
            await new Promise(resolve => setTimeout(resolve, 500));
        } catch (error) {
            console.error(`Ошибка в пачке ${i + 1}:`, error.message);
        }
    }
    
    return allResults;
}
/**
 * Внутренняя функция для отправки запроса одной пачкой (до 1000 товаров)
 */
async function fetchOzonProductsInfoChunk(apiKey, clientId, productIds) {
    const config = {
        product_id: productIds.map(id => String(id)) // Преобразуем в строки, как требует API
    };
    
    try {
        const response = await axios.post(
            server_config.ozon_product_info, // предполагаемый URL, замените на правильный
            config,
            {
                headers: {
                    'Client-Id': clientId,
                    'Api-Key': apiKey,
                    'Content-Type': 'application/json'
                }
            }
        );
        
        const items = response.data?.result?.items || response.data?.items || [];
        
        console.log(`Получена информация для ${items.length} товаров из ${productIds.length} запрошенных`);
        
        return items;
        
    } catch (error) {
        console.error('Ошибка при получении информации о товарах Ozon:', error.response?.data || error.message);
        throw error;
    }
}

/**
 * Вычисляет объем в литрах с округлением вверх
 * @param {Object} dimensions - Объект с размерами { width, height, length }
 * @returns {number|null} - Объем в литрах или null
 */
function calculateVolume(dimensions) {
  if (!dimensions || typeof dimensions !== 'object') {
    return null;
  }
  
  const { width, height, length } = dimensions;
  
  if (typeof width !== 'number' || width <= 0 ||
      typeof height !== 'number' || height <= 0 ||
      typeof length !== 'number' || length <= 0) {
    return null;
  }
  
  const volumeCm3 = width * height * length;
  const volumeLiters = volumeCm3 / 1000;
  
  return Math.ceil(volumeLiters);
}

/**
 * Извлекает первое фото из карточки товара
 * @param {Object} card - Карточка товара
 * @returns {string|null} - URL первого фото или null
 */
function getFirstPhoto(card) {
  if (!card.photos || !Array.isArray(card.photos) || card.photos.length === 0) {
    return null;
  }
  return card.photos[0].big || null;
}

/**
 * Извлекает основные поля из карточки товара
 * @param {Object} card - Карточка товара
 * @returns {Object} - Объект с основными полями
 */
function extractBasicFields(card) {
  const fields = ['nmID', 'imtID', 'subjectID', 'subjectName', 'vendorCode', 'brand', 'title'];
  const result = {};
  
  fields.forEach(field => {
    if (card[field] !== undefined && card[field] !== null) {
      result[field] = card[field];
    }
  });
  
  return result;
}
/**
 * Обрабатывает данные карточек товаров (с объемом)
 * @param {Array} wbData - Массив карточек товаров от Wildberries API
 * @returns {Array} Массив объектов с полями: nmID, imtID, subjectID, subjectName, vendorCode, brand, title, card_photo, wbvol
 */
function processCards(wbData) {
  if (!Array.isArray(wbData)) {
    throw new Error("wbData is not an array");
  }
  
  return wbData.map(card => {
    const basicFields = extractBasicFields(card);
    const volume = calculateVolume(card.dimensions);
    
    return {
      ...basicFields,
      card_photo: getFirstPhoto(card),
      ...(volume !== null && { wbvol: volume }) // Добавляем объем, если он есть
    };
  });
}


router.get('/getgoodsdata', authenticate, async (req, res) => {
  try {
/** BEGIN UPDATE OF WB GOODS **/
/*     1. получим данные из Вайлдберриз */
    const contentAPIKEY = await getApiKeyByUser(req.user.id,'2');
    const wb_goodsdata = await fetchWBGoodsData(contentAPIKEY);

/*     2. Преобразуем в два массива в соответствии со структурой БД */
    const wb_goods = processCards(wb_goodsdata.data.cards);

/*     3. Update goods table in DB */
    const wb_goodsupdate_result = await syncTableToDB(wb_goods,'goods','vendorcode')
/** END UPDATE OF WB GOODS **/

/** BEGIN UPDATE OF OZON GOODS **/
/*     1. Get api key and userid from DB */
    const ozon_content_apikey = await getApiKeyByUser(req.user.id,'3');
    const ozon_userid = await getApiKeyByUser(req.user.id,'4');

/*     2. Get goods id's from OZON */
    const ozon_goodslist = await fetchOZONGoodsList(ozon_content_apikey, ozon_userid);
    const ozon_id_list = ozon_goodslist.map(item => item.product_id);

/*     3. Get goods data from OZON */
    const ozon_goods = await fetchOzonProductsInfo(ozon_content_apikey, ozon_userid, ozon_id_list);

/*     4. Update goods table in DB */
    const ozon_goodsupdate_result = await syncTableToDB(ozon_goods,'goods','vendorcode')

/** END UPDATE OF OZON GOODS **/


/*     5. Fetch product_data from bd */
    const productdata =   await getViewData('product_data');

/*     6. Filter deleted */
    const activeProducts = removeByKeyValue(productdata, 'deleted', true);

    res.status(200).json(normalizeResponseData(activeProducts));
  } catch (error) {
    const { status, data } = createErrorResponse(error);
    res.status(status).json(data);
  }
});


function normalizeResponseData(data) {
  return Array.isArray(data) ? data : [data];
}


router.post('/updateprices', async (req, res) => {
  try {
      let data = req.body.data.listGoods; // Обновление пути до данных
      let transformedData = data.map(item => {
        // Проверка, есть ли размеры в товаре и взятие первого элемента
        let firstSize = item.sizes && item.sizes[0] ? item.sizes[0] : null;

        return {
          nmId: item.nmID,
          price: firstSize ? firstSize.price : 0, // Если размеры есть, берём цену первого размера 
          discount: item.discount,
          promoCode: 0,
          currentprice: firstSize ? firstSize.discountedPrice : 0, // Если размеры есть, берём цену первого размера
          dayprice: 0, // Примерное значение
          nightprice: 0, // Примерное значение
          daydisc: 0, // Примерное значение
          nightdisc: 0, // Примерное значение
          active: ''
        };
      });
      // Сохранение данных в базе данных
      const results = await checkAndInsertPrice(transformedData);
      res.json(results); // Отправляем результаты
      const successMessage = 'API успешно отработал ';
      logMessage('/api/save-data/prices', 2, successMessage); // Логирование успешной отработки запроса API
    } catch (error) {
      sendlogTG(error.message);
      logMessage('/api/save-data/prices', 2, error.message); // Логирование неуспешной отработки запроса API
      res.status(500).send('Ошибка сервера');
    }
    });


/**
 * Обновление себестоимости товара
 * POST /api/content/update_cost_price
 * Body: { vendorcode, new_cost, start_date }
 * Headers: { Authorization: Bearer <token> }
 */
router.post('/update_cost_price', async (req, res) => {
  try {
    const { vendorcode, new_cost, start_date } = req.body;
    
    // Валидация обязательных полей
    if (!vendorcode) {
      return res.status(400).json({
        success: false,
        error: 'vendorcode обязателен'
      });
    }
    
    if (!new_cost || new_cost <= 0) {
      return res.status(400).json({
        success: false,
        error: 'new_cost должен быть положительным числом'
      });
    }
    
    if (!start_date) {
      return res.status(400).json({
        success: false,
        error: 'start_date обязателен'
      });
    }
    
    // Проверка формата даты YYYY-MM-DD
    const dateRegex = /^\d{4}-\d{2}-\d{2}$/;
    if (!dateRegex.test(start_date)) {
      return res.status(400).json({
        success: false,
        error: 'start_date должен быть в формате YYYY-MM-DD'
      });
    }
    
    // Вызов хранимой функции PostgreSQL
    const query = `
      SELECT * FROM update_cost_price($1, $2, $3)
    `;
    
    const result = await pool.query(query, [
      vendorcode,
      new_cost,
      start_date
    ]);
    
    const response = result.rows[0];
    
    // Отправка ответа клиенту
    res.json({
      success: response.status === 'SUCCESS',
      status: response.status,
      message: response.message,
      data: {
        old_cost: response.old_cost,
        new_cost: response.new_cost,
        effective_from: response.effective_from,
        effective_to: response.effective_to
      }
    });
    
  } catch (error) {
    console.error('Ошибка при обновлении себестоимости:', error);
    res.status(500).json({
      success: false,
      error: 'Внутренняя ошибка сервера',
      details: process.env.NODE_ENV === 'development' ? error.message : undefined
    });
  }
});

export default router;