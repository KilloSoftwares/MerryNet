import { Request, Response, NextFunction } from 'express';
import { subscriptionService } from '../services/subscription.service';
import { successResponse } from '../utils/errors';

export class SubscriptionController {
  /**
   * Get all available plans
   */
  async getPlans(req: Request, res: Response, next: NextFunction) {
    try {
      const plans = await subscriptionService.getPlans();
      res.status(200).json(successResponse(plans));
    } catch (error) {
      next(error);
    }
  }

  /**
   * Get user's active subscription
   */
  async getActiveSubscription(req: Request, res: Response, next: NextFunction) {
    try {
      const userId = req.user!.id;
      const subscription = await subscriptionService.getActiveSubscription(userId);
      res.status(200).json(successResponse(subscription));
    } catch (error) {
      next(error);
    }
  }

  /**
   * Get user's subscription history
   */
  async getSubscriptions(req: Request, res: Response, next: NextFunction) {
    try {
      const userId = req.user!.id;
      const page = parseInt(req.query.page as string) || 1;
      const limit = parseInt(req.query.limit as string) || 20;
      const { subscriptions, total } = await subscriptionService.getUserSubscriptions(userId, page, limit);

      res.status(200).json(
        successResponse(subscriptions, {
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

export const subscriptionController = new SubscriptionController();
