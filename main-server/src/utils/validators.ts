import { z } from 'zod';

// Phone number validation (Kenyan format: 254XXXXXXXXX)
export const phoneSchema = z
  .string()
  .regex(/^254\d{9}$/, 'Phone number must be in format 254XXXXXXXXX');

// Auth schemas
export const loginSchema = z.object({
  phone: phoneSchema,
});

export const verifyOtpSchema = z.object({
  phone: phoneSchema,
  code: z.string().length(6, 'OTP code must be 6 digits'),
});

export const refreshTokenSchema = z.object({
  refreshToken: z.string().min(1, 'Refresh token is required'),
});

// Payment schemas
export const initiatePaymentSchema = z.object({
  planId: z.enum(['hourly', 'daily', 'weekly', 'monthly']),
  phone: phoneSchema.optional(), // uses authenticated user's phone if not provided
  autoRenew: z.boolean().optional().default(false),
});

// Subscription schemas
export const createSubscriptionSchema = z.object({
  planId: z.enum(['hourly', 'daily', 'weekly', 'monthly']),
  autoRenew: z.boolean().optional().default(false),
});

// Reseller schemas
export const registerResellerSchema = z.object({
  deviceId: z.string().min(1).max(100),
  publicKey: z.string().optional(),
  endpoint: z.string().optional(),
  location: z.string().optional(),
  capacity: z.number().int().min(1).max(1000).optional().default(100),
  compensationType: z.enum(['COMMISSION', 'FREE_NET']).optional().default('COMMISSION'),
  platform: z.enum(['rpi', 'vps', 'android', 'docker']).optional(),
});

export const updateResellerSchema = z.object({
  endpoint: z.string().optional(),
  location: z.string().optional(),
  capacity: z.number().int().min(1).max(1000).optional(),
  compensationType: z.enum(['COMMISSION', 'FREE_NET']).optional(),
});

// Query params
export const paginationSchema = z.object({
  page: z.coerce.number().int().min(1).optional().default(1),
  limit: z.coerce.number().int().min(1).max(100).optional().default(20),
  sortBy: z.string().optional().default('createdAt'),
  sortOrder: z.enum(['asc', 'desc']).optional().default('desc'),
});

export const dateRangeSchema = z.object({
  from: z.coerce.date().optional(),
  to: z.coerce.date().optional(),
});
