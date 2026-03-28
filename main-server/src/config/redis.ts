import Redis from 'ioredis';
import { config } from './index';
import { logger } from '../utils/logger';

let redis: Redis;

export function getRedis(): Redis {
  if (!redis) {
    redis = new Redis(config.redis.url, {
      password: config.redis.password,
      maxRetriesPerRequest: 3,
      retryStrategy(times) {
        const delay = Math.min(times * 200, 5000);
        logger.warn(`Redis reconnecting... attempt ${times}, delay ${delay}ms`);
        return delay;
      },
      reconnectOnError(err) {
        const targetError = 'READONLY';
        if (err.message.includes(targetError)) {
          return true;
        }
        return false;
      },
    });

    redis.on('connect', () => {
      logger.info('✅ Redis connected successfully');
    });

    redis.on('error', (err) => {
      logger.error('❌ Redis error:', err.message);
    });

    redis.on('close', () => {
      logger.warn('Redis connection closed');
    });
  }

  return redis;
}

export async function disconnectRedis(): Promise<void> {
  if (redis) {
    await redis.quit();
    logger.info('Redis disconnected');
  }
}

// Cache helpers
export const cache = {
  async get<T>(key: string): Promise<T | null> {
    const data = await getRedis().get(key);
    return data ? JSON.parse(data) : null;
  },

  async set(key: string, value: unknown, ttlSeconds?: number): Promise<void> {
    const serialized = JSON.stringify(value);
    if (ttlSeconds) {
      await getRedis().setex(key, ttlSeconds, serialized);
    } else {
      await getRedis().set(key, serialized);
    }
  },

  async del(key: string): Promise<void> {
    await getRedis().del(key);
  },

  async exists(key: string): Promise<boolean> {
    return (await getRedis().exists(key)) === 1;
  },

  async incr(key: string): Promise<number> {
    return getRedis().incr(key);
  },

  async expire(key: string, seconds: number): Promise<void> {
    await getRedis().expire(key, seconds);
  },
};
