// src/api/routes/fi.routes.js
import { Router } from 'express';
import { authenticate } from '../middleware/auth.middleware.js';
import { getOverheadTypes, addOverheadType, getOverheadGroups, 
         getMonthlyOverheads, addOverheadGroup, changeOverheadTypeGroup } 
         from '../../services/fi/overheads.service.js';

const router = Router();

// GET /api/fi/getohtypes
router.get('/getohtypes', authenticate, async (req, res, next) => {
  try {
    const rows = await getOverheadTypes(req.query.locale);
    res.json(rows);
  } catch (error) {
    next(error);
  }
});

// POST /api/fi/addohtype
router.post('/addohtype', authenticate, async (req, res, next) => {
  try {
    const { name, description, oh_grp_id, locale } = req.body;
    const result = await addOverheadType(name, description, oh_grp_id, locale);
    res.status(201).json(result);
  } catch (error) {
    next(error);
  }
});

// GET /api/fi/getohtypes
router.get('/getohgroups', authenticate, async (req, res, next) => {
  try {
    const rows = await getOverheadGroups(req.query.locale);
    res.json(rows);
  } catch (error) {
    next(error);
  }
});

// POST /api/fi/addohtype
router.post('/addohgroup', authenticate, async (req, res, next) => {
  try {
    const { name, description, locale } = req.body;
    const result = await addOverheadGroup(name, description, locale);
    res.status(201).json(result);
  } catch (error) {
    next(error);
  }
});

router.post('/changeohtypegroup', authenticate, async (req, res, next) => {
  try {
    const { id, oh_grp_id } = req.body;
    const result = await changeOverheadTypeGroup(id, oh_grp_id);
    res.status(201).json(result);
  } catch (error) {
    next(error);
  }
});

router.get('/getmonthlyoh', authenticate, async (req, res, next) => {
  try {
    const rows = await getMonthlyOverheads(req.query.locale);
    res.json(rows);
  } catch (error) {
    next(error);
  }
});

export default router;