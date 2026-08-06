# Design: on-device generative sketches + runtime variation

**Status:** proposed (design review). No implementation yet.

Goal: every cloud becomes a creature that (a) genuinely resembles the cloud
[consistency], and (b) is drawn freshly and uniquely each time — different by
viewing angle, by person, and across a city [creativity]. All on-device, $0,
offline, kid-safe, and in the existing animated-line aesthetic.

## Core principle: stable identity, variable expression

The split that delivers "a mix of consistency and creativity":

- **Stable, driven by the cloud's shape:** the creature *category* (rabbit vs
  whale). The drawing always looks like what the cloud resembles. This is the
  consistency thread and reuses the shape-retrieval engine already built.
- **Variable, driven by a seed:** the actual linework (a fresh generative
  sample), pose, expression, accessory, stroke style, animation. This is the
  creativity/uniqueness, and it's where "different angles → different drawings"
  and "different within a city" come from.

## Part 1 — On-device generative sketches

### Why sketch generation, not image generation

The app draws *strokes* that trace themselves onto the sky. That rules out
raster image models (DALL·E / Stable Diffusion) — they output pixels, would
need vectorizing, lose the animation, are heavy, and (open-ended) pose a
kid-safety problem. A **sketch-generation model outputs pen strokes directly**:
vector, tiny, fast, animatable, and category-bounded so it's safe (a "cat"
model only ever draws cat-ish sketches).

### Candidate model

**sketch-rnn** (Google Magenta, Apache-2.0 code; trained on the *Quick, Draw!*
dataset, CC BY 4.0). A VAE + RNN whose decoder emits, per step, a Gaussian
mixture over the next pen offset `(Δx, Δy)` plus a pen state
`{draw, lift, end}`. Sampling a latent `z` and rolling the decoder out yields a
complete stroke sequence — exactly our `DrawingConcept.DrawingPath` format.

- **Size:** ~4–5 MB per category checkpoint, or a single multi-category
  conditional model (~10 MB). Bundle-size is a real decision (see risks).
- **Speed:** ~100–250 autoregressive steps of small matrix mults → expected
  well under 100 ms on-device (to be confirmed by the spike).
- **Safety:** bounded by category — no open-ended content.

### Integration — reuse the engine already built

The current pipeline is `cloud contour → Hu shape match → pick creature → warp
template onto cloud → compose → animate`. Generation slots in with **minimal
change** (call this **Mode A**):

```
cloud contour
   │
   ├─► Hu shape match (existing) ──► creature CATEGORY  [consistency]
   │
   └─► SketchGenerator.generate(category, seed) ──► fresh stroke sketch  [creativity]
                     │
        TemplateWarp / TPS (existing) ──► drape the generated sketch onto the cloud
                     │
        DrawingConcept ──► AnimatedDrawing (existing reveal)
```

The static `DrawingTemplates.json` doesn't go away — it becomes the **shape
prototype registry** the Hu matcher uses to pick the category, and its strokes
become the **fallback drawing** when generation is unavailable. So the fallback
chain is: **generated sketch → static template → CLIP/outline → "Cool cloud!".**

A future **Mode B** would *condition* generation on the cloud contour (encode
the cloud, decode a creature already shaped like it) for an even tighter fit.
Deferred — Mode A reuses the tested warp and de-risks first.

### What has to be built (and the unknowns)

| Piece | Effort | Risk |
|---|---|---|
| sketch-rnn checkpoint → Core ML (decoder cell) | med | **high** — RNN + custom sampling; conversion is the crux |
| Swift rollout loop + Gaussian-mixture sampling | med | med — standard MDN sampling, ~100 lines |
| Category mapping to available Quick, Draw! classes | low | low — but some (dragon, swan) may not exist; adjust set or train |
| Bundle size / model packaging | low | med — per-category vs one conditional model |
| Aesthetic acceptance (doodle quality) | — | med — Quick, Draw! sketches are crude; may read as charming "kid-drawn," may read as too rough |

## Part 2 — Runtime variation & seeding policy

### The seed

```
seed = hash(
    cloudShapeBucket,   // Hu-moment bucket (existing) — the consistency anchor
    regionBucket,       // city-level (existing, from scan reporting) — city variety
    timeBucket,         // e.g. floor(now / 6h) — drawings evolve over time
    deviceSalt          // random 64-bit persisted per install — personal uniqueness
)
```

A **stickiness** parameter `α ∈ [0,1]` blends how much weight the *shared*
components (cloud + region) carry vs. the *personal* ones (device + time).
`α → 1` = everyone at a cloud sees the same thing (social/shared feel); `α → 0`
= always fresh and personal. Default proposed: **α ≈ 0.5**.

### Variation dimensions (all seeded, deterministic)

A seeded PRNG (SplitMix64) drives:

1. **Category** — usually the best Hu match [consistency]; a small
   temperature `τ_cat` lets it occasionally pick the 2nd/3rd match for surprise.
2. **Generative latent `z`** — the fresh linework. `τ_gen` = the creativity
   knob (latent sampling temperature).
3. **Expression** — happy / sleepy / surprised (small feature variants).
4. **Accessory** — `Bernoulli(p_acc)` then a weighted pick (hat, scarf…).
5. **Orientation** — occasional horizontal flip within cloud-fit bounds.
6. **Stroke style** — line weight, slight hand-drawn jitter, tint.
7. **Animation** — reveal order / speed variation.

### How this delivers exactly what was asked

- **Same cloud, different angles → different drawings.** A different angle
  produces a different contour → different Hu bucket (can shift category) and
  always a different warp; combined with the per-device salt, the drawing
  genuinely differs.
- **Different within a city.** The `deviceSalt` + `timeBucket` guarantee
  neighbors get different drawings even of the same cloud.
- **Consistency where it matters.** The `cloudShapeBucket` anchor keeps the
  *category* stable — a rabbit-shaped cloud reads as a rabbit for everyone —
  while everything else varies.
- **Reproducible.** Same seed inputs → identical drawing, so behavior is
  testable and a drawing could later be shared/regenerated.

## Phased plan

1. **De-risk spike (do first).** Convert *one* sketch-rnn category to Core ML,
   implement the Swift sampling rollout, generate a sketch, and render it
   through the existing `AnimatedDrawing`. Measure quality + latency on device.
   Go/no-go on the whole generative direction hinges here.
2. **Multi-category generation** wired as the linework source in the compose
   pipeline (Mode A), with the static-template fallback intact.
3. **Variation engine** — the seed + dimensions above, layered on top.
4. **Tuning & safety** — `τ_gen`/`α` defaults, kid-safety review of the
   category set, bundle-size optimization (per-category vs conditional model).

## Open decisions (for review)

1. **Aesthetic:** lean into the crude "hand-drawn doodle" look of Quick, Draw!
   (charming, kid-made feel) or invest in cleaner generation (train/curate)?
2. **Model packaging:** several small per-category models (simpler, bigger
   bundle) vs one multi-category conditional model (smaller, more conversion
   work)?
3. **Stickiness default `α`:** how much should strangers at the same cloud see
   the *same* creature vs. always-fresh? (Affects any future social/shared
   feature.)
4. **Creature set:** align to categories that exist in Quick, Draw! (drop/replace
   dragon, swan, …) or commit to training custom categories?

## What stays true regardless

The shape-retrieval + TPS-warp + compose + animate engine already built is the
substrate under all of this. Generation and variation plug into it; they don't
replace it. If the generative spike fails or ships later, the static-template
system is the working fallback.
