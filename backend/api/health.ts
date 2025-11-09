import { redis } from './lib/redis';

export const config = {
  runtime: 'edge',
};

export default async function handler(req: Request) {
  if (req.method !== 'GET') {
    return Response.json(
      { error: 'Method not allowed' },
      { status: 405 }
    );
  }

  try {
    // Test Redis connection
    await redis.ping();

    return Response.json({
      status: 'healthy',
      timestamp: new Date().toISOString(),
      service: 'Cloudoodle Backend',
      redis: 'connected',
    });
  } catch (error) {
    return Response.json(
      {
        status: 'unhealthy',
        timestamp: new Date().toISOString(),
        service: 'Cloudoodle Backend',
        redis: 'disconnected',
        error: error instanceof Error ? error.message : 'Unknown error',
      },
      { status: 503 }
    );
  }
}
