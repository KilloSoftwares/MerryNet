import crypto from 'crypto';

/**
 * Generate a random OTP code of given length
 */
export function generateOtp(length: number = 6): string {
  const digits = '0123456789';
  let otp = '';
  const bytes = crypto.randomBytes(length);
  for (let i = 0; i < length; i++) {
    otp += digits[bytes[i] % 10];
  }
  return otp;
}

/**
 * Generate a random referral code
 */
export function generateReferralCode(length: number = 8): string {
  const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789'; // no I, O, 0, 1 for clarity
  let code = '';
  const bytes = crypto.randomBytes(length);
  for (let i = 0; i < length; i++) {
    code += chars[bytes[i] % chars.length];
  }
  return code;
}

/**
 * Format phone number to 254XXXXXXXXX format
 */
export function formatPhone(phone: string): string {
  let cleaned = phone.replace(/\D/g, '');
  if (cleaned.startsWith('0')) {
    cleaned = '254' + cleaned.slice(1);
  } else if (cleaned.startsWith('+254')) {
    cleaned = cleaned.slice(1);
  } else if (!cleaned.startsWith('254')) {
    cleaned = '254' + cleaned;
  }
  return cleaned;
}

/**
 * Calculate subscription end time based on plan duration
 */
export function calculateEndTime(durationHours: number, startTime?: Date): Date {
  const start = startTime || new Date();
  return new Date(start.getTime() + durationHours * 60 * 60 * 1000);
}

/**
 * Check if a subscription is expired
 */
export function isExpired(endTime: Date): boolean {
  return new Date() > endTime;
}

/**
 * Format bytes to human readable
 */
export function formatBytes(bytes: number): string {
  if (bytes === 0) return '0 B';
  const k = 1024;
  const sizes = ['B', 'KB', 'MB', 'GB', 'TB'];
  const i = Math.floor(Math.log(bytes) / Math.log(k));
  return `${parseFloat((bytes / Math.pow(k, i)).toFixed(2))} ${sizes[i]}`;
}

/**
 * Sleep for specified milliseconds (useful for retries)
 */
export function sleep(ms: number): Promise<void> {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

/**
 * Generate WireGuard keypair (placeholder — actual key generation done by WG tools)
 */
export function generateWireGuardKeys(): { privateKey: string; publicKey: string } {
  // In production, use actual wg genkey/pubkey commands
  // This is a placeholder using crypto for development
  const privateKey = crypto.randomBytes(32).toString('base64');
  const publicKey = crypto.randomBytes(32).toString('base64');
  return { privateKey, publicKey };
}

/**
 * Generate M-Pesa timestamp in YYYYMMDDHHmmss format
 */
export function getMpesaTimestamp(): string {
  const now = new Date();
  const year = now.getFullYear();
  const month = String(now.getMonth() + 1).padStart(2, '0');
  const day = String(now.getDate()).padStart(2, '0');
  const hours = String(now.getHours()).padStart(2, '0');
  const minutes = String(now.getMinutes()).padStart(2, '0');
  const seconds = String(now.getSeconds()).padStart(2, '0');
  return `${year}${month}${day}${hours}${minutes}${seconds}`;
}

/**
 * Generate M-Pesa password (Base64 of ShortCode + PassKey + Timestamp)
 */
export function getMpesaPassword(shortCode: string, passKey: string, timestamp: string): string {
  return Buffer.from(`${shortCode}${passKey}${timestamp}`).toString('base64');
}

/**
 * Allocate a peer IP from subnet (simple incrementing allocator)
 */
export function allocatePeerIp(subnet: string, peerIndex: number): string {
  // subnet format: 10.0.X.0/24
  const parts = subnet.split('/')[0].split('.');
  parts[3] = String(peerIndex + 2); // .1 reserved for gateway, start from .2
  return parts.join('.');
}
