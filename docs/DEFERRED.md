# Deferred — what we know but aren't doing now

This is the living "later" pile. Items get added here when we
deliberately decide not to do them in the current cycle, so we don't
forget them and so the reasoning lives next to the decision.

> When you ship one of these, **delete it from this list** and add a
> one-line entry to the bottom under **Done** so future-us can see the
> trajectory.

---

## Code polish — would land before TestFlight in an ideal world

### Onboarding refinements (item E — partial)
- Smoother slide transitions — current `.move(edge:)` snap looks fine
  but could use a custom `AnyTransition` for the demo→finished swap.

### Accessibility (item D — partial)
- Dynamic-type audit — the editorial design hardcodes sizes; should
  scale gracefully under the larger accessibility sizes. Likely
  requires switching body text to `.font(.body)` style families while
  keeping the serif headlines at fixed sizes (intentional editorial
  choice). Significant rework — not landing in this cycle.
- Contrast: the warm-gold `CV.Color.accent` on `Color.black` passes
  WCAG AA at body sizes but should be spot-checked for the smaller
  mono labels.
- VoiceOver sweep extended to: FeedView gear, ContentView notification
  toast dismiss, CaptureFlowView close + share + shutter, DemoPage
  sky panel. Profile/Map/Settings still rely on default inference
  beyond what AppKit gives us via labels on the inner views.

### Demo content variety
*(shipped — Whale / Dragon / Bunny / Sailboat rotate; tap to swap to
a different one each time. Adding more shapes is a copy-paste away.)*

---

## Operational — required to launch

These are not code work; they need accounts, portals, and credentials
only the human can provide. Tracked in `TASKS.md` already; mirrored
here so future-us can see the full punch list in one place.

- [ ] Fill `ios/Config.xcconfig` with real Gemini / Supabase / Sentry keys
- [ ] Run Supabase migrations 001-009
- [ ] Create `sighting-images` storage bucket + 3 policies
- [ ] Deploy `notify-nearby-users` and `delete-account` edge functions
- [ ] Set APNs secrets in Supabase
- [ ] Create database webhook for `sightings INSERT`
- [ ] Apple Developer Portal: App ID `com.cloudoodle.app` with Push,
      WeatherKit, Sign In with Apple capabilities
- [ ] APNs `.p8` key generated and stored in Supabase secrets
- [ ] Configure Apple auth provider in Supabase (Services ID, Team ID,
      Key ID, `.p8` private key)
- [ ] App Store Connect listing + screenshots + privacy declarations
- [ ] Privacy Policy + Terms of Service hosted at a public URL (drafts
      shipped — needs hosting)
- [ ] Sentry DSN added to `Config.xcconfig`
- [ ] TestFlight build from a physical device

---

## Replacement work (already shipped a placeholder)

These have a usable-but-temporary version landed. Future work is to
swap them out, not to add new functionality.

- **App icon** — placeholder generated procedurally (cloud silhouette
  on a soft-blue gradient). Designer should replace with a real
  brand-finished icon before submission.
- **Privacy Policy** + **Terms of Service** — drafts shipped under
  `docs/`. Hosting URL is still a placeholder; once hosted, swap the
  `PRIVACY_URL` / `TERMS_URL` constants in `LegalLinks.swift`.
- **Bundled username suggestions** — five suggestions drawn from a
  pool of 16. Future work: server-driven suggestion list so we can
  refresh wordmarks without shipping a build.

---

## Done

- 2026-06: Onboarding flow (8 pages), error UX polish (Gemini typed
  errors, like toggle revert, feed pagination banner), iOS 26
  FoundationModels quip generation
- 2026-06: Cloudoodle rebrand from CloudView (bundle ID, module name,
  surfaces)
- 2026-06: Privacy/ToS drafts, placeholder app icon, Settings polish
  (legal links, app version, restart-onboarding affordance)
- 2026-06: Sentry breadcrumbs (Telemetry helper wired across
  auth/scan/upload/permission paths), push-notification copy variants
  (4-template rotation deterministic per sighting), reduce-motion
  guard on HandDrawingView, onboarding advance haptic, username
  availability debounce (350 ms), Gemini retry-with-backoff on 429 /
  5xx / network, "Weather unavailable" drawer notice, save-flow
  re-entrancy guard, FlowingChips VoiceOver collapse.
- 2026-06: Demo content variety (4-shape rotation on Onboarding
  page 7), skip-onboarding affordance in chrome, VoiceOver labels on
  icon-only buttons (FeedView gear, capture close, capture shutter,
  share, notification dismiss), DemoPage A11y as a tappable element.
