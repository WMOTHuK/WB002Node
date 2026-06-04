// src/api/routes/index.js
import { Router } from 'express';
import authRoutes from '../../../routes/auth.js';
import apiKeysRoutes from '../../../routes/apiKeys.js';
import contentRoutes from '../../../routes/contentRoutes.js';
import CRMRoutes from '../../../routes/CRMRoutes.js';
import dbRoutes from '../../../routes/dbRoutes.js';
import { authenticate } from '../middleware/auth.middleware.js';

const router = Router();

// Публичные маршруты
router.use('/auth', authRoutes);

// Защищённые маршруты
router.use('/auth', authenticate, apiKeysRoutes);
router.use('/content', authenticate, contentRoutes);
router.use('/CRM', authenticate, CRMRoutes);
router.use('/DB', authenticate, dbRoutes);

export { router };