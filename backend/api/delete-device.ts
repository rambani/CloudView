import { redis } from './lib/redis';

export const config = {
  runtime: 'edge',
};

const MAX_BODY_BYTES = 256;
const APNS_TOKEN_RE = /^[0-9a-fA-F]{64}$/;
const PER_IP_LIMIT_PER_MINUTE = 30;

async function rateLimit(key: string, limit: number): Promise<boolean> {
  const count = await redis.incr(key);
  if (count === 1) await redis.expire(key, 60);
  return count <= limit;
}

function badRequest(message: string) {
  return Response.json({ error: message }, { status: 400 });
}

/**
 * Erase all data tied to a device token. Implements the deletion-on-request
 * commitment in docs/PRIVACY.md and covers GDPR Article 17 / CCPA §1798.105
 * obligations. Idempotent: deleting a token that doesn't exist returns
 * success so a client can fire-and-forget without retry confusion.
 *
 * Note: we deliberately do not require auth here. The device token itself is
 * the credential — only someone with access to the token can request its
 * deletion, and a deletion never reveals new information about the token.
 * If you wanted stricter semantics you could require the request be signed
 * by the same APNs auth (round-trip), but that's overkill for an erase.
 */
export default async function handler(req: Request) {
  if (req.method === 'OPTIONS') {
    return new Response(null, { status: 204 });
  }
  if (req.method !== 'POST' && req.method !== 'DELETE') {
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
    if (!(await rateLimit(`rl:ip:delete:${ip}`, PER_IP_LIMIT_PER_MINUTE))) {
      return Response.json({ error: 'Rate limit exceeded' }, { status: 429 });
    }

    let body: unknown;
    try {
      body = await req.json();
    } catch {
      return badRequest('Invalid JSON');
    }
    if (!body || typeof body !== 'object') return badRequest('Invalid body');

    const { deviceToken } = body as { deviceToken?: unknown };
    if (typeof deviceToken !== 'string' || !APNS_TOKEN_RE.test(deviceToken)) {
      return badRequest('deviceToken must be 64 hex characters');
    }

    // Look up region before deleting so we know which region set to clean.
    const deviceKey = `device:${deviceToken}`;
    const device = await redis.get<{ region?: string }>(deviceKey);

    await redis.del(deviceKey);

    if (device?.region && device.region !== 'Unknown') {
      const regionKey = `region-devices:${device.region.toLowerCase().replace(/\s+/g, '-')}`;
      await redis.srem(regionKey, deviceToken);
    }

    // Aggregated counters (`activity:*`) are not tied to a token by design,
    // so there's nothing per-device to erase from them. The aggregates are
    // already auto-expiring at end of UTC day.

    console.log(`🗑️  Device record erased (token prefix ${deviceToken.substring(0, 8)}…)`);

    return Response.json({ success: true });

  } catch (error) {
    console.error('Error deleting device:', error);
    return Response.json({ error: 'Internal server error' }, { status: 500 });
  }
}
