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