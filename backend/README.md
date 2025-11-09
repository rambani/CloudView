# CloudView Backend

Privacy-preserving backend for CloudView community notifications using **Vercel Edge Functions** + **Upstash Redis**.

## 🎯 Features

- ✅ **100% Free** for small-to-medium scale apps
- ✅ **Privacy-first**: Only stores city/region, drawing categories, and timestamps
- ✅ **Serverless**: Scales automatically with zero maintenance
- ✅ **Fast**: Edge functions run close to users worldwide
- ✅ **Simple**: Deploy in under 5 minutes

## 💰 Cost Breakdown

### Vercel (Hobby Plan - Free)
- 100GB bandwidth/month
- 100K edge function invocations/month
- Automatic HTTPS
- Global CDN

### Upstash Redis (Free Tier)
- 10K commands/day (~300K/month)
- 256 MB storage
- Automatic data expiration

**Total cost**: **$0/month** for apps with <1000 daily active users

## 🚀 Quick Setup (5 minutes)

### 1. Create Upstash Redis Database

1. Go to [https://console.upstash.com/](https://console.upstash.com/)
2. Sign up for free (GitHub login works)
3. Click **Create Database**
   - Name: `cloudview-data`
   - Type: **Regional** (cheaper, faster for single region)
   - Region: Choose closest to your users
4. Copy the credentials:
   - **UPSTASH_REDIS_REST_URL**
   - **UPSTASH_REDIS_REST_TOKEN**

### 2. Install Vercel CLI

```bash
npm install -g vercel
```

### 3. Deploy to Vercel

```bash
cd backend

# Install dependencies
npm install

# Login to Vercel
vercel login

# Deploy (first time)
vercel

# Follow prompts:
# - Link to existing project? No
# - Project name: cloudview-backend
# - Which scope? (select your account)
# - Link to existing directory? Yes

# Set environment variables
vercel env add UPSTASH_REDIS_REST_URL
# Paste your Upstash URL

vercel env add UPSTASH_REDIS_REST_TOKEN
# Paste your Upstash token

# Deploy to production
vercel --prod
```

Your backend is now live! You'll get URLs like:
```
https://cloudview-backend.vercel.app/api/report-scan
https://cloudview-backend.vercel.app/api/regional-activity
https://cloudview-backend.vercel.app/api/health
```

### 4. Update iOS App

Update `CloudView/Services/ScanReportingService.swift`:

```swift
private let backendURL = "https://YOUR-PROJECT.vercel.app/api/report-scan"
private var isEnabled = true // Enable it!
```

Update `CloudView/Services/ScanReportingService.swift` in the `enable()` function:

```swift
func enable(withBackendURL url: String) {
    // Already implemented, just call it from your app
}
```

Or simply update the default URL at line 11.

## 📡 API Endpoints

### POST `/api/report-scan`

Report an anonymous cloud drawing scan.

**Request:**
```json
{
  "region": "San Francisco",
  "category": "animals",
  "timestamp": "2025-11-09T10:30:00Z"
}
```

**Response:**
```json
{
  "success": true
}
```

**Response (with notification trigger):**
```json
{
  "success": true,
  "notification": {
    "triggered": true,
    "category": "animals",
    "message": {
      "title": "Animals Everywhere! 🦁☁️",
      "body": "Lots of animal shapes spotted in San Francisco clouds today!"
    }
  }
}
```

### GET `/api/regional-activity?region=<city>&date=<YYYY-MM-DD>`

Get aggregated activity for a region.

**Request:**
```
GET /api/regional-activity?region=San%20Francisco
```

**Response:**
```json
{
  "region": "San Francisco",
  "date": "2025-11-09",
  "categories": {
    "animals": 23,
    "mythical": 15,
    "landmarks": 8
  },
  "totalScans": 46,
  "lastUpdated": "2025-11-09T10:30:00Z"
}
```

### GET `/api/health`

Check backend health and Redis connection.

**Response:**
```json
{
  "status": "healthy",
  "timestamp": "2025-11-09T10:30:00Z",
  "service": "CloudView Backend",
  "redis": "connected"
}
```

## 🔒 Privacy Guarantees

### What We Store
- ✅ City/region names (e.g., "San Francisco")
- ✅ Drawing categories (e.g., "animals", "mythical")
- ✅ Aggregated counts per category
- ✅ Timestamps for daily aggregation

### What We DON'T Store
- ❌ User IDs or device identifiers
- ❌ Exact GPS coordinates
- ❌ IP addresses
- ❌ Personal information
- ❌ Individual scan records (only aggregates)

### Data Retention
- All data automatically expires after **24 hours**
- Redis keys use TTL (Time To Live) for automatic deletion
- No manual cleanup needed

## 📊 Monitoring

### View Logs
```bash
vercel logs
```

### View Redis Data
Go to [Upstash Console](https://console.upstash.com/) → Your Database → Data Browser

### Test Endpoints
```bash
# Test health check
curl https://YOUR-PROJECT.vercel.app/api/health

# Test scan reporting
curl -X POST https://YOUR-PROJECT.vercel.app/api/report-scan \
  -H "Content-Type: application/json" \
  -d '{
    "region": "San Francisco",
    "category": "animals",
    "timestamp": "2025-11-09T10:30:00Z"
  }'

# Test regional activity
curl "https://YOUR-PROJECT.vercel.app/api/regional-activity?region=San%20Francisco"
```

## 🔧 Local Development

```bash
cd backend

# Install dependencies
npm install

# Copy environment variables
cp .env.example .env

# Edit .env with your Upstash credentials
nano .env

# Run development server
npm run dev
```

The backend will be available at `http://localhost:3000`

## 🚨 Troubleshooting

### "Redis connection failed"
- Check that `UPSTASH_REDIS_REST_URL` and `UPSTASH_REDIS_REST_TOKEN` are set correctly in Vercel
- Verify credentials in [Upstash Console](https://console.upstash.com/)

### "Rate limit exceeded"
- Free tier: 10K Redis commands/day
- Upgrade Upstash to pay-as-you-go (~$0.20 per 100K commands)

### "Deployment failed"
- Run `vercel --debug` for detailed logs
- Check that all environment variables are set
- Ensure Node.js version is compatible (18+)

## 📈 Scaling

When you exceed free tier limits:

### Upstash Redis Pay-As-You-Go
- ~$0.20 per 100K commands
- ~$0.25 per GB storage
- For 10K daily users: ~$5-10/month

### Vercel Pro ($20/month)
- 1TB bandwidth
- Unlimited edge function invocations
- Team collaboration features

**Total cost at 10K daily users**: ~$25-30/month

## 🔐 Security Best Practices

1. **Never commit `.env` files** - Already in `.gitignore`
2. **Rotate Upstash tokens** if exposed
3. **Monitor usage** in Upstash console
4. **Set rate limits** in Vercel if needed
5. **Enable Vercel Analytics** for traffic monitoring

## 📚 Additional Resources

- [Vercel Edge Functions Docs](https://vercel.com/docs/functions/edge-functions)
- [Upstash Redis Docs](https://docs.upstash.com/redis)
- [Vercel Environment Variables](https://vercel.com/docs/projects/environment-variables)

## 🤝 Support

Issues? Questions?
- Check [Vercel Status](https://www.vercel-status.com/)
- Check [Upstash Status](https://status.upstash.com/)
- Review logs: `vercel logs`

---

**Built with ❤️ for privacy-preserving community features**
