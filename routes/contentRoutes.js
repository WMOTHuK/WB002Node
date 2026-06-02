// routes/contentRoutes.js
import server_config from '../config/apiurls.js'
import express from 'express';
import axios from 'axios';
import { createErrorResponse } from '../utils/errorhandling.js'
import { authenticate } from '../middleware/auth.js';
import { syncTableToDB, syncTableFromDB } from '../General/DBactions/tableSync.js';
import { pool } from '../General/globals.js';
import { getAPIKey } from '../utils/apiutils.js';
import { checkAndInsertPrice } from '../utils/pricingutils.js';
import { getViewData } from '../General/DBactions/dbViews.js';
import { removeByKeyValue } from '../General/ArrayActions/arraySort.js';


const router = express.Router();

// конфигурацию запроса по карточкам товаров
const DEFAULT_REQUEST_CONFIG = {
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

// запрос к API 
async function fetchGoodsData(apiKey) {
  return axios.post(server_config.getcardsurl, DEFAULT_REQUEST_CONFIG, {
    headers: { 'Authorization': `Bearer ${apiKey}` }
  });
}

function processCards(wbData) {
  if (!Array.isArray(wbData)) {
    throw new Error("wbData is not an array");
  }

  const singleFields = [];
  const photos = [];

  // Определение ключей, которые нужно включить в singleFields
  const includedKeys = ['nmID', 'imtID', 'subjectID', 'subjectName', 'vendorCode', 'brand', 'title'];

  

  wbData.forEach(card => {
    const cardSingleFields = {};

    Object.entries(card).forEach(([key, value]) => {
      // Преобразование ключа к нижнему регистру
      const keyLowerCase = key.toLowerCase();

      if (key === 'photos' && Array.isArray(value)) {
        // Обработка массива фотографий
        const firstPhotoSmall = value.length > 0 ? value[0].tm : null;
        const firstPhotoBig = value.length > 0 ? value[0].big : null;
        if (firstPhotoSmall) {
          photos.push({ vendorcode: card.vendorCode, small: firstPhotoSmall, big: firstPhotoBig }); // Используем vendorcode из входных данных
        } else {}
      } else if (includedKeys.includes(key)) {
        // Включение поля, если его ключ в списке разрешенных
        cardSingleFields[keyLowerCase] = value;
      }
    });

    if (Object.keys(cardSingleFields).length > 0) {
      singleFields.push(cardSingleFields);
    }
  });

  return { singleFields, photos };
}



router.get('/getgoodsdata', authenticate, async (req, res) => {
  try {
/*     1. получим данные из Вайлдберриз */
    const contentAPIKEY = await getAPIKey(req.user.id,'2');
    const response = await fetchGoodsData(contentAPIKEY);

/*     2. Преобразуем в два массива в соответствии со структурой БД */
    const { singleFields: goods, photos } = processCards(response.data.cards);

/*     3. Поочерёдно обновим данные в БД для каждой из таблиц */
    const resultgoodsupdate = syncTableToDB(goods,'goods','vendorcode')
    const resultphotosupdate = syncTableToDB(photos,'photos','vendorcode')

/*     4. Fetch product_data from bd */
    const productdata = await getViewData(pool, 'product_data');

/*     5. Filter deleted */
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