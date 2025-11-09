# 🚀 Deploy CloudView Backend NOW

Your Upstash Redis is configured and ready! Follow these simple commands:

## Step 1: Install Vercel CLI (if needed)

```bash
npm install -g vercel
```

## Step 2: Login to Vercel

```bash
vercel login
```

This will open your browser - confirm the login.

## Step 3: Deploy

```bash
cd /home/user/CloudView/backend

# First deployment (creates project)
vercel
```

**Answer the prompts:**
- Set up and deploy? → **Yes**
- Which scope? → **Your personal account**
- Link to existing project? → **No**
- Project name? → **cloudview-backend** (or your choice)
- In which directory is your code? → **`./`** (press Enter)
- Want to override settings? → **No**

## Step 4: Set Environment Variables

```bash
vercel env add UPSTASH_REDIS_REST_URL production
```
When prompted, paste: `https://flexible-moose-35374.upstash.io`

```bash
vercel env add UPSTASH_REDIS_REST_TOKEN production
```
When prompted, paste: `AYouAAIncDIwOTZiNTY4ZGYxZTc0ZDI2OGVhODMzMjExMDhiMmRjN3AyMzUzNzQ`

## Step 5: Deploy to Production

```bash
vercel --prod
```

**Your deployment URL** will be shown (something like `https://cloudview-backend-xyz.vercel.app`)

## Step 6: Test Your Backend

```bash
./test-backend.sh https://YOUR-DEPLOYMENT-URL.vercel.app
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

## Step 7: Update iOS App

Edit `CloudView/Services/ScanReportingService.swift`:

**Line 11** - Change to your deployment URL:
```swift
private let backendURL = "https://YOUR-DEPLOYMENT-URL.vercel.app/api/report-scan"
```

**Line 12** - Enable the service:
```swift
private var isEnabled = true
```

## ✅ Done!

Your privacy-preserving backend is now live! 🎉

---

## 🔧 Troubleshooting

### "Command not found: vercel"
```bash
npm install -g vercel
```

### "Not authenticated"
```bash
vercel login
```

### "Environment variable not set"
Re-run the `vercel env add` commands from Step 4

### Need to redeploy?
```bash
cd /home/user/CloudView/backend
vercel --prod
```

---

## 📊 Monitor Your Backend

- **Vercel Dashboard**: https://vercel.com/dashboard
- **Upstash Console**: https://console.upstash.com/
- **View Logs**: `vercel logs`

---

**Questions?** Check the full guide in `DEPLOYMENT_GUIDE.md`
