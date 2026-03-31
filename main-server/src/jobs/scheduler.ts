import Bull from 'bull';
import { config } from '../config';
import { subscriptionService } from '../services/subscription.service';
import { resellerService } from '../services/reseller.service';
import { logger } from '../utils/logger';
import { getRedis } from '../config/redis';

// ============================================================
// Job Queues
// ============================================================

export const subscriptionExpiryQueue = new Bull('subscription-expiry', config.redis.url, {
  defaultJobOptions: {
    removeOnComplete: 100,
    removeOnFail: 50,
    attempts: 3,
    backoff: { type: 'exponential', delay: 5000 },
  },
});

export const autoRenewalQueue = new Bull('auto-renewal', config.redis.url, {
  defaultJobOptions: {
    removeOnComplete: 50,
    removeOnFail: 50,
    attempts: 2,
    backoff: { type: 'fixed', delay: 30000 },
  },
});

export const nodeHealthQueue = new Bull('node-health', config.redis.url, {
  defaultJobOptions: {
    removeOnComplete: 20,
    removeOnFail: 10,
  },
});

export const payoutQueue = new Bull('commission-payout', config.redis.url, {
  defaultJobOptions: {
    removeOnComplete: 10,
    removeOnFail: 10,
    attempts: 3,
  },
});

export const provisioningQueue = new Bull('vpn-provisioning', config.redis.url, {
  defaultJobOptions: {
    removeOnComplete: 100,
    removeOnFail: 50,
    attempts: 3,
    backoff: { type: 'exponential', delay: 2000 },
  },
});

// ============================================================
// Job Processors
// ============================================================

subscriptionExpiryQueue.process(async () => {
  logger.debug('⏰ Running subscription expiry check...');
  const count = await subscriptionService.expireSubscriptions();
  return { expiredCount: count };
});

autoRenewalQueue.process(async () => {
  logger.debug('🔄 Running auto-renewal check...');
  const count = await subscriptionService.processAutoRenewals();
  return { renewedCount: count };
});

nodeHealthQueue.process(async () => {
  logger.debug('🏥 Running node health check...');
  const offlineCount = await resellerService.markStaleNodesOffline();
  
  // Also refresh access for online resellers
  const onlineNodes = await resellerService.getOnlineNodes();
  for (const node of onlineNodes) {
    if (node.compensationType === 'FREE_NET' || (node.compensationType as any) === 'DEVELOPER') {
      await subscriptionService.ensureResellerAccess(node.id);
    }
  }

  return { offlineCount, refreshedCount: onlineNodes.length };
});

payoutQueue.process(async () => {
  logger.debug('💰 Running commission payout...');
  const count = await resellerService.processPayouts();
  return { paidCount: count };
});

provisioningQueue.process(async (job) => {
  const { transactionId, userId, planId } = job.data;
  logger.info(`🔧 Provisioning VPN for user ${userId}, plan ${planId}`);

  const subscription = await subscriptionService.createSubscription({
    userId,
    planId,
    transactionId,
  });

  // Provision VPN access
  const vpnConfig = await subscriptionService.provisionVPN(subscription.id);
  return vpnConfig;
});

// ============================================================
// Job Scheduling (Repeatable)
// ============================================================

export async function startJobScheduler(): Promise<void> {
  // Check expired subscriptions every 30 seconds
  await subscriptionExpiryQueue.add({}, { repeat: { every: 30000 } });

  // Check auto-renewals every 60 seconds
  await autoRenewalQueue.add({}, { repeat: { every: 60000 } });

  // Check node health every 60 seconds
  await nodeHealthQueue.add({}, { repeat: { every: 60000 } });

  // Process commission payouts every Sunday at midnight
  await payoutQueue.add({}, {
    repeat: { cron: '0 0 * * 0' }, // Every Sunday at midnight
  });

  // Listen for payment:completed events from Redis pub/sub
  const subscriber = getRedis().duplicate();
  await subscriber.subscribe('payment:completed');
  subscriber.on('message', async (_channel, message) => {
    try {
      const data = JSON.parse(message);
      logger.info(`📨 Payment completed event: ${JSON.stringify(data)}`);
      await provisioningQueue.add(data);
    } catch (error) {
      logger.error('Failed to process payment event:', error);
    }
  });

  logger.info('✅ Job scheduler started');
  logger.info('  📋 Subscription expiry: every 30s');
  logger.info('  🔄 Auto-renewal: every 60s');
  logger.info('  🏥 Node health: every 60s');
  logger.info('  💰 Payouts: weekly (Sunday midnight)');
  logger.info('  📨 Provisioning: on payment completion');
}

// ============================================================
// Error Handling
// ============================================================

const queues = [subscriptionExpiryQueue, autoRenewalQueue, nodeHealthQueue, payoutQueue, provisioningQueue];
for (const queue of queues) {
  queue.on('failed', (job, err) => {
    logger.error(`Job ${job.id} in ${job.queue.name} failed:`, err.message);
  });

  queue.on('completed', (job, result) => {
    logger.debug(`Job ${job.id} in ${job.queue.name} completed:`, result);
  });
}

export async function stopJobScheduler(): Promise<void> {
  for (const queue of queues) {
    await queue.obliterate({ force: true });
    await queue.close();
  }
  logger.info('Job scheduler stopped');
}
