import { logger } from '../utils/logger';
import { config } from '../config';

import twilio from 'twilio';

// ... (keep interface and ConsoleSmsProvider)
export interface SmsProvider {
  send(to: string, message: string): Promise<boolean>;
}

class ConsoleSmsProvider implements SmsProvider {
  async send(to: string, message: string): Promise<boolean> {
    logger.info(`[SMS MOCK] To: ${to}, Message: ${message}`);
    return true;
  }
}

class TwilioSmsProvider implements SmsProvider {
  private client: twilio.Twilio;
  private fromNumber: string;

  constructor() {
    this.client = twilio(
      process.env.TWILIO_ACCOUNT_SID || '',
      process.env.TWILIO_AUTH_TOKEN || ''
    );
    this.fromNumber = process.env.TWILIO_PHONE_NUMBER || '';
  }

  async send(to: string, message: string): Promise<boolean> {
    try {
      if (!process.env.TWILIO_ACCOUNT_SID || !process.env.TWILIO_AUTH_TOKEN) {
         logger.warn('Twilio credentials completely missing, skipping send');
         return false;
      }
      const response = await this.client.messages.create({
        body: message,
        from: this.fromNumber,
        to: to.startsWith('+') ? to : `+${to}`
      });
      logger.info(`[Twilio SMS] Sent to ${to}. Message SID: ${response.sid}`);
      return true;
    } catch (error: any) {
      logger.error(`[Twilio SMS] Failed to send SMS to ${to}: ${error.message}`);
      return false;
    }
  }
}

export class SmsService {
  private provider: SmsProvider;

  constructor() {
    if (config.env === 'production' && process.env.TWILIO_ACCOUNT_SID) {
      this.provider = new TwilioSmsProvider();
    } else {
      this.provider = new ConsoleSmsProvider();
    }
  }

  async sendOtp(phone: string, otp: string): Promise<boolean> {
    const message = `Your Maranet Zero verification code is: ${otp}. Valid for 5 minutes.`;
    return this.provider.send(phone, message);
  }
}

export const smsService = new SmsService();
