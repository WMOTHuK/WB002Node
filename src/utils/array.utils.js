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


/**
 * Удалить указанные ключи из массива объектов
 * @param {Array} data - Массив объектов
 * @param {Array<string>} keys - Ключи для удаления
 * @returns {Array}
 */
export function excludeKeys(data, keys) {
  return data.map(item => {
    const clean = { ...item };
    keys.forEach(k => delete clean[k]);
    return clean;
  });
}

/**
 * Заменить пустые значения на null для указанных ключей
 * @param {Array} data - Массив объектов
 * @param {Array<string>} keys - Ключи для проверки
 * @returns {Array}
 */
export function nullIfEmpty(data, keys) {
  return data.map(item => {
    const clean = { ...item };
    for (const key of keys) {
      if (clean[key] === '' || clean[key] === undefined || clean[key] === null) {
        clean[key] = null;
      }
    }
    return clean;
  });
}

/**
 * Добавить поля к каждому объекту массива
 * @param {Array} data
 * @param {Object} fields - { key: value }
 * @returns {Array}
 */
export function addFields(data, fields) {
  return data.map(item => ({ ...item, ...fields }));
}

/**
 * Композитная очистка массива объектов
 * @param {Array} data
 * @param {Object} options
 * @param {Object} [options.addFields] - Поля для добавления
 * @param {Array<string>} [options.exclude] - Ключи для удаления
 * @param {Array<string>} [options.nullIfEmpty] - Ключи для замены пустых на null
 * @returns {Array}
 */
export function cleanData(data, { addFields: add, exclude = [], nullIfEmpty: nullKeys = [] } = {}) {
  let result = [...data];

  if (add && Object.keys(add).length > 0) {
    result = result.map(item => ({ ...item, ...add }));
  }

  if (exclude.length > 0) {
    result = excludeKeys(result, exclude);
  }

  if (nullKeys.length > 0) {
    result = nullIfEmpty(result, nullKeys);
  }

  return result;
}