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

    if (!region || region.length > 80) {
      return Response.json(
        { error: 'Missing or invalid parameter: region' },
        { status: 400 }
      );
    }
    if (!/^\d{4}-\d{2}-\d{2}$/.test(date)) {
      return Response.json(
        { error: 'Invalid date format (expected YYYY-MM-DD)' },
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
