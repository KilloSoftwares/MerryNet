import { Request, Response, NextFunction } from 'express';
import { resellerService } from '../services/reseller.service';
import { successResponse } from '../utils/errors';

export class ResellerController {
  /**
   * Register as a reseller
   */
  async register(req: Request, res: Response, next: NextFunction) {
    try {
      const userId = req.user!.id;
      const reseller = await resellerService.register(userId, req.body);
      res.status(201).json(successResponse(reseller));
    } catch (error) {
      next(error);
    }
  }

  /**
   * Get reseller dashboard data
   */
  async getDashboard(req: Request, res: Response, next: NextFunction) {
    try {
      const userId = req.user!.id;
      const [reseller, earnings] = await Promise.all([
        resellerService.getByUserId(userId),
        resellerService.getEarnings(userId).catch(() => null),
      ]);

      res.status(200).json(
        successResponse({
          reseller,
          earnings,
        })
      );
    } catch (error) {
      next(error);
    }
  }

  /**
   * Get reseller earnings
   */
  async getEarnings(req: Request, res: Response, next: NextFunction) {
    try {
      const reseller = await resellerService.getByUserId(req.user!.id);
      const earnings = await resellerService.getEarnings(reseller.id);
      res.status(200).json(successResponse(earnings));
    } catch (error) {
      next(error);
    }
  }

  /**
   * Get all online nodes (admin endpoint)
   */
  async getOnlineNodes(req: Request, res: Response, next: NextFunction) {
    try {
      const nodes = await resellerService.getOnlineNodes();
      res.status(200).json(successResponse(nodes));
    } catch (error) {
      next(error);
    }
  }

  /**
   * Get all resellers (admin endpoint)
   */
  async getAllResellers(req: Request, res: Response, next: NextFunction) {
    try {
      const page = parseInt(req.query.page as string) || 1;
      const limit = parseInt(req.query.limit as string) || 20;
      const { resellers, total } = await resellerService.getAll(page, limit);

      res.status(200).json(
        successResponse(resellers, {
          page,
          limit,
          total,
          totalPages: Math.ceil(total / limit),
        })
      );
    } catch (error) {
      next(error);
    }
  }
}

export const resellerController = new ResellerController();
