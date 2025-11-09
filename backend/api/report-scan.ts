import {
  redis,
  AnonymousScanReport,
  RegionalActivity,
  getTodayDate,
  getActivityId,
} from './lib/redis';
import { checkThresholds } from './lib/notifications';
import { apnsService } from './lib/apns';

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
    const report: AnonymousScanReport = await req.json();

    // Validate input
    if (!report.region || !report.category || !report.timestamp) {
      return Response.json(
        { error: 'Missing required fields: region, category, timestamp' },
        { status: 400 }
      );
    }

    // Validate category
    if (!VALID_CATEGORIES.includes(report.category)) {
      return Response.json(
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

        // Send actual push notification to all devices in this region
        console.log('📬 Notification trigger:', {
          region: report.region,
          category,
          message,
          count: category === 'total' ? activity.totalScans : activity.categories[category],
        });

        // Send push notification via APNs
        const sentCount = await apnsService.sendToRegion(report.region, {
          title: message.title,
          body: message.body,
          data: {
            category,
            region: report.region,
            count: (category === 'total' ? activity.totalScans : activity.categories[category]).toString(),
          },
        });

        console.log(`✅ Sent notification to ${sentCount} devices in ${report.region}`);

        // Return notification info for client (optional)
        return Response.json({
          success: true,
          notification: {
            triggered: true,
            category,
            message,
            sentTo: sentCount,
          },
        });
      }
    }

    return Response.json({ success: true });
  } catch (error) {
    console.error('Error reporting scan:', error);
    return Response.json(
      { error: 'Internal server error' },
      { status: 500 }
    );
  }
}
