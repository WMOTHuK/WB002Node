
//jobs/crmjobs.js
import axios from 'axios';
import { sendlogTG } from "../../../General/logger.js";
import { getAPIKey } from "../../../utils/apiutils.js";
import { parseAdverts, pausecampaignslist } from "../../../utils/crmutils.js";
import { getuniquekeys } from "../../../utils/arrayutils.js";
import server_config  from '../../../config/apiurls.js';


export const pauseactivecompaigns = {
  async run() {
      try {
          sendlogTG('[CRON] Запуск задачи pauseactivecompaigns', new Date().toISOString());
          
          // 1. Получим список компаний с сервера
          const crmapikey = await getAPIKey('2', '1');
          const response = await axios.get(server_config.getcompaignsurl, {
              headers: { 'Authorization': `Bearer ${crmapikey}` }
          });

          // 2. Проверяем и преобразуем данные
          const activeadverts = parseAdverts(response.data, '9');
          const advertids = getuniquekeys(activeadverts, 'advertid');

          // 3. Выполним паузу компаний и получим результат
          const TGMessage = await pausecampaignslist(advertids, crmapikey);
          sendlogTG(TGMessage);

      } catch (error) {
          this._handleError(error);
      }
  },

  _handleError(error) {
      let errorMessage = '⚠️ Критическая ошибка:\n';
      
      if (error.response) {
          // Ошибка от API
          errorMessage += `Статус: ${error.response.status}\n`;
          errorMessage += `Сообщение: ${error.response.data?.message || 'Нет деталей'}`;
      } else if (error.request) {
          // Ошибка запроса
          errorMessage += `Не получен ответ от сервера: ${error.message}`;
      } else {
          // Другие ошибки
          errorMessage += error.message;
      }
      
      sendlogTG(errorMessage);
  }
};