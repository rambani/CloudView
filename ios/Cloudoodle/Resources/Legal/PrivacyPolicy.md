# Cloudoodle Privacy Policy

**Last updated: June 2026**

This is the working draft. It describes what Cloudoodle actually does
today; treat it as ready-to-host once the contact email and effective
date are finalized.

## What Cloudoodle does

Cloudoodle is a personal sky-watching app. Once a day you open the
camera, point at the clouds, and Cloudoodle analyzes the photo to
identify a shape (a whale, a dragon, a sleeping cat) and develops it
into a Polaroid stamped with the date and weather. You keep your
stack on-device and can write a short note about the day.

This is intentionally a quiet, single-user app: there is no community
feed, no public profile, and no way for other users to see your
Polaroids or notes.

## Information we keep on your device

Most of what Cloudoodle holds about you never leaves your phone:

- **Your Polaroids and notes.** Captured photos, the developed
  versions with ink overlays, your daily notes, and the AI's
  shape/weather metadata are all saved in a local journal file in
  the app's Documents folder. Uninstalling the app removes them.
- **Your subscription state and quota.** Cached locally. The
  subscription itself is managed by Apple (see below).
- **Your daily reminder time** (if you've enabled one). Used to
  schedule a local notification on your device. No server involved.

## Information sent to third parties when you scan

To turn a captured photo into a Polaroid, the cropped region around
the cloud is sent to our backend, which forwards it to **Google
Gemini** for processing within the same request:

- Gemini analyzes the cropped image to identify a shape name, cloud
  type, and watchability score, then produces the developed version
  with delicate ink overlays tracing the identified shape. Google's
  data-use policy applies to those requests; the image is not
  retained by Google beyond the responses.

Google does not receive your name, account information, exact
location, or note text — only the cropped image bytes and our
in-prompt instructions. Our backend keeps no copy of the cropped
image; it's discarded once the response is returned to your device.

We use Apple's **WeatherKit** to read the current weather and
hourly forecast at your location. Those queries are made directly
from your device to Apple — we do not see them or proxy them.

## Account

Cloudoodle uses a Supabase-backed account to call our `develop-
polaroid` backend (which holds the AI API keys server-side so you
don't have to). There are two flavors:

- **Anonymous account** — created automatically the first time you
  scan. No email, no password, no name. We get a UUID we can use
  to attribute a scan to a stable identity, and that's it.
- **Linked account** — at any time in Settings → Sign In you can
  attach an email/password or Sign In with Apple to your existing
  anonymous account. We then also collect:
    - Your email address (the sign-in identifier).
    - A username you pick (used internally; not displayed to anyone
      else in this version of the app).
    - For Sign In with Apple users: the name and email Apple returns
      to us on first sign-in. Apple's "Hide My Email" private relay
      address is supported.

Linking lets us preserve your Polaroid stack across device
reinstalls (when we ship sync) and powers the personalized
regional-summary daily reminder (see below).

## Optional metadata contribution

After each Polaroid is developed — and only if you are signed in —
we send three small fields to our backend:

- The AI's shape description (e.g. "a whale drifting").
- Your city name (e.g. "Brooklyn"). Never precise coordinates.
- The capture timestamp.

We **do not** send the photo, the developed Polaroid, your note,
your exact location, your device token, your email, or anything
else. This metadata is used only to compute regional summaries
("23 people near Brooklyn saw birds in the sky today") that can
later be delivered as a daily reminder push.

You can opt out by signing out of your account; signed-out users
contribute no metadata.

## Location

With your permission, we read your device's location to:

- Fetch local weather via Apple WeatherKit.
- Resolve a coarse city name (via Apple's reverse geocoder) that we
  stamp on your Polaroid and — if you're signed in — send as part
  of the metadata contribution described above.

Location is only read while the app is in use. We never read your
location in the background. Precise coordinates never leave your
device.

## Subscription and payment

Cloudoodle Unlimited is a subscription managed by Apple through the
App Store. Your purchase, renewal, and cancellation are handled by
Apple — we never see your payment method or card details. The app
verifies your subscription locally using Apple's signed receipts;
no payment data is sent to our backend.

You can cancel anytime in iOS Settings → your Apple ID →
Subscriptions.

## Notifications

If you enable the daily reminder in Settings, Cloudoodle schedules
a **local** notification at the time you pick. It fires from your
device; the notification text is generated locally. No server-side
push is involved in this version.

In a future version, we may send a regional-summary push as
described above. That would require your subscription remaining
active to opt in.

## Diagnostic data

We use Sentry to capture crash reports. These include stack traces
and basic device information (iOS version, device model). They do
not include your photos, location, account details, or note text.

## Information we don't collect

- We don't track you across other apps or websites.
- We don't sell or share your information with advertisers.
- We don't profile you for ad targeting.
- We don't read your photo library; we only read photos you
  capture inside the Cloudoodle camera.
- We don't store, upload, or share your notes or your photos.

## Where the small amount of data we do collect lives

- **Backend (only if you're signed in):** Supabase (Postgres). Hosted
  in the US region.
- **Cloud analysis + develop (per-Polaroid):** Google Gemini.
  Single-request use with no retention.
- **Weather:** Apple WeatherKit, queried from your device.
- **Crash reports:** Sentry.

## How to delete your data

- **Your on-device Polaroids and notes:** uninstall the app.
- **Your account and contributed metadata** (if you have an
  account): Settings → Account → Delete Account. This removes your
  profile row and every `sighting_metadata` entry you've
  contributed. Cannot be undone.
- **By email:** write to the contact below and we'll process the
  request manually.

Deleting your account does not remove data from Sentry's crash
reports; we operate Sentry with default 90-day retention, after
which those reports auto-expire.

## Children

Cloudoodle is rated 4+ on the App Store. We don't knowingly collect
information from anyone under 13. If you believe a minor has signed
up, contact us and we'll remove the account.

## Changes to this policy

We'll update the "Last updated" date at the top of this page when
we make material changes. Continued use of Cloudoodle after a
change means you've accepted the new policy.

## Contact

Privacy questions, deletion requests, or anything in between:

**hello@cloudoodle.app** *(placeholder — swap for the real address before publishing)*
