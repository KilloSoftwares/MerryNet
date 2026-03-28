import { prisma } from '../config/database';
import { AppError } from '../utils/errors';
import { logger } from '../utils/logger';

export class ResellerService {
  /**
   * Register a new reseller node
   */
  async register(userId: string, data: {
    deviceId: string;
    publicKey?: string;
    endpoint?: string;
    location?: string;
    capacity?: number;
    compensationType?: 'COMMISSION' | 'FREE_NET';
    platform?: string;
  }) {
    // Check if user already has a reseller account
    const existing = await prisma.reseller.findUnique({ where: { userId } });
    if (existing) {
      throw AppError.conflict('User is already registered as a reseller');
    }

    // Check device ID uniqueness
    const deviceExists = await prisma.reseller.findUnique({
      where: { deviceId: data.deviceId },
    });
    if (deviceExists) {
      throw AppError.conflict('Device is already registered');
    }

    // Assign subnet for the node (10.0.X.0/24)
    const nodeCount = await prisma.reseller.count();
    const subnetIndex = nodeCount + 1;
    const assignedSubnet = `10.0.${subnetIndex}.0/24`;

    const reseller = await prisma.reseller.create({
      data: {
        userId,
        deviceId: data.deviceId,
        publicKey: data.publicKey,
        endpoint: data.endpoint,
        location: data.location,
        capacity: data.capacity || 100,
        compensationType: data.compensationType || 'COMMISSION',
        assignedSubnet,
        platform: data.platform,
        version: '1.0.0',
      },
    });

    logger.info(`🖥️ Reseller registered: ${data.deviceId} (${data.platform}), subnet: ${assignedSubnet}`);

    return reseller;
  }

  /**
   * Update reseller info (heartbeat data)
   */
  async updateHeartbeat(resellerId: string, data: {
    activePeers: number;
    isOnline: boolean;
    endpoint?: string;
  }) {
    return prisma.reseller.update({
      where: { id: resellerId },
      data: {
        activePeers: data.activePeers,
        isOnline: data.isOnline,
        lastSeen: new Date(),
        ...(data.endpoint && { endpoint: data.endpoint }),
      },
    });
  }

  /**
   * Record node metrics
   */
  async recordMetrics(resellerId: string, metrics: {
    activePeers: number;
    cpuUsage: number;
    memoryUsage: number;
    bytesRx: bigint;
    bytesTx: bigint;
    uptime: number;
  }) {
    return prisma.nodeMetric.create({
      data: {
        resellerId,
        ...metrics,
      },
    });
  }

  /**
   * Get all resellers (admin)
   */
  async getAll(page: number = 1, limit: number = 20) {
    const [resellers, total] = await Promise.all([
      prisma.reseller.findMany({
        include: {
          user: { select: { phone: true } },
          _count: { select: { commissions: true } },
        },
        orderBy: { createdAt: 'desc' },
        skip: (page - 1) * limit,
        take: limit,
      }),
      prisma.reseller.count(),
    ]);

    return { resellers, total };
  }

  /**
   * Get reseller by user ID
   */
  async getByUserId(userId: string) {
    const reseller = await prisma.reseller.findUnique({
      where: { userId },
      include: {
        user: { select: { phone: true } },
        commissions: {
          orderBy: { createdAt: 'desc' },
          take: 10,
        },
      },
    });

    if (!reseller) throw AppError.notFound('Reseller');
    return reseller;
  }

  /**
   * Get reseller earnings summary
   */
  async getEarnings(resellerId: string) {
    const [totalEarnings, unpaidCommissions, paidCommissions, totalPeersServed] = await Promise.all([
      prisma.commission.aggregate({
        where: { resellerId },
        _sum: { amount: true },
      }),
      prisma.commission.aggregate({
        where: { resellerId, paid: false },
        _sum: { amount: true },
        _count: true,
      }),
      prisma.commission.aggregate({
        where: { resellerId, paid: true },
        _sum: { amount: true },
        _count: true,
      }),
      prisma.subscription.count({
        where: { resellerId },
      }),
    ]);

    return {
      totalEarnings: totalEarnings._sum.amount || 0,
      unpaidAmount: unpaidCommissions._sum.amount || 0,
      unpaidCount: unpaidCommissions._count,
      paidAmount: paidCommissions._sum.amount || 0,
      paidCount: paidCommissions._count,
      totalPeersServed,
    };
  }

  /**
   * Get online nodes
   */
  async getOnlineNodes() {
    return prisma.reseller.findMany({
      where: {
        isOnline: true,
        lastSeen: { gte: new Date(Date.now() - 5 * 60 * 1000) }, // seen in last 5 min
      },
      select: {
        id: true,
        deviceId: true,
        endpoint: true,
        location: true,
        capacity: true,
        activePeers: true,
        platform: true,
      },
      orderBy: { activePeers: 'asc' },
    });
  }

  /**
   * Mark nodes as offline if they haven't sent heartbeat
   */
  async markStaleNodesOffline(): Promise<number> {
    const result = await prisma.reseller.updateMany({
      where: {
        isOnline: true,
        lastSeen: { lt: new Date(Date.now() - 5 * 60 * 1000) }, // 5 min timeout
      },
      data: { isOnline: false },
    });

    if (result.count > 0) {
      logger.warn(`⚠️ Marked ${result.count} nodes as offline (stale heartbeat)`);
    }

    return result.count;
  }

  /**
   * Process commission payouts (weekly batch)
   */
  async processPayouts(): Promise<number> {
    const unpaidCommissions = await prisma.commission.findMany({
      where: { paid: false },
      include: {
        reseller: {
          include: { user: { select: { phone: true } } },
        },
      },
    });

    // Group by reseller
    const payoutMap = new Map<string, {
      resellerId: string;
      phone: string;
      totalAmount: number;
      commissionIds: string[];
    }>();

    for (const commission of unpaidCommissions) {
      const existing = payoutMap.get(commission.resellerId);
      if (existing) {
        existing.totalAmount += Number(commission.amount);
        existing.commissionIds.push(commission.id);
      } else {
        payoutMap.set(commission.resellerId, {
          resellerId: commission.resellerId,
          phone: commission.reseller.user.phone,
          totalAmount: Number(commission.amount),
          commissionIds: [commission.id],
        });
      }
    }

    let paidCount = 0;
    for (const [_, payout] of payoutMap) {
      if (payout.totalAmount < 50) continue; // Min payout KES 50

      try {
        // M-PESA B2C PAYOUT LOGIC
        // This is where Daraja B2C APIs would dispatch the KES directly to the reseller's MSISDN.
        logger.info(`💸 [M-PESA B2C MOCK] Transporting KES ${payout.totalAmount} to MSISDN: ${payout.phone}`);
        
        // For now, mark as paid
        await prisma.commission.updateMany({
          where: { id: { in: payout.commissionIds } },
          data: { paid: true, paidAt: new Date() },
        });

        paidCount++;
        logger.info(
          `💰 Payout: KES ${payout.totalAmount} to reseller ${payout.resellerId} (${payout.phone})`
        );
      } catch (error) {
        logger.error(`Payout failed for reseller ${payout.resellerId}:`, error);
      }
    }

    return paidCount;
  }
}

export const resellerService = new ResellerService();
