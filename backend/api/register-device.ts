import { redis } from './lib/redis';

export const config = {
  runtime: 'edge',
};

interface DeviceRegistration {
  deviceToken: string;
  region: string;
  notificationsEnabled: boolean;
}

const MAX_BODY_BYTES = 1024;
const MAX_REGION_LENGTH = 80;
// APNs tokens are 64-char lowercase hex; reject anything else early.
const APNS_TOKEN_RE = /^[0-9a-fA-F]{64}$/;
// Devices that don't check in for 90 days get GC'd by Redis. Keeps stale tokens
// out of the per-region fan-out so we don't burn APNs quota on dead installs.
const DEVICE_TTL_SECONDS = 60 * 60 * 24 * 90;
const PER_IP_LIMIT_PER_MINUTE = 30;

async function rateLimit(key: string, limit: number): Promise<boolean> {
  const count = await redis.incr(key);
  if (count === 1) await redis.expire(key, 60);
  return count <= limit;
}

function badRequest(message: string) {
  return Response.json({ error: message }, { status: 400 });
}

export default async function handler(req: Request) {
  if (req.method === 'OPTIONS') {
    return new Response(null, { status: 204 });
  }

  if (req.method !== 'POST') {
    return Response.json({ error: 'Method not allowed' }, { status: 405 });
  }

  try {
    const contentLength = Number(req.headers.get('content-length') ?? '0');
    if (contentLength > MAX_BODY_BYTES) {
      return Response.json({ error: 'Payload too large' }, { status: 413 });
    }

    const ip =
      req.headers.get('x-forwarded-for')?.split(',')[0]?.trim() ||
      req.headers.get('x-real-ip') ||
      'unknown';
    if (!(await rateLimit(`rl:ip:register:${ip}`, PER_IP_LIMIT_PER_MINUTE))) {
      return Response.json({ error: 'Rate limit exceeded' }, { status: 429 });
    }

    let body: unknown;
    try {
      body = await req.json();
    } catch {
      return badRequest('Invalid JSON');
    }
    if (!body || typeof body !== 'object') return badRequest('Invalid body');

    const registration = body as Partial<DeviceRegistration>;
    if (!registration.deviceToken || typeof registration.deviceToken !== 'string') {
      return badRequest('Missing or invalid field: deviceToken');
    }
    if (!APNS_TOKEN_RE.test(registration.deviceToken)) {
      return badRequest('deviceToken must be 64 hex characters');
    }
    if (registration.region != null && (typeof registration.region !== 'string' || registration.region.length > MAX_REGION_LENGTH)) {
      return badRequest('Invalid region');
    }

    // Look up any prior registration so we can move the token between regions.
    const deviceKey = `device:${registration.deviceToken}`;
    const previous = await redis.get<{ region?: string }>(deviceKey);

    const region = registration.region?.trim() || 'Unknown';
    const deviceData = {
      token: registration.deviceToken,
      region,
      notificationsEnabled: registration.notificationsEnabled !== false,
      lastUpdated: new Date().toISOString(),
    };

    await redis.set(deviceKey, deviceData, { ex: DEVICE_TTL_SECONDS });

    if (previous?.region && previous.region !== region && previous.region !== 'Unknown') {
      const oldKey = `region-devices:${previous.region.toLowerCase().replace(/\s+/g, '-')}`;
      await redis.srem(oldKey, registration.deviceToken);
    }

    if (region && region !== 'Unknown') {
      const regionKey = `region-devices:${region.toLowerCase().replace(/\s+/g, '-')}`;
      await redis.sadd(regionKey, registration.deviceToken);
    }

    console.log(`✅ Device registered: ${registration.deviceToken.substring(0, 8)}... in region: ${region}`);

    return Response.json({ success: true, message: 'Device registered successfully' });

  } catch (error) {
    console.error('Error registering device:', error);
    return Response.json({ error: 'Internal server error' }, { status: 500 });
  }
}
