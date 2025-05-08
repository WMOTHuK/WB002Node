//General/DBactions/descriptionsMapper.js
import { readtable } from '../DBactions/readtable.js';

/**
 * Заменяет ключи в данных на их описания из БД
 * @param {Array} data - Массив данных для обработки
 * @param {Array} mappingConfig - Конфигурация замены полей
 * @returns {Promise<Array>} - Обработанные данные
 */
export async function replaceKeysWithDescriptions(data, mappingConfig) {
  if (!data?.length || !mappingConfig?.length) return data;

  // Собираем все необходимые описания из БД
  const descriptionsCache = {};
  
  for (const config of mappingConfig) {
    if (!descriptionsCache[config.tableName]) {
      const rows = await readtable(config.tableName, []);
      descriptionsCache[config.tableName] = new Map(
        rows.map(row => [row[config.keyField || config.field], row.description])
      );
    }
  }

  // Заменяем ключи на описания
  return data.map(item => {
    const newItem = { ...item };
    
    for (const config of mappingConfig) {
      const fieldValue = newItem[config.field];
      const descriptions = descriptionsCache[config.tableName];
      
      if (descriptions && descriptions.has(fieldValue)) {
        newItem[config.field] = descriptions.get(fieldValue);
      }
    }
    
    return newItem;
  });
}