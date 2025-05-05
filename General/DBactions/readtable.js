// readtable.js
import { pool } from "../globals.js";
const DEFAULT_OPERATORS = {
    EQ: '=',
    NE: '!=',
    GT: '>',
    LT: '<',
    GE: '>=',
    LE: '<=',
    BT: 'BETWEEN',
    NB: 'NOT BETWEEN',
    CP: 'LIKE',
    NP: 'NOT LIKE'
  };
  
  /**
   * Чтение данных из таблицы PostgreSQL с фильтрацией
   * @param {object} pool - Пул подключений к PostgreSQL
   * @param {string} tableName - Имя таблицы
   * @param {Array} options - Массив условий фильтрации
   * @returns {Promise<Array>} - Массив записей из таблицы
   */
  export async function readtable( tableName, options = []) {
    if (!tableName || typeof tableName !== 'string') throw new Error('Valid table name is required');
    
    try {
      // Если options пуст - читаем всю таблицу
      if (!options || options.length === 0) {
        const result = await pool.query(`SELECT * FROM ${tableName}`);
        return result.rows;
      }
      
      // Строим параметризованный запрос
      const { queryText, values } = buildQuery(tableName, options);
      const result = await pool.query(queryText, values);
      
      return result.rows;
    } catch (error) {
      console.error('Error in readTable:', error);
      throw error;
    }
  }
  
  /**
   * Строит параметризованный SQL-запрос на основе условий
   * @param {string} tableName - Имя таблицы
   * @param {Array} options - Массив условий
   * @returns {object} - { queryText: string, values: Array }
   */
  function buildQuery(tableName, options) {
    const values = [];
    const conditions = [];
    let paramIndex = 1;
    
    options.forEach(option => {
      if (!option.colname) throw new Error('colname is required in options');
      if (!option.sign) throw new Error('sign is required in options');
      
      const operator = DEFAULT_OPERATORS[option.sign];
      if (!operator) throw new Error(`Unsupported operator: ${option.sign}`);
      
      switch (option.sign) {
        case 'EQ':
        case 'NE':
        case 'GT':
        case 'LT':
        case 'GE':
        case 'LE':
          if (option.low === undefined) throw new Error(`low value is required for ${option.sign}`);
          conditions.push(`${option.colname} ${operator} $${paramIndex}`);
          values.push(option.low);
          paramIndex++;
          break;
          
        case 'BT':
        case 'NB':
          if (option.low === undefined || option.high === undefined) {
            throw new Error(`low and high values are required for ${option.sign}`);
          }
          conditions.push(`${option.colname} ${operator} $${paramIndex} AND $${paramIndex + 1}`);
          values.push(option.low, option.high);
          paramIndex += 2;
          break;
          
        case 'CP':
        case 'NP':
          if (option.low === undefined) throw new Error(`low value is required for ${option.sign}`);
          conditions.push(`${option.colname} ${operator} $${paramIndex}`);
          values.push(option.low);
          paramIndex++;
          break;
          
        default:
          throw new Error(`Unsupported operator: ${option.sign}`);
      }
    });
    
    const whereClause = conditions.length > 0 ? `WHERE ${conditions.join(' AND ')}` : '';
    const queryText = `SELECT * FROM ${tableName} ${whereClause}`;
    
    return { queryText, values };
  }
  
  export default {
    readtable,
    DEFAULT_OPERATORS
  };