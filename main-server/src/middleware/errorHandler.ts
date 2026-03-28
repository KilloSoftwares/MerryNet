import { Request, Response, NextFunction } from 'express';
import { ZodError, ZodSchema } from 'zod';
import { AppError, errorResponse } from '../utils/errors';
import { logger } from '../utils/logger';

/**
 * Global error handler middleware
 */
export function errorHandler(err: Error, req: Request, res: Response, _next: NextFunction): void {
  logger.error('Error:', {
    message: err.message,
    stack: err.stack,
    path: req.path,
    method: req.method,
    ip: req.ip,
  });

  if (err instanceof AppError) {
    res.status(err.statusCode).json(errorResponse(err));
    return;
  }

  if (err instanceof ZodError) {
    const appError = AppError.badRequest('Validation error', err.errors);
    res.status(400).json(errorResponse(appError));
    return;
  }

  // Unexpected errors
  const serverError = AppError.internal('Something went wrong');
  res.status(500).json(errorResponse(serverError));
}

/**
 * Validates request body against a Zod schema
 */
export function validateBody(schema: ZodSchema) {
  return (req: Request, _res: Response, next: NextFunction) => {
    try {
      req.body = schema.parse(req.body);
      next();
    } catch (error) {
      next(error);
    }
  };
}

/**
 * Validates request query params against a Zod schema
 */
export function validateQuery(schema: ZodSchema) {
  return (req: Request, _res: Response, next: NextFunction) => {
    try {
      req.query = schema.parse(req.query);
      next();
    } catch (error) {
      next(error);
    }
  };
}

/**
 * Validates request params against a Zod schema
 */
export function validateParams(schema: ZodSchema) {
  return (req: Request, _res: Response, next: NextFunction) => {
    try {
      req.params = schema.parse(req.params);
      next();
    } catch (error) {
      next(error);
    }
  };
}

/**
 * Not found handler
 */
export function notFoundHandler(req: Request, res: Response): void {
  const error = AppError.notFound(`Route ${req.method} ${req.path}`);
  res.status(404).json(errorResponse(error));
}
