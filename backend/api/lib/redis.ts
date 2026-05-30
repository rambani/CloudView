import { Redis } from '@upstash/redis';

// Lazy singleton so importing this module in tests / typecheck doesn't trip
// "[Upstash Redis] The 'token' property is missing" warnings, and so a missing
// env var becomes a real error at the first use site rather than at import.
let _redis: Redis | null = null;

function getRedis(): Redis {
  if (_redis) return _redis;
  const url = process.env.UPSTASH_REDIS_REST_URL;
  const token = process.env.UPSTASH_REDIS_REST_TOKEN;
  if (!url || !token) {
    throw new Error(
      'Upstash Redis is not configured: set UPSTASH_REDIS_REST_URL and UPSTASH_REDIS_REST_TOKEN.'
    );
  }
  _redis = new Redis({ url, token });
  return _redis;
}

// Backwards-compatible proxy: callers keep using `redis.get(...)` etc.
export const redis = new Proxy({} as Redis, {
  get(_target, prop, receiver) {
    const value = Reflect.get(getRedis(), prop, receiver);
    return typeof value === 'function' ? value.bind(getRedis()) : value;
  },
});

// Data models
export interface AnonymousScanReport {
  region: string;
  category: string;
  timestamp: string;
}

export interface RegionalActivity {
  region: string;
  date: string;
  categories: Record<string, number>;
  totalScans: number;
  lastUpdated: string;
}

// Helper to get today's date in YYYY-MM-DD format
export function getTodayDate(): string {
  return new Date().toISOString().split('T')[0];
}

// Helper to get region key (normalized)
export function getRegionKey(region: string): string {
  return region.toLowerCase().replace(/\s+/g, '-');
}

// Helper to get activity document ID
export function getActivityId(region: string, date: string): string {
  const regionKey = getRegionKey(region);
  return `activity:${regionKey}:${date}`;
}

// Seconds remaining until end of UTC day, with a 1-hour floor so
// late-day writes still have a reasonable lifetime.
export function endOfDayTtlSeconds(): number {
  const now = new Date();
  const endOfDay = Date.UTC(
    now.getUTCFullYear(),
    now.getUTCMonth(),
    now.getUTCDate() + 1
  );
  const seconds = Math.floor((endOfDay - now.getTime()) / 1000);
  return Math.max(seconds, 3600);
}
