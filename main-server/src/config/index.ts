import dotenv from 'dotenv';
import path from 'path';

dotenv.config({ path: path.resolve(__dirname, '../../.env') });

export const config = {
  env: process.env.NODE_ENV || 'development',
  port: parseInt(process.env.PORT || '3000', 10),
  host: process.env.HOST || '0.0.0.0',

  database: {
    url: process.env.DATABASE_URL || 'postgresql://maranet:maranet_secret@localhost:5432/maranet?schema=public',
  },

  redis: {
    url: process.env.REDIS_URL || 'redis://localhost:6379',
    password: process.env.REDIS_PASSWORD || undefined,
  },

  jwt: {
    secret: process.env.JWT_SECRET || 'dev-secret-change-me',
    expiresIn: process.env.JWT_EXPIRES_IN || '7d',
    refreshExpiresIn: process.env.JWT_REFRESH_EXPIRES_IN || '30d',
    privateKeyPath: path.resolve(__dirname, 'certs/private.pem'),
    publicKeyPath: path.resolve(__dirname, 'certs/public.pem'),
  },

  mpesa: {
    consumerKey: process.env.MPESA_CONSUMER_KEY || '',
    consumerSecret: process.env.MPESA_CONSUMER_SECRET || '',
    businessShortCode: process.env.MPESA_BUSINESS_SHORT_CODE || '174379',
    passKey: process.env.MPESA_PASS_KEY || '',
    callbackUrl: process.env.MPESA_CALLBACK_URL || 'https://api.maranet.app/api/v1/payments/mpesa/callback',
    environment: process.env.MPESA_ENVIRONMENT || 'sandbox',
    baseUrl: process.env.MPESA_BASE_URL || 'https://sandbox.safaricom.co.ke',
  },

  grpc: {
    port: parseInt(process.env.GRPC_PORT || '50051', 10),
    host: process.env.GRPC_HOST || '0.0.0.0',
  },

  gateway: {
    host: process.env.GATEWAY_HOST || 'localhost',
    grpcPort: parseInt(process.env.GATEWAY_GRPC_PORT || '50052', 10),
  },

  metrics: {
    port: parseInt(process.env.METRICS_PORT || '9090', 10),
  },

  logging: {
    level: process.env.LOG_LEVEL || 'debug',
    format: process.env.LOG_FORMAT || 'json',
  },

  security: {
    bcryptRounds: parseInt(process.env.BCRYPT_ROUNDS || '12', 10),
    rateLimitWindowMs: parseInt(process.env.RATE_LIMIT_WINDOW_MS || '900000', 10),
    rateLimitMax: parseInt(process.env.RATE_LIMIT_MAX || '100', 10),
    corsOrigin: process.env.CORS_ORIGIN || '*',
  },

  plans: {
    hourly: { id: 'hourly', price: parseInt(process.env.PLAN_HOURLY_PRICE || '10', 10), durationHours: 1 },
    daily: { id: 'daily', price: parseInt(process.env.PLAN_DAILY_PRICE || '30', 10), durationHours: 24 },
    weekly: { id: 'weekly', price: parseInt(process.env.PLAN_WEEKLY_PRICE || '150', 10), durationHours: 168 },
    monthly: { id: 'monthly', price: parseInt(process.env.PLAN_MONTHLY_PRICE || '500', 10), durationHours: 720 },
  },

  bootstrap: {
    domain: process.env.BOOTSTRAP_DOMAIN || 'free.facebook.com.maranet.app',
  },

  cognitive: {
    llmUrl: process.env.LLM_SERVICE_URL || 'http://localhost:8001',
    hmmUrl: process.env.HMM_SERVICE_URL || 'http://localhost:8003',
    artUrl: process.env.ART_SERVICE_URL || 'http://localhost:8002',
    apiKey: process.env.COGNITIVE_API_KEY || 'twin-dev-key',
  },
} as const;

export type Config = typeof config;
