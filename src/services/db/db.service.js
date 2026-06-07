// src/services/db/db.service.js
import { syncTableToDB } from '../../utils/tableSync.utils.js';
import { db } from '../../utils/sql.utils.js';
import { pool } from '../../config/db.config.js';

const allowedTableNames = []; // TODO: заполнить

export async function updateTable(rows, tableName, keyFields) {
  return syncTableToDB(rows, tableName, keyFields, { batchSize: 500 });
}

export async function getTable(tableName) {
  if (!allowedTableNames.includes(tableName)) {
    throw new Error(`Table "${tableName}" is not allowed`);
  }
  const { rows } = await db.select(tableName);
  return rows;
}

export async function updateRow(tableName, where, data) {
  await db.update(tableName, data, where);
}

export async function insertRow(tableName, data) {
  await db.insert(tableName, data);
}

export async function getLocaleStrings(fields, locale) {
  const { rows } = await pool.query(
    `SELECT * FROM localization WHERE loctype = '1' AND locale = $1 AND colname = ANY($2)`,
    [locale, fields]
  );
  return rows;
}
