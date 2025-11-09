import { Redis } from '@upstash/redis';

const redis = new Redis({
  url: process.env.UPSTASH_REDIS_REST_URL,
  token: process.env.UPSTASH_REDIS_REST_TOKEN,
});

async function test() {
  try {
    console.log('Testing Redis connection...');
    console.log('URL:', process.env.UPSTASH_REDIS_REST_URL);
    
    // Test ping
    const pong = await redis.ping();
    console.log('✅ Ping successful:', pong);
    
    // Test set/get
    await redis.set('test-key', 'Hello from CloudView!');
    const value = await redis.get('test-key');
    console.log('✅ Set/Get successful:', value);
    
    // Clean up
    await redis.del('test-key');
    console.log('✅ All tests passed!');
    
  } catch (error) {
    console.error('❌ Connection failed:', error.message);
    console.error('Please check your Upstash Console for REST API credentials');
  }
}

test();
