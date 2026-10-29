# Cloudoodle 🌤️✨

Point your phone at the sky and Cloudoodle figures out what your clouds look
like — a turtle, a dragon, a castle — and traces an animated line drawing over
them, anchored in AR so it stays with the cloud as you look around.

> **Naming note:** the product is *Cloudoodle* (the `@main` app is
> `CloudoodleApp`). The Xcode project, scheme, and bundle identifier are still
> `CloudView` / `com.cloudview.app` for historical reasons.

## Features

### ☁️ On-device cloud recognition
- **Real cloud contours**: the Vision framework extracts the actual outline of
  a cloud from the camera frame (`CloudDetector`).
- **Recognition, fully on-device**: a permissively licensed vision-language
  encoder (SigLIP 2 base, Apache-2.0, compiled to Core ML) looks at the real
  photo of the cloud and names which drawable creature it resembles. **$0 per
  recognition, no network call, nothing leaves the device.** See
  [`docs/RECOGNITION.md`](docs/RECOGNITION.md). (Apple's MobileCLIP and
  FastVLM weights are research-only and are deliberately not used.)
- **Variety per scan**: instead of a strict top-1, the matcher softmax-samples
  from the top matches, so different looks at the same cloud can surface
  different ideas ("five viewers, five different things").
- **Animated line drawing**: each stroke grows along its length at pen speed
  — dark ink over a soft white halo so it reads on cloud and sky alike —
  sized and oriented to the real cloud through the camera intrinsics
  (`AnimatedDrawing`, `StrokeGeometry`, `CameraFrameGeometry`).

### 🌍 AR placement
- Drawings are anchored in world space along the camera ray, so they stay put
  in the sky as you pan and explore.
- A bounded pool of concurrent drawings (oldest evicted) keeps memory in check.

### ☀️ Weather (WeatherKit)
- Current conditions, temperature, humidity, and an hourly forecast.
- Uses Apple's **WeatherKit** — no API key to manage; it authenticates via the
  app's signing identity.
- Glassmorphic UI with a swipeable panel and playful, weather-aware copy.

### 🖼️ Save & share
- Snapshots of finished drawings are saved to a local gallery
  (`DrawingArchiveService` / `GalleryView`) and can be shared via the system
  share sheet.

### 🔔 Opt-in community notifications (privacy-preserving)
- Optionally reports **anonymous, city-level** scan themes (e.g. "animals") to a
  serverless backend, which aggregates regional activity and can send a push
  like *"lots of animals spotted in the sky near you today."*
- No images, no precise location, no account. See
  [`docs/PRIVACY.md`](docs/PRIVACY.md) and [`backend/`](backend/).

### 🎯 Kid-friendly by construction
- The recognition label set is a curated, family-friendly allowlist
  (`AnnotationHints.json` / the offline embedding tooling). No open-ended text
  generation, so output stays appropriate.

## Requirements

- iOS 16.0+
- An iPhone with ARKit support (AR does **not** run in the simulator)
- Xcode 15.0+, Swift 5.9+

## Setup

### 1. Open the project

```bash
open CloudView.xcodeproj
```

### 2. Add the recognition model (one-time, manual)

`CloudEmbedder.mlpackage` (~90 MB, ship it as an On-Demand Resource) and
`LabelEmbeddings.json` are **not** checked into git. Follow
[`docs/CLIP_SETUP.md`](docs/CLIP_SETUP.md) — two scripts and a drag into
Xcode. Until you do, recognition is off: the shape-template library still
draws creatures on clouds it can match, and clouds it can't match get an
honest "Cool cloud!" rather than a placeholder label.

### 3. Enable WeatherKit

WeatherKit needs the capability enabled once on the Apple Developer Portal for
the App ID matching `PRODUCT_BUNDLE_IDENTIFIER` (default `com.cloudview.app`):

1. <https://developer.apple.com/account/resources/identifiers/list>
2. Open (or create) the App ID → enable **WeatherKit** under *Capabilities* → Save.

The entitlement is already declared in `CloudView/CloudView.entitlements`. If
WeatherKit isn't reachable, DEBUG builds show sample weather and Release builds
show a "weather unavailable" placeholder.

### 4. Build and run

1. Select a physical iPhone as the target (AR requires a real device).
2. `Cmd + R`.
3. Allow camera, location, and motion permissions when prompted.
4. Point at the sky and hold steady.

## How to use

1. Launch on your iPhone.
2. Point at clouds and **hold still** for ~2 seconds.
3. Watch a line illustration draw itself over the cloud.
4. Pan around to discover more.
5. Swipe up the bottom panel for weather; open the gallery to revisit and share.

## Architecture

```
CloudView/
├── ViewModels/ARViewModel.swift        AR session, detection→recognition→draw loop
├── Services/
│   ├── CloudDetector.swift             Vision contour extraction of cloud shapes
│   ├── CloudClusteringService.swift    groups shapes into clusters (1:1 today)
│   ├── CloudCropRenderer.swift         real cloud photo → 224×224 buffer for the encoder
│   ├── ImageEmbeddingEncoder.swift     Core ML encoder (SigLIP 2 / CLIP), bundle or On-Demand Resource
│   ├── LabelEmbeddingMatcher.swift     cosine match + weighted-random sampling
│   ├── CloudRecognitionService.swift   orchestrator ([] when the model is absent)
│   ├── CloudLobeSplitter.swift         bank → lobes (brightness watershed)
│   ├── CloudSculptor.swift             "develop": creature sculpted + inked into the photo
│   ├── RecognitionToDrawingAdapter.swift  Interpretation → DrawingConcept
│   ├── WeatherService.swift            WeatherKit integration
│   ├── DrawingArchiveService.swift     local gallery persistence
│   ├── ScanReportingService.swift      opt-in anonymous scan reporting
│   ├── NotificationService.swift       APNs registration + handling
│   └── DiagnosticsService.swift        MetricKit diagnostics (no vendor)
├── Models/
│   ├── AnimatedDrawing.swift           line-mesh generation + reveal animation
│   ├── DrawingLibrary.swift            DrawingConcept wire format
│   ├── CloudCluster.swift / Interpretation.swift / AppState.swift
└── Views/                              ContentView, WeatherView, GalleryView, …

backend/                                Vercel edge functions + Upstash Redis + APNs
```

### Recognition pipeline

```
Real cloud crop → image encoder → unit-norm embedding
                                             ↓
        pre-computed text embeddings (one per drawable creature)
                                             ↓
             cosine similarity → top-K → weighted-random sample
                                             ↓
   DrawingTemplateLibrary assembles that creature on the cloud → AR drawing
```

If the top match is below a confidence floor, the app shows a gentle
"Cool cloud!" state rather than a confidently-wrong label. Full rationale,
cost analysis, and failure modes are in [`docs/RECOGNITION.md`](docs/RECOGNITION.md).

### Technologies

ARKit · RealityKit · Vision · Core ML (SigLIP 2) · WeatherKit · CoreLocation ·
CoreMotion · SwiftUI · Combine. Backend: TypeScript on Vercel edge runtime,
Upstash Redis, APNs.

## Backend

See [`backend/README.md`](backend/README.md) and
[`backend/DEPLOYMENT_GUIDE.md`](backend/DEPLOYMENT_GUIDE.md). It exposes health,
device registration, anonymous scan reporting, and regional-activity endpoints,
with rate limiting, atomic notification de-duplication, and end-of-day TTLs.
Typechecked and unit-tested in CI.

## Testing & CI

- **Backend**: `cd backend && npm install && npm run typecheck && npm test`
- **iOS**: build + unit tests run in CI on a macOS runner against an iOS
  simulator (see [`.github/workflows/ci.yml`](.github/workflows/ci.yml)). The
  workflow also fails fast if the App Icon slot is empty.

## Contributing

Contributions are welcome — please open a PR. When changing the recognition
label set, regenerate the embeddings with `tools/generate_label_embeddings.py`
(see [`docs/RECOGNITION.md`](docs/RECOGNITION.md)).

## License

MIT — see the LICENSE file.

---

Made with ☁️ and ❤️
