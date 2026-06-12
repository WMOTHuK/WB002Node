// src/api/routes/crm.routes.js
import { Router } from 'express';
import { authenticate } from '../middleware/auth.middleware.js';
import { syncCampaigns, getActiveCampaigns } from '../../services/crm/crm.service.js';

const router = Router();

router.get('/updatecrmfromwb', authenticate, async (req, res, next) => {
  try {
    const result = await syncCampaigns(req.user.id);
    res.json(result);
  } catch (error) {
    next(error);
  }
});

router.get('/getactivecompaigns', authenticate, async (req, res, next) => {
  try {
    const result = await getActiveCampaigns(req.user.id);
    res.json(result);
  } catch (error) {
    next(error);
  }
});


export default router;