import { redis } from './lib/redis';

export const config = {
  runtime: 'edge',
};

interface DeviceRegistration {
  deviceToken: string;
  region: string;
  notificationsEnabled: boolean;
}

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
    const registration: DeviceRegistration = await req.json();

    // Validate input
    if (!registration.deviceToken) {
      return Response.json(
        { error: 'Missing required field: deviceToken' },
        { status: 400 }
      );
    }

    // Store device token with region
    // Key format: device:<token>
    const deviceKey = `device:${registration.deviceToken}`;

    const deviceData = {
      token: registration.deviceToken,
      region: registration.region || 'Unknown',
      notificationsEnabled: registration.notificationsEnabled !== false,
      lastUpdated: new Date().toISOString(),
    };

    // Store device (no expiration - persist until user uninstalls/opts out)
    await redis.set(deviceKey, deviceData);

    // Also add to region-based set for quick lookup
    // Key format: region-devices:<region-name>
    if (registration.region && registration.region !== 'Unknown') {
      const regionKey = `region-devices:${registration.region.toLowerCase().replace(/\s+/g, '-')}`;
      await redis.sadd(regionKey, registration.deviceToken);
    }

    console.log(`✅ Device registered: ${registration.deviceToken.substring(0, 8)}... in region: ${registration.region}`);

    return Response.json({
      success: true,
      message: 'Device registered successfully'
    });

  } catch (error) {
    console.error('Error registering device:', error);
    return Response.json(
      { error: 'Internal server error' },
      { status: 500 }
    );
  }
}
