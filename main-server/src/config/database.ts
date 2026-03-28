import { PrismaClient } from '@prisma/client';
import { config } from './index';
import { logger } from '../utils/logger';

const prisma = new PrismaClient({
  datasources: {
    db: {
      url: config.database.url,
    },
  },
  log: config.env === 'development'
    ? [
        { emit: 'event', level: 'query' },
        { emit: 'event', level: 'error' },
        { emit: 'event', level: 'warn' },
      ]
    : [{ emit: 'event', level: 'error' }],
});

if (config.env === 'development') {
  prisma.$on('query', (e) => {
    logger.debug(`Query: ${e.query} — Duration: ${e.duration}ms`);
  });
}

prisma.$on('error', (e) => {
  logger.error('Prisma error:', e);
});

export { prisma };

export async function connectDatabase(): Promise<void> {
  try {
    await prisma.$connect();
    logger.info('✅ Database connected successfully');
  } catch (error) {
    logger.error('❌ Database connection failed:', error);
    throw error;
  }
}

export async function disconnectDatabase(): Promise<void> {
  await prisma.$disconnect();
  logger.info('Database disconnected');
}
