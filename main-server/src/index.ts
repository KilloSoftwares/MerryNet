import express from 'express';
import cors from 'cors';
import helmet from 'helmet';
import compression from 'compression';
import morgan from 'morgan';
import { config } from './config';
import { connectDatabase, disconnectDatabase } from './config/database';
import { getRedis, disconnectRedis } from './config/redis';
import { errorHandler, notFoundHandler } from './middleware/errorHandler';
import { apiLimiter } from './middleware/rateLimiter';
import { logger } from './utils/logger';
import routes from './routes';
import { startJobScheduler, stopJobScheduler } from './jobs/scheduler';
import { startGrpcServer, stopGrpcServer } from './grpc/server';

// ============================================================
// Express App
// ============================================================

const app = express();

// ============================================================
// Security Middleware
// ============================================================

// Helmet for security headers (must be first)
app.use(helmet({
  contentSecurityPolicy: {
    directives: {
      defaultSrc: ["'self'"],
      styleSrc: ["'self'", "'unsafe-inline'"],
      scriptSrc: ["'self'"],
      imgSrc: ["'self'", 'data:', 'https:'],
    },
  },
  hsts: {
    maxAge: 31536000, // 1 year
    includeSubDomains: true,
    preload: true,
  },
  noSniff: true,
  xssFilter: true,
}));

// CORS configuration - more restrictive for production
const corsOptions = {
  origin: config.env === 'production'
    ? process.env.ALLOWED_ORIGINS?.split(',') || ['https://maranet.app']
    : config.security.corsOrigin,
  credentials: true,
  methods: ['GET', 'POST', 'PUT', 'DELETE', 'PATCH', 'OPTIONS'],
  allowedHeaders: ['Content-Type', 'Authorization', 'X-Requested-With'],
  maxAge: 86400, // 24 hours
};
app.use(cors(corsOptions));

// Rate limiting for all API routes
app.use('/api', apiLimiter);

// Body parsing
app.use(express.json({ limit: '10mb' }));
app.use(express.urlencoded({ extended: true }));

// Compression
app.use(compression());

// Request logging
app.use(
  morgan(config.env === 'development' ? 'dev' : 'combined', {
    stream: { write: (message) => logger.info(message.trim()) },
  })
);

// Trust proxy (for rate limiting behind reverse proxy)
app.set('trust proxy', 1);

// ============================================================
// Routes
// ============================================================

// API v1
app.use('/api/v1', routes);

// Root health check
app.get('/', (_req, res) => {
  res.json({
    service: 'Maranet Zero API',
    version: '1.0.0',
    status: 'running',
    docs: '/api/v1/health',
  });
});

// 404 handler
app.use(notFoundHandler);

// Error handler (must be last)
app.use(errorHandler);

// ============================================================
// Server Startup
// ============================================================

async function start(): Promise<void> {
  try {
    // Connect to database
    await connectDatabase();

    // Connect to Redis
    getRedis();

    // Start job scheduler
    await startJobScheduler();

    // Start gRPC server
    const grpcServer = startGrpcServer();

    // Start HTTP server
    const server = app.listen(config.port, config.host, () => {
      logger.info(`
╔══════════════════════════════════════════════════════╗
║                                                      ║
║        🌐 Maranet Zero API Server                    ║
║                                                      ║
║   Status:  Running                                   ║
║   Mode:    ${config.env.padEnd(39)}  ║
║   URL:     http://${config.host}:${config.port}${' '.repeat(Math.max(0, 30 - `http://${config.host}:${config.port}`.length))}  ║
║   API:     /api/v1                                   ║
║   Health:  /api/v1/health                            ║
║                                                      ║
╚══════════════════════════════════════════════════════╝
      `);
    });

    // Graceful shutdown
    const gracefulShutdown = async (signal: string) => {
      logger.info(`\n${signal} received. Starting graceful shutdown...`);

      server.close(async () => {
        logger.info('HTTP server closed');
        await stopGrpcServer(grpcServer);
        await stopJobScheduler();
        await disconnectRedis();
        await disconnectDatabase();
        logger.info('✅ Graceful shutdown complete');
        process.exit(0);
      });

      // Force shutdown after 30 seconds
      setTimeout(() => {
        logger.error('Forced shutdown after timeout');
        process.exit(1);
      }, 30000);
    };

    process.on('SIGTERM', () => gracefulShutdown('SIGTERM'));
    process.on('SIGINT', () => gracefulShutdown('SIGINT'));

    // Unhandled rejection handler
    process.on('unhandledRejection', (reason, promise) => {
      logger.error('Unhandled Rejection at:', promise, 'reason:', reason);
    });

    process.on('uncaughtException', (error) => {
      logger.error('Uncaught Exception:', error);
      gracefulShutdown('uncaughtException');
    });
  } catch (error) {
    logger.error('❌ Failed to start server:', error);
    process.exit(1);
  }
}

start();

export { app };
