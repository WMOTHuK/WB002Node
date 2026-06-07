// src/utils/ozon.utils.js
import axios from 'axios';
import apiConfig from '../config/api.config.js';
import { logger } from './logger.js';
import { calculateVolume } from './common.utils.js';

/**
 * Получить список товаров Ozon (с пагинацией)
 */
export async function fetchOzonProductList(apiKey, clientId) {
  let allProducts = [];
  let lastId = "";
  let total = 0;

  while (true) {
    const { data } = await axios.post(apiConfig.ozonProductListUrl, {
      filter: { offer_id: [], product_id: [], visibility: "ALL" },
      last_id: lastId,
      limit: 100
    }, {
      headers: { 'Client-Id': clientId, 'Api-Key': apiKey, 'Content-Type': 'application/json' }
    });

    const { items, last_id, total: totalCount } = data.result;
    total = totalCount;

    if (items?.length) {
      allProducts = [...allProducts, ...items.filter(i => !i.archived)];
      logger.debug(`Ozon: загружено ${allProducts.length} из ${total}`);
    }

    if (!items?.length || items.length < 100 || allProducts.length >= total) break;
    lastId = last_id || "";
  }

  return allProducts.map(item => item.product_id);
}

/**
 * Получить детальную информацию о товарах Ozon пачками
 */
export async function fetchOzonProductInfo(apiKey, clientId, productIds) {
  const chunkSize = 100;
  const results = [];

  for (let i = 0; i < productIds.length; i += chunkSize) {
    const chunk = productIds.slice(i, i + chunkSize);
    const { data } = await axios.post(apiConfig.ozonProductInfoUrl, {
      product_id: chunk.map(String)
    }, {
      headers: { 'Client-Id': clientId, 'Api-Key': apiKey, 'Content-Type': 'application/json' }
    });

    results.push(...(data.result?.items || data.items || []));

    if (i + chunkSize < productIds.length) {
      await new Promise(r => setTimeout(r, 500));
    }
  }

  return results;
}

/**
 * Получить объёмы товаров Ozon
 */
export async function fetchOzonVolumes(apiKey, clientId, productIds) {
  if (!productIds.length) return {};

  const { data } = await axios.post(apiConfig.ozonProductAttributesUrl, {
    filter: { product_id: productIds.map(String) },
    last_id: "",
    limit: Math.min(productIds.length, 1000)
  }, {
    headers: { 'Client-Id': clientId, 'Api-Key': apiKey, 'Content-Type': 'application/json' },
    timeout: 30000
  });

  const volumeMap = {};
  for (const item of data.result || []) {
    const volume = calculateVolume(item);
    if (volume !== null) volumeMap[item.id] = volume;
  }

  return volumeMap;
}

/**
 * Собрать товары Ozon для БД
 */
export async function processOzonGoods(apiKey, clientId) {
  const productIds = await fetchOzonProductList(apiKey, clientId);
  if (!productIds.length) return [];

  const [volumeMap, items] = await Promise.all([
    fetchOzonVolumes(apiKey, clientId, productIds),
    fetchOzonProductInfo(apiKey, clientId, productIds)
  ]);

  return items
    .filter(item => item.id && item.offer_id)
    .map(item => ({
      ozid: item.sku || item.id,
      vendorcode: item.offer_id,
      title: item.name,
      card_photo: item.primary_image?.[0] || null,
      ozvol: volumeMap[item.id] || null
    }));
}
