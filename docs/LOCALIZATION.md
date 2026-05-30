# Localization

Cloudoodle uses Xcode's **String Catalog** (`Localizable.xcstrings`) for
all UI strings. Build settings include `LOCALIZATION_PREFERS_STRING_CATALOGS = YES`
so Xcode auto-extracts new strings as they appear in code.

## How strings get localized

SwiftUI is doing the heavy lifting. Any literal you pass to `Text(...)`,
`.accessibilityLabel(...)`, `.accessibilityHint(...)`, `Button(_:action:)`
title, etc. is treated as a `LocalizedStringKey` — Xcode/iOS look it up
in the String Catalog at runtime against the active locale and use the
device's English fallback when no translation exists for that locale.

This means **you don't need `NSLocalizedString(...)` calls** in code.
Just use string literals and they work.

```swift
// Already localizable:
Text("Settings")
.accessibilityLabel("Close instructions")
Button("Done") { dismiss() }

// Still localizable, with substitution:
Text("Cloudoodle drew \(label)")
```

## Adding a new language

In Xcode → project settings → CloudView target → **Info** tab → **Localizations**:

1. Click `+` and pick the language (e.g. Spanish, German).
2. Open `CloudView/Resources/Localizable.xcstrings`.
3. For each key, the new language column starts empty. Fill in
   translations. The catalog is JSON-backed but Xcode renders it as a
   table; no manual JSON editing needed.

That's it — next build, the app uses the new language when the device
locale matches.

## Adding a new string in code

Just use it. Xcode's build-time catalog-update pass detects the new
literal on the next build and adds it to `Localizable.xcstrings` with
`extractionState : "automatic"`. Verify it landed in the catalog after
the build; if it did, you're done.

If you want to keep the catalog tidy (recommended for review), open the
catalog after extraction and mark the new entry `manual` so the
auto-extraction doesn't churn its metadata.

## What's NOT localized today

These are deliberately not in the catalog because they're either
user-data or independent of UI language:

- **Recognition labels** (`turtle`, `dragon`, etc.) returned from the
  CLIP matcher. Today they render in English regardless of locale. To
  localize, add a label translation table keyed by `Interpretation.label`
  and look up in the UI layer. The labels themselves stay as English keys
  in the kid-safe allowlist (single source of truth).
- **City names** from `CLGeocoder` reverse-geocoding. Apple returns
  these in the device locale already.
- **Weather condition strings** from WeatherKit (`current.condition.description`).
  WeatherKit returns localized values for the active locale.

## Translation pipeline

For shipping translations, the practical workflow is:

1. Export the catalog (`File → Export → Localizations…` in Xcode) →
   produces `.xliff` files per language.
2. Send the `.xliff` to translators or an agency (Crowdin, Lokalise,
   Smartling all import `.xliff` directly).
3. Import their finished `.xliff` back (`File → Import → Localizations…`).
4. Build and verify.

`.xliff` is the industry-standard format; every translation service
accepts it.

## Priority languages for kids' app market

If budget is bounded, my recommendation by ROI for a 4+ kids' app:

1. **Spanish** (es) — single largest non-English iOS market segment in
   the US plus all of LatAm
2. **Portuguese (Brazil)** (pt-BR) — large mobile market
3. **French** (fr) — France + Quebec + Africa
4. **German** (de) — Germany has high per-capita app spending
5. **Japanese** (ja) — high app spending, but the cultural fit for
   "cloud watching" is even stronger than other markets
6. **Simplified Chinese** (zh-Hans) — China market is complex (App
   Store rules etc.) but the addressable user base is huge

Skipping localization just means losing those markets, not breaking the
app. The fallback is always English.
