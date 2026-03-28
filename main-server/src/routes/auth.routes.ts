import { Router } from 'express';
import { authController } from '../controllers/auth.controller';
import { authenticate } from '../middleware/auth';
import { validateBody } from '../middleware/errorHandler';
import { strictRateLimiter } from '../middleware/rateLimiter';
import { loginSchema, verifyOtpSchema, refreshTokenSchema } from '../utils/validators';

const router = Router();

// POST /api/v1/auth/login — Request OTP
router.post(
  '/login',
  strictRateLimiter(),
  validateBody(loginSchema),
  authController.requestLogin
);

// POST /api/v1/auth/verify — Verify OTP
router.post(
  '/verify',
  strictRateLimiter(),
  validateBody(verifyOtpSchema),
  authController.verifyOtp
);

// POST /api/v1/auth/refresh — Refresh token
router.post(
  '/refresh',
  validateBody(refreshTokenSchema),
  authController.refreshToken
);

// POST /api/v1/auth/logout
router.post(
  '/logout',
  authenticate,
  authController.logout
);

// GET /api/v1/auth/profile
router.get(
  '/profile',
  authenticate,
  authController.getProfile
);

export default router;
