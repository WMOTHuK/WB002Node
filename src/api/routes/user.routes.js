// src/api/routes/user.routes.js
import { Router } from 'express';
import { authenticate } from '../middleware/auth.middleware.js';
import { changeUserTaxRates, changeUserLocale, getUserSettings } from '../../services/user/user.service.js';
import { runDailyTasksForUser } from '../../services/scheduler/dailyTasks.service.js';

const router = Router();

// POST /api/user/changeusertaxrates
router.post('/changeusertaxrates', authenticate, async (req, res, next) => {
  try {
    const { sellerTax, vatTax, validFrom } = req.body;
    if (sellerTax == null && vatTax == null) {
      return res.status(400).json({ error: 'sellerTax or vatTax is required' });
    }
    if (!validFrom) {
      return res.status(400).json({ error: 'validFrom is required' });
    }
    const result = await changeUserTaxRates(req.user.id, { sellerTax, vatTax, validFrom });
    res.json(result);
  } catch (error) {
    next(error);
  }
});

// POST /api/user/changeuserlocale
router.post('/changeuserlocale', authenticate, async (req, res, next) => {
  try {
    const { locale } = req.body;
    if (!locale) {
      return res.status(400).json({ error: 'locale is required' });
    }
    const result = await changeUserLocale(req.user.id, locale, req.user.id);
    res.json(result);
  } catch (error) {
    next(error);
  }
});

// GET /api/user/getusersettings
router.get('/getusersettings', authenticate, async (req, res, next) => {
  try {
    const date = req.query.date || new Date().toISOString().split('T')[0];
    const rows = await getUserSettings(req.user.id, date);
    res.json(rows);
  } catch (error) {
    next(error);
  }
});


// POST /api/user/syncdata
router.post('/syncdata', authenticate, async (req, res, next) => {
  try {
    const results = await runDailyTasksForUser(req.user.id);
    res.json({ success: true, results });
  } catch (error) {
    next(error);
  }
});


export default router;
