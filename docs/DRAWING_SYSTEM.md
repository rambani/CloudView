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
- **`SimilarityTransform`** fits the least-squares similarity (uniform scale +
  rotation + translation, no reflection or shear) mapping the *template's*
  landmarks onto the *cloud's*. It's solved in closed form as complex linear
  regression `w = c·z + d` — no matrix inversion, fully testable. Applying it to
  the template's strokes lands ears at the cloud's top, a tail off its side
  bump, and so on.

### 3. Composition — hybrid by confidence

`TemplateDrawingComposer.swift` picks how literally to fuse based on the match
score:

- **Strong match → cloud-as-body.** The cloud's own outline *is* the body
  (draw order 0); only the template's detail strokes (ears, eyes, tail) are
  drawn, warped to attach at the cloud's real extremes. Maximum pareidolia.
- **Weaker match → full creature, warped.** The template's silhouette is drawn
  as the body and warped to hug the cloud, with all details on top — so a loose
  resemblance still reads as a complete, recognizable creature.

The output is a `DrawingConcept` (ordered paths), which the existing
`AnimatedDrawing` renderer traces out stroke-by-stroke — body first, details
after — with no renderer changes.

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

1. Get clean line-art (see **Art sourcing** below).
2. Trace its body outline into `silhouette` and its details into `strokes`,
   normalized 0–1. Keep the silhouette to ~10–24 points and details minimal —
   the cloud carries the body in the common case.
3. Rebuild. The library precomputes the Hu signature at load; no code change.
4. Add a decode/compose case to `TemplateDrawingTests` if the creature has an
   unusual shape you want to lock in.

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

## Tuning knobs

| Where | Constant | Effect |
|---|---|---|
| `DrawingTemplateLibrary` | `confidenceFloor` (0.30) | Below this, decline and fall back. Raise to be more conservative. |
| `TemplateDrawingComposer` | `defaultStrongThreshold` (0.55) | Score ≥ → cloud-as-body; below → full creature. |
| `ShapeMatcher` | `scoreScale` (6.0) | How fast confidence decays with Hu distance. |

## Limitations & next steps

- **Similarity warp only.** The current fit is global scale/rotation/translation.
  A thin-plate-spline refinement keyed on more landmarks would let appendages
  follow individual cloud bumps more tightly. The composer is structured so this
  drops into the fitting stage without touching callers.
- **Single-cloud clusters.** `CloudClusteringService` returns one cluster per
  cloud today; multi-cloud constellations ("those three clouds are a dragon")
  are a natural extension — the signature and rasterizer already handle clusters.
- **Retrieval could blend with CLIP.** When the MobileCLIP model is bundled, its
  score could be fused with the Hu-shape score for labels that exist in both the
  allowlist and the template library.
- **Per-role attachment.** Stroke `role`s ("ear", "tail", …) are carried but not
  yet used to attach specific details to specific cloud landmarks; a role-aware
  local transform would sharpen the "it's really in the cloud" effect.
```
