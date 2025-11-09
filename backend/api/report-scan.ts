import { NextRequest, NextResponse } from 'next/server';
import {
  redis,
  AnonymousScanReport,
  RegionalActivity,
  getTodayDate,
  getActivityId,
} from './lib/redis';
import { checkThresholds } from './lib/notifications';

export const config = {
  runtime: 'edge',
};

const VALID_CATEGORIES = [
  'animals',
  'mythical',
  'landmarks',
  'vehicles',
  'food',
  'nature',
];

export default async function handler(req: NextRequest) {
  // Handle CORS preflight
  if (req.method === 'OPTIONS') {
    return new NextResponse(null, { status: 204 });
  }

  if (req.method !== 'POST') {
    return NextResponse.json(
      { error: 'Method not allowed' },
      { status: 405 }
    );
  }

  try {
    const report: AnonymousScanReport = await req.json();

    // Validate input
    if (!report.region || !report.category || !report.timestamp) {
      return NextResponse.json(
        { error: 'Missing required fields: region, category, timestamp' },
        { status: 400 }
      );
    }

    // Validate category
    if (!VALID_CATEGORIES.includes(report.category)) {
      return NextResponse.json(
        { error: `Invalid category. Must be one of: ${VALID_CATEGORIES.join(', ')}` },
        { status: 400 }
      );
    }

    const today = getTodayDate();
    const activityId = getActivityId(report.region, today);

    // Get current activity or create new one
    let activity = await redis.get<RegionalActivity>(activityId);

    if (!activity) {
      // Create new activity document
      activity = {
        region: report.region,
        date: today,
        categories: { [report.category]: 1 },
        totalScans: 1,
        lastUpdated: new Date().toISOString(),
      };
    } else {
      // Update existing activity
      const categories = activity.categories || {};
      categories[report.category] = (categories[report.category] || 0) + 1;

      activity = {
        ...activity,
        categories,
        totalScans: (activity.totalScans || 0) + 1,
        lastUpdated: new Date().toISOString(),
      };
    }

    // Save to Redis with 24-hour expiration
    await redis.set(activityId, activity, { ex: 86400 }); // 24 hours in seconds

    // Check if we should trigger notifications
    const { category, message } = checkThresholds(activity);

    if (category && message) {
      // Check if we've already sent this notification today
      const notificationKey = `notification:${report.region}:${today}:${category}`;
      const alreadySent = await redis.get(notificationKey);

      if (!alreadySent) {
        // Mark notification as sent (expires in 24 hours)
        await redis.set(notificationKey, '1', { ex: 86400 });

        // Log notification (in production, you'd send push notifications here)
        console.log('Notification trigger:', {
          region: report.region,
          category,
          message,
          count: category === 'total' ? activity.totalScans : activity.categories[category],
        });

        // Return notification info for client (optional)
        return NextResponse.json({
          success: true,
          notification: {
            triggered: true,
            category,
            message,
          },
        });
      }
    }

    return NextResponse.json({ success: true });
  } catch (error) {
    console.error('Error reporting scan:', error);
    return NextResponse.json(
      { error: 'Internal server error' },
      { status: 500 }
    );
  }
}
