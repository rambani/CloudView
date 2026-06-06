# Cloudoodle Privacy Policy

**Last updated: June 2026**

This is the working draft. It describes what Cloudoodle actually does
today; treat it as ready-to-host once the contact email and effective
date are finalized.

## What Cloudoodle does

Cloudoodle is a sky-watching app. Open the camera, point it at the
clouds, and the app analyzes the photo to identify a shape (a whale, a
dragon, a sleeping cat) and the current weather. You can keep
sightings to yourself or share them to a community feed.

## Information we collect

**Account information** — when you sign up, we collect:

- Your email address (used as your sign-in identifier)
- A username you pick (public, shown on your shared sightings)
- For Sign In with Apple users: the name and email Apple returns to
  us on first sign-in. Apple's "Hide My Email" private relay address
  is supported.

**Location** — with your permission, we read your device's location
to:

- Show cloud sightings near you in the map view
- Fetch local weather (WeatherKit, an Apple service)
- Attach a city + country label to sightings you share

Location is only read while the app is in use. We never read your
location in the background.

**Photos** — when you scan the sky:

- The photo is sent to Google's Gemini Flash API to identify a cloud
  shape. Google's data-use policy applies to this single request; the
  photo is not retained by Google beyond the response.
- If you tap "Share" on the result, the photo is uploaded to our
  storage bucket and shown in the public community feed. You can
  delete it at any time from your profile.
- If you don't share, the photo never leaves your device.

**Device push token** — if you allow notifications, we store an Apple
Push Notification token tied to your account so we can send you
golden-hour and big-sky nudges.

**Diagnostic data** — we use Sentry to capture crash reports. These
include stack traces and basic device information (iOS version, device
model). They do not include your photos, location, or any personal
content.

## Information we don't collect

- We don't track you across other apps or websites.
- We don't sell or share your information with advertisers.
- We don't profile you for ad targeting.
- We don't read your photo library; we only read individual photos
  you capture inside the camera tab.

## Where your data lives

- **Backend:** Supabase (Postgres, Storage). Hosted in the US region.
- **Cloud analysis:** Google Gemini Flash API, single-request use.
- **Weather:** Apple WeatherKit (queries are made from your device,
  not our server).
- **Crash reports:** Sentry.

## How to delete your data

- **In-app:** Settings → Delete Account. This deletes your profile
  row, every sighting you've shared, every photo you've uploaded, and
  every like you've cast. It cannot be undone.
- **By email:** write to the contact below and we'll process the
  request manually.

Deleting your account does not remove your data from Sentry's crash
reports; we operate Sentry with default 90-day retention, after which
those reports auto-expire.

## Children

Cloudoodle is rated 12+ on the App Store. We don't knowingly collect
information from anyone under 13. If you believe a minor has signed
up, contact us and we'll remove the account.

## Changes to this policy

We'll update the "Last updated" date at the top of this page when we
make material changes. Continued use of Cloudoodle after a change
means you've accepted the new policy.

## Contact

Privacy questions, deletion requests, or anything in between:

**hello@cloudoodle.app** *(placeholder — swap for the real address before publishing)*
