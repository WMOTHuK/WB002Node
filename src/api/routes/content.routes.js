// src/api/routes/content.routes.js
import { Router } from 'express';
import { authenticate } from '../middleware/auth.middleware.js';
import { getActiveProducts } from '../../services/goods/goods.service.js';
import { updatePricesFromWB, updateCostPrice } from '../../services/goods/pricing.service.js';

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

export default router;