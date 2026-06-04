# Deferred — what we know but aren't doing now

This is the living "later" pile. Items get added here when we
deliberately decide not to do them in the current cycle, so we don't
forget them and so the reasoning lives next to the decision.

> When you ship one of these, **delete it from this list** and add a
> one-line entry to the bottom under **Done** so future-us can see the
> trajectory.

---

## Code polish — would land before TestFlight in an ideal world

### Onboarding refinements (item E)
- Explicit "Skip onboarding" button for QA — useful when running the
  app from Xcode and you don't want to walk through 8 pages on every
  launch. Today the only way is to clear `UserDefaults` for the
  `hasOnboarded` key.
- Per-page advance haptic (`.selectionFeedback`) to make the flow
  feel more tactile.
- Real Supabase username availability debounce (we hit the API on
  every chip tap; should debounce 350ms after typing stops).
- Smoother slide transitions — current `.move(edge:)` snap looks fine
  but could use a custom `AnyTransition` for the demo→finished swap.

### Push-notification copy variety (item F)
- `notify-nearby-users` edge function ships one template body shape.
  Should rotate among 3-4 poetic openers so users seeing multiple
  pushes in a week don't see the same phrasing twice.
- Time-of-day variants ("Golden hour in 20 min", "Big sky brewing
  overhead", "Anvil cloud climbing in the west") would each match a
  real weather condition the function already evaluates.

### Sentry breadcrumbs (item G)
- Wire crumb events at: sign-in success/failure, sign-out, scan
  attempt, scan success/failure (with `GeminiError` category), sighting
  upload start/finish, location grant, notification grant, account
  deletion.
- Today Sentry is initialized but receives only uncaught crashes —
  with breadcrumbs, production stack traces show the user's path into
  the error which makes triage much faster.

### Accessibility (item D)
- VoiceOver labels on all FlowingChips items (currently the chips read
  as plain text without context about whether they're selected).
- Dynamic-type audit — the editorial design hardcodes sizes; should
  scale gracefully under the larger accessibility sizes.
- Contrast: the warm-gold `CV.Color.accent` on `Color.black` passes
  WCAG AA at body sizes but should be spot-checked for the smaller
  mono labels.
- Reduce-motion guard around `HandDrawingView` — the pen-tip
  animation runs unconditionally; should fall back to a static stroke
  reveal when `accessibilityReduceMotion` is on.

### Error UX
- Retry-with-backoff on transient Gemini failures (429, 5xx). Today
  the user has to manually retry; one quiet auto-retry would smooth
  over the common rate-limit case.
- "Weather unavailable" subtle indicator in the drawer when
  `WeatherService.fetch` returns nil. Today the drawer just shows
  fewer cells; user can't tell whether weather is missing or there's
  no rain forecast.
- Better save-failure recovery — `CaptureFlowView.saveSighting`
  errors put the share button into a stuck-loading state if the user
  taps before the prior request resolves. Should disable the button
  while saving.

### Demo content variety (Onboarding page 7)
- The hard-coded Whale doodle is one of one. Could rotate among 3-4
  demo sightings (whale, dragon, bunny, sleeping cat) so users
  reinstalling the app see something new.

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
