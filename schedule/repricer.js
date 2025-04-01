import schedule from 'node-schedule';
import { pool } from '../General/globals.js';
import axios from 'axios';
import { logMessage, sendlogTG } from '../General/logger.js';
// Функция для выполнения последовательности действий

function generateDiscountMessage(data, ttm) {
    let message = ""; // Инициализация выходной текстовой переменной
  
    for (const item of data) {
      // Определение типа скидки и её значения в зависимости от ttm
      const discountType = ttm === 'day' ? 'дневная' : 'ночная';
      const discountValue = ttm === 'day' ? item.daydisc : item.nightdisc;
  
      // Формирование сообщения для текущего элемента и добавление его к общему сообщению
      message += `Номенклатура ${item.nmid}: установлена ${discountType} скидка в размере ${discountValue}%\n`;
    }
  
    return message;
  }

// Функция для получения активных цен из таблицы prices
async function getactiverepricing() {
    // Замените 'X' на значение, которое используется для обозначения активных записей в вашей БД
    const activeValue = 'X';
  
    try {
      // Открытие соединения с БД
      const client = await pool.connect();
  
      // Выполнение SQL-запроса
      const res = await client.query('SELECT * FROM prices WHERE active = $1', [activeValue]);
  
      // Освобождение клиента
      client.release();
  
      // Возвращение результатов запроса
      return res.rows; // rows содержит массив выбранных строк
    } catch (err) {
        const failMessage = `Ошибка получения активных репрайсов из БД`;
        logMessage(getactiverepricing.name, 2, failMessage); // Логирование Ошибок
      throw err;
    }
  }
  
async function postreprice(data, ttm) {
    const url = 'https://discounts-prices-api.wb.ru/api/v2/upload/task'; // Замените на реальный URL API
    const apiKey = 'eyJhbGciOiJFUzI1NiIsImtpZCI6IjIwMjMxMjI1djEiLCJ0eXAiOiJKV1QifQ.eyJlbnQiOjEsImV4cCI6MTcyMjkwODM4NSwiaWQiOiI2NjkzN2E4YS1kNDFmLTQwZWUtOWU0ZC03ZTExNTJhZjczYWIiLCJpaWQiOjI3NzY1ODQ0LCJvaWQiOjEzMTQ0MDMsInMiOjgsInNpZCI6ImI1NTI4ZWVmLWE0MzYtNDk1OS1hNzEzLTQ2MTcxYTM1NjdmYyIsInQiOmZhbHNlLCJ1aWQiOjI3NzY1ODQ0fQ.2LMLOry_vPfFCN9w6HxzfC0MSNkCA69-QzFsao4i7b4v1AoFs0_zUYK2eBKn2-cw4_T8WGk867k6hVaqkvRWXA'; // Замените на ваш реальный ключ авторизации

   // Формирование тела запроса
    const requestBody = {
      "data": data.map(item => ({
        "nmID": Number(item.nmid),
        "price": Number(item.price), // Предполагаем, что price доступен в объекте item
        "discount": ttm === 'day' ? Number(item.daydisc) : Number(item.nightdisc)
      }))
    };

    // Настройка заголовков запроса
    const config = {
      headers: {
        'Authorization': `Bearer ${apiKey}` // Пример использования токена авторизации
      }
    };
  
    try {
      // Отправка POST-запроса
        const response = await axios.post(url, requestBody, config);
        // В случае успеха, отправляем в телеграмм
        if (response && response.status === 200) {
            sendlogTG(generateDiscountMessage(data, ttm));
        } else {
            const failMessage = `Неизвестный результат отправки - сообщение ${response.message}, статус  ${response.status}`;
            sendlogTG(failMessage); // Лог в телеграмм
            logMessage(executeRepricer.name, 2, failMessage); // Логирование 
        }

      return response; // Возвращаем весь объект ответа
    } catch (error) {
      // В случае ошибки, возвращаем объект ошибки
      const failMessage = `Ошибка при отправке post-запроса на обновление скидок - ${error.message}`;
      logMessage(postreprice.name, 2, failMessage); // Логирование Ошибок
      sendlogTG(failMessage); // Лог в телеграмм

      throw error; // Перебрасываем ошибку дальше
    }
  }

  async function executeRepricer(ttm) {
    try {
      // Считывание и обработка данных из БД
      const data = await getactiverepricing(); // предполагается, что функция возвращает промис
      if (data && data.length > 0) {

        // Отправка POST-запроса и обработка результата один раз для всего массива
        await postreprice(data, ttm); // предполагается, что функция возвращает промис и отправляет POST-запрос
        
      } else {
        const failMessage = `нет активных репрайсов`;
        logMessage(executeRepricer.name, 2, failMessage); // Логирование 
      }
    } catch (error) {
        const failMessage = `Ошибка при выполнении задачи`;
        logMessage(executeRepricer.name, 2, failMessage); // Логирование 
    }
  }

// Обёртка для executeRepricer, чтобы можно было передать параметр и корректно планировать выполнение
  function scheduleExecuteRepricer(ttm) {
    return function() {
      executeRepricer(ttm);
    };
  }

// Тест гитхаб после переименования
// Планирование выполнения с обёрткой
//schedule.scheduleJob('05 0 * * *', scheduleExecuteRepricer('night')); // теперь будет запускаться в 00:15 каждый день
//schedule.scheduleJob('45 6 * * *', scheduleExecuteRepricer('day')); // теперь будет запускаться в 06:45 каждый день