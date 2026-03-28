import axios from 'axios';
import { config } from '../config';
import { cache } from '../config/redis';
import { prisma } from '../config/database';
import { AppError } from '../utils/errors';
import { getMpesaTimestamp, getMpesaPassword, formatPhone } from '../utils/helpers';
import { logger } from '../utils/logger';

interface MpesaTokenResponse {
  access_token: string;
  expires_in: string;
}

interface StkPushResponse {
  MerchantRequestID: string;
  CheckoutRequestID: string;
  ResponseCode: string;
  ResponseDescription: string;
  CustomerMessage: string;
}

interface StkCallbackItem {
  Name: string;
  Value?: string | number;
}

interface StkCallbackBody {
  stkCallback: {
    MerchantRequestID: string;
    CheckoutRequestID: string;
    ResultCode: number;
    ResultDesc: string;
    CallbackMetadata?: {
      Item: StkCallbackItem[];
    };
  };
}

export class MpesaService {
  private baseUrl: string;

  constructor() {
    this.baseUrl = config.mpesa.baseUrl;
  }

  /**
   * Get M-Pesa OAuth access token (cached)
   */
  async getAccessToken(): Promise<string> {
    const cached = await cache.get<string>('mpesa:access_token');
    if (cached) return cached;

    try {
      const auth = Buffer.from(
        `${config.mpesa.consumerKey}:${config.mpesa.consumerSecret}`
      ).toString('base64');

      const response = await axios.get<MpesaTokenResponse>(
        `${this.baseUrl}/oauth/v1/generate?grant_type=client_credentials`,
        {
          headers: { Authorization: `Basic ${auth}` },
        }
      );

      const token = response.data.access_token;
      const expiresIn = parseInt(response.data.expires_in) - 60; // Refresh 1 min early

      await cache.set('mpesa:access_token', token, expiresIn);
      return token;
    } catch (error) {
      logger.error('Failed to get M-Pesa access token:', error);
      throw AppError.serviceUnavailable('M-Pesa service temporarily unavailable');
    }
  }

  /**
   * Initiate M-Pesa STK Push
   */
  async initiateSTKPush(params: {
    userId: string;
    phone: string;
    amount: number;
    planId: string;
    accountReference?: string;
  }): Promise<{ checkoutRequestId: string; merchantRequestId: string }> {
    const { userId, phone, amount, planId, accountReference } = params;
    const formattedPhone = formatPhone(phone);
    const timestamp = getMpesaTimestamp();
    const password = getMpesaPassword(
      config.mpesa.businessShortCode,
      config.mpesa.passKey,
      timestamp
    );

    // Create pending transaction first
    const transaction = await prisma.transaction.create({
      data: {
        userId,
        amount,
        planId,
        phone: formattedPhone,
        currency: 'KES',
        status: 'PENDING',
      },
    });

    try {
      const accessToken = await this.getAccessToken();

      const payload = {
        BusinessShortCode: config.mpesa.businessShortCode,
        Password: password,
        Timestamp: timestamp,
        TransactionType: 'CustomerPayBillOnline',
        Amount: Math.ceil(amount),
        PartyA: formattedPhone,
        PartyB: config.mpesa.businessShortCode,
        PhoneNumber: formattedPhone,
        CallBackURL: config.mpesa.callbackUrl,
        AccountReference: accountReference || `MARANET-${planId.toUpperCase()}`,
        TransactionDesc: `Maranet ${planId} bundle`,
      };

      const response = await axios.post<StkPushResponse>(
        `${this.baseUrl}/mpesa/stkpush/v1/processrequest`,
        payload,
        {
          headers: {
            Authorization: `Bearer ${accessToken}`,
            'Content-Type': 'application/json',
          },
        }
      );

      if (response.data.ResponseCode !== '0') {
        throw new Error(response.data.ResponseDescription);
      }

      // Update transaction with M-Pesa IDs
      await prisma.transaction.update({
        where: { id: transaction.id },
        data: {
          merchantRequestId: response.data.MerchantRequestID,
          checkoutRequestId: response.data.CheckoutRequestID,
        },
      });

      // Cache the transaction mapping
      await cache.set(
        `mpesa:checkout:${response.data.CheckoutRequestID}`,
        {
          transactionId: transaction.id,
          userId,
          planId,
        },
        600 // 10 minutes TTL
      );

      logger.info(`💰 STK Push initiated: ${response.data.CheckoutRequestID} for ${formattedPhone}`);

      return {
        checkoutRequestId: response.data.CheckoutRequestID,
        merchantRequestId: response.data.MerchantRequestID,
      };
    } catch (error) {
      // Mark transaction as failed
      await prisma.transaction.update({
        where: { id: transaction.id },
        data: { status: 'FAILED', resultDesc: 'STK Push initiation failed' },
      });

      if (axios.isAxiosError(error)) {
        logger.error('M-Pesa STK Push failed:', error.response?.data);
        throw AppError.serviceUnavailable('Payment initiation failed. Please try again.');
      }
      throw error;
    }
  }

  /**
   * Process M-Pesa callback
   */
  async processCallback(callbackData: StkCallbackBody): Promise<void> {
    const { stkCallback } = callbackData;
    const {
      CheckoutRequestID,
      ResultCode,
      ResultDesc,
      CallbackMetadata,
    } = stkCallback;

    logger.info(`📞 M-Pesa callback: ${CheckoutRequestID}, ResultCode: ${ResultCode}`);

    // Find the transaction
    const transaction = await prisma.transaction.findUnique({
      where: { checkoutRequestId: CheckoutRequestID },
    });

    if (!transaction) {
      logger.error(`Transaction not found for checkout: ${CheckoutRequestID}`);
      return;
    }

    if (transaction.status !== 'PENDING') {
      logger.warn(`Transaction ${transaction.id} already processed (${transaction.status})`);
      return;
    }

    if (ResultCode === 0) {
      // SUCCESS
      let mpesaCode: string | undefined;
      let transactionDate: Date | undefined;

      if (CallbackMetadata?.Item) {
        for (const item of CallbackMetadata.Item) {
          if (item.Name === 'MpesaReceiptNumber' && item.Value) {
            mpesaCode = String(item.Value);
          }
          if (item.Name === 'TransactionDate' && item.Value) {
            const dateStr = String(item.Value);
            transactionDate = new Date(
              `${dateStr.slice(0, 4)}-${dateStr.slice(4, 6)}-${dateStr.slice(6, 8)}T${dateStr.slice(8, 10)}:${dateStr.slice(10, 12)}:${dateStr.slice(12, 14)}`
            );
          }
        }
      }

      await prisma.transaction.update({
        where: { id: transaction.id },
        data: {
          status: 'COMPLETED',
          resultCode: ResultCode,
          resultDesc: ResultDesc,
          mpesaCode,
          transactionDate,
        },
      });

      // Trigger subscription provisioning via Redis pub/sub
      const { getRedis } = await import('../config/redis');
      await getRedis().publish('payment:completed', JSON.stringify({
        transactionId: transaction.id,
        userId: transaction.userId,
        planId: transaction.planId,
        amount: transaction.amount,
      }));

      logger.info(`✅ Payment completed: ${mpesaCode} for user ${transaction.userId}`);
    } else {
      // FAILED
      await prisma.transaction.update({
        where: { id: transaction.id },
        data: {
          status: 'FAILED',
          resultCode: ResultCode,
          resultDesc: ResultDesc,
        },
      });

      logger.warn(`❌ Payment failed: ${ResultDesc} (code: ${ResultCode})`);
    }

    // Clean up cache
    await cache.del(`mpesa:checkout:${CheckoutRequestID}`);
  }

  /**
   * Query STK Push status
   */
  async querySTKStatus(checkoutRequestId: string): Promise<{
    status: string;
    resultDesc: string;
  }> {
    const transaction = await prisma.transaction.findUnique({
      where: { checkoutRequestId },
    });

    if (!transaction) {
      throw AppError.notFound('Transaction');
    }

    return {
      status: transaction.status,
      resultDesc: transaction.resultDesc || 'Pending',
    };
  }
}

export const mpesaService = new MpesaService();
