  export async function checkAndInsertPrice(data) {
  const client = await pool.connect();

  try {
    const results = [];

    for (const item of data) {
      // Проверяем, существует ли запись с таким wbid
      const res = await client.query('SELECT * FROM prices WHERE nmid = $1', [item.nmId]);

      if (res.rows.length > 0) {
        // Если запись существует
        item.currentprice = item.price * (1 - item.discount / 100);
        await client.query(
          'UPDATE prices SET price = $2, discount = $3, promoCode = $4, currentprice = $5 WHERE nmId = $1',
          [item.nmId, item.price, item.discount, item.promoCode, item.currentprice]
        );
        const successMessage = `Данные о ценах товара ${item.nmId} Успешно обновлены в БД`;
  /*       logMessage(checkAndInsertPrice.name, 2, successMessage); // Логирование успешного результата Обновления записи */
        results.push(successMessage);
      } else {
        // Вставляем новую запись, если wbid не найден
        await client.query('INSERT INTO prices(nmId, price, discount, promoCode, currentprice, dayprice, nightprice, daydisc, nightdisc, active) VALUES($1, $2, $3, $4, $5, $6, $7, $8, $9, $10)',
        [item.nmId, item.price, item.discount, item.promoCode, item.currentprice, item.dayprice, item.nightprice, item.daydisc, item.nightdisc, item.active]);
        const successMessage = `Данные о ценах товара ${item.nmId} Успешно записаны в БД`;
        logMessage(checkAndInsertPrice.name, 2, successMessage); // Логирование успешного создания записи
        results.push(successMessage);
      }
    }

    return results;
  } catch (error) {
    return (error.message)  ;
  } finally {
    client.release(); // Освобождаем клиента
  }}