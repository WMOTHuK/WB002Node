// src/api/routes/crm.routes.js
import { Router } from 'express';
import { authenticate } from '../middleware/auth.middleware.js';
import { syncCampaigns, getActiveCampaigns, getAllCardsForCampaign, getAssignedCardsForCampaign } from '../../services/crm/crm.service.js';

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

router.get('/getallcardsforcampaign', authenticate, async (req, res, next) => {
  try {
    const result = await getAllCardsForCampaign(req.campaignId);
    res.json(result);
  } catch (error) {
    next(error);
  }
});


router.get('/getampaigncards', authenticate, async (req, res, next) => {
  try {
    const result = await getAssignedCardsForCampaign(req.campaignId);
    res.json(result);
  } catch (error) {
    next(error);
  }
});


export default router;