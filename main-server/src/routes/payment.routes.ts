import { Router } from 'express';
import { paymentController } from '../controllers/payment.controller';
import { authenticate } from '../middleware/auth';
import { validateBody } from '../middleware/errorHandler';
import { paymentRateLimiter } from '../middleware/rateLimiter';
import { initiatePaymentSchema } from '../utils/validators';

const router = Router();

// POST /api/v1/payments/initiate — Initiate M-Pesa payment
router.post(
  '/initiate',
  authenticate,
  paymentRateLimiter(),
  validateBody(initiatePaymentSchema),
  paymentController.initiatePayment
);

// POST /api/v1/payments/mpesa/callback — M-Pesa callback (no auth needed)
router.post(
  '/mpesa/callback',
  paymentController.mpesaCallback
);

// GET /api/v1/payments/status/:checkoutRequestId — Check payment status
router.get(
  '/status/:checkoutRequestId',
  authenticate,
  paymentController.checkPaymentStatus
);

// GET /api/v1/payments/transactions — Get transaction history
router.get(
  '/transactions',
  authenticate,
  paymentController.getTransactions
);

export default router;
