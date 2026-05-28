import { Redis } from '@upstash/redis';

// Initialize Upstash Redis client
// You'll set UPSTASH_REDIS_REST_URL and UPSTASH_REDIS_REST_TOKEN in Vercel environment variables
export const redis = new Redis({
  url: process.env.UPSTASH_REDIS_REST_URL!,
  token: process.env.UPSTASH_REDIS_REST_TOKEN!,
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
