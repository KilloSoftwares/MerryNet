import { Router } from 'express';
import { resellerController } from '../controllers/reseller.controller';
import { authenticate, requireReseller } from '../middleware/auth';
import { validateBody } from '../middleware/errorHandler';
import { registerResellerSchema } from '../utils/validators';

const router = Router();

// POST /api/v1/resellers/register — Register as reseller
router.post(
  '/register',
  authenticate,
  validateBody(registerResellerSchema),
  resellerController.register
);

// GET /api/v1/resellers/dashboard — Reseller dashboard
router.get(
  '/dashboard',
  authenticate,
  requireReseller,
  resellerController.getDashboard
);

// GET /api/v1/resellers/earnings — Reseller earnings
router.get(
  '/earnings',
  authenticate,
  requireReseller,
  resellerController.getEarnings
);

// GET /api/v1/resellers/nodes — Online nodes (admin)
router.get(
  '/nodes',
  authenticate,
  resellerController.getOnlineNodes
);

// GET /api/v1/resellers — All resellers (admin)
router.get(
  '/',
  authenticate,
  resellerController.getAllResellers
);

export default router;
