/* // src/services/scheduler/repricer.js
import { pool } from '../../../General/globals.js'
import axios from 'axios';
import { logger } from '../../utils/logger.js';

const WB_REPRICER_URL = process.env.WB_REPRICER_URL || 'https://discounts-prices-api.wb.ru/api/v2/upload/task';
const WB_REPRICER_API_KEY = process.env.WB_REPRICER_API_KEY;
const ACTIVE_MARK = 'X';

// ---------------------------------------------------------------------------
// Получить активные репрайсы из БД
// ---------------------------------------------------------------------------
async function getActiveRepricing() {
  try {
    const { rows } = await pool.query(
      'SELECT * FROM prices WHERE active = $1',
      [ACTIVE_MARK]
    );
    return rows;
  } catch (error) {
    logger.error('Ошибка получения активных репрайсов из БД:', error.message);
    throw error;
  }
}

// ---------------------------------------------------------------------------
// Отправить цены и скидки в WB API
// ---------------------------------------------------------------------------
async function postReprice(data, ttm) {
  if (!WB_REPRICER_API_KEY) {
    throw new Error('WB_REPRICER_API_KEY не задан в .env');
  }

  const requestBody = {
    data: data.map(item => ({
      nmID: Number(item.nmid),
      price: Number(item.price),
      discount: ttm === 'day' ? Number(item.daydisc) : Number(item.nightdisc)
    }))
  };

  try {
    const response = await axios.post(WB_REPRICER_URL, requestBody, {
      headers: {
        Authorization: `Bearer ${WB_REPRICER_API_KEY}`
      }
    });

    if (response.status === 200) {
      const message = formatDiscountMessage(data, ttm);
      logger.info(message);
    } else {
      logger.warn(`Неожиданный статус от WB: ${response.status} — ${response.statusText}`);
    }

    return response;
  } catch (error) {
    const detail = error.response?.data?.detail || error.message;
    logger.error(`Ошибка отправки репрайса: ${detail}`);
    throw error;
  }
}

// ---------------------------------------------------------------------------
// Форматировать сообщение о скидках
// ---------------------------------------------------------------------------
function formatDiscountMessage(data, ttm) {
  const discountType = ttm === 'day' ? 'дневная' : 'ночная';
  const discountField = ttm === 'day' ? 'daydisc' : 'nightdisc';

  return data
    .map(item => `Номенклатура ${item.nmid}: установлена ${discountType} скидка ${item[discountField]}%`)
    .join('\n');
}

// ---------------------------------------------------------------------------
// Основная функция запуска репрайсера
// ---------------------------------------------------------------------------
async function executeRepricer(ttm) {
  const data = await getActiveRepricing();

  if (!data || data.length === 0) {
    logger.info('Нет активных репрайсов');
    return;
  }

  await postReprice(data, ttm);
  logger.info(`Репрайс (${ttm}) выполнен для ${data.length} номенклатур`);
}

// ---------------------------------------------------------------------------
// Инициализация cron-задач
// ---------------------------------------------------------------------------
export function initRepricer(schedule) {
  const dayCron = process.env.REPRICER_DAY_CRON || '45 6 * * *';
  const nightCron = process.env.REPRICER_NIGHT_CRON || '05 0 * * *';

  schedule.scheduleJob(dayCron, () => executeRepricer('day'));
  schedule.scheduleJob(nightCron, () => executeRepricer('night'));

  logger.info(`Репрайсер запущен: день — "${dayCron}", ночь — "${nightCron}"`);
} */