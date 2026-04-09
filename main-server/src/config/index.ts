import dotenv from 'dotenv';
import path from 'path';

dotenv.config({ path: path.resolve(__dirname, '../../.env') });

// ============================================================
// Configuration Validation
// ============================================================

function validateConfig() {
  const errors: string[] = [];

  // Required secrets validation
  if (!process.env.JWT_SECRET || process.env.JWT_SECRET === 'dev-secret-change-me') {
    errors.push('JWT_SECRET must be set to a strong random value (not the default)');
  }

  if (!process.env.DATABASE_URL || process.env.DATABASE_URL.includes('maranet_secret')) {
    errors.push('DATABASE_URL must be set with a strong password (not the default)');
  }

  if (process.env.NODE_ENV === 'production' && !process.env.REDIS_PASSWORD) {
    errors.push('REDIS_PASSWORD is required in production');
  }

  // M-Pesa validation for production
  if (process.env.NODE_ENV === 'production') {
    if (!process.env.MPESA_CONSUMER_KEY) {
      errors.push('MPESA_CONSUMER_KEY is required in production');
    }
    if (!process.env.MPESA_CONSUMER_SECRET) {
      errors.push('MPESA_CONSUMER_SECRET is required in production');
    }
    if (!process.env.MPESA_PASS_KEY) {
      errors.push('MPESA_PASS_KEY is required in production');
    }
    if (process.env.MPESA_ENVIRONMENT === 'sandbox') {
      errors.push('MPESA_ENVIRONMENT must be "production" in production (not sandbox)');
    }
  }

  // Cognitive API key validation
  if (process.env.COGNITIVE_API_KEY === 'twin-dev-key') {
    errors.push('COGNITIVE_API_KEY must be changed from default value');
  }

  if (errors.length > 0) {
    console.error('❌ Configuration validation failed:');
    errors.forEach((err) => console.error(`  - ${err}`));
    console.error('\nPlease update your .env file with proper values.');
    console.error('See ENV_SETUP_GUIDE.md for instructions.');
    process.exit(1);
  }
}

// Run validation on startup
validateConfig();

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
    secret: process.env.JWT_SECRET!,
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
    useTLS: getEnvBool('GRPC_USE_TLS', false),
    certFile: process.env.GRPC_TLS_CERT_FILE || '',
    keyFile: process.env.GRPC_TLS_KEY_FILE || '',
  },

  gateway: {
    host: process.env.GATEWAY_HOST || 'localhost',
    grpcPort: parseInt(process.env.GATEWAY_GRPC_PORT || '50052', 10),
    useTLS: getEnvBool('GATEWAY_USE_TLS', false),
    caFile: process.env.GATEWAY_TLS_CA_FILE || '',
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
    apiKey: process.env.COGNITIVE_API_KEY!,
  },
} as const;

function getEnvBool(key: string, fallback: boolean): boolean {
  const value = process.env[key];
  if (value === undefined || value === '') {
    return fallback;
  }
  return ['true', '1', 'yes', 'on'].includes(value.toLowerCase());
}

export type Config = typeof config;
