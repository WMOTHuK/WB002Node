// src/utils/common.utils.js

/**
 * Задержка на указанное количество миллисекунд
 */
export function delay(ms) {
  return new Promise(resolve => setTimeout(resolve, ms));
}

/**
 * Рассчитать объём в литрах (округление вверх) из размеров Ozon
 */
export function calculateVolume({ height, depth, width, dimension_unit }) {
  if (!height || !depth || !width) return null;

  const factors = { mm: 0.1, cm: 1, m: 100 };
  const factor = factors[dimension_unit];
  if (!factor) return null;

  const cm3 = (height * factor) * (depth * factor) * (width * factor);
  return Math.ceil(cm3 / 1000);
}

/**
 * Преобразовать ключи объекта из camelCase в snake_case
 */
export function toSnakeCase(obj) {
  if (Array.isArray(obj)) return obj.map(toSnakeCase);
  if (obj !== null && typeof obj === 'object') {
    return Object.fromEntries(
      Object.entries(obj).map(([key, value]) => [
        key.replace(/[A-Z]/g, letter => `_${letter.toLowerCase()}`),
        toSnakeCase(value)
      ])
    );
  }
  return obj;
}