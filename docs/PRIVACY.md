# Cloudoodle Privacy Policy

_Effective date: TBD (update when published)._
_App: Cloudoodle, bundle ID com.cloudview.app._

This policy describes what data Cloudoodle collects, why, where it is sent, and
how long it is kept. It is written to be honest enough that the App Store
Privacy Nutrition Label answers below are an accurate summary of it.

Plain-English summary:

- The app needs your camera and your approximate location to draw on clouds
  and to show local weather. Both happen on your device.
- The app does **not** create an account, does not ask for an email, and does
  not show ads.
- If you turn on the "see what others are spotting" community feature, the
  app sends an anonymous device token plus the *name of your city* to our
  backend so we can count how many drawings have appeared in your area and
  optionally send a notification when things get busy. We never store your
  exact location, name, email, or any other personal data.
- You can turn the community feature off at any time. When you do, we stop
  collecting new data and your device token expires automatically.

The rest of this document is the formal version.

## 1. Data that stays on your device

Cloudoodle uses the following information only on your device. None of it
leaves the device.

| Data | Used for | Stored? |
|---|---|---|
| Camera frames | AR drawing — detecting cloud outlines via Vision framework | Discarded immediately after analysis |
| Motion sensor (gravity) | Detecting whether the phone is pointing up at the sky | Not stored |
| Precise location (CoreLocation) | Querying Apple WeatherKit for local weather and computing local sunrise/sunset | Held only for the duration of one weather refresh |
| Notification settings | Remembering whether you allowed notifications | iOS-managed; not transmitted |

## 2. Data sent to Apple (WeatherKit)

When you grant location permission, the app calls Apple's WeatherKit service
with your coordinates to fetch current conditions and a short forecast. This
request is governed by Apple's privacy policy, not ours. We do not see, log,
or store the coordinates server-side.

WeatherKit attribution is shown in the weather panel, as required by Apple.

## 3. Data we send to our backend — only if you opt in

The "community" feature is **off by default**. When you turn it on in the
app's settings:

| Data | Sent to | Why |
|---|---|---|
| Anonymous push-notification token (APNs device token) | Our backend at https://cloud-view-backend.vercel.app | So the backend can send "lots of activity near you" notifications |
| City-level region (e.g. "Brooklyn", "Hamburg") derived by reverse-geocoding your coordinates | Same | So aggregated counts can be bucketed by area |
| Drawing category (one of: animals, mythical, landmarks, vehicles, food, nature) | Same | So we can tell what people are spotting locally |
| Timestamp | Same | So we can window the aggregation to the current day |

We **do not** send:
- Your exact GPS coordinates
- Your name, email, phone, Apple ID, or any account identifier
- The image of the cloud or the camera frame
- The specific drawing name (only the category)

The data is bucketed by region and date. Per-device records expire 90 days
after the last app launch. Per-day aggregates expire at the end of the UTC
day. We rate-limit requests per IP and per region to discourage spoofing.

To opt out, toggle the community feature off in app settings. The next time
the app launches, the device record will be removed from the per-region set
used for notifications.

## 4. Data we do not collect

- No analytics SDK is integrated.
- No advertising SDK is integrated.
- No third-party tracker is integrated.
- We do not show ads.
- We do not sell or share data with third parties.

## 5. Children's privacy

Cloudoodle is rated 4+ on the App Store. The community feature defaults to
off; without it, the app collects nothing and sends nothing. We do not
knowingly process personal information from children under 13 without
verifiable parental consent.

If you are a parent and believe your child has enabled the community feature
and you want their data removed, email [TBD privacy contact] and we will
delete any record associated with the device token within 30 days.

## 6. Data retention

- Per-device records on the backend: 90 days after last update.
- Per-day regional aggregates: end of the UTC day on which they were created.
- Apple WeatherKit and CLGeocoder requests: governed by Apple, not us.

## 7. Your rights

You can:
- Disable the community feature at any time in app settings.
- Revoke camera, location, or notifications permission at any time in iOS
  Settings → Cloudoodle.
- Email [TBD privacy contact] to request deletion of any record tied to your
  current APNs device token. We will action this within 30 days.

We will honor deletion requests under GDPR, CCPA, and Apple's developer
agreements regardless of jurisdiction.

## 8. Changes

We will update this page if the data we collect changes and bump the
"Effective date" at the top.

---

# Appendix: App Store Privacy Nutrition Label answers

This is the exact set of checkboxes the App Store Connect Privacy form needs.
Use these as your answers when submitting.

### Data Used to Track You

**Answer: None.**

(Tracking, in App Store terminology, means linking user/device data with
data from other companies' apps or sites, or sharing it with data brokers.
Cloudoodle does neither.)

### Data Linked to You

**Answer: Only if the user opts in.**

The App Store form does not have an "only if opted in" option, so the
correct answer is **yes**, with the following categories declared:

- **Identifiers → Device ID** (APNs push token)
- **Location → Coarse Location** (city-level region name derived from coords)
- **Usage Data → Product Interaction** (drawing category counts)

Purpose for all three: **App Functionality**.

### Data Not Linked to You

**Answer: None.**

(Anything we send is paired with the device token, which is per-install and
identifying enough to count as "linked." We choose to be honest about this
rather than claiming an anonymity property the architecture doesn't enforce.)

### If we add analytics later

If we ever integrate an analytics SDK (e.g. for crash reporting or product
analytics), we must update this document AND the nutrition label to add the
relevant categories — typically:
- Diagnostics → Crash Data
- Diagnostics → Performance Data
- Usage Data → Other Usage Data
