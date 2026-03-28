import { Request, Response, NextFunction } from 'express';
import { cache } from '../config/redis';
import { AppError } from '../utils/errors';
import { config } from '../config';

/**
 * Rate limiter using Redis for distributed environments
 */
export function rateLimiter(maxRequests?: number, windowMs?: number) {
  const max = maxRequests || config.security.rateLimitMax;
  const window = windowMs || config.security.rateLimitWindowMs;
  const windowSeconds = Math.ceil(window / 1000);

  return async (req: Request, _res: Response, next: NextFunction) => {
    try {
      const identifier = req.user?.id || req.ip || 'unknown';
      const key = `ratelimit:${req.path}:${identifier}`;

      const current = await cache.incr(key);
      if (current === 1) {
        await cache.expire(key, windowSeconds);
      }

      if (current > max) {
        throw AppError.tooManyRequests(
          `Rate limit exceeded. Try again in ${windowSeconds} seconds.`
        );
      }

      next();
    } catch (error) {
      if (error instanceof AppError) {
        next(error);
      } else {
        // If Redis is down, allow the request
        next();
      }
    }
  };
}

/**
 * Strict rate limiter for sensitive endpoints (auth, payments)
 */
export function strictRateLimiter() {
  return rateLimiter(10, 60000); // 10 requests per minute
}

/**
 * Payment rate limiter
 */
export function paymentRateLimiter() {
  return rateLimiter(5, 300000); // 5 payment attempts per 5 minutes
}
