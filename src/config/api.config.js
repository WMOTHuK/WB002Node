// Конфигурация сервера

const server_config = {
    getcardsurl: 'https://content-api.wildberries.ru/content/v2/get/cards/list', // URL получения данных о карточках
    getcompaignsurl: 'https://advert-api.wildberries.ru/adv/v1/promotion/count', // URL список компаний
    getcrmdetailsurl: 'https://advert-api.wildberries.ru/api/advert/v2/adverts', // URL подробные данные о компаниях
    wb_crmurl : 'https://advert-api.wildberries.ru/adv/v0',
    wb_repricer_url : 'https://discounts-prices-api.wb.ru/api/v2/upload/task', // URL WB repricer
    ozon_product_list: 'https://api-seller.ozon.ru/v3/product/list', // URL получения cписка карточек
    ozon_product_info: 'https://api-seller.ozon.ru/v3/product/info/list', // URL get product details
    ozon_product_attr: 'https://api-seller.ozon.ru/v4/product/info/attributes'// URL get product attributes
 
  };

  export default server_config