# 🔔 Push Notifications Setup Guide

Complete guide to enable real push notifications in Cloudoodle.

## 📋 Prerequisites

- ✅ **Apple Developer Account** ($99/year) - Required for push notifications
- ✅ **Xcode** with your app project
- ✅ **Backend deployed** to Vercel (already done!)
- ✅ **App Bundle ID** (e.g., `com.yourcompany.cloudview`)

---

## Part 1: Apple Developer Portal Setup (10 minutes)

### Step 1: Create App ID with Push Notifications

1. Go to https://developer.apple.com/account/
2. Click **Certificates, Identifiers & Profiles**
3. Click **Identifiers** → **+** button
4. Select **App IDs** → Continue
5. Fill in:
   - **Description**: Cloudoodle
   - **Bundle ID**: `com.yourcompany.cloudview` (must match your Xcode project)
   - **Capabilities**: Check ✅ **Push Notifications**
6. Click **Continue** → **Register**

### Step 2: Create APNs Key

1. In Apple Developer Portal, go to **Keys**
2. Click **+** button
3. Fill in:
   - **Key Name**: Cloudoodle APNs Key
   - **Enable**: Check ✅ **Apple Push Notifications service (APNs)**
4. Click **Continue** → **Register**
5. **Download the .p8 file** ⚠️ You can only download this ONCE!
6. Note the **Key ID** (shown at the top, e.g., `ABC123XYZ4`)

### Step 3: Find Your Team ID

1. In Apple Developer Portal, go to **Membership**
2. Your **Team ID** is shown (e.g., `DEF456GHI7`)
3. Copy this - you'll need it for backend configuration

---

## Part 2: Xcode Configuration (5 minutes)

### Step 1: Enable Push Notifications Capability

1. Open your Cloudoodle project in Xcode
2. Select your **Cloudoodle** target
3. Go to **Signing & Capabilities** tab
4. Click **+ Capability**
5. Add **Push Notifications**
6. Add **Background Modes**
   - Check ✅ **Remote notifications**

### Step 2: Update Bundle Identifier

1. In **Signing & Capabilities**, verify your **Bundle Identifier** matches the App ID you created
2. Example: `com.yourcompany.cloudview`

### Step 3: Enable Automatic Signing (Recommended)

1. In **Signing & Capabilities**
2. Check ✅ **Automatically manage signing**
3. Select your Team
4. Xcode will handle provisioning profiles automatically

---

## Part 3: Backend Configuration (5 minutes)

### Step 1: Prepare APNs Key Content

Open the `.p8` file you downloaded in a text editor. It looks like:
```
-----BEGIN PRIVATE KEY-----
MIGTAgEAMBMGByqGSM49AgEGCCqGSM49AwEHBHkwdwIBAQQg...
...more lines...
-----END PRIVATE KEY-----
```

Copy the **entire contents** (including the BEGIN/END lines).

### Step 2: Add Environment Variables to Vercel

```bash
cd /home/user/Cloudoodle/backend

# Add APNs Key ID
vercel env add APNS_KEY_ID production
# Paste your Key ID (e.g., ABC123XYZ4)

# Add Team ID
vercel env add APNS_TEAM_ID production
# Paste your Team ID (e.g., DEF456GHI7)

# Add APNs Key (the .p8 file contents)
vercel env add APNS_KEY production
# Paste the entire .p8 file contents

# Add Environment (use 'development' for testing, 'production' for App Store)
vercel env add APNS_ENVIRONMENT production
# Type: development   (for testing with Xcode/TestFlight)
# Or:   production    (for App Store releases)
```

### Step 3: Update Bundle ID in Backend

Edit `backend/api/lib/apns.ts` line 81:

```typescript
'apns-topic': 'com.yourcompany.cloudview', // Replace with YOUR bundle ID
```

Change to your actual Bundle ID.

### Step 4: Redeploy Backend

```bash
cd /home/user/Cloudoodle/backend
vercel --prod
```

Wait ~30 seconds for deployment to complete.

---

## Part 4: Testing Push Notifications (10 minutes)

### Step 1: Build and Run on Real Device

⚠️ **Push notifications ONLY work on real iOS devices** - not the simulator!

1. Connect your iPhone/iPad via cable
2. In Xcode, select your device (not simulator)
3. Click **Run** (▶️ button)
4. App will install and launch on your device

### Step 2: Grant Permissions

When the app launches:
1. Tap to trigger permission request
2. Tap **Allow** for notifications
3. Check Xcode console for:
   ```
   📱 Device token: abc123def456...
   ✅ Device registered with backend successfully
   ```

### Step 3: Trigger a Notification

You need to create enough drawings to hit the threshold. For testing:

**Option A: Lower Thresholds for Testing**

Edit `backend/api/lib/notifications.ts` line 5:

```typescript
const THRESHOLDS = {
  animals: 3,      // Changed from 20 to 3 for testing
  mythical: 2,     // Changed from 15 to 2
  landmarks: 2,    // etc.
  vehicles: 2,
  food: 2,
  nature: 2,
  total: 5,        // Changed from 50 to 5
};
```

Redeploy: `vercel --prod`

**Option B: Manual Test**

Send a test request:
```bash
curl -X POST "https://cloud-view-backend.vercel.app/api/report-scan" \
  -H "Content-Type: application/json" \
  -d '{
    "region": "San Francisco",
    "category": "animals",
    "timestamp": "2025-11-09T10:30:00Z"
  }'
```

Repeat 3 times to hit the threshold.

### Step 4: Verify Notification

On your device, you should see:
- 🔔 Notification appears: **"Animals Everywhere! 🦁☁️"**
- Body: **"Lots of animal shapes spotted in San Francisco clouds today!"**

In Vercel logs:
```bash
vercel logs --follow
```

You should see:
```
📬 Notification trigger: { region: 'San Francisco', category: 'animals', ... }
✅ Sent notification to 1 devices in San Francisco
```

---

## Part 5: Production Deployment

### Before App Store Submission:

1. **Change APNs Environment to Production**
   ```bash
   vercel env add APNS_ENVIRONMENT production
   vercel --prod
   ```

2. **Restore Real Thresholds**
   - Change `THRESHOLDS` back to original values (20, 15, 10, etc.)
   - Redeploy: `vercel --prod`

3. **Test with TestFlight**
   - Upload build to App Store Connect
   - Invite beta testers
   - Verify push notifications work in TestFlight

4. **Submit to App Store**
   - Follow Apple's review guidelines
   - Explain your privacy-preserving approach in review notes

---

## 🔧 Troubleshooting

### "Device token not received"

**Check:**
- Running on real device (not simulator)
- Push Notifications capability enabled in Xcode
- Correct Bundle ID in Apple Developer Portal
- Provisioning profile includes Push Notifications

**Fix:**
1. Delete app from device
2. Clean build folder (Xcode → Product → Clean Build Folder)
3. Rebuild and run

### "APNs error: 403 Forbidden"

**Cause:** APNs authentication failed

**Fix:**
- Verify APNS_KEY_ID is correct
- Verify APNS_TEAM_ID is correct
- Verify APNS_KEY contains full .p8 file contents
- Make sure no extra spaces/newlines in environment variables

### "APNs error: 400 BadDeviceToken"

**Cause:** Using development certificate with production tokens (or vice versa)

**Fix:**
- If testing with Xcode: `APNS_ENVIRONMENT=development`
- If in App Store: `APNS_ENVIRONMENT=production`

### "Notification not appearing on device"

**Check:**
1. Notifications enabled in iOS Settings → Cloudoodle → Notifications
2. Device is not in Do Not Disturb mode
3. App is not currently in foreground (notifications silent when app is open)
4. Check Vercel logs for errors

### "Backend logs show 'APNs not configured'"

**Cause:** Environment variables not set correctly

**Fix:**
```bash
# Verify environment variables
vercel env ls

# If missing, add them:
vercel env add APNS_KEY_ID production
vercel env add APNS_TEAM_ID production
vercel env add APNS_KEY production
vercel env add APNS_ENVIRONMENT production

# Redeploy
vercel --prod
```

---

## 📊 Monitoring Push Notifications

### View Delivery Stats

**Vercel Dashboard:**
- https://vercel.com/dashboard → Your Project → Logs
- Search for "Sent notification to" to see delivery counts

**Upstash Console:**
- https://console.upstash.com/ → Your Database → Data Browser
- Check `region-devices:*` keys to see registered devices

### Check Device Registration

```bash
# In Upstash Data Browser, search for:
region-devices:san-francisco

# You'll see a set of device tokens registered for that region
```

---

## 🔒 Privacy & Security

### What We Store:
- ✅ Device tokens (needed to send notifications)
- ✅ Region/city (to target relevant users)
- ✅ Notification preference (enabled/disabled)

### What We DON'T Store:
- ❌ User names or emails
- ❌ Exact GPS coordinates
- ❌ Device identifiers (UDID, advertising ID)
- ❌ Personal information

### Data Retention:
- **Device tokens**: Stored until app is uninstalled or user opts out
- **Activity data**: Deleted after 24 hours
- **Notification tracking**: Deleted after 7 days

---

## 💰 Cost Impact

Push notifications add minimal cost:

**APNs:** Free from Apple (unlimited notifications)

**Backend:**
- Each notification = 2-3 Redis commands
- 1000 notifications/day ≈ 3000 Redis commands
- Still within free tier (10K commands/day)

**Vercel:**
- Minimal function invocation increase
- Still within free tier for most apps

---

## 🎉 You're All Set!

When everything is configured:

✅ Users install app → receive notification permission prompt
✅ Users grant permission → device token sent to backend
✅ Users create drawings → scan reports sent to backend
✅ Backend detects threshold → sends push notification
✅ All users in that region receive: **"Animals Everywhere! 🦁☁️"**

**Your privacy-first push notification system is complete!** 🚀

---

## 📚 Additional Resources

- [Apple Push Notifications Documentation](https://developer.apple.com/documentation/usernotifications)
- [APNs Provider API](https://developer.apple.com/documentation/usernotifications/setting_up_a_remote_notification_server)
- [Vercel Environment Variables](https://vercel.com/docs/projects/environment-variables)
- [Upstash Redis Documentation](https://docs.upstash.com/redis)
