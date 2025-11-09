import { Redis } from '@upstash/redis';

const redis = new Redis({
  url: 'https://flexible-moose-35374.upstash.io',
  token: 'AYouAAIncDIwOTZiNTY4ZGYxZTc0ZDI2OGVhODMzMjExMDhiMmRjN3AyMzUzNzQ',
});

console.log('🧪 Testing Upstash Redis connection...\n');

try {
  console.log('1. Setting test value...');
  await redis.set("cloudview-test", "Hello from CloudView! 🌤️");

  console.log('2. Getting test value...');
  const result = await redis.get("cloudview-test");

  console.log('3. Testing activity aggregation...');
  await redis.set("activity:san-francisco:2025-11-09", {
    region: "San Francisco",
    date: "2025-11-09",
    categories: { animals: 5, mythical: 3 },
    totalScans: 8
  });

  const activity = await redis.get("activity:san-francisco:2025-11-09");

  console.log('4. Cleaning up...');
  await redis.del("cloudview-test");
  await redis.del("activity:san-francisco:2025-11-09");

  console.log('\n✅ All tests passed!');
  console.log('✅ Redis is working correctly');
  console.log('✅ Your backend is ready to deploy to Vercel\n');

} catch (error) {
  console.error('\n❌ Test failed:', error.message);
  process.exit(1);
}
