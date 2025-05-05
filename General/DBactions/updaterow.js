//.General/DBactions/updateRow.js
import { pool } from "../globals.js";

/**
 * Обновление строк в таблице PostgreSQL
 * @param {object} pool - Пул подключений к PostgreSQL
 * @param {string} tableName - Имя таблицы
 * @param {Array} conditions - Массив условий для выбора строк
 * @param {Array} data - Массив данных для обновления
 * @returns {Promise<object>} - Статус операции и информация об обновленных строках
 */
export async function updateRow( tableName, conditions = [], data = []) {
    if (!pool) throw new Error('Pool is required');
    if (!tableName || typeof tableName !== 'string') throw new Error('Valid table name is required');
    
    // Проверка что массивы conditions и data не пусты
    if (!Array.isArray(conditions)) throw new Error('Conditions must be an array');
    if (!Array.isArray(data)) throw new Error('Data must be an array');
    if (conditions.length === 0) throw new Error('Conditions array cannot be empty');
    if (data.length === 0) throw new Error('Data array cannot be empty');

    try {
        // Строим параметризованный UPDATE запрос
        const { queryText, values } = buildUpdateQuery(tableName, conditions, data);

        // Выполняем запрос
        const result = await pool.query(queryText, values);

        return {
            success: true,
            rowsAffected: result.rowCount,
            message: `Successfully updated ${result.rowCount} row(s)`,
            data: result.rows
        };
    } catch (error) {
        console.error('Error in updateRow:', error);
        return {
            success: false,
            message: error.message,
            rowsAffected: 0,
            data: []
        };
    }
}

/**
 * Строит параметризованный UPDATE запрос
 * @param {string} tableName - Имя таблицы
 * @param {Array} conditions - Массив условий
 * @param {Array} data - Массив данных для обновления
 * @returns {object} - { queryText: string, values: Array }
 */
function buildUpdateQuery(tableName, conditions, data) {
    const setParts = [];
    const whereParts = [];
    const values = [];
    let paramIndex = 1;

    // Формируем SET часть запроса
    data.forEach(item => {
        if (!item.column) throw new Error('Missing column property in data item');
        if (item.value === undefined) throw new Error(`Missing value for column ${item.column}`);

        setParts.push(`${item.column} = $${paramIndex}`);
        values.push(item.value);
        paramIndex++;
    });

    // Формируем WHERE часть запроса
    conditions.forEach(condition => {
        if (!condition.column) throw new Error('Missing column property in condition item');
        if (condition.value === undefined) throw new Error(`Missing value for column ${condition.column}`);

        const operator = condition.operator || '=';
        whereParts.push(`${condition.column} ${operator} $${paramIndex}`);
        values.push(condition.value);
        paramIndex++;
    });

    const queryText = `
        UPDATE ${tableName}
        SET ${setParts.join(', ')}
        WHERE ${whereParts.join(' AND ')}
        RETURNING *
    `;

    return { queryText, values };
}

export default {
    updateRow
};