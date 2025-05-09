// General/DBactions/descriptionsMapper.js
import { readtable } from '../DBactions/readtable.js';

/**
 * Добавляет столбцы с описаниями к данным, сохраняя исходные значения
 * @param {Array} data - Массив данных для обработки
 * @param {Array} mappingConfig - Конфигурация полей с описаниями
 * @returns {Promise<Array>} - Данные с добавленными описаниями
 */
export async function addDescriptionColumns(data, mappingConfig) {
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

  // Добавляем описания как новые поля
  return data.map(item => {
    const newItem = {};
    const fields = Object.keys(item);
    
    // Проходим по всем полям исходного объекта
    for (const field of fields) {
      // Вставляем исходное поле
      newItem[field] = item[field];
      
      // Проверяем, нужно ли добавлять описание для этого поля
      const config = mappingConfig.find(c => c.field === field);
      if (config) {
        const descriptions = descriptionsCache[config.tableName];
        const descriptionField = `${field}_desc`;
        
        // Добавляем поле с описанием после исходного поля
        newItem[descriptionField] = descriptions?.get(item[field]) || '';
      }
    }
    
    return newItem;
  });
}