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

// APNs topic (bundle ID) — set APNS_TOPIC env var, fall back to the published one.
const APNS_TOPIC = process.env.APNS_TOPIC || 'com.cloudoodle.app';

// JWT cache: APNs allows the same token for up to 60 minutes; refresh proactively.
let cachedJwt: { token: string; expiresAt: number; signingKey: CryptoKey } | null = null;

export class APNsService {
  private config: APNsConfig | null = null;
  private signingKey: CryptoKey | null = null;
  private signingKeyPromise: Promise<CryptoKey> | null = null;

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
          'apns-topic': APNS_TOPIC,
          'apns-push-type': 'alert',
          'apns-priority': '10',
        },
        body: JSON.stringify(notification),
      });

      if (response.status === 200) {
        console.log(`✅ Push notification sent to ${deviceToken.substring(0, 8)}...`);
        return true;
      }

      const errorBody = await response.text();
      console.error(`❌ APNs error (${response.status}):`, errorBody);

      // 410 Gone or BadDeviceToken means the token is permanently invalid; prune it.
      if (response.status === 410 || errorBody.includes('BadDeviceToken') || errorBody.includes('Unregistered')) {
        await this.pruneToken(deviceToken);
      }
      return false;

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

    // Send in parallel batches so a single edge invocation can handle hundreds of devices
    // without exhausting its timeout. Cap concurrency to stay polite to APNs.
    const CONCURRENCY = 20;
    let successCount = 0;

    for (let i = 0; i < deviceTokens.length; i += CONCURRENCY) {
      const batch = deviceTokens.slice(i, i + CONCURRENCY);
      const results = await Promise.all(
        batch.map(token => this.sendNotification(token, payload))
      );
      successCount += results.filter(Boolean).length;
    }

    return successCount;
  }

  private async pruneToken(token: string): Promise<void> {
    try {
      const device = await redis.get<{ region?: string }>(`device:${token}`);
      await redis.del(`device:${token}`);
      if (device?.region && device.region !== 'Unknown') {
        const regionKey = `region-devices:${device.region.toLowerCase().replace(/\s+/g, '-')}`;
        await redis.srem(regionKey, token);
      }
    } catch (err) {
      console.error('Failed to prune invalid device token:', err);
    }
  }

  // MARK: - JWT (ES256) using Web Crypto, supported by Vercel Edge runtime.

  private async getSigningKey(): Promise<CryptoKey> {
    if (this.signingKey) return this.signingKey;
    if (this.signingKeyPromise) return this.signingKeyPromise;

    this.signingKeyPromise = (async () => {
      if (!this.config) throw new Error('APNs not configured');
      const pkcs8 = pemToPkcs8(this.config.key);
      const key = await crypto.subtle.importKey(
        'pkcs8',
        pkcs8,
        { name: 'ECDSA', namedCurve: 'P-256' },
        false,
        ['sign']
      );
      this.signingKey = key;
      return key;
    })();
    return this.signingKeyPromise;
  }

  private async generateJWT(): Promise<string> {
    if (!this.config) throw new Error('APNs not configured');

    // APNs accepts tokens for up to 60 minutes; refresh 5 minutes early.
    const now = Math.floor(Date.now() / 1000);
    if (cachedJwt && cachedJwt.expiresAt > now + 60) {
      return cachedJwt.token;
    }

    const header = { alg: 'ES256', kid: this.config.keyId, typ: 'JWT' };
    const claims = { iss: this.config.teamId, iat: now };
    const signingInput =
      base64UrlEncode(new TextEncoder().encode(JSON.stringify(header))) +
      '.' +
      base64UrlEncode(new TextEncoder().encode(JSON.stringify(claims)));

    const signingKey = await this.getSigningKey();
    const signature = await crypto.subtle.sign(
      { name: 'ECDSA', hash: 'SHA-256' },
      signingKey,
      new TextEncoder().encode(signingInput)
    );

    const token = `${signingInput}.${base64UrlEncode(new Uint8Array(signature))}`;
    cachedJwt = { token, expiresAt: now + 50 * 60, signingKey };
    return token;
  }
}

// --- PEM / base64url helpers --------------------------------------------------

function base64UrlEncode(bytes: Uint8Array): string {
  let bin = '';
  for (let i = 0; i < bytes.length; i++) bin += String.fromCharCode(bytes[i]);
  return btoa(bin).replace(/=+$/, '').replace(/\+/g, '-').replace(/\//g, '_');
}

function pemToPkcs8(pem: string): ArrayBuffer {
  // Accept either a raw base64 blob or a full PEM with headers / \n / literal "\n"
  const normalized = pem
    .replace(/-----BEGIN [^-]+-----/g, '')
    .replace(/-----END [^-]+-----/g, '')
    .replace(/\\n/g, '')
    .replace(/\s+/g, '');
  const bin = atob(normalized);
  const out = new Uint8Array(bin.length);
  for (let i = 0; i < bin.length; i++) out[i] = bin.charCodeAt(i);
  return out.buffer;
}

// Singleton instance
export const apnsService = new APNsService();
