# Cloud-fitted drawing system

How Cloudoodle turns a real cloud into a real-feeling creature drawing — one
that looks *discovered in* the cloud rather than pasted on top.

## The principle: pareidolia, not stickers

Cloud-watching feels magical because your brain locks a creature's form onto
the cloud's actual bumps. Two failure modes break that spell:

- **"Made up" recognition** — picking a creature that has nothing to do with
  the cloud's shape (e.g. CLIP run on a flat white blob returning a near-random
  label). The drawing then feels arbitrary.
- **"Pasted on" art** — dropping a generic clip-art creature over the cloud,
  ignoring its real outline.

This system avoids both by (1) choosing a creature *because the cloud's shape
resembles it*, and (2) warping that creature's line-art onto the cloud's real
form.

## Pipeline

```
cloud contour (Vision) ──► Hu-moment signature (CloudShapeSignature)
                                     │
                     ShapeMatcher: rank templates by shape distance
                                     │
                     best match + confidence ≥ floor?
                        │no                        │yes
                        ▼                          ▼
             fall back to CLIP/outline    SimilarityTransform.fit
             (RecognitionToDrawingAdapter)  template landmarks → cloud landmarks
                                                   │
                                     TemplateDrawingComposer (hybrid by confidence)
                                        strong → cloud-as-body
                                        weak   → full creature, warped
                                                   │
                                         DrawingConcept ──► AnimatedDrawing (existing reveal)
```

### 1. Retrieval — which creature does this cloud resemble?

`CloudShapeSignature` already computes **Hu's seven invariant moments** for a
contour (translation/rotation/scale/reflection invariant). `ShapeMatcher`
(`DrawingTemplateLibrary.swift`) compares the cloud's moments to each template's
precomputed moments in sign-preserving log space (the OpenCV `matchShapes`
metric), and converts distance to a 0–1 confidence via exponential decay.

Because Hu moments are rotation-invariant, a dragon-shaped cloud matches the
dragon template at any tilt — but orientation itself isn't distinguished (a
wide streak and a tall streak read as the same *form*). That's the right
trade-off for clouds. Below a confidence floor we decline to claim a creature
at all and fall back, so we never confidently draw a dragon on a shapeless blob.

### 2. Fitting — drape the art onto the real cloud

`TemplateFitting.swift`:

- **`CloudLandmarks`** reduces any contour to five stable reference points:
  centroid + the four extremes (top/bottom/left/right). The extremes are where
  a silhouette pushes out — the bumps the eye reads as head, feet, tail.
- **`TemplateWarp`** chooses the deformation. When the rich landmarks support
  it, a **`ThinPlateSpline`** — the smoothest 2-D warp that exactly maps each
  source landmark onto its target — drapes the template so appendages follow
  the cloud's individual bumps in eight directions. Coincident landmarks (a
  shape whose topmost point is also its top-left diagonal) are de-duplicated
  first, since they'd make the spline system singular. When too few distinct
  landmarks survive, it falls back to **`SimilarityTransform`**: the
  closed-form least-squares similarity (uniform scale + rotation + translation)
  solved as complex linear regression `w = c·z + d`, no matrix inversion.
  Both satisfy a common `PointWarp` interface so the composer is agnostic.

### 3. Composition — hybrid by confidence

`TemplateDrawingComposer.swift` picks how literally to fuse based on the match
score:

- **Strong match → cloud-as-body.** The cloud's own outline *is* the body
  (draw order 0); only the template's detail strokes (ears, eyes, tail) are
  drawn, warped to attach at the cloud's real extremes. Maximum pareidolia.
- **Weaker match → full creature, warped.** The template's silhouette is drawn
  as the body and warped to hug the cloud, with all details on top — so a loose
  resemblance still reads as a complete, recognizable creature.

The output is a `DrawingConcept` (ordered paths), which `AnimatedDrawing`
traces out stroke-by-stroke — body first, details after.

### 4. Rendering — size, orientation, legibility, reveal

Four things decide whether the result reads as *discovered in* the cloud or
pasted on top, and all four live between the detector and RealityKit:

- **Upright coordinates.** ARKit's capture buffer is landscape-right; Vision is
  told so (`VNImageRequestHandler(…, orientation: .right)`), so every contour,
  bounding box and landmark comes back in the portrait image the user sees.
  Without that, "top of the cloud" was the buffer's top — the screen's right —
  and ears landed on the side. `CameraFrameGeometry` holds the pure bridge
  (upright ↔ buffer pixels, world extents, anchor roll) and is unit-tested.
- **Size through the intrinsics.** The drawing's world size is
  `pixels / focalLength × distance`, the same pinhole math that places it. The
  previous `pixels × 0.01` constant made drawings roughly a third of the
  cloud's extent. Stroke width is specified in image pixels
  (`Style.lineWidthPixels`) and converted the same way, so lines keep a
  constant on-screen weight on any cloud.
- **Facing the camera.** The anchor takes the camera's rotation at creation
  (plus the upright roll). Previously the drawing lay in the world XY plane:
  correct when facing the session's starting heading, edge-on and invisible
  when facing 90° away.
- **Ink + halo, drawn at pen speed.** Each stroke is a dark ink ribbon over a
  wider soft-white halo (legible on white cloud *and* blue sky), with round
  joins and caps. Strokes are revealed by arc length — the ribbon mesh is
  rebuilt each frame to the pen's current position (`StrokeGeometry`, pure
  and tested) — rather than scaled/faded in, so the reveal looks drawn.

## Template schema

`CloudView/Resources/DrawingTemplates.json`:

```jsonc
{
  "version": 1,
  "templates": [
    {
      "label": "rabbit",              // shown to the user (capitalized)
      "category": "animals",          // mirrors scan-reporting themes
      "silhouette": [[x,y], ...],     // closed body outline, normalized 0–1
      "strokes": [                    // detail marks, warped onto the cloud
        { "role": "ear", "order": 1, "closed": false, "points": [[x,y], ...] }
      ]
    }
  ]
}
```

Coordinates are normalized 0–1, top-left origin, y-down — the same convention
as the cloud contour and the renderer. `silhouette` drives retrieval and is the
body in full-creature mode; `strokes` are the identifying details. A missing or
malformed file simply disables template drawings (the app falls back), so it's
safe to ship incrementally.

### Adding a creature

Don't hand-trace coordinates — use the offline pipeline tool:

```bash
cd tools
python3 build_drawing_templates.py --manifest your-art/manifest.json \
    --output ../CloudView/Resources/DrawingTemplates.json
```

It takes SVG art (from an AI image-gen → vectorizer flow, an illustrator's
export, or hand drawing), flattens curves/arcs/transforms, normalizes into the
schema's local space, simplifies (RDP, optional Chaikin smoothing), and emits
schema v2 (creatures + parts, the format `DrawingAssembler` consumes) with
validation. `--check` validates an existing v1 or v2 JSON. A runnable example
lives in `tools/example-art/`; schema v2 itself is documented in
`docs/GENERATIVE_DRAWING_DESIGN.md` and `CloudView/Models/DrawingParts.swift`.
The library precomputes Hu signatures at load; adding art needs no code change.

## Art sourcing (licensing)

The shipped starter set (rabbit, fish, cat, bird) is **placeholder** art whose
only job is to exercise the engine. Production art should be
**permissively-licensed line-art** authored to the schema above.

**Recommended: [Openclipart](https://openclipart.org) (CC0 1.0).** Public-domain
dedication — commercial use, modification, no attribution — with native SVG
downloads to trace path coordinates from.

Backups:
- **[SVG Repo](https://www.svgrepo.com)** — filter to **CC0/MIT only** and check
  each icon's license badge; collections are single-author, so style stays
  consistent.
- **[FreeSVG](https://freesvg.org) / [PublicDomainVectors](https://publicdomainvectors.org)** —
  CC0, same ecosystem as Openclipart, wider search coverage.
- **Quality option: [The Noun Project](https://thenounproject.com)** — most
  consistent single-line style, but the free tier is **CC BY (attribution
  required)**; buy the royalty-free license (~$4.99/icon) to ship without a
  credit line. Do **not** ship the free CC BY version without in-app attribution.

**Avoid:** OpenMoji (CC BY-SA — share-alike is viral into a closed-source app),
Streamline free tier (attribution required), and any CC BY-SA source.

**Due diligence (important):** CC0 tags on crowd-sourced sites are only as
trustworthy as the uploader. Someone can upload a copyrighted/trademarked
character (a franchise mascot) tagged CC0 — the tag doesn't make it legal. For
each creature, pick only **generic, non-branded** drawings that don't resemble
any known character. Because we re-trace simple geometric line drawings of
common animals, the derivative carries thin-to-no copyright of its own, which
further insulates the app — but the "don't trace a branded character" rule is
absolute.

### 5. Develop — the keepsake (sculpt mode)

The AR reveal is a sketch; the image worth sharing is the photo. After the
reveal, `CloudSculptor` "develops" the clean camera frame captured at drawing
time: the creature's strokes are rendered not as ink on top but as **shading
inside the cloud**, so the result is still a real photo of a real cloud that
now unmistakably looks like something. No model, no network, ~100 ms on the
GPU (Core Image).

```
stroke mask ─► narrow + wide blurs, mixed by local luminance ─► SHADOW (blue-grey)
(inside the cloud)   shifted up            ─► RIM LIGHT above each crease
(over sky)           wide blur             ─► WISP: thin cloud where an ear overhangs
small closed paths (eyes, nose)            ─► filled as pools, not outlines
local contrast inside the cloud, soft vignette toward it
```

On bright puff the crease is faded a little and a soft spread is added, so a
feature on a white dome is broader rather than fainter. The sculpt width
scales with the cloud (3% of its short side), floored at 2.4 ink widths.

`tools/sculpt_preview.py` is a Pillow twin of the exact recipe — same steps,
same constants (keep `SculptRecipe` and the Python header in sync). Run it on
a sky photo to iterate on the look without a device:

```bash
python3 tools/sculpt_preview.py --photo sky.jpg --out /tmp/sculpt.png
```

On top of the sculpt, the drawing itself is rendered as **thin white line**
(~0.16% of the long side, 88% opacity, faint glow) — the reference image's
medium. On sunlit cumulus the sculpt gives the line depth; on grey banks,
where shading vanishes into the cloud's own greys, the line carries alone.
`SculptRecipe.drawLineArt` toggles it; with it on the sculpt runs at
`underlayShadowStrength`.

The developed image becomes the share image (`ShareableDrawing.kind ==
.developed`) and shows as a thumbnail on the drawing capsule; the retake
button still takes a plain AR snapshot for a different framing.

### 6. Scenes — reaching across the sky

The reference image's dragon breathes toward a castle on the *next* cloud
bank. `NeighborCloud` carries the nearest other detected cloud into the
assembler in the primary cloud's normalized space; parts anchored
`neighbor` (the castle) sit on the neighbor's top, sized to it, and are
skipped when there is no neighbor — a castle needs its own bank. When a
neighbor exists the creature **faces it** (authored art faces left; the
assembly flips if the neighbor is to the right), so breath and gaze land
on the companion instead of a seeded coin flip. `ARViewModel.nearestNeighbor`
picks the neighbor: closest center within 2.5 primary widths.

Try it on a photo: `python3 tools/sculpt_preview.py --photo sky.jpg
--creature dragon --style final --out out.png` assembles the shipped art on
the photo's best blob with the second-best as the neighbor.

## Tuning knobs

| Where | Constant | Effect |
|---|---|---|
| `DrawingTemplateLibrary` | `confidenceFloor` (0.30) | Below this, decline and fall back. Raise to be more conservative. |
| `TemplateDrawingComposer` | `defaultStrongThreshold` (0.55) | Score ≥ → cloud-as-body; below → full creature. |
| `ShapeMatcher` | `scoreScale` (6.0) | How fast confidence decays with Hu distance. |
| `CloudCandidateSelection` | `maxAreaFraction` (0.60) | Blobs bigger than this are an overcast sheet, not a cloud. |
| `CloudDetector` | `adaptiveGain` (3.0) | Red-channel contrast around the frame mean for cloud/sky separation. |
| `AnimatedDrawing.Look` | ink/halo colors, `haloWidthFactor` (2.6) | Stroke legibility. |
| `SculptRecipe` | `shadowStrength` (0.78), `strokeWidthCloudFraction` (0.03), `wispStrength` (0.85) | How hard the developed photo carves the creature in. Iterate with `tools/sculpt_preview.py`. |

## Validation — what the retrieval step can and can't do today

`tools/validate_retrieval.py` is an exact port of the matcher. Run against the
shipped library (`--matrix --synthetic 300`) it shows:

- **Creatures are distinguishable from each other.** A silhouette would be
  mistaken "strongly" (≥ 0.55) for only 0.5 other creatures on average.
- **Rounded clouds mostly fail the floor.** For 300 synthetic cumulus-like
  blobs, the best score averages 0.20; 75% fall below the 0.30 floor, and the
  ones that pass concentrate on the blobbiest silhouettes (butterfly,
  unicorn, octopus). The cause is the Hu tail (h₅–h₇): near zero for any
  rounded shape, so its log-magnitude is noise and dominates the distance.
  A noise floor on the log moments doesn't help — at −8 the matcher accepts
  99% of blobs but calls 75% of them "octopus". No constant fixes this.

Conclusion: the matcher is honest (it declines rather than inventing) but
too weak to deliver the pareidolia promise for the most common clouds. The
next step is a descriptor that keeps orientation and local structure
(e.g. turning-function / Fourier descriptors of the resampled outline, or a
tiny learned embedding), chosen on **human-rated real clouds**, not synthetic
ones. The data path for that exists: DEBUG builds can record every contour the
pipeline acts on (Settings → Developer → *Record cloud contours*, then
*Export*), and `validate_retrieval.py --log … --html …` renders a rating
sheet with the top-3 silhouettes overlaid on each cloud.

## Limitations & next steps

- **Landmark-driven warp.** The thin-plate spline is keyed on nine semantic
  landmarks (centroid + axis/diagonal extremes). Denser correspondences —
  arc-length-resampled contour points aligned to a canonical start — would let
  the drape follow finer detail, at the cost of correspondence robustness.
- **Single-cloud clusters.** `CloudClusteringService` returns one cluster per
  cloud today; multi-cloud constellations ("those three clouds are a dragon")
  are a natural extension — the signature and rasterizer already handle clusters.
- **Retrieval could blend with CLIP.** When the MobileCLIP model is bundled, its
  score could be fused with the Hu-shape score for labels that exist in both the
  allowlist and the template library. (Without the model, a cloud the library
  declines gets an honest "Cool cloud!" — there is no stub recognizer in the
  shipping pipeline.)
- **Detection tuning on device.** The red-channel adaptive threshold and the
  center-weighted candidate choice replace a fixed brightness boost and
  "whatever Vision listed first"; both are principled but were authored
  without a device in hand. Check them against a few skies (clear with one
  puff, broken cumulus, hazy, overcast) and tune `adaptiveGain` /
  `maxAreaFraction` if needed.
- **Per-role attachment.** Stroke `role`s ("ear", "tail", …) are carried but not
  yet used to attach specific details to specific cloud landmarks; a role-aware
  local transform would sharpen the "it's really in the cloud" effect.
```
