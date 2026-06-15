// src/api/routes/crm.routes.js
import { Router } from 'express';
import { authenticate } from '../middleware/auth.middleware.js';
import { syncCampaigns, getActiveCampaigns, getAllCardsForCampaign, 
         getAssignedCardsForCampaign, syncCampaignSubcards, getGoodsGroupsWithTypes,
         addGroupToCampaign } from '../../services/crm/crm.service.js';

const router = Router();

router.get('/updatecrmfromwb', authenticate, async (req, res, next) => {
  try {
    const result = await syncCampaigns(req.user.id);
    res.json(result);
  } catch (error) {
    next(error);
  }
});

router.get('/getcompaigns', authenticate, async (req, res, next) => {
  try {
    const result = await getActiveCampaigns(req.user.id, req.query.active_only);
    res.json(result);
  } catch (error) {
    next(error);
  }
});

router.get('/getallcardsforcampaign', authenticate, async (req, res, next) => {
  try {
    const result = await getAllCardsForCampaign(req.query.campaign_id);
    res.json(result);
  } catch (error) {
    next(error);
  }
});


router.get('/getampaigncards', authenticate, async (req, res, next) => {
  try {
    const result = await getAssignedCardsForCampaign(req.query.campaign_id);
    res.json(result);
  } catch (error) {
    next(error);
  }
});


router.post('/synccampaignsubcards', authenticate, async (req, res, next) => {
  try {
    const { advertid, cards } = req.body;
    const result = await syncCampaignSubcards( advertid, cards);
    res.json(result);
  } catch (error) {
    next(error);
  }
});


router.get('/getgoodsgroupswithtypes', authenticate, async (req, res, next) => {
  try {
    const result = await getGoodsGroupsWithTypes()
    res.json(result);
  } catch (error) {
    next(error);
  }
});


router.post('/linkgrouptocampaign', authenticate, async (req, res, next) => {
  try {
    const { advertid, goods_grp_id } = req.body;
    const result = await addGroupToCampaign(advertid, goods_grp_id)
    res.json(result);
  } catch (error) {
    next(error);
  }
});

export default router;