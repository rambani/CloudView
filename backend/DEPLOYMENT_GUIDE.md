# 🚀 CloudView Backend Deployment Guide

Your backend is **ready to deploy**! Follow these steps to get it live.

## ✅ What's Already Done

- ✅ Backend code written and tested
- ✅ Dependencies installed (`npm install` completed)
- ✅ Git committed and pushed
- ✅ Configuration files ready

## 🎯 What You Need to Do (10 minutes)

### Step 1: Create Upstash Redis Database (2 minutes)

1. **Go to**: https://console.upstash.com/
2. **Sign up** using GitHub (fastest) or email
3. **Click "Create Database"**
   - **Name**: `cloudview-data`
   - **Type**: Select **Regional** (it's faster and cheaper)
   - **Region**: Choose the one closest to your users (e.g., `us-east-1` for US)
   - Click **Create**

4. **Copy your credentials** (you'll see them on the database page):
   ```
   UPSTASH_REDIS_REST_URL=https://us1-......upstash.io
   UPSTASH_REDIS_REST_TOKEN=AY......
   ```

   ⚠️ **Keep these safe!** You'll need them in the next step.

---

### Step 2: Deploy to Vercel (5 minutes)

#### Option A: Using Vercel CLI (Recommended)

1. **Install Vercel CLI globally**:
   ```bash
   npm install -g vercel
   ```

2. **Navigate to backend directory**:
   ```bash
   cd /home/user/CloudView/backend
   ```

3. **Login to Vercel**:
   ```bash
   vercel login
   ```
   - It will open a browser
   - Confirm the login

4. **Deploy (first time)**:
   ```bash
   vercel
   ```

   You'll be asked:
   - **Set up and deploy?** → Yes
   - **Which scope?** → Select your personal account
   - **Link to existing project?** → No
   - **Project name?** → `cloudview-backend` (or whatever you prefer)
   - **In which directory?** → `./` (press Enter)
   - **Override settings?** → No

5. **Add environment variables**:
   ```bash
   vercel env add UPSTASH_REDIS_REST_URL
   ```
   Paste your URL from Step 1, then:

   ```bash
   vercel env add UPSTASH_REDIS_REST_TOKEN
   ```
   Paste your token from Step 1

6. **Deploy to production**:
   ```bash
   vercel --prod
   ```

7. **Save your deployment URL**:
   ```
   ✅ Production: https://cloudview-backend-abc123.vercel.app
   ```

#### Option B: Using Vercel Dashboard (Alternative)

1. **Go to**: https://vercel.com/new
2. **Import Git Repository**
   - Connect your GitHub account
   - Select your `CloudView` repository
   - **Root Directory**: Set to `backend`
   - Click **Import**

3. **Add Environment Variables**:
   - Click **Environment Variables**
   - Add `UPSTASH_REDIS_REST_URL` with your Upstash URL
   - Add `UPSTASH_REDIS_REST_TOKEN` with your Upstash token

4. **Deploy**:
   - Click **Deploy**
   - Wait ~1 minute for deployment
   - Copy your deployment URL

---

### Step 3: Test Your Backend (1 minute)

Replace `YOUR-URL` with your actual deployment URL:

```bash
cd /home/user/CloudView/backend

# Test the backend
./test-backend.sh https://YOUR-URL.vercel.app
```

Expected output:
```
🧪 Testing CloudView Backend
============================
1️⃣  Testing health endpoint...
✅ Health check passed

2️⃣  Testing scan reporting...
✅ Scan reporting passed

3️⃣  Testing regional activity...
✅ Regional activity passed

🎉 All tests passed!
```

---

### Step 4: Update iOS App (1 minute)

Edit `CloudView/Services/ScanReportingService.swift`:

**Line 11** - Change:
```swift
private let backendURL = "https://your-backend-api.com/api/scans/report"
```

To:
```swift
private let backendURL = "https://YOUR-ACTUAL-URL.vercel.app/api/report-scan"
```

**Line 12** - Change:
```swift
private var isEnabled = false // Disabled until backend is ready
```

To:
```swift
private var isEnabled = true // Backend is now ready!
```

Save the file, and you're done! 🎉

---

## 🧪 Quick Test Commands

After deployment, test each endpoint:

### Health Check
```bash
curl https://YOUR-URL.vercel.app/api/health
```

Expected:
```json
{
  "status": "healthy",
  "timestamp": "2025-11-09T...",
  "service": "CloudView Backend",
  "redis": "connected"
}
```

### Report a Scan
```bash
curl -X POST https://YOUR-URL.vercel.app/api/report-scan \
  -H "Content-Type: application/json" \
  -d '{
    "region": "San Francisco",
    "category": "animals",
    "timestamp": "2025-11-09T10:30:00Z"
  }'
```

Expected:
```json
{
  "success": true
}
```

### Get Regional Activity
```bash
curl "https://YOUR-URL.vercel.app/api/regional-activity?region=San%20Francisco"
```

Expected:
```json
{
  "region": "San Francisco",
  "date": "2025-11-09",
  "categories": {
    "animals": 1
  },
  "totalScans": 1,
  "lastUpdated": "..."
}
```

---

## 📊 Monitoring Your Backend

### View Logs
```bash
vercel logs
```

### View Redis Data
Go to: https://console.upstash.com/ → Your Database → **Data Browser**

You'll see keys like:
- `activity:san-francisco:2025-11-09` - Regional activity data
- `notification:San Francisco:2025-11-09:animals` - Notification tracking

### Check Usage
- **Vercel**: https://vercel.com/dashboard → Your Project → Analytics
- **Upstash**: https://console.upstash.com/ → Your Database → Metrics

---

## 💰 Cost Tracking

### Free Tier Limits
- **Vercel**: 100GB bandwidth, 100K function invocations/month
- **Upstash**: 10K Redis commands/day (~300K/month)

### What This Means
- **~1,000 daily active users**: Completely free ✅
- **~10,000 daily active users**: ~$5-10/month
- **~50,000 daily active users**: ~$20-30/month

You'll get email alerts before hitting any limits.

---

## 🔧 Troubleshooting

### "Redis connection failed"
- Check environment variables in Vercel dashboard
- Verify Upstash credentials are correct
- Check Upstash database is running (not paused)

### "Module not found" errors
- Run `npm install` in backend directory
- Redeploy with `vercel --prod`

### CORS errors from iOS app
- Already configured in `vercel.json`
- If issues persist, check Vercel logs

### Deployment fails
```bash
# Get detailed logs
vercel --debug

# Clear cache and redeploy
vercel --force
```

---

## 🎉 You're All Set!

Once deployed:
1. ✅ Your backend is live and auto-scaling
2. ✅ Data expires automatically after 24 hours
3. ✅ Privacy-first design (no user tracking)
4. ✅ 100% free for small-medium apps
5. ✅ Global edge network for fast responses

**Questions?** Check:
- Vercel Docs: https://vercel.com/docs
- Upstash Docs: https://docs.upstash.com/redis
- This repo's README: `/backend/README.md`

**Happy cloud watching! ☁️**
