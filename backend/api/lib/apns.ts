import { redis } from './redis';

/**
 * APNs (Apple Push Notification service) Integration
 *
 * This module handles sending push notifications to iOS devices.
 *
 * Setup Required:
 * 1. Create APNs Key in Apple Developer Portal
 * 2. Add environment variables to Vercel:
 *    - APNS_KEY_ID: Your APNs Key ID
 *    - APNS_TEAM_ID: Your Apple Team ID
 *    - APNS_KEY: Your APNs private key (p8 file contents)
 *    - APNS_ENVIRONMENT: 'production' or 'development'
 */

interface APNsConfig {
  keyId: string;
  teamId: string;
  key: string;
  environment: 'production' | 'development';
}

interface APNsPayload {
  title: string;
  body: string;
  data?: Record<string, string>;
}

export class APNsService {
  private config: APNsConfig | null = null;

  constructor() {
    // Check if APNs is configured
    const keyId = process.env.APNS_KEY_ID;
    const teamId = process.env.APNS_TEAM_ID;
    const key = process.env.APNS_KEY;
    const environment = process.env.APNS_ENVIRONMENT as 'production' | 'development' || 'development';

    if (keyId && teamId && key) {
      this.config = { keyId, teamId, key, environment };
      console.log(`✅ APNs configured for ${environment} environment`);
    } else {
      console.log('⚠️  APNs not configured - notifications will be logged only');
    }
  }

  isConfigured(): boolean {
    return this.config !== null;
  }

  async sendNotification(deviceToken: string, payload: APNsPayload): Promise<boolean> {
    if (!this.config) {
      // APNs not configured - just log the notification
      console.log('📱 [Mock Notification]', {
        deviceToken: deviceToken.substring(0, 8) + '...',
        title: payload.title,
        body: payload.body,
        data: payload.data,
      });
      return true;
    }

    try {
      // Generate JWT token for APNs authentication
      const jwt = await this.generateJWT();

      // APNs endpoint
      const apnsUrl = this.config.environment === 'production'
        ? `https://api.push.apple.com/3/device/${deviceToken}`
        : `https://api.sandbox.push.apple.com/3/device/${deviceToken}`;

      // APNs notification payload
      const notification = {
        aps: {
          alert: {
            title: payload.title,
            body: payload.body,
          },
          sound: 'default',
          badge: 1,
        },
        ...payload.data,
      };

      // Send notification
      const response = await fetch(apnsUrl, {
        method: 'POST',
        headers: {
          'authorization': `bearer ${jwt}`,
          'apns-topic': 'com.yourapp.cloudview', // Replace with your bundle ID
          'apns-push-type': 'alert',
          'apns-priority': '10',
        },
        body: JSON.stringify(notification),
      });

      if (response.status === 200) {
        console.log(`✅ Push notification sent to ${deviceToken.substring(0, 8)}...`);
        return true;
      } else {
        const errorBody = await response.text();
        console.error(`❌ APNs error (${response.status}):`, errorBody);
        return false;
      }

    } catch (error) {
      console.error('❌ Error sending push notification:', error);
      return false;
    }
  }

  async sendToRegion(region: string, payload: APNsPayload): Promise<number> {
    // Get all devices for this region
    const regionKey = `region-devices:${region.toLowerCase().replace(/\s+/g, '-')}`;
    const deviceTokens = await redis.smembers(regionKey);

    if (!deviceTokens || deviceTokens.length === 0) {
      console.log(`ℹ️  No devices registered for region: ${region}`);
      return 0;
    }

    console.log(`📤 Sending notification to ${deviceTokens.length} devices in ${region}`);

    // Send to all devices
    let successCount = 0;
    for (const token of deviceTokens) {
      const success = await this.sendNotification(token, payload);
      if (success) successCount++;
    }

    return successCount;
  }

  private async generateJWT(): Promise<string> {
    if (!this.config) {
      throw new Error('APNs not configured');
    }

    // JWT header
    const header = {
      alg: 'ES256',
      kid: this.config.keyId,
    };

    // JWT claims
    const now = Math.floor(Date.now() / 1000);
    const claims = {
      iss: this.config.teamId,
      iat: now,
    };

    // In production, you would use a proper JWT library to sign with ES256
    // For now, this is a placeholder that will work with the mock logging
    const encodedHeader = btoa(JSON.stringify(header));
    const encodedClaims = btoa(JSON.stringify(claims));

    // Note: In real implementation, you need to sign this with your APNs private key using ES256
    // This requires a crypto library that supports ECDSA signing
    // For Vercel Edge Functions, you would use the Web Crypto API or a compatible library

    return `${encodedHeader}.${encodedClaims}.SIGNATURE_PLACEHOLDER`;
  }
}

// Singleton instance
export const apnsService = new APNsService();
