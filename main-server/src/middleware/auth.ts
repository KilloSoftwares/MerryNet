import { Request, Response, NextFunction } from 'express';
import jwt from 'jsonwebtoken';
import { config } from '../config';
import { AppError } from '../utils/errors';
import { prisma } from '../config/database';
import { logger } from '../utils/logger';

export interface AuthUser {
  id: string;
  phone: string;
  isReseller: boolean;
}

declare global {
  namespace Express {
    interface Request {
      user?: AuthUser;
    }
  }
}

export function authenticate(req: Request, _res: Response, next: NextFunction): void {
  try {
    const authHeader = req.headers.authorization;
    if (!authHeader || !authHeader.startsWith('Bearer ')) {
      throw AppError.unauthorized('No token provided');
    }

    const token = authHeader.split(' ')[1];
    const decoded = jwt.verify(token, config.jwt.secret) as {
      userId: string;
      phone: string;
      isReseller: boolean;
    };

    req.user = {
      id: decoded.userId,
      phone: decoded.phone,
      isReseller: decoded.isReseller,
    };

    next();
  } catch (error) {
    if (error instanceof jwt.TokenExpiredError) {
      next(AppError.unauthorized('Token expired'));
    } else if (error instanceof jwt.JsonWebTokenError) {
      next(AppError.unauthorized('Invalid token'));
    } else {
      next(error);
    }
  }
}

export function optionalAuth(req: Request, _res: Response, next: NextFunction): void {
  try {
    const authHeader = req.headers.authorization;
    if (!authHeader || !authHeader.startsWith('Bearer ')) {
      return next();
    }

    const token = authHeader.split(' ')[1];
    const decoded = jwt.verify(token, config.jwt.secret) as {
      userId: string;
      phone: string;
      isReseller: boolean;
    };

    req.user = {
      id: decoded.userId,
      phone: decoded.phone,
      isReseller: decoded.isReseller,
    };

    next();
  } catch {
    // Token invalid but auth is optional — continue without user
    next();
  }
}

export function requireReseller(req: Request, _res: Response, next: NextFunction): void {
  if (!req.user) {
    return next(AppError.unauthorized());
  }
  if (!req.user.isReseller) {
    return next(AppError.forbidden('Reseller access required'));
  }
  next();
}

export function generateTokens(user: { id: string; phone: string; isReseller: boolean }) {
  const accessToken = jwt.sign(
    { userId: user.id, phone: user.phone, isReseller: user.isReseller },
    config.jwt.secret,
    { expiresIn: config.jwt.expiresIn as any }
  );

  const refreshToken = jwt.sign(
    { userId: user.id, type: 'refresh' },
    config.jwt.secret,
    { expiresIn: config.jwt.refreshExpiresIn as any }
  );

  return { accessToken, refreshToken };
}
