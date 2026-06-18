// src/utils/date.utils.js
export function formatDelay(ms) {
  const totalSeconds = Math.floor(ms / 1000);
  const hours = Math.floor(totalSeconds / 3600);
  const minutes = Math.floor((totalSeconds % 3600) / 60);
  return `${hours.toString().padStart(2, '0')}:${minutes.toString().padStart(2, '0')}`;
}

export function calculateDelay(timeStr) {
  const [hours, minutes] = timeStr.split(':').map(Number);
  const now = new Date();
  const targetTime = new Date(
    now.getFullYear(),
    now.getMonth(),
    now.getDate(),
    hours,
    minutes
  );

  if (targetTime < now) {
    targetTime.setDate(targetTime.getDate() + 1);
  }

  return targetTime - now;
}

/**
 * Вычислить номер недели в году по дате
 * @param {string|Date} date
 * @returns {number} 1-53
 */
export function getWeekNumber(date) {
  const d = new Date(date);
  const startOfYear = new Date(d.getFullYear(), 0, 1);
  const days = Math.floor((d - startOfYear) / (24 * 60 * 60 * 1000));
  return Math.ceil((days + startOfYear.getDay() + 1) / 7);
}

/**
 * Форматировать диапазон дат в читаемую строку
 * @param {string} dateFrom
 * @param {string} dateTo
 * @returns {string} "с DD.MM.YYYY по DD.MM.YYYY"
 */
export function formatDateRange(dateFrom, dateTo) {
  const format = (d) => {
    const date = new Date(d);
    return date.toLocaleDateString('ru-RU');
  };
  return `с ${format(dateFrom)} по ${format(dateTo)}`;
}