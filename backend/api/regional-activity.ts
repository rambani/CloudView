import { NextRequest, NextResponse } from 'next/server';
import {
  redis,
  RegionalActivity,
  getTodayDate,
  getActivityId,
} from './lib/redis';

export const config = {
  runtime: 'edge',
};

export default async function handler(req: NextRequest) {
  // Handle CORS preflight
  if (req.method === 'OPTIONS') {
    return new NextResponse(null, { status: 204 });
  }

  if (req.method !== 'GET') {
    return NextResponse.json(
      { error: 'Method not allowed' },
      { status: 405 }
    );
  }

  try {
    const { searchParams } = new URL(req.url);
    const region = searchParams.get('region');
    const date = searchParams.get('date') || getTodayDate();

    if (!region) {
      return NextResponse.json(
        { error: 'Missing required parameter: region' },
        { status: 400 }
      );
    }

    const activityId = getActivityId(region, date);
    const activity = await redis.get<RegionalActivity>(activityId);

    if (!activity) {
      // No activity found for this region/date
      return NextResponse.json({
        region,
        date,
        categories: {},
        totalScans: 0,
      });
    }

    return NextResponse.json(activity);
  } catch (error) {
    console.error('Error getting regional activity:', error);
    return NextResponse.json(
      { error: 'Internal server error' },
      { status: 500 }
    );
  }
}
