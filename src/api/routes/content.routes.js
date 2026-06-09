// src/api/routes/content.routes.js
import { Router } from 'express';
import { authenticate } from '../middleware/auth.middleware.js';
import { getActiveProducts } from '../../services/goods/goods.service.js';
import { updatePricesFromWB, updateCostPrice } from '../../services/goods/pricing.service.js';
import { getGoodsTypes, addGoodsType, getGoodsGroups, 
         addGoodsGroup, changeGoodsGroup, changeGoodsGroupType} from '../../services/goods/goods.service.js';

const router = Router();

// GET /api/content/getgoodsdata
router.get('/getgoodsdata', authenticate, async (req, res, next) => {
  try {
    const products = await getActiveProducts(req.user.id);
    res.json(products);
  } catch (error) {
    next(error);
  }
});

// POST /api/content/updateprices
router.post('/updateprices', async (req, res, next) => {
  try {
    const data = req.body.data.listGoods;
    const results = await updatePricesFromWB(data);
    res.json(results);
  } catch (error) {
    next(error);
  }
});

// POST /api/content/update_cost_price
router.post('/update_cost_price', async (req, res, next) => {
  try {
    const { vendorcode, new_cost, start_date } = req.body;

    if (!vendorcode || !new_cost || !start_date) {
      return res.status(400).json({ success: false, error: 'vendorcode, new_cost, start_date обязательны' });
    }

    const result = await updateCostPrice(vendorcode, new_cost, start_date);
    res.json({
      success: result.status === 'SUCCESS',
      message: result.message,
      data: result
    });
  } catch (error) {
    next(error);
  }
});


router.get('/getgoodstypes', authenticate, async (req, res, next) => {
  try {
    const rows = await getGoodsTypes(req.query.locale);
    res.json(rows);
  } catch (error) {
    next(error);
  }
});

router.post('/addgoodstype', authenticate, async (req, res, next) => {
  try {
    const { name, description, locale } = req.body;
    const result = await addGoodsType(name, description, locale);
    res.status(201).json(result);
  } catch (error) {
    next(error);
  }
});


router.get('/getgoodsgroups', authenticate, async (req, res, next) => {
  try {
    const rows = await getGoodsGroups(req.query.locale);
    res.json(rows);
  } catch (error) {
    next(error);
  }
});

router.post('/addgoodsgroup', authenticate, async (req, res, next) => {
  try {
    const { name, description, goods_type_id, locale } = req.body;
    const result = await addGoodsGroup(name, description, goods_type_id, locale);
    res.status(201).json(result);
  } catch (error) {
    next(error);
  }
});

router.post('/changegoodsgrouptype', authenticate, async (req, res, next) => {
  try {
    const { id, goods_type_id } = req.body;
    const result = await changeGoodsGroupType(id, goods_type_id);
    res.status(201).json(result);
  } catch (error) {
    next(error);
  }
});




export default router;