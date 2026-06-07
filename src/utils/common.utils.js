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