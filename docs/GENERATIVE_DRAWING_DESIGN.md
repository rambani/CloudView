# Design: rich part-based drawings + runtime variation

**Status:** revised after design review. Supersedes the earlier draft of this
document, which proposed live on-device sketch generation as the primary art
source — that is now a v2 stretch track (see Appendix) after a reference-image
review and a feasibility research pass both pointed the same way.

Goal: every cloud becomes a creature that (a) genuinely resembles the cloud
[consistency], (b) matches an illustrator-grade line aesthetic, and (c) feels
effectively endless — different by viewing angle, by person, and across a city
[creativity]. All on-device at runtime, $0, offline, kid-safe, in the existing
animated-line aesthetic.

## The reference aesthetic

The quality bar is a fine-line pen drawing fused into a real cloud: the
creature's **body and bulk ARE the cloud**; the art contributes the identifying
detail — horns and spikes riding the cloud's top edge, a detailed eye, teeth
along a lower bump, a breath-stream flowing to a companion element (e.g. a
castle rising from a neighboring cloud bank). Thin, even line weight,
semi-transparent white over sky.

Two conclusions follow:

1. **The existing engine is the right substrate.** Cloud-as-body + detail
   attached at the cloud's real landmarks (already built: Hu shape retrieval,
   TPS warp, hybrid composer) is precisely how that image works.
2. **No on-device generative model reaches this fidelity** (research verdict,
   Appendix). The detail must come from **pre-authored art** — produced with
   image-gen models at build time, vectorized, and human-curated.

## Where "endless" comes from without live generation

Four independent, compounding sources:

1. **The cloud itself.** No two clouds — or two viewing angles of one cloud —
   produce the same contour. The body and the warp differ on every scan before
   any art variation applies. This is a free infinite generator.
2. **Component decomposition** (the big one). Art ships not as monolithic
   drawings but as a **parts library**: tagged head styles, eye styles,
   horn/spike/ear/fin sets, mouths, wings, tails, accessories, and companion
   elements (castle, birds, moon, breath-stream). A composer assembles a
   drawing per scan. A modest curated pool — 20 creatures × 6 heads × 5 eyes ×
   6 detail sets × 4 mouths × 10 accessories × 8 companions-or-none — is
   ~10⁶ distinct assemblies per creature category, before styling.
3. **Seeded selection** (below) spreads assemblies across people, places, time.
4. **Style variation:** line weight, hand-drawn jitter, opacity, reveal
   order/speed of the stroke animation.

"Endless" is perceptual: with ~10⁶ assemblies × never-repeating cloud bodies,
perceived repeats are effectively impossible; literal repeats are impossible.
The bounded parts pool is what *guarantees* the curated aesthetic — recurring
part styles read as an artist's hand, not as repetition, and the library grows
with updates.

## Part schema (extends the existing template schema)

`DrawingTemplates.json` evolves from whole-creature templates to:

```jsonc
{
  "version": 2,
  "creatures": [
    {
      "label": "dragon",
      "category": "mythical",
      "silhouette": [[x,y], ...],     // shape prototype for Hu retrieval (unchanged)
      "slots": {                       // which part kinds this creature uses,
        "head":   { "required": true },   // and where they attach
        "eye":    { "required": true },
        "crest":  { "required": false },  // spikes / ears / fins / horns
        "mouth":  { "required": true },
        "limb":   { "required": false },
        "tail":   { "required": false },
        "companion": { "required": false, "probability": 0.3 }
      }
    }
  ],
  "parts": [
    {
      "id": "dragon-head-03",
      "kind": "head",
      "creatures": ["dragon"],         // or ["*"] for shared parts (eyes, accessories)
      "anchor": "top",                 // cloud landmark to attach at:
                                        // top|bottom|left|right|centroid|topLeft|topRight|...
      "strokes": [ { "order": 1, "closed": false, "points": [[x,y], ...] }, ... ]
    }
  ]
}
```

- Parts are authored in their own normalized local space; the composer places
  them at the named cloud landmark via a local similarity transform (position +
  scale from the cloud's bounding geometry), then the global TPS warp applies.
- `creatures: ["*"]` lets eyes/accessories be shared across the library,
  multiplying combinations further.
- The v1 whole-creature templates remain valid as single-part creatures, so
  migration is incremental and the current system keeps working throughout.

## Seeding policy (unchanged from prior draft)

```
seed = hash(cloudShapeBucket, regionBucket, timeBucket, deviceSalt)
```

A seeded PRNG (SplitMix64) deterministically drives: category temperature
(usually the best Hu match; occasionally 2nd/3rd), part selection per slot,
companion inclusion, expression, orientation flip, stroke style, animation
timing. Stickiness `α` blends shared (cloud+region) vs personal (device+time)
components; default 0.5. Same inputs → same drawing (testable, shareable).

- Same cloud, different angles → different contour + salt → different assembly
  on a differently-warped body.
- Same city → deviceSalt/timeBucket guarantee neighbors differ.
- Category stays anchored to the cloud's shape → still feels *discovered*.

## Build-time art pipeline (AI-generated, curated)

1. **Generate** creature line-art with a strong image model, prompted to the
   house style (fine single-weight line, white-on-transparent, no shading),
   many variants per creature and per part.
2. **Vectorize** (e.g. vtracer/potrace) → centerline strokes; simplify (RDP),
   resample, smooth (Catmull-Rom) into clean point sequences.
3. **Split into parts** along the slot taxonomy; tag anchors.
4. **Curate**: human passes every shipped part for quality, style coherence,
   and kid-safety. Nothing un-reviewed ships.
5. Emit `DrawingTemplates.json` v2 via an offline tool (`tools/`), mirroring
   the existing `generate_label_embeddings.py` pattern.

Output is owned, vetted, offline assets — no runtime cost, latency, vendor, or
moderation exposure.

## Phased plan

1. **Schema + composer:** part schema v2, slot-based assembly composer,
   landmark anchoring; v1 templates keep working. Unit-tested (pure code).
2. **Variation engine:** seed, SplitMix64, per-slot selection, style/animation
   variation. Unit-tested (deterministic).
3. **Art pipeline tooling:** the offline generate→vectorize→split→emit tool.
4. **First real art drop:** one creature (dragon) at reference quality,
   end-to-end, to validate the look on-device before scaling the library.
5. **Scale the library**; tune α and temperatures.

## Appendix: on-device generation (deferred v2 track)

Research verdict (2026-08): generation compute is trivially on-device-feasible —
a sketch-rnn decoder (Magenta, Apache-2.0 code; Quick, Draw! data CC-BY 4.0) is
a ~512-unit LSTM + 20-component GMM head, a few MB, milliseconds per drawing.
The proven integration pattern is a **single-step decoder as the Core ML
model** (in: prev point + state; out: 123-dim GMM/pen vector + state) with the
autoregressive loop and all sampling in Swift, as magenta-js does in JS; Core
ML stateful models (iOS 18+) make state handling cleaner. No turnkey iOS port
exists — the Swift loop is custom work.

The blocker is quality, not compute: every small convertible model is trained
on Quick, Draw!'s crude time-pressured doodles, no large clean stroke-ordered
creature dataset exists to retrain on, and cleaner research models
(SketchKnitter et al., diffusion) are too heavy and not Core ML-friendly.
Post-processing (RDP+smoothing) and sample-and-rank lift output to "clean,
confident doodle" — a possible future *distinct sketchy mode*, not a route to
the reference aesthetic. Revisit if a clean vector dataset or a small clean
generator emerges.

Key sources: arXiv:1704.03477 (sketch-rnn) · magenta-js `@magenta/sketch`
(sampling loop reference) · coremltools stateful-models guide ·
arXiv:2306.03103 (sample-and-rank) · SketchKnitter (ICLR 2023).
