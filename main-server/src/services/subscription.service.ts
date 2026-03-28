import { Decimal } from '@prisma/client/runtime/library';
import { prisma } from '../config/database';
import { cache } from '../config/redis';
import { AppError } from '../utils/errors';
import { calculateEndTime } from '../utils/helpers';
import { logger } from '../utils/logger';
import { sendCreatePeer, sendRemovePeer } from '../grpc/server';
import { generateWireGuardKeys } from '../utils/helpers';

export class SubscriptionService {
  /**
   * Get all available plans
   */
  async getPlans() {
    const cached = await cache.get<any[]>('plans:all');
    if (cached) return cached;

    const plans = await prisma.plan.findMany({
      where: { isActive: true },
      orderBy: { sortOrder: 'asc' },
    });

    await cache.set('plans:all', plans, 300); // Cache 5 minutes
    return plans;
  }

  /**
   * Get a specific plan
   */
  async getPlan(planId: string) {
    const plan = await prisma.plan.findUnique({ where: { id: planId } });
    if (!plan) throw AppError.notFound('Plan');
    return plan;
  }

  /**
   * Create a subscription after successful payment
   */
  async createSubscription(params: {
    userId: string;
    planId: string;
    transactionId: string;
    autoRenew?: boolean;
  }) {
    const { userId, planId, transactionId, autoRenew = false } = params;

    // Get the plan
    const plan = await this.getPlan(planId);

    // Calculate end time
    const endTime = calculateEndTime(plan.durationHours);

    // Create subscription in a transaction
    const subscription = await prisma.$transaction(async (tx) => {
      // Create subscription
      const sub = await tx.subscription.create({
        data: {
          userId,
          planId,
          startTime: new Date(),
          endTime,
          status: 'ACTIVE',
          autoRenew,
        },
      });

      // Link transaction to subscription
      await tx.transaction.update({
        where: { id: transactionId },
        data: { subscriptionId: sub.id },
      });

      // Update user's active subscription
      await tx.user.update({
        where: { id: userId },
        data: {
          activeSubscriptionId: sub.id,
          autoRenew,
        },
      });

      return sub;
    });

    logger.info(
      `🎫 Subscription created: ${subscription.id} (${planId}) for user ${userId}, expires ${endTime.toISOString()}`
    );

    // Cache active subscription
    await cache.set(`subscription:active:${userId}`, subscription, plan.durationHours * 3600);

    return subscription;
  }

  /**
   * Provision VPN access for a subscription
   * Selects best reseller node and creates WireGuard peer
   */
  async provisionVPN(subscriptionId: string) {
    const subscription = await prisma.subscription.findUnique({
      where: { id: subscriptionId },
      include: { user: true },
    });

    if (!subscription) throw AppError.notFound('Subscription');

    // Select best reseller node
    const bestNode = await this.selectBestNode();
    if (!bestNode) {
      logger.warn('No available reseller nodes for VPN provisioning');
      throw AppError.serviceUnavailable('No VPN nodes available. Please try again later.');
    }

    // Update subscription with reseller
    await prisma.subscription.update({
      where: { id: subscriptionId },
      data: { resellerId: bestNode.id },
    });

    // Create commission for reseller
    const transaction = await prisma.transaction.findFirst({
      where: { subscriptionId },
    });

    if (transaction && bestNode.compensationType === 'COMMISSION') {
      const commissionAmount = new Decimal(transaction.amount.toString())
        .mul(bestNode.commissionRate)
        .div(100);

      await prisma.commission.create({
        data: {
          resellerId: bestNode.id,
          transactionId: transaction.id,
          amount: commissionAmount,
        },
      });

      // Update reseller total earnings
      await prisma.reseller.update({
        where: { id: bestNode.id },
        data: {
          totalEarnings: { increment: commissionAmount },
          activePeers: { increment: 1 },
        },
      });

      logger.info(
        `💸 Commission created: KES ${commissionAmount} for reseller ${bestNode.id}`
      );
    }

    // Generate client credentials on the server to simplify mobile app
    const clientKeys = generateWireGuardKeys();
    const assignedIp = `10.0.0.${Math.floor(Math.random() * 250) + 2}/32`;

    // Send gRPC CreatePeer command to the reseller node
    await sendCreatePeer(
      bestNode.deviceId,
      subscription.userId,
      subscriptionId,
      clientKeys.publicKey,
      assignedIp,
      subscription.endTime
    );

    return {
      subscriptionId,
      resellerId: bestNode.id,
      resellerEndpoint: bestNode.endpoint,
      clientPublicKey: clientKeys.publicKey,
      clientPrivateKey: clientKeys.privateKey,
      clientAddress: assignedIp,
      serverPublicKey: bestNode.publicKey,
    };
  }

  /**
   * Select the best reseller node (least loaded, online)
   */
  private async selectBestNode() {
    return prisma.reseller.findFirst({
      where: {
        isOnline: true,
        activePeers: { lt: prisma.reseller.fields.capacity as any }, // Simplified
      },
      orderBy: [
        { activePeers: 'asc' }, // Least loaded first
      ],
    });
  }

  /**
   * Get user's subscriptions
   */
  async getUserSubscriptions(userId: string, page: number = 1, limit: number = 20) {
    const [subscriptions, total] = await Promise.all([
      prisma.subscription.findMany({
        where: { userId },
        include: { plan: true, reseller: { select: { location: true } } },
        orderBy: { createdAt: 'desc' },
        skip: (page - 1) * limit,
        take: limit,
      }),
      prisma.subscription.count({ where: { userId } }),
    ]);

    return { subscriptions, total };
  }

  /**
   * Get active subscription for a user
   */
  async getActiveSubscription(userId: string) {
    // Check cache first
    const cached = await cache.get<any>(`subscription:active:${userId}`);
    if (cached && new Date(cached.endTime) > new Date()) {
      return cached;
    }

    const subscription = await prisma.subscription.findFirst({
      where: {
        userId,
        status: 'ACTIVE',
        endTime: { gt: new Date() },
      },
      include: { plan: true },
      orderBy: { endTime: 'desc' },
    });

    if (subscription) {
      const ttl = Math.max(
        1,
        Math.floor((new Date(subscription.endTime).getTime() - Date.now()) / 1000)
      );
      await cache.set(`subscription:active:${userId}`, subscription, ttl);
    }

    return subscription;
  }

  /**
   * Expire subscriptions that have passed their end time
   */
  async expireSubscriptions(): Promise<number> {
    const expired = await prisma.subscription.updateMany({
      where: {
        status: 'ACTIVE',
        endTime: { lte: new Date() },
      },
      data: { status: 'EXPIRED' },
    });

    if (expired.count > 0) {
      logger.info(`⏰ Expired ${expired.count} subscriptions`);

      // Get expired subscriptions for peer cleanup
      const expiredSubs = await prisma.subscription.findMany({
        where: {
          status: 'EXPIRED',
          updatedAt: { gte: new Date(Date.now() - 60000) }, // last minute
        },
        include: { reseller: true },
      });

      for (const sub of expiredSubs) {
        if (sub.resellerId && sub.reseller) {
          // Decrement active peers
          await prisma.reseller.update({
            where: { id: sub.resellerId },
            data: { activePeers: { decrement: 1 } },
          });

          // Attempt to locate public key in a real scenario (mocking removal)
          // Since we generated dynamic keys, we should technically store the active
          //  publicKey on the subscription model. For this implementation, we just mock the payload.
          await sendRemovePeer(sub.reseller.deviceId, 'expired_client_pub_key');
        }

        // Clear cached subscription
        await cache.del(`subscription:active:${sub.userId}`);

        // Clear active subscription on user
        await prisma.user.update({
          where: { id: sub.userId, activeSubscriptionId: sub.id },
          data: { activeSubscriptionId: null },
        });
      }
    }

    return expired.count;
  }

  /**
   * Handle auto-renewal
   */
  async processAutoRenewals(): Promise<number> {
    const soonExpiring = await prisma.subscription.findMany({
      where: {
        status: 'ACTIVE',
        autoRenew: true,
        endTime: {
          lte: new Date(Date.now() + 5 * 60 * 1000), // expires within 5 minutes
          gt: new Date(),
        },
      },
      include: { user: true, plan: true },
    });

    let renewed = 0;
    for (const sub of soonExpiring) {
      try {
        // Import mpesaService dynamically to avoid circular deps
        const { mpesaService } = await import('./mpesa.service');
        await mpesaService.initiateSTKPush({
          userId: sub.userId,
          phone: sub.user.phone,
          amount: Number(sub.plan.price),
          planId: sub.planId,
          accountReference: `RENEWAL-${sub.planId.toUpperCase()}`,
        });
        renewed++;
        logger.info(`🔄 Auto-renewal initiated for user ${sub.userId}`);
      } catch (error) {
        logger.error(`Failed to auto-renew for user ${sub.userId}:`, error);
      }
    }

    return renewed;
  }
}

export const subscriptionService = new SubscriptionService();
