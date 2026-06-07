// src/api/routes/crm.routes.js
import { Router } from 'express';
import { authenticate } from '../middleware/auth.middleware.js';
import { getCampaigns } from '../../services/crm/crm.service.js';

const router = Router();

router.get('/getcompaigns', authenticate, async (req, res, next) => {
  try {
    const result = await getCampaigns(req.user.id);
    res.json(result);
  } catch (error) {
    next(error);
  }
});

export default router;