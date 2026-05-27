# CloudView iOS

A cloud-watching app where you scan the sky, Claude draws shapes onto actual clouds, and generates witty quips. Community sightings aggregated by city.

## Tech stack

| Layer | Technology |
|---|---|
| Platform | iOS 17+ / SwiftUI |
| AI Analysis | Anthropic API (claude-sonnet-4-6 vision) |
| Backend | Supabase (Postgres + Storage + Auth) |
| Maps | MapKit |
| Camera | AVFoundation |
| Location | CoreLocation |

## Prerequisites

- Xcode 15+
- [XcodeGen](https://github.com/yonaskolb/XcodeGen): `brew install xcodegen`
- An Anthropic API key (get one at console.anthropic.com)
- A Supabase project (free tier works fine)

## Quick start

```bash
cd ios
make open          # generates Xcode project and opens it
```

Then in Xcode: select the CloudView scheme → iPhone 15 Pro simulator → Run.

On first launch, go to Settings and enter:
1. Your Anthropic API key
2. Your Supabase project URL  
3. Your Supabase anon key

## Supabase setup

1. Create a project at [supabase.com](https://supabase.com)
2. Go to **SQL Editor** and run `supabase/migrations/001_initial.sql`
3. Go to **Storage** → confirm the `sighting-images` bucket was created as public
4. Copy your project URL and anon key from **Settings → API**

## Project structure

```
CloudView/
├── App/
│   ├── CloudViewApp.swift     — @main entry, environment setup
│   ├── AppState.swift         — @Observable global navigation state
│   └── ContentView.swift      — Root TabView + modal coordination
├── Core/
│   ├── Models/
│   │   ├── CloudAnalysis.swift   — Claude's JSON response model
│   │   ├── CloudSighting.swift   — Full sighting (photo + analysis + location)
│   │   └── AppUser.swift         — User profile + city stats
│   ├── Services/
│   │   ├── AnthropicService.swift  — Vision API call + JSON parsing
│   │   ├── SupabaseService.swift   — Auth, feed, upload, likes
│   │   ├── LocationService.swift   — CoreLocation + reverse geocoding
│   │   └── CameraService.swift     — AVFoundation capture
│   └── Extensions/
│       └── UIImage+Compress.swift
├── Features/
│   ├── Camera/          — Live preview + capture
│   ├── Analysis/        — Scanning animation + ResultView with AI drawing
│   ├── Feed/            — Community feed with like support
│   ├── Map/             — City cluster map (MapKit)
│   ├── Settings/        — API keys + Supabase auth
│   └── Profile/         — Collection grid + streak stats
└── UI/
    ├── DesignTokens.swift   — Colors, fonts, spacing
    ├── GlassDrawer.swift    — 3-position draggable frosted glass sheet
    └── CustomTabBar.swift   — Bottom tab bar with camera shortcut
```

## How the AI drawing works

1. User captures a photo with the camera
2. Photo is resized to 1568px max and base64-encoded
3. Sent to `claude-sonnet-4-6` with a structured prompt requesting:
   - Shape name, quip, cloud type, weather mood, watchability score
   - **Drawing elements** — arrays of `[x, y]` points normalized 0–1 relative to the image
4. Claude responds with JSON including smooth/straight path elements
5. `CloudOverlayView` uses SwiftUI `Canvas` + `Path` to render these paths
6. Paths animate in using `.trim(from: 0, to: progress)` — the same draw-on effect from the prototype
7. Shape name label is placed at Claude's suggested `label_x / label_y` position

## Key design decisions

- **Normalized coordinates**: Claude returns `[[x, y]]` points in 0–1 space so paths scale correctly to any screen size
- **Catmull-Rom splines**: When `smooth: true`, points are connected with curves (not jagged straight lines)
- **Caption fade**: The quip caption opacity drops as the glass drawer rises (same as the HTML prototype)
- **Local-first capture**: Images are stored as `localImageData: Data` immediately; Supabase upload is optional (the "Share with Community" button)
- **API key in UserDefaults**: Key never leaves the device; the user brings their own Anthropic key

## Running tests

```bash
make test
```

Tests cover JSON parsing for `CloudAnalysis` and the `CloudSighting` round-trip.
