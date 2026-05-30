import { redis } from './lib/redis';
import {
  getCached,
  setCached,
  Interpretation,
  RecognitionResult,
} from './lib/recognition';
import { filterAllowlist } from './lib/allowlist';

export const config = {
  runtime: 'edge',
};

const MAX_BODY_BYTES = 16 * 1024; // outlines up to a few hundred points
const PER_IP_LIMIT_PER_MINUTE = 60;
const PER_REGION_LIMIT_PER_MINUTE = 1200;

interface RecognizeRequest {
  signature: string;
  // Optional — only sent when the client suspects the shape is novel
  // (cache miss on previous attempt). Saves uplink bandwidth on hits.
  outline?: Array<{ x: number; y: number }>;
  region?: string;
}

async function rateLimit(key: string, limit: number): Promise<boolean> {
  const count = await redis.incr(key);
  if (count === 1) await redis.expire(key, 60);
  return count <= limit;
}

function badRequest(message: string) {
  return Response.json({ error: message }, { status: 400 });
}

/**
 * Phase 0 stub. Returns canned interpretations seeded by the signature so
 * the iOS pipeline can flow end-to-end without burning vision-model dollars.
 * Phase 1 replaces the stub body with a real Claude/GPT-4V call; the request
 * and response shapes don't change.
 */
function stubInterpretations(signature: string): Interpretation[] {
  const bank = [
    'turtle', 'dragon', 'rabbit', 'cat', 'whale', 'dolphin',
    'rocket', 'castle', 'dog', 'penguin', 'unicorn', 'bear',
  ];
  // Hash the signature into a starting offset so the same signature
  // always returns the same 5 picks (deterministic dev experience).
  let h = 0;
  for (let i = 0; i < signature.length; i++) {
    h = (h * 31 + signature.charCodeAt(i)) | 0;
  }
  const picks: Interpretation[] = [];
  for (let i = 0; i < 5; i++) {
    const idx = Math.abs((h + i * 7) % bank.length);
    picks.push({
      label: bank[idx]!,
      confidence: 0.55,
      annotations: [],
    });
  }
  return picks;
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
    if (!(await rateLimit(`rl:ip:recognize:${ip}`, PER_IP_LIMIT_PER_MINUTE))) {
      return Response.json({ error: 'Rate limit exceeded' }, { status: 429 });
    }

    let body: unknown;
    try {
      body = await req.json();
    } catch {
      return badRequest('Invalid JSON');
    }
    if (!body || typeof body !== 'object') return badRequest('Invalid body');

    const reqBody = body as Partial<RecognizeRequest>;
    if (typeof reqBody.signature !== 'string' || reqBody.signature.length === 0) {
      return badRequest('Missing required field: signature');
    }
    if (reqBody.signature.length > 200) {
      return badRequest('Signature too long');
    }
    if (reqBody.region) {
      if (
        typeof reqBody.region !== 'string' ||
        reqBody.region.length > 80
      ) {
        return badRequest('Invalid region');
      }
      if (!(await rateLimit(`rl:region:recognize:${reqBody.region.toLowerCase()}`, PER_REGION_LIMIT_PER_MINUTE))) {
        return Response.json({ error: 'Region rate limit exceeded' }, { status: 429 });
      }
    }

    // Cache hit? Return cached interpretations untouched. Client picks one
    // at random.
    const cached = await getCached(reqBody.signature);
    if (cached) {
      return Response.json({
        ...cached,
        source: 'cache',
      });
    }

    // Cache miss → Phase 0 stub. Phase 1 plugs in the real vision call here.
    const stub = stubInterpretations(reqBody.signature);
    const filtered = filterAllowlist(stub);

    const result: RecognitionResult = { interpretations: filtered };
    await setCached(reqBody.signature, result);

    return Response.json({ ...result, source: 'stub' });

  } catch (error) {
    console.error('Recognition handler error:', error);
    return Response.json({ error: 'Internal server error' }, { status: 500 });
  }
}
