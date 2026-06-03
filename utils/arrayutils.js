/**
 * Возвращает массив уникальных значений указанного поля из массива объектов
 * @param {Array} inputData - Входной массив объектов
 * @param {string} fieldName - Название поля для извлечения значений
 * @param {boolean} [convertToNumber=true] - Конвертировать ли значения в числа
 * @returns {Array} Массив уникальных значений
 */
export function getuniquekeys(inputData, fieldName) {
    // 1. Проверка входящих данных
    if (!Array.isArray(inputData)) {
      console.warn('Ожидался массив данных, получено:', inputData);
      return [];
    }
  
    if (typeof fieldName !== 'string') {
      console.warn('Поле должно быть строкой, получено:', fieldName);
      return [];
    }
  
    // 2. Извлечение и фильтрация уникальных значений
    const uniqueValues = [...new Set(
      inputData
        .map(item => item?.[fieldName]) // Безопасное извлечение поля
        .filter(value => value !== undefined && value !== null) // Отсеиваем пустые
    )];
  
    // 3. Опциональная конвертация в числа
    return uniqueValues;
}

/**
 * Фильтрует массив объектов, оставляя только указанные поля (альтернативная версия с использованием reduce)
 * @param {Array} inputData - Входной массив объектов
 * @param {Array<string>} allowedKeys - Список ключей (полей), которые нужно оставить
 * @returns {Array} Массив объектов только с указанными полями
 */
export function filterArrayByKeys(inputData, allowedKeys) {
    if (!Array.isArray(inputData) || !Array.isArray(allowedKeys)) {
        return [];
    }
    
    return inputData.map(item => {
        return allowedKeys.reduce((acc, key) => {
            if (item && key in item) {
                acc[key] = item[key];
            }
            return acc;
        }, {});
    }).filter(obj => Object.keys(obj).length > 0);
}

/**
 * Фильтрует массив объектов, оставляя только указанные поля (с поддержкой вложенных полей)
 * @param {Array} inputData - Входной массив объектов
 * @param {Array<string>} allowedKeys - Список ключей (полей), которые нужно оставить
 * @param {Object} options - Дополнительные опции
 * @param {boolean} options.removeEmpty - Удалять ли пустые объекты (default: true)
 * @returns {Array} Массив объектов только с указанными полями
 */
export function filterDeepArrayByKeys(inputData, allowedKeys, options = { removeEmpty: true }) {
    if (!Array.isArray(inputData)) {
        console.warn('Ожидался массив данных, получено:', inputData);
        return [];
    }
    
    if (!Array.isArray(allowedKeys) || allowedKeys.length === 0) {
        console.warn('allowedKeys должен быть непустым массивом строк');
        return [];
    }
    
    const result = inputData.map(item => {
        const filteredItem = {};
        
        allowedKeys.forEach(key => {
            // Поддержка вложенных полей (например, 'dimensions.width')
            if (key.includes('.')) {
                const keys = key.split('.');
                let value = item;
                for (const k of keys) {
                    if (value && typeof value === 'object' && k in value) {
                        value = value[k];
                    } else {
                        value = undefined;
                        break;
                    }
                }
                if (value !== undefined) {
                    filteredItem[key] = value;
                }
            } else {
                // Обычное поле
                if (item && key in item && item[key] !== undefined) {
                    filteredItem[key] = item[key];
                }
            }
        });
        
        return filteredItem;
    });
    
    // Удаляем пустые объекты, если требуется
    if (options.removeEmpty) {
        return result.filter(obj => Object.keys(obj).length > 0);
    }
    
    return result;
}

export const removeByKeyValue = (array, key, value) => {
  return array.filter(item => item[key] !== value);
};


/**
 * Переименовывает ключи только для указанных полей (остальные оставляет как есть)
 * @param {Array} inputData - Входной массив объектов
 * @param {Object} keyMap - Карта соответствия { старый_ключ: новый_ключ }
 * @returns {Array} Массив объектов с переименованными ключами
 */
export function renameKeysOnlyMapped(inputData, keyMap) {
    if (!Array.isArray(inputData) || typeof keyMap !== 'object') {
        return [];
    }
    
    return inputData.map(item => {
        const newItem = { ...item }; // Копируем все поля
        
        Object.entries(keyMap).forEach(([oldKey, newKey]) => {
            if (oldKey in newItem) {
                newItem[newKey] = newItem[oldKey];
                delete newItem[oldKey];
            }
        });
        
        return newItem;
    });
}