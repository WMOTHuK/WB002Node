// src/api/routes/fi.routes.js
import { Router } from 'express';
import { authenticate } from '../middleware/auth.middleware.js';
import { getOverheadTypes, addOverheadType, getOverheadGroups, 
         getMonthlyOverheads, addOverheadGroup, changeOverheadTypeGroup,
         saveMonthlyOverheads } from '../../services/fi/overheads.service.js';
import { syncWBFinReports, getWBFinReports, syncWBFinReportDetails } from '../../services/fi/wbReports.service.js';
import { getWBFinReportSummary } from '../../services/fi/wbReports.service.js';
import { calculateWBReport } from '../../services/fi/wbReports.service.js';

const router = Router();
const wbfikey = 
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
    const rows = await getMonthlyOverheads(req.user.id, req.query.date);
    res.json(rows);
  } catch (error) {
    next(error);
  }
});



// POST /api/fi/savemonthlyoh
router.post('/savemonthlyoh', authenticate, async (req, res, next) => {
  try {
    const { updates } = req.body;
    if (!updates || !Array.isArray(updates)) {
      return res.status(400).json({ error: 'updates must be a non-empty array' });
    }
    const result = await saveMonthlyOverheads(req.user.id, updates);
    res.json(result);
  } catch (error) {
    next(error);
  }
});


// POST /api/fi/updatewbreportslist
router.post('/updatewbreportslist', authenticate, async (req, res, next) => {
  try {
    const { dateFrom, dateTo } = req.body;
    if (!dateFrom || !dateTo) {
      return res.status(400).json({ error: 'dateFrom and dateTo are required' });
    }
    const result = await syncWBFinReports(req.user.id, dateFrom, dateTo);
    res.json(result);
  } catch (error) {
    next(error);
  }
});


// GET /api/fi/getwbreportslist
router.get('/getwbreportslist', authenticate, async (req, res, next) => {
  try {
    const limit = req.query.limit ? parseInt(req.query.limit) : 30;
    const rows = await getWBFinReports(req.user.id, limit);
    res.json(rows);
  } catch (error) {
    next(error);
  }
});

// POST /api/fi/getwbfireportdetailsbyid
router.post('/getwbfireportdetailsbyid', authenticate, async (req, res, next) => {
  try {
    const reportId = req.body.report_id;
    if (!reportId) {
      return res.status(400).json({ error: 'reportId is required' });
    }
    const result = await syncWBFinReportDetails(req.user.id, reportId);
    res.json(result);
  } catch (error) {
    next(error);
  }
});




// GET /api/fi/getwbfireportsummary
router.get('/getwbfireportsummary', authenticate, async (req, res, next) => {
  try {
    const { reportId, limit } = req.query;
    if (!reportId && !limit) {
      return res.status(400).json({ error: 'reportId or limit is required' });
    }
    const result = await getWBFinReportSummary(req.user.id, {
      reportId: reportId || null,
      limit: limit ? parseInt(limit) : null
    });
    res.json(result);
  } catch (error) {
    next(error);
  }
});

export default router;

// POST /api/fi/calculatewbreport
router.post('/calculatewbreport', authenticate, async (req, res, next) => {
  try {
    const { reportId } = req.body;
    if (!reportId) {
      return res.status(400).json({ error: 'reportId is required' });
    }
    const result = await calculateWBReport(req.user.id, reportId);
    res.json(result);
  } catch (error) {
    next(error);
  }
});

// GET /api/fi/getwbfireportproductsummary
router.get('/getwbfireportproductsummary', authenticate, async (req, res, next) => {
  try {
    const { reportId } = req.query;
    if (!reportId) {
      return res.status(400).json({ error: 'reportId is required' });
    }
    const result = await getWBFinReportProductSummary(req.user.id, reportId);
    res.json(result);
  } catch (error) {
    next(error);
  }
});