import { prisma } from '../config/database';
import { cache } from '../config/redis';
import { generateTokens } from '../middleware/auth';
import { AppError } from '../utils/errors';
import { generateOtp, generateReferralCode, formatPhone } from '../utils/helpers';
import { logger } from '../utils/logger';
import { smsService } from './sms.service';

const OTP_EXPIRY_MINUTES = 5;
const OTP_MAX_ATTEMPTS = 3;

export class AuthService {
  /**
   * Request login — sends OTP to phone number
   */
  async requestLogin(phone: string): Promise<{ message: string; otpId: string }> {
    const formattedPhone = formatPhone(phone);

    // Rate limit: max 3 OTP requests per phone per 10 minutes
    const rateLimitKey = `otp:ratelimit:${formattedPhone}`;
    const otpCount = await cache.incr(rateLimitKey);
    if (otpCount === 1) {
      await cache.expire(rateLimitKey, 600); // 10 minutes
    }
    if (otpCount > 3) {
      throw AppError.tooManyRequests('Too many OTP requests. Try again in 10 minutes.');
    }

    // Generate OTP
    const code = generateOtp(6);
    const expiresAt = new Date(Date.now() + OTP_EXPIRY_MINUTES * 60 * 1000);

    // Store OTP
    const otp = await prisma.otpCode.create({
      data: {
        phone: formattedPhone,
        code,
        purpose: 'login',
        expiresAt,
      },
    });

    // Cache OTP for quick verification
    await cache.set(`otp:${formattedPhone}:${code}`, otp.id, OTP_EXPIRY_MINUTES * 60);

    // Send OTP via SMS
    try {
      await smsService.sendOtp(phone, code);
    } catch (err: any) {
      logger.error('SMS delivery service failed:', err.message);
    }

    // For development, log the OTP
    logger.info(`📱 OTP for ${formattedPhone}: ${code}`);

    return {
      message: 'OTP sent successfully',
      otpId: otp.id,
    };
  }

  /**
   * Verify OTP and return tokens
   */
  async verifyOtp(phone: string, code: string): Promise<{
    accessToken: string;
    refreshToken: string;
    user: { id: string; phone: string; isNewUser: boolean };
  }> {
    const formattedPhone = formatPhone(phone);

    // Find valid OTP
    const otp = await prisma.otpCode.findFirst({
      where: {
        phone: formattedPhone,
        code,
        purpose: 'login',
        verified: false,
        expiresAt: { gt: new Date() },
        attempts: { lt: OTP_MAX_ATTEMPTS },
      },
      orderBy: { createdAt: 'desc' },
    });

    if (!otp) {
      // Increment attempts on the latest OTP for this phone
      const latestOtp = await prisma.otpCode.findFirst({
        where: { phone: formattedPhone, purpose: 'login', verified: false },
        orderBy: { createdAt: 'desc' },
      });
      if (latestOtp) {
        await prisma.otpCode.update({
          where: { id: latestOtp.id },
          data: { attempts: { increment: 1 } },
        });
      }
      throw AppError.unauthorized('Invalid or expired OTP');
    }

    // Mark OTP as verified
    await prisma.otpCode.update({
      where: { id: otp.id },
      data: { verified: true },
    });

    // Find or create user
    let isNewUser = false;
    let user = await prisma.user.findUnique({
      where: { phone: formattedPhone },
      include: { reseller: true },
    });

    if (!user) {
      isNewUser = true;
      user = await prisma.user.create({
        data: {
          phone: formattedPhone,
          referralCode: generateReferralCode(),
          lastLoginAt: new Date(),
        },
        include: { reseller: true },
      });
      logger.info(`🆕 New user created: ${formattedPhone}`);
    } else {
      await prisma.user.update({
        where: { id: user.id },
        data: { lastLoginAt: new Date() },
      });
    }

    // Generate tokens
    const isReseller = !!user.reseller;
    const tokens = generateTokens({ id: user.id, phone: user.phone, isReseller });

    // Store refresh token
    const refreshExpiresAt = new Date(Date.now() + 30 * 24 * 60 * 60 * 1000); // 30 days
    await prisma.refreshToken.create({
      data: {
        userId: user.id,
        token: tokens.refreshToken,
        expiresAt: refreshExpiresAt,
      },
    });

    // Clear OTP cache
    await cache.del(`otp:${formattedPhone}:${code}`);

    return {
      ...tokens,
      user: {
        id: user.id,
        phone: user.phone,
        isNewUser,
      },
    };
  }

  /**
   * Refresh access token
   */
  async refreshAccessToken(refreshToken: string): Promise<{
    accessToken: string;
    refreshToken: string;
  }> {
    // Find the refresh token
    const storedToken = await prisma.refreshToken.findUnique({
      where: { token: refreshToken },
      include: { user: { include: { reseller: true } } },
    });

    if (!storedToken || storedToken.expiresAt < new Date()) {
      if (storedToken) {
        await prisma.refreshToken.delete({ where: { id: storedToken.id } });
      }
      throw AppError.unauthorized('Invalid or expired refresh token');
    }

    const user = storedToken.user;
    const isReseller = !!user.reseller;

    // Generate new tokens
    const tokens = generateTokens({ id: user.id, phone: user.phone, isReseller });

    // Replace old refresh token
    await prisma.refreshToken.delete({ where: { id: storedToken.id } });
    const refreshExpiresAt = new Date(Date.now() + 30 * 24 * 60 * 60 * 1000);
    await prisma.refreshToken.create({
      data: {
        userId: user.id,
        token: tokens.refreshToken,
        expiresAt: refreshExpiresAt,
      },
    });

    return tokens;
  }

  /**
   * Logout — revoke refresh token
   */
  async logout(refreshToken: string): Promise<void> {
    await prisma.refreshToken.deleteMany({
      where: { token: refreshToken },
    });
  }

  /**
   * Get user profile
   */
  async getProfile(userId: string) {
    const user = await prisma.user.findUnique({
      where: { id: userId },
      include: {
        reseller: true,
        activeSubscription: {
          include: { plan: true },
        },
      },
    });

    if (!user) {
      throw AppError.notFound('User');
    }

    return {
      id: user.id,
      phone: user.phone,
      referralCode: user.referralCode,
      autoRenew: user.autoRenew,
      isReseller: !!user.reseller,
      createdAt: user.createdAt,
      activeSubscription: user.activeSubscription
        ? {
            id: user.activeSubscription.id,
            plan: user.activeSubscription.plan,
            startTime: user.activeSubscription.startTime,
            endTime: user.activeSubscription.endTime,
            status: user.activeSubscription.status,
          }
        : null,
    };
  }
}

export const authService = new AuthService();
