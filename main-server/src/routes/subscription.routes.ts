import { Router } from 'express';
import { subscriptionController } from '../controllers/subscription.controller';
import { authenticate, optionalAuth } from '../middleware/auth';

const router = Router();

// GET /api/v1/subscriptions/plans — Get available plans (public)
router.get(
  '/plans',
  optionalAuth,
  subscriptionController.getPlans
);

// GET /api/v1/subscriptions/active — Get active subscription
router.get(
  '/active',
  authenticate,
  subscriptionController.getActiveSubscription
);

// GET /api/v1/subscriptions — Get subscription history
router.get(
  '/',
  authenticate,
  subscriptionController.getSubscriptions
);

export default router;
