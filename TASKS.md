# Cloudoodle — Tasks Before Shipping

These are the manual steps that require accounts, portals, or credentials
that can't be automated. Complete them in order.

---

## 1. Fill in API Keys

Copy the xcconfig template and fill in your credentials:

```bash
cp ios/Config.xcconfig.example ios/Config.xcconfig
```

Edit `ios/Config.xcconfig`:

| Key | Where to get it |
|-----|----------------|
| `GEMINI_API_KEY` | https://aistudio.google.com/app/apikey — free, no credit card |
| `SUPABASE_URL` | Supabase Dashboard → Settings → API → Project URL |
| `SUPABASE_ANON_KEY` | Supabase Dashboard → Settings → API → anon key |
| `SENTRY_DSN` | https://sentry.io → New Project → iOS → DSN string |

Then regenerate the Xcode project:

```bash
cd ios && xcodegen generate
```

---

## 2. Supabase — Run Migrations

In your Supabase Dashboard → SQL Editor, run the migrations **in order**:

1. `ios/supabase/migrations/001_initial.sql` — tables, RLS policies, all functions
2. `ios/supabase/migrations/002_push_notifications.sql` — push notification support
3. `ios/supabase/migrations/003_delete_account.sql` — account deletion function
4. `ios/supabase/migrations/004_toggle_like_locking.sql` — concurrency fix for likes
5. `ios/supabase/migrations/005_delete_storage_on_account_delete.sql` — delete uploaded images on account deletion
6. `ios/supabase/migrations/006_toggle_like_auth_check.sql` — security fix: prevent acting on other users' behalf via toggle_like RPC
7. `ios/supabase/migrations/007_restrict_profiles_within_radius.sql` — security fix: restrict profiles_within_radius to service role to prevent device_token leak
8. `ios/supabase/migrations/008_hide_private_profile_columns.sql` — security fix: column-level grants on profiles so other users can't read device_token / last_latitude / last_longitude
9. `ios/supabase/migrations/009_blocked_users.sql` — UGC: blocked_users table + view/RPCs that filter out blocked authors (App Review Guideline 1.2)

---

## 3. Supabase — Create Storage Bucket

In Supabase Dashboard → Storage:

1. Click **New bucket**
2. Name: `sighting-images`
3. Toggle **Public bucket** ON
4. Click **Save**

Then in SQL Editor, run the storage policies (commented out at the bottom of `001_schema.sql`):

```sql
CREATE POLICY "sighting_images_select" ON storage.objects FOR SELECT
    USING (bucket_id = 'sighting-images');

CREATE POLICY "sighting_images_insert" ON storage.objects FOR INSERT
    WITH CHECK (bucket_id = 'sighting-images'
        AND auth.uid()::text = (storage.foldername(name))[1]);

CREATE POLICY "sighting_images_delete" ON storage.objects FOR DELETE
    USING (bucket_id = 'sighting-images'
        AND auth.uid()::text = (storage.foldername(name))[1]);
```

---

## 4. Supabase — Deploy Edge Functions

```bash
cd ios
supabase login
supabase link --project-ref <your-project-ref>

supabase functions deploy notify-nearby-users
supabase functions deploy delete-account
```

Set the APNs secrets for push notifications:

```bash
supabase secrets set APNS_KEY_ID=<10-char key ID>
supabase secrets set APNS_TEAM_ID=<10-char Apple team ID>
supabase secrets set APNS_BUNDLE_ID=com.cloudoodle.app
supabase secrets set APNS_PRIVATE_KEY="$(cat /path/to/AuthKey_XXXXXXXX.p8)"
# Set to "development" while testing with Debug builds (sandbox tokens).
# Leave unset or set "production" for App Store / TestFlight builds.
supabase secrets set APNS_ENVIRONMENT=production
```

---

## 5. Supabase — Create Database Webhook

In Supabase Dashboard → Database → Webhooks → Create webhook:

- **Name**: `notify-nearby-users`
- **Table**: `sightings`
- **Events**: `INSERT`
- **URL**: `https://<project-ref>.supabase.co/functions/v1/notify-nearby-users`
- **HTTP Headers**: `Authorization: Bearer <service_role_key>`

---

## 6. Apple Developer Portal

Go to https://developer.apple.com → Certificates, Identifiers & Profiles:

### App ID
1. Create App ID with bundle ID: `com.cloudoodle.app`
2. Enable capabilities:
   - **Push Notifications**
   - **WeatherKit**

### APNs Auth Key
1. Keys → Create a key
2. Enable **Apple Push Notifications service (APNs)**
3. Download the `.p8` file — **you can only download it once**
4. Note the **Key ID** and your **Team ID**
5. Use these in Step 4 (Supabase secrets above)

---

## 7. App Store Connect

Go to https://appstoreconnect.apple.com → My Apps → New App:

1. Fill in: Name, bundle ID (`com.cloudoodle.app`), SKU, language
2. Set **Age Rating**: `12+` (or `17+` if keeping user-generated content open)
3. Add **Privacy Policy URL** — you must host this publicly (see Step 8)
4. Fill in: App description, keywords, category (`Photo & Video`)
5. Upload screenshots: 6.7" (required), 6.1", 5.5" — one set covers most devices

**Data collection declarations** in App Privacy section:
- Location: Precise, linked to identity, app functionality
- Photos/Videos: linked, app functionality  
- Email: linked, app functionality
- User ID: linked, app functionality

---

## 8. Privacy Policy & Terms of Service

Draft text is already shipped — see `docs/PrivacyPolicy.md` and
`docs/TermsOfService.md` (mirrored into the app bundle at
`ios/Cloudoodle/Resources/Legal/*.md`, viewable in-app under
**Settings → Legal**). What remains is hosting + swapping placeholders.

1. Edit the contact email in both `docs/PrivacyPolicy.md` and
   `docs/TermsOfService.md` (replace `hello@cloudoodle.app`).
2. Fill in the governing-law jurisdiction in
   `docs/TermsOfService.md` ("Governing law" section).
3. Host both at a stable public URL (Notion + custom domain, Vercel
   static site, GitHub Pages — all fine).
4. Edit `ios/Cloudoodle/Features/Settings/LegalLinks.swift` and fill in
   `privacyURL` and `termsURL`. With both set, the in-app Settings rows
   open Safari to the hosted version; the bundled markdown stays as a
   fallback that nobody normally hits.
5. Paste the privacy URL into App Store Connect → App Privacy.

---

## 9. Sentry Crash Reporting

1. Create account at https://sentry.io (free tier: 5,000 errors/month)
2. Create a new project → Platform: **Apple (Cocoa)**
3. Copy the **DSN** string
4. Add it to `ios/Config.xcconfig` as `SENTRY_DSN = <your dsn>`

Sentry is already wired up in `CloudoodleApp.swift` — it activates automatically when a non-empty DSN is present.

---

## 10. Content Moderation (Recommended Before Public Launch)

The AI generates shape names and quips that go into the public feed. Edge cases are rare but possible.

**Recommended approach:**
- Add a "Report" button to feed cards (call `SupabaseService.reportSighting(id:reason:)` — already implemented)
- In Supabase Dashboard → Table Editor → `sighting_reports`, review reports manually
- For scale: integrate [OpenAI Moderation API](https://platform.openai.com/docs/guides/moderation) into the `notify-nearby-users` Edge Function to screen quips before they trigger notifications

---

## 11. Sign In with Apple (Required if email/password is offered)

App Review Guideline 4.8 *requires* Sign In with Apple when you offer
email/password authentication (which this app does). The app will be
rejected on submission without it. iOS-side code is now in place; the
remaining work is on the Apple Developer Portal and Supabase Dashboard.

1. Enable **Sign In with Apple** capability in the App ID (Apple Developer Portal)
2. ✅ Entitlement is in `Cloudoodle.entitlements` and `Cloudoodle.Release.entitlements`
3. ✅ `ASAuthorizationAppleIDProvider` flow is implemented in
   `Features/Settings/SignInWithAppleButtonView.swift` and rendered by `AuthForm`
4. Enable Apple as a provider in Supabase Dashboard → Authentication → Providers:
   - **Services ID**: create one in Apple Developer Portal under
     Identifiers → Services IDs. This is *separate* from the app's
     bundle ID and is what Supabase verifies against.
   - **Team ID**: your 10-character Apple Team ID
   - **Key ID**: from the Sign In with Apple key you create in
     Certificates, Identifiers & Profiles → Keys
   - **Private key**: the `.p8` contents of that key
5. Test sign-in on a physical device — Apple Sign In doesn't run on
   the Simulator for tokens that Supabase will accept

---

## 12. TestFlight Before Submission

1. Archive in Xcode (Product → Archive) with **Release** configuration
2. Upload to App Store Connect via Xcode Organiser
3. Add internal testers in TestFlight
4. Test on a **physical device** — WeatherKit and push notifications do not work in Simulator
5. Verify: capture → scan → drawing → drawer → share → notification round-trip

---

## Summary Checklist

- [ ] `Config.xcconfig` filled in with real keys
- [ ] Supabase migrations 001, 002, 003, 004 run
- [ ] Storage bucket `sighting-images` created with policies
- [ ] Edge Functions `notify-nearby-users` and `delete-account` deployed
- [ ] APNs secrets set in Supabase
- [ ] Database Webhook created for `sightings` INSERT
- [ ] Apple App ID created with Push + WeatherKit capabilities
- [ ] APNs Auth Key (p8) downloaded and stored safely
- [ ] App Store Connect listing created with privacy declarations
- [ ] Privacy Policy hosted at a public URL
- [ ] Terms of Service hosted at a public URL
- [ ] Sentry DSN added to xcconfig
- [ ] Tested on physical device via TestFlight
