// General/DBactions/tableSync.js
import { readtable } from './readtable.js';
import { bulkUpsert, bulkUpdate } from './bulkOperations.js';

/**
 * Синхронизация данных с таблицей БД
 * @param {Array} sourceData - Данные для синхронизации
 * @param {string} tableName - Имя таблицы
 * @param {string|Array} keyFields - Поле/поля ключа
 * @param {Object} [options] - Дополнительные опции
 * @param {boolean} [options.useBulk=true] - Использовать bulk операции
 * @param {number} [options.batchSize=1000] - Размер пакета
 * @param {Array} [options.ignoreFields=[]] - Поля, которые не нужно сравнивать при обновлении
 * @returns {Promise<SyncResult>}
 */
export async function syncTableToDB(
    sourceData,
    tableName,
    keyFields,
    { useBulk = true, batchSize = 1000, ignoreFields = [] } = {}
  ) {
    if (!Array.isArray(sourceData)) {
      throw new Error('sourceData must be an array');
    }
  
    const keyFieldList = Array.isArray(keyFields) 
      ? keyFields 
      : [keyFields];
  
    try {
      // Очищаем данные от игнорируемых полей ДЛЯ ВСЕХ операций
      const dataToSync = sourceData.map(item => {
        const cleanItem = { ...item };
        ignoreFields.forEach(field => delete cleanItem[field]);
        return cleanItem;
      });
  
      // Для bulk операций
      if (useBulk && sourceData.length <= batchSize * 10) {
        const result = await bulkUpsert(tableName, dataToSync, keyFieldList);
        return formatResult(result, sourceData.length);
      }
  
      // Для очень больших наборов данных
      const dbRecords = await readtable(tableName, []);
      const dbMap = createLookupMap(dbRecords, keyFieldList);
  
      return await processInBatches(
        dataToSync, // Используем очищенные данные
        tableName,
        keyFieldList,
        dbMap,
        batchSize,
        ignoreFields
      );
    } catch (error) {
      console.error('Table sync error:', error);
      return {
        success: false,
        inserted: 0,
        updated: 0,
        unchanged: 0,
        errors: [error.message],
        totalProcessed: 0
      };
    }
  }
  
/** Вспомогательные функции */

function createLookupMap(records, keyFields) {
  return new Map(
    records.map(record => [
      keyFields.map(field => record[field]).join('|'),
      record
    ])
  );
}

async function processInBatches(data, tableName, keyFields, dbMap, batchSize, ignoreFields) {
  const result = {
    inserted: 0,
    updated: 0,
    unchanged: 0,
    errors: []
  };

  for (let i = 0; i < data.length; i += batchSize) {
    const batch = data.slice(i, i + batchSize);
    const batchResult = await processBatch(batch, tableName, keyFields, dbMap, ignoreFields);
    
    result.inserted += batchResult.inserted;
    result.updated += batchResult.updated;
    result.unchanged += batchResult.unchanged;
    result.errors.push(...batchResult.errors);
  }

  return {
    ...result,
    success: result.errors.length === 0,
    totalProcessed: data.length
  };
}

async function processBatch(batch, tableName, keyFields, dbMap, ignoreFields) {
  const batchResult = {
    inserted: 0,
    updated: 0,
    unchanged: 0,
    errors: []
  };

  const toInsert = [];
  const toUpdate = [];

  for (const newRecord of batch) {
    try {
      const recordKey = keyFields.map(f => newRecord[f]).join('|');
      const existing = dbMap.get(recordKey);

      if (!existing) {
        toInsert.push(newRecord);
      } else {
        const changedFields = getChangedFields(newRecord, existing, keyFields, ignoreFields);
        if (changedFields.length > 0) {
          toUpdate.push({ ...newRecord, _changed: changedFields });
        } else {
          batchResult.unchanged++;
        }
      }
    } catch (error) {
      batchResult.errors.push({
        record: newRecord,
        error: error.message
      });
    }
  }

  // Пакетные операции
  if (toInsert.length > 0) {
    const insertResult = await bulkUpsert(tableName, toInsert, keyFields);
    if (insertResult.success) {
      batchResult.inserted += insertResult.rowsAffected;
    } else {
      batchResult.errors.push({
        operation: 'insert',
        error: insertResult.error
      });
    }
  }

  if (toUpdate.length > 0) {
    const updateResult = await bulkUpdate(
      tableName,
      toUpdate,
      keyFields
    );
    if (updateResult.success) {
      batchResult.updated += updateResult.rowsAffected;
    } else {
      batchResult.errors.push({
        operation: 'update',
        error: updateResult.error
      });
    }
  }

  return batchResult;
}

function getChangedFields(newRecord, oldRecord, excludeFields = [], ignoreFields = []) {
  return Object.keys(newRecord)
    .filter(key => ![...excludeFields, ...ignoreFields].includes(key)) // Исключаем ключевые и игнорируемые поля
    .filter(key => newRecord[key] !== oldRecord[key]);
}

function formatResult(opResult, total) {
  return {
    success: opResult.success,
    inserted: opResult.success ? opResult.rowsAffected : 0,
    updated: 0,
    unchanged: opResult.success ? total - opResult.rowsAffected : 0,
    errors: opResult.success ? [] : [opResult.error],
    totalProcessed: total
  };
}


/**
 * Синхронизирует данные из БД с переданным массивом (приоритет у данных из БД)
 * @param {Array} sourceData - Исходные данные для обновления
 * @param {string} tableName - Имя таблицы в БД
 * @param {string|Array} keyFields - Поле/поля ключа
 * @param {Object} [options] - Дополнительные опции
 * @param {Array} [options.ignoreFields=[]] - Поля, которые не нужно обновлять
 * @returns {Promise<Array>} - Обновлённый массив данных
 */
export async function syncTableFromDB(
    sourceData,
    tableName,
    keyFields,
    { ignoreFields = [] } = {}
  ) {
    if (!Array.isArray(sourceData)) {
      throw new Error('sourceData must be an array');
    }
  
    const keyFieldList = Array.isArray(keyFields) 
      ? keyFields 
      : [keyFields];
  
    try {
      // 1. Получаем все записи из таблицы БД
      const dbRecords = await readtable(tableName, []);
      const dbMap = createLookupMap(dbRecords, keyFieldList);
  
      // 2. Создаём копию исходных данных для модификации
      const updatedData = [...sourceData];
  
      // 3. Обновляем записи в массиве данными из БД
      for (let i = 0; i < updatedData.length; i++) {
        const recordKey = keyFieldList.map(f => updatedData[i][f]).join('|');
        const dbRecord = dbMap.get(recordKey);
  
        if (dbRecord) {
          // Создаём обновлённую запись
          const updatedRecord = { ...updatedData[i] };
          
          // Копируем все поля из БД, кроме ключевых и игнорируемых
          for (const field in dbRecord) {
            if (
              !keyFieldList.includes(field) && 
              !ignoreFields.includes(field)
            ) {
              updatedRecord[field] = dbRecord[field];
            }
          }
  
          updatedData[i] = updatedRecord;
        }
      }
  
      return updatedData;
    } catch (error) {
      console.error('Error in syncTableFromDB:', error);
      // В случае ошибки возвращаем исходные данные
      return sourceData;
    }
  }
  
  // ... (остальные существующие функции остаются без изменений)
  
  export default {
    syncTableToDB, // переименованная старая функция
    syncTableFromDB,                  // новая функция
    bulkUpsert,
    bulkUpdate
  };