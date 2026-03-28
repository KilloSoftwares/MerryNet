import { logger } from '../utils/logger';
import { config } from '../config';

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
  async send(to: string, message: string): Promise<boolean> {
    // TODO: Implement actual Twilio logic when credentials are provided
    logger.warn('Twilio SMS provider not yet fully implemented');
    return false;
  }
}

export class SmsService {
  private provider: SmsProvider;

  constructor() {
    // In dev/test, use ConsoleSmsProvider. In production, could switch based on config.
    this.provider = new ConsoleSmsProvider();
  }

  async sendOtp(phone: string, otp: string): Promise<boolean> {
    const message = `Your Maranet Zero verification code is: ${otp}. Valid for 5 minutes.`;
    return this.provider.send(phone, message);
  }
}

export const smsService = new SmsService();
