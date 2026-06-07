// src/utils/array.utils.js
import { logger } from './logger.js';

/**
 * Возвращает массив уникальных значений указанного поля из массива объектов
 * @param {Array} inputData - Массив объектов
 * @param {string} fieldName - Поле для извлечения
 * @returns {Array} Уникальные значения
 */
export function getUniqueKeys(inputData, fieldName) {
  if (!Array.isArray(inputData)) {
    logger.warn('getUniqueKeys: ожидался массив, получено:', typeof inputData);
    return [];
  }

  if (typeof fieldName !== 'string') {
    logger.warn('getUniqueKeys: fieldName должен быть строкой');
    return [];
  }

  return [...new Set(
    inputData
      .map(item => item?.[fieldName])
      .filter(value => value !== undefined && value !== null)
  )];
}

/**
 * Оставляет в объектах только указанные поля (с поддержкой вложенных через точку)
 * @param {Array} inputData - Массив объектов
 * @param {Array<string>} allowedKeys - Список полей (можно вложенные: 'dimensions.width')
 * @param {Object} [options]
 * @param {boolean} [options.removeEmpty=true] - Удалять пустые объекты
 * @returns {Array}
 */
export function filterByKeys(inputData, allowedKeys, options = { removeEmpty: true }) {
  if (!Array.isArray(inputData) || !Array.isArray(allowedKeys) || allowedKeys.length === 0) {
    return [];
  }

  const result = inputData.map(item => {
    const filtered = {};

    for (const key of allowedKeys) {
      let value;
      if (key.includes('.')) {
        value = key.split('.').reduce((obj, k) => obj?.[k], item);
      } else {
        value = item?.[key];
      }
      if (value !== undefined) {
        filtered[key] = value;
      }
    }

    return filtered;
  });

  return options.removeEmpty
    ? result.filter(obj => Object.keys(obj).length > 0)
    : result;
}

/**
 * Удалить объекты из массива по значению поля
 * @param {Array} array
 * @param {string} key
 * @param {*} value
 * @returns {Array}
 */
export function removeByKeyValue(array, key, value) {
  return array.filter(item => item[key] !== value);
}

/**
 * Переименовать ключи в объектах (только указанные, остальные без изменений)
 * @param {Array} inputData
 * @param {Object} keyMap - { oldKey: newKey }
 * @returns {Array}
 */
export function renameKeysOnlyMapped(inputData, keyMap) {
  if (!Array.isArray(inputData) || typeof keyMap !== 'object') {
    return [];
  }

  return inputData.map(item => {
    const renamed = { ...item };
    for (const [oldKey, newKey] of Object.entries(keyMap)) {
      if (oldKey in renamed) {
        renamed[newKey] = renamed[oldKey];
        delete renamed[oldKey];
      }
    }
    return renamed;
  });
}