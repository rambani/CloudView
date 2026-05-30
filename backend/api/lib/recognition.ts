import { redis } from './redis';

// MARK: - Wire types

export interface Annotation {
  kind: 'dot' | 'line' | 'arc';
  // Normalized 0–1 within cluster bounding box.
  points: Array<{ x: number; y: number }>;
}

export interface Interpretation {
  label: string;
  confidence: number;
  annotations: Annotation[];
}

export interface RecognitionResult {
  interpretations: Interpretation[];
  // Set when the result was just produced; absent on cache hits.
  createdAt?: string;
}

// MARK: - Cache helpers
//
// Keyed by the iOS-side shape signature, which is already bucketed for
// locality-sensitive matching, so we don't need a second LSH step here.
// Cache entries live "forever" (1-year TTL just to avoid keyspace bloat).

const CACHE_TTL_SECONDS = 60 * 60 * 24 * 365;

export function recognitionCacheKey(signature: string): string {
  return `recognition:${signature}`;
}

export async function getCached(signature: string): Promise<RecognitionResult | null> {
  return await redis.get<RecognitionResult>(recognitionCacheKey(signature));
}

export async function setCached(
  signature: string,
  result: RecognitionResult
): Promise<void> {
  await redis.set(
    recognitionCacheKey(signature),
    { ...result, createdAt: new Date().toISOString() },
    { ex: CACHE_TTL_SECONDS }
  );
}

/**
 * No-match sentinel — for shapes where the vision model genuinely couldn't
 * find anything kid-safe. Cached with the same key so we don't spend a
 * second API call on the same dead shape.
 */
export const NO_MATCH: RecognitionResult = { interpretations: [] };
