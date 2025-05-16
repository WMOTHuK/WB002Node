// routes/crmRoutes.js

import express from 'express';
import axios from 'axios';
import { readtable } from '../General/DBactions/readtable.js';
import { authenticate } from '../middleware/auth.js';
import { decrypt } from '../utils/crypto.js';
import { syncTableToDB, syncTableFromDB } from '../General/DBactions/tableSync.js'
import { addDescriptionColumns } from '../General/DBactions/descriptionsMapper.js';
import server_config from '../config/apiurls.js'
import { getAPIKey } from '../utils/apiutils.js';
import { parseAdverts, enrichAdvertData } from '../utils/crmutils.js';

const router = express.Router();


router.get('/getcompaigns', authenticate, async (req, res) => {
  try {
    const userId = req.user.id;

    // Получаем API ключ из БД
    const crmapikey = await getAPIKey(userId, '1');

    // Выполняем запрос к внешнему API
    const response = await axios.get(server_config.getcompaignsurl,  {
      headers: { 'Authorization': `Bearer ${crmapikey}` }
    });

    // Проверяем и преобразуем данные
    let responseData = response.data;
    
    const parsedData = parseAdverts(responseData);  // Прогоним через парсер 

    //Обагатим данными (имя, тип оплаты,Активность фиксированных фраз)
    const enrichedData = await enrichAdvertData(parsedData, SERVER_CONFIG.getcrmdetailsurl, crmAPIKEY, userId);
    // Теперь enrichedData содержит все исходные поля + name, paymentType, searchPluseState

    // Синхронизация с БД (игнорируем поля pause_time, restart_time и active при сравнении)
    const tablekey = ['advertid', 'user_id']
    const tableName = 'crm_headers'
    const syncResult = await syncTableToDB(
      enrichedData,
      tableName,
      tablekey, 
      { 
        batchSize: 500,
        ignoreFields: ['pause_time', 'restart_time', 'active'] 
      }
    );

    const updatedData = await syncTableFromDB(
      enrichedData,
      'crm_headers',
      tablekey, 
      { 
        batchSize: 500
      }
    );

    // Фильтруем записи (исключаем статус 7)
    const filteredData = updatedData.filter(item => item.crmstatus !== 7);


    // Заменяем ключи на описания
    const finalData = await addDescriptionColumns(filteredData, [
      { field: 'crmstatus', tableName: 'crm_status' },
      { field: 'crmtype', tableName: 'crm_type' }
    ]);

    res.status(200).json({
      data: finalData,
      dbSync: syncResult
    });
  } catch (error) {
    console.error('Error in /getcompaigns:', error);
    
    const status = error.response?.status || 500;
    const message = error.response?.data?.message || error.message;
    
    res.status(status).json({ 
      error: 'Failed to fetch crm data',
      details: message,
      stack: process.env.NODE_ENV === 'development' ? error.stack : undefined
    });
  }
});

export default router;