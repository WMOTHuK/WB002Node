// src/config/api.config.js
const apiConfig = {

  // WB CONTENT
  wbCardsUrl: 'https://content-api.wildberries.ru/content/v2/get/cards/list',

  //WB CRM
  wbCrmUrl: 'https://advert-api.wildberries.ru/adv/v0',
  wbCampaignsUrl: 'https://advert-api.wildberries.ru/adv/v1/promotion/count',
  wbCampaignDetailsUrl: 'https://advert-api.wildberries.ru/api/advert/v2/adverts',
  wbCampaignCostsUrl: 'https://advert-api.wildberries.ru/adv/v1/upd',

  //WB FI
  wbFinReportsList: 'https://finance-api.wildberries.ru/api/finance/v1/sales-reports/list',
  wbFinReportDetails: 'https://finance-api.wildberries.ru/api/finance/v1/sales-reports/detailed',

  //WB PRICING
  wbRepricerUrl: 'https://discounts-prices-api.wb.ru/api/v2/upload/task',

  // OZON CONTENT
  ozonProductListUrl: 'https://api-seller.ozon.ru/v3/product/list',
  ozonProductInfoUrl: 'https://api-seller.ozon.ru/v3/product/info/list',
  ozonProductAttributesUrl: 'https://api-seller.ozon.ru/v4/product/info/attributes',

  // OZON FI
  ozonAccrualTypesUrl: 'https://api-seller.ozon.ru/v1/finance/accrual/types',

  // KEY Types
  //WB
  wbcrmkey: 1,
  wbcontentkey: 2,
  wbfinancekey: 5,
  //OZON
  ozoncontentkey: 3,
  ozonclientid: 4,
  ozonfinancekey: 6,
};



export default apiConfig;