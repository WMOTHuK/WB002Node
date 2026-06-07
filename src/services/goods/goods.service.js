// src/services/goods/goods.service.js
import { getApiKeyByUser } from '../apiKey.service.js';
import { fetchWBGoods, processWBCards } from '../../utils/wb.utils.js';
import { processOzonGoods } from '../../utils/ozon.utils.js';
import { syncTableToDB, syncTableFromDB } from '../../utils/tableSync.utils.js';
import { getViewData } from '../../utils/db/dbViews.utils.js';
import { removeByKeyValue } from '../../utils/array.utils.js';

/**
 * Синхронизировать товары WB
 */
async function syncWBGoods(userId) {
  const apiKey = await getApiKeyByUser(userId, '2');
  const cards = await fetchWBGoods(apiKey);
  const goods = processWBCards(cards);
  return syncTableToDB(goods, 'goods', 'vendorcode');
}

/**
 * Синхронизировать товары Ozon
 */
async function syncOzonGoods(userId) {
  const apiKey = await getApiKeyByUser(userId, '3');
  const clientId = await getApiKeyByUser(userId, '4');
  const goods = await processOzonGoods(apiKey, clientId);
  return syncTableToDB(goods, 'goods', 'vendorcode');
}

/**
 * Получить активные товары из БД
 */
export async function getActiveProducts(userId) {
  await syncWBGoods(userId);
  await syncOzonGoods(userId);

  const productData = await getViewData('product_data');
  return removeByKeyValue(productData, 'deleted', true);
}