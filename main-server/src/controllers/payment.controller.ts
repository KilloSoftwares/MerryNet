import { Request, Response, NextFunction } from 'express';
import { mpesaService } from '../services/mpesa.service';
import { subscriptionService } from '../services/subscription.service';
import { successResponse, AppError } from '../utils/errors';
import { logger } from '../utils/logger';

export class PaymentController {
  /**
   * Initiate M-Pesa STK Push payment
   */
  async initiatePayment(req: Request, res: Response, next: NextFunction) {
    try {
      const userId = req.user!.id;
      const { planId, phone, autoRenew } = req.body;

      // Get plan details
      const plan = await subscriptionService.getPlan(planId);

      // Use provided phone or user's registered phone
      const paymentPhone = phone || req.user!.phone;

      const result = await mpesaService.initiateSTKPush({
        userId,
        phone: paymentPhone,
        amount: Number(plan.price),
        planId,
      });

      res.status(200).json(
        successResponse({
          message: 'Payment initiated. Please check your phone for the M-Pesa prompt.',
          checkoutRequestId: result.checkoutRequestId,
          merchantRequestId: result.merchantRequestId,
          planId,
          amount: Number(plan.price),
          currency: 'KES',
        })
      );
    } catch (error) {
      next(error);
    }
  }

  /**
   * M-Pesa callback endpoint (called by Safaricom)
   */
  async mpesaCallback(req: Request, res: Response, next: NextFunction) {
    try {
      logger.info('M-Pesa callback received:', JSON.stringify(req.body));

      const { Body } = req.body;
      if (!Body?.stkCallback) {
        logger.warn('Invalid M-Pesa callback format');
        res.status(200).json({ ResultCode: 0, ResultDesc: 'Accepted' });
        return;
      }

      await mpesaService.processCallback(Body);

      // Always respond with success to M-Pesa
      res.status(200).json({ ResultCode: 0, ResultDesc: 'Accepted' });
    } catch (error) {
      logger.error('M-Pesa callback processing error:', error);
      // Still respond 200 to M-Pesa to prevent retries
      res.status(200).json({ ResultCode: 0, ResultDesc: 'Accepted' });
    }
  }

  /**
   * Check payment status
   */
  async checkPaymentStatus(req: Request, res: Response, next: NextFunction) {
    try {
      const { checkoutRequestId } = req.params;
      const result = await mpesaService.querySTKStatus(checkoutRequestId);
      res.status(200).json(successResponse(result));
    } catch (error) {
      next(error);
    }
  }

  /**
   * Get user's transaction history
   */
  async getTransactions(req: Request, res: Response, next: NextFunction) {
    try {
      const userId = req.user!.id;
      const page = parseInt(req.query.page as string) || 1;
      const limit = parseInt(req.query.limit as string) || 20;

      const { prisma } = await import('../config/database');
      const [transactions, total] = await Promise.all([
        prisma.transaction.findMany({
          where: { userId },
          include: { plan: true },
          orderBy: { createdAt: 'desc' },
          skip: (page - 1) * limit,
          take: limit,
        }),
        prisma.transaction.count({ where: { userId } }),
      ]);

      res.status(200).json(
        successResponse(transactions, {
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

export const paymentController = new PaymentController();
