// src/utils/wb.utils.js
import axios from 'axios';
import apiConfig from '../config/api.config.js';
import { renameKeysOnlyMapped } from '../utils/array.utils.js';

const WB_REQUEST_CONFIG = {
  settings: {
    sort: { ascending: false },
    filter: {
      textSearch: "",
      allowedCategoriesOnly: true,
      tagIDs: [], objectIDs: [], brands: [],
      imtID: 0, withPhoto: -1
    },
    cursor: { updatedAt: null, nmID: 0, limit: 99 }
  }
};

/**
 * Запросить карточки товаров из WB API
 */
export async function fetchWBGoods(apiKey) {
  const { data } = await axios.post(apiConfig.wbCardsUrl, WB_REQUEST_CONFIG, {
    headers: { Authorization: `Bearer ${apiKey}` }
  });
  return data.cards;
}

/**
 * Извлечь основные поля из карточки WB
 */
export function extractBasicFields(card) {
  const fields = ['nmID', 'imtID', 'subjectID', 'subjectName', 'vendorCode', 'brand', 'title'];
  const result = {};
  for (const field of fields) {
    if (card[field] != null) result[field] = card[field];
  }
  return result;
}

/**
 * Первое фото карточки
 */
export function getFirstPhoto(card) {
  return card.photos?.[0]?.big || null;
}

/**
 * Рассчитать объём в литрах из dimensions WB
 */
export function calculateWBVolume(dimensions) {
  if (!dimensions?.width || !dimensions?.height || !dimensions?.length) return null;
  const cm3 = dimensions.width * dimensions.height * dimensions.length;
  return Math.ceil(cm3 / 1000);
}

/**
 * Преобразовать карточки WB в плоский массив для БД
 */
export function processWBCards(cards) {
  const processed = cards.map(card => ({
    ...extractBasicFields(card),
    card_photo: getFirstPhoto(card),
    wbvol: calculateWBVolume(card.dimensions)
  }));

  return renameKeysOnlyMapped(processed, { nmID: 'nm_id' });
}