// routes/contentRoutes.js
import server_config from '../config/apiurls.js'
import express from 'express';
import axios from 'axios';
import { createErrorResponse } from '../utils/errorhandling.js'
import { authenticate } from '../middleware/auth.js';
import { syncTableToDB, syncTableFromDB } from '../General/DBactions/tableSync.js';
import { pool } from '../General/globals.js';
import { getAPIKey } from '../utils/apiutils.js';


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
          photos.push({ nmid: card.nmID, small: firstPhotoSmall, big: firstPhotoBig }); // Используем nmID из входных данных
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

const extendGoods = async (pool, igoods) => {
  if (!igoods || igoods.length === 0) return igoods;

  try {
    // 1. Получаем nmid всех товаров для запроса
    const nmids = igoods.map(g => g.nmid);
    
    // 2. Запрос к БД для получения данных
    const query = `
      SELECT 
        g.nmid, 
        g.sprice, 
        p.big
      FROM goods g
      LEFT JOIN photos p ON g.nmid = p.nmid
      WHERE g.nmid = ANY($1::int[])
    `;

    const { rows: dbData } = await pool.query(query, [nmids]);

    // 3. Создаем lookup-объект для быстрого доступа
    const dbDataMap = dbData.reduce((acc, row) => {
      acc[row.nmid] = {
        sprice: row.sprice,
        big: row.big
      };
      return acc;
    }, {});

    // 4. Расширяем исходный массив
    return igoods.map(item => ({
      ...item,
      sprice: dbDataMap[item.nmid]?.sprice || null,
      big: dbDataMap[item.nmid]?.big || null
    }));

  } catch (error) {
    console.error('Ошибка при расширении товаров:', error);
    throw error;
  }
};



router.get('/getgoodsdata', authenticate, async (req, res) => {
  try {
/*     1. получим данные из Вайлдберриз */
    const contentAPIKEY = await getAPIKey(req.user.id,'2');
    const response = await fetchGoodsData(contentAPIKEY);

/*     2. Преобразуем в два массива в соответствии со структурой БД */
    const { singleFields: goods, photos } = processCards(response.data.cards);

/*     3. Поочерёдно обновим данные в БД для каждой из таблиц */
    const resultgoodsupdate = syncTableToDB(goods,'goods','nmid')
    const resultphotosupdate = syncTableToDB(photos,'photos','nmid')

/*     4. Добавим в массив goods нужные поля и обновим данные из БД */
    const extendedgoods = await extendGoods(pool,goods)

/*     5. Сортируем по номенклатуре продавца */
    const sortedGoods = extendedgoods.sort((a, b) => 
      (a.vendorcode || '').localeCompare(b.vendorcode || '')
    );

    res.status(200).json(normalizeResponseData(sortedGoods));
  } catch (error) {
    const { status, data } = createErrorResponse(error);
    res.status(status).json(data);
  }
});


function normalizeResponseData(data) {
  return Array.isArray(data) ? data : [data];
}

export default router;