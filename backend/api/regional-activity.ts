import {
  redis,
  RegionalActivity,
  getTodayDate,
  getActivityId,
} from './lib/redis';

export const config = {
  runtime: 'edge',
};

export default async function handler(req: Request) {
  // Handle CORS preflight
  if (req.method === 'OPTIONS') {
    return new Response(null, { status: 204 });
  }

  if (req.method !== 'GET') {
    return Response.json(
      { error: 'Method not allowed' },
      { status: 405 }
    );
  }

  try {
    const { searchParams } = new URL(req.url);
    const region = searchParams.get('region');
    const date = searchParams.get('date') || getTodayDate();

    if (!region) {
      return Response.json(
        { error: 'Missing required parameter: region' },
        { status: 400 }
      );
    }

    const activityId = getActivityId(region, date);
    const activity = await redis.get<RegionalActivity>(activityId);

    if (!activity) {
      // No activity found for this region/date
      return Response.json({
        region,
        date,
        categories: {},
        totalScans: 0,
      });
    }

    return Response.json(activity);
  } catch (error) {
    console.error('Error getting regional activity:', error);
    return Response.json(
      { error: 'Internal server error' },
      { status: 500 }
    );
  }
}
