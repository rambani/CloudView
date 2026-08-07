# Art production workflow

How creature art gets made, vetted, and shipped. The end of every path is the
same: SVGs in `tools/art/`, described by `tools/art/manifest.json`, compiled by
`build_drawing_templates.py` into `CloudView/Resources/DrawingTemplates.json`
(schema v2). The app never sees raster art — only stroke sequences.

```
image-gen model ──► vectorizer ──► SVG ─┐
illustrator export ─────────────► SVG ─┼─► art/ + manifest ─► build tool ─► app
hand-authored ──────────────────► SVG ─┘
```

## House style (what every part must look like)

The reference is a fine-line pen drawing fused into a real cloud (see the
dragon-and-castle reference in docs/GENERATIVE_DRAWING_DESIGN.md):

- **Single-weight thin line.** No fills, no shading, no hatching — the app
  renders uniform-width white strokes. Anything filled vectorizes badly.
- **The cloud is the body.** Parts are *details* — face, crest, wing, breath,
  companion — not complete creatures. Draw the accent, not the animal.
- **Few strokes, long lines.** 3–10 strokes per part; flowing curves beat many
  short segments. Every stroke animates in sequence, so order them like a
  hand would draw them (outline → features → accents).
- **Kid-friendly.** Friendly or majestic, never scary. 4+ age rating.

## Path A — AI generation (primary, per the design doc)

1. **Generate** with any strong image model. Prompt skeleton:

   > single continuous fine line drawing of a {part description}, minimal
   > one-weight black ink outline on pure white background, no shading, no
   > fill, no hatching, elegant hand-drawn pen style, children's book,
   > whimsical — {e.g. "a dragon's head crest of flowing swept horn spikes,
   > drawn as a decorative ridge, wider than tall"}

   Generate 8–16 candidates per part. Ask for *parts* ("a crest ridge", "a
   pair of gentle eyes and a smile"), not whole creatures.

2. **Vectorize** the winners to centerline SVG:
   - [vtracer](https://github.com/visioncortex/vtracer):
     `vtracer --input part.png --output part.svg --colormode binary --mode polygon`
   - or potrace: `mkbitmap part.png -o part.pbm && potrace part.pbm -s -o part.svg`
   - Outline-tracers produce *double-stroked* outlines (both edges of the ink
     line). For thin input lines the build tool's simplification usually
     collapses them acceptably; if a part comes out doubled, use a centerline
     tracer or trace it by hand in any vector editor — parts are small.

3. **Clean in any vector editor** (optional): delete stray blobs, join
   fragments, simplify nodes. Save as plain SVG.

## Path B — illustrator / hand-authored

Draw directly as SVG paths (`M/L/C/Q/A` + `Z`). This is how the current
starter set was made. Rules of thumb:
- One SVG per part; the part's internal layout is preserved (the whole SVG's
  bounding box is normalized to the part's local space), so multi-element
  layouts like eyes-plus-mouth must live in **one** SVG.
- Give elements `id` attributes ("eye", "jaw") — they become stroke roles.
- Draw at any scale; the tool normalizes. Wider-than-tall parts (crests,
  breath streams) keep their aspect.

## Wiring a part into the app

1. Drop the SVG under `tools/art/<creature>/` (or `art/shared/`).
2. Add an entry to `tools/art/manifest.json`: `id`, `kind` (the slot it
   fills), `creatures` (labels or `"*"` for shared), `anchor` (cloud landmark:
   `top`, `centroid`, `left`, `bottomRight`, …), optional `scale` (fraction of
   the cloud's short side, default 0.35), `source`.
3. If it's a new slot kind, declare it in the creature's `slots` with
   `required` or a `probability`.
4. Rebuild:
   ```bash
   cd tools
   python3 build_drawing_templates.py --manifest art/manifest.json \
       --tolerance 0.002 --output ../CloudView/Resources/DrawingTemplates.json
   ```
5. No code change is needed — the library loads v2, precomputes Hu
   signatures, and the assembler picks the part up as a candidate.

## Curation checklist (every shipped part)

- [ ] Reads clearly as white-on-sky at phone-screen size (squint test).
- [ ] Single-weight lines only; no fills/shading survived vectorization.
- [ ] Stroke count ≤ ~10; total points per part ≤ ~150 (check the build
      tool's summary line).
- [ ] Not derived from / resembling any branded or franchise character.
- [ ] Kid-appropriate (4+): friendly, no gore, no weapons pointed at anything.
- [ ] Anchor + scale sanity-checked on device against a few real clouds.
- [ ] Reveal order tells a little story (outline → features → accents).

## Silhouettes (matching prototypes)

Each creature's `silhouette.svg` drives Hu-moment shape matching — it's the
*prototype shape* a cloud must resemble, not display art. Keep silhouettes
simple closed polygons with a distinctive gesture (long neck, humped back,
spiky ridge). Distinctiveness across creatures matters more than beauty.

Two tuning notes, learned building the current set:

- **RDP tolerance:** build with `--tolerance 0.002`. At the default 0.006,
  sparse hand-made polygons can lose genuinely-informative vertices (the
  dragon's back spikes flattened, drifting its Hu signature).
- **Near-symmetric shapes have noisy Hu tails.** For left-right-symmetric
  silhouettes, Hu moments h5–h7 sit near zero and flip sign under tiny
  coordinate changes, which the log-space metric amplifies. Identity-ranking
  is unaffected (verified across the current 9), but don't chase small score
  differences on symmetric shapes — and prefer slightly asymmetric prototype
  gestures where possible.

## Verifying a rebuild

```bash
python3 build_drawing_templates.py --check ../CloudView/Resources/DrawingTemplates.json
```

plus the app's unit tests (`CloudViewTests`) cover schema decode and assembly.
When replacing silhouettes, confirm each regenerated creature's nearest
Hu-match is still itself (the build for this repo was verified that way; a
small self-distance from normalization/rounding is normal, ~0.0–0.5 in
log-metric units).
