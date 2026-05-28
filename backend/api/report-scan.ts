import {
  redis,
  AnonymousScanReport,
  RegionalActivity,
  getTodayDate,
  getActivityId,
  endOfDayTtlSeconds,
} from './lib/redis';
import { checkThresholds } from './lib/notifications';
import { apnsService } from './lib/apns';

export const config = {
  runtime: 'edge',
};

const VALID_CATEGORIES = new Set([
  'animals',
  'mythical',
  'landmarks',
  'vehicles',
  'food',
  'nature',
]);

const MAX_BODY_BYTES = 2 * 1024; // 2KB is way more than a scan report needs
const MAX_REGION_LENGTH = 80;
const PER_IP_LIMIT_PER_MINUTE = 60;
const PER_REGION_LIMIT_PER_MINUTE = 600;

function badRequest(message: string) {
  return Response.json({ error: message }, { status: 400 });
}

function isIsoTimestamp(value: unknown): value is string {
  if (typeof value !== 'string' || value.length > 40) return false;
  const t = Date.parse(value);
  if (Number.isNaN(t)) return false;
  // Reject timestamps far in the future or more than 24h in the past.
  const now = Date.now();
  return t <= now + 5 * 60_000 && t >= now - 24 * 60 * 60_000;
}

async function rateLimit(key: string, limit: number): Promise<boolean> {
  const count = await redis.incr(key);
  if (count === 1) {
    await redis.expire(key, 60);
  }
  return count <= limit;
}

export default async function handler(req: Request) {
  // Handle CORS preflight
  if (req.method === 'OPTIONS') {
    return new Response(null, { status: 204 });
  }

  if (req.method !== 'POST') {
    return Response.json(
      { error: 'Method not allowed' },
      { status: 405 }
    );
  }

  try {
    // Size guard before parsing.
    const contentLength = Number(req.headers.get('content-length') ?? '0');
    if (contentLength > MAX_BODY_BYTES) {
      return Response.json({ error: 'Payload too large' }, { status: 413 });
    }

    const ip =
      req.headers.get('x-forwarded-for')?.split(',')[0]?.trim() ||
      req.headers.get('x-real-ip') ||
      'unknown';
    if (!(await rateLimit(`rl:ip:${ip}`, PER_IP_LIMIT_PER_MINUTE))) {
      return Response.json({ error: 'Rate limit exceeded' }, { status: 429 });
    }

    let body: unknown;
    try {
      body = await req.json();
    } catch {
      return badRequest('Invalid JSON');
    }
    if (!body || typeof body !== 'object') return badRequest('Invalid body');

    const report = body as Partial<AnonymousScanReport>;
    if (!report.region || typeof report.region !== 'string') {
      return badRequest('Missing or invalid field: region');
    }
    if (report.region.length > MAX_REGION_LENGTH) {
      return badRequest('Region too long');
    }
    if (!report.category || typeof report.category !== 'string' || !VALID_CATEGORIES.has(report.category)) {
      return badRequest(`Invalid category. Must be one of: ${[...VALID_CATEGORIES].join(', ')}`);
    }
    if (!isIsoTimestamp(report.timestamp)) {
      return badRequest('Missing or invalid timestamp');
    }

    // Per-region rate limit to make it harder to spoof a notification surge.
    if (!(await rateLimit(`rl:region:${report.region.toLowerCase()}`, PER_REGION_LIMIT_PER_MINUTE))) {
      return Response.json({ error: 'Region rate limit exceeded' }, { status: 429 });
    }

    const today = getTodayDate();
    const activityId = getActivityId(report.region, today);

    // Get current activity or create new one
    let activity = await redis.get<RegionalActivity>(activityId);

    if (!activity) {
      activity = {
        region: report.region,
        date: today,
        categories: { [report.category]: 1 },
        totalScans: 1,
        lastUpdated: new Date().toISOString(),
      };
    } else {
      const categories = activity.categories || {};
      categories[report.category] = (categories[report.category] || 0) + 1;

      activity = {
        ...activity,
        categories,
        totalScans: (activity.totalScans || 0) + 1,
        lastUpdated: new Date().toISOString(),
      };
    }

    // Expire at end of UTC day so a late surge doesn't keep extending the window.
    await redis.set(activityId, activity, { ex: endOfDayTtlSeconds() });

    // Check every threshold that just crossed and notify per-category, deduped.
    const hits = checkThresholds(activity);
    const triggered: Array<{ category: string; sentTo: number }> = [];

    for (const hit of hits) {
      const notificationKey = `notification:${report.region}:${today}:${hit.category}`;
      // SET ... NX gives us atomic "first writer wins" dedupe.
      const claimed = await redis.set(notificationKey, '1', { nx: true, ex: 86400 });
      if (!claimed) continue;

      console.log('📬 Notification trigger:', {
        region: report.region,
        category: hit.category,
        count: hit.count,
      });

      const sentCount = await apnsService.sendToRegion(report.region, {
        title: hit.message.title,
        body: hit.message.body,
        data: {
          category: hit.category,
          region: report.region,
          count: hit.count.toString(),
        },
      });
      triggered.push({ category: hit.category, sentTo: sentCount });
    }

    return Response.json({
      success: true,
      ...(triggered.length > 0 ? { notifications: triggered } : {}),
    });
  } catch (error) {
    console.error('Error reporting scan:', error);
    return Response.json(
      { error: 'Internal server error' },
      { status: 500 }
    );
  }
}
