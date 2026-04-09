import rateLimit from 'express-rate-limit';
import { Request, Response, NextFunction } from 'express';
import { logger } from '../utils/logger';

// ============================================================
// General API Rate Limiter
// ============================================================

export const apiLimiter = rateLimit({
  windowMs: 15 * 60 * 1000, // 15 minutes
  max: 100, // Limit each IP to 100 requests per windowMs
  message: {
    error: 'Too many requests',
    message: 'You have exceeded the rate limit. Please try again later.',
  },
  standardHeaders: true, // Return rate limit info in the `RateLimit-*` headers
  legacyHeaders: false, // Disable the `X-RateLimit-*` headers
  skip: (req) => {
    // Skip rate limiting for health checks
    return req.path === '/api/v1/health' || req.path === '/';
  },
});

// ============================================================
// M-Pesa Callback Rate Limiter (More restrictive)
// ============================================================

// Track failed callback attempts per IP
const callbackAttempts = new Map<string, { count: number; firstAttempt: number }>();

export const mpesaCallbackLimiter = (req: Request, res: Response, next: NextFunction) => {
  const ip = req.ip || req.connection.remoteAddress || 'unknown';
  const now = Date.now();
  const windowMs = 60 * 1000; // 1 minute window
  const maxAttempts = 10; // Max 10 attempts per minute

  const attempt = callbackAttempts.get(ip);

  if (!attempt || now - attempt.firstAttempt > windowMs) {
    // Reset if window expired
    callbackAttempts.set(ip, { count: 1, firstAttempt: now });
    next();
    return;
  }

  if (attempt.count >= maxAttempts) {
    logger.warn('M-Pesa callback rate limit exceeded', { ip, attempts: attempt.count });
    res.status(429).json({
      error: 'Too many callback attempts',
      message: 'Rate limit exceeded. Please wait before retrying.',
    });
    return;
  }

  attempt.count++;
  next();
};

// Clean up old entries periodically
setInterval(() => {
  const now = Date.now();
  const windowMs = 60 * 1000;
  for (const [ip, attempt] of callbackAttempts.entries()) {
    if (now - attempt.firstAttempt > windowMs) {
      callbackAttempts.delete(ip);
    }
  }
}, 60 * 1000);

// ============================================================
// Authentication Rate Limiter (Very restrictive)
// ============================================================

export const authLimiter = rateLimit({
  windowMs: 15 * 60 * 1000, // 15 minutes
  max: 5, // Limit each IP to 5 login attempts per windowMs
  message: {
    error: 'Too many login attempts',
    message: 'Please try again after 15 minutes.',
  },
  standardHeaders: true,
  legacyHeaders: false,
  skipSuccessfulRequests: true, // Only count failed attempts
});

// ============================================================
// Payment Creation Rate Limiter
// ============================================================

export const paymentLimiter = rateLimit({
  windowMs: 60 * 1000, // 1 minute
  max: 5, // Max 5 payment initiations per minute per IP
  message: {
    error: 'Too many payment requests',
    message: 'Please wait before initiating another payment.',
  },
  standardHeaders: true,
  legacyHeaders: false,
});