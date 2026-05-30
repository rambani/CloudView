# Cloud Recognition Architecture

How Cloudoodle identifies what a cloud "looks like" without any external
AI vendor, paying any per-request cost, or sending any image off device.

## Decision: CLIP embedding match, fully on-device

We use a small open-weights vision-text model (Apple's MobileCLIP-S0, ~26 MB,
~3 ms inference per image on a modern iPhone) compiled to Core ML. The
recognition pipeline is:

```
Cloud silhouette → CLIP image encoder → 512-dim image embedding
                                              ↓
                  Pre-computed label text embeddings (one per allowlisted
                  label, ~150 of them, generated offline once and shipped
                  as a JSON in the app bundle)
                                              ↓
                  Cosine similarity → top-K labels
                                              ↓
                  Weighted-random sample 5 from top 15 → variety per scan
```

**$0 per recognition. No network call. No vendor. Fully offline.**

## Why this works for clouds specifically

CLIP was trained on natural photos with captions. Cloud silhouettes are
unusual inputs, so the raw match quality is lower than you'd get from
either GPT-4V or a CNN trained specifically on cloud labels. We compensate
by:

1. **Prompt engineering on the offline label embeddings.** Each label gets
   multiple phrasings ("dragon", "a dragon flying in the sky", "the silhouette
   of a dragon", "a cloud that looks like a dragon"). We embed each, average,
   normalize. This pushes the label embedding closer to where cloud-like
   inputs land in CLIP space.

2. **Top-K then weighted sampling.** Instead of strict argmax, we take the
   top 15 by cosine similarity and sample 5 by softmax-weighted probability.
   That gives us:
   - The "5 viewers see 5 different things" property (sample varies per scan)
   - Variety without departing too far from the best matches (probability
     mass concentrates on the strongest candidates)

3. **Per-label canonical annotation positions.** CLIP doesn't tell us where
   to draw eye-dots or mouth-lines. We ship a small hand-authored JSON
   (`AnnotationHints.json`) with normalized coordinates per label — "for a
   cat, the eyes sit at (0.4, 0.3) and (0.6, 0.3) within the bounding box".
   Quality is consistent because we wrote it.

## What this gives up vs. a vision LLM

The honest tradeoff: CLIP gives you taxonomy, not imagination. Top-5 for a
puffy round cloud might be "rabbit, kitten, cat, bear, sheep" — all
plausible round-fluffy things. A vision LLM might return "rabbit, snowman,
giant marshmallow, pile of pillows, sleeping cloud kitten." More creative,
more surprising.

For an iOS app that needs to ship at $0/month forever and that can't depend
on a vendor's pricing or API stability, taxonomy is acceptable. The
animation, the cloud-as-main-subject visual treatment, and the variety
across scans are what make the experience feel magical — not the linguistic
flair of the labels.

## On-device cost reality

| Stage | Cost |
|---|---|
| Pre-compute label embeddings (offline, run once) | 30 seconds on any laptop |
| App bundle size impact | ~26 MB MobileCLIP + ~300 KB embeddings JSON |
| Memory at runtime | ~50 MB while encoding, freed after |
| Inference per cloud | ~3-7 ms on iPhone 13+ |
| API/server cost per recognition | $0 |
| **Total monthly cost at 1M MAU** | **$0** |

Backend cost shrinks dramatically too: we no longer need the recognition
cache or the recognize endpoint. The only remaining backend role is the
opt-in scan-reporting → theme aggregation → notification feature.

## What's wired up where

```
iOS:
  Resources/MobileCLIP-S0.mlmodelc/      Core ML model (NOT in git; download manually)
  Resources/LabelEmbeddings.json         pre-computed label embeddings
  Resources/AnnotationHints.json         per-label canonical annotation positions

  Models/CloudCluster.swift              cluster type (already shipped Phase 0)
  Models/Interpretation.swift            interpretation + annotation types

  Services/CLIPImageEncoder.swift        wraps MLModel, runs CLIP image branch
  Services/CloudSilhouetteRenderer.swift CloudCluster → 224×224 CVPixelBuffer
  Services/LabelEmbeddingMatcher.swift   cosine sim + weighted-random top-K
  Services/CloudRecognitionService.swift orchestrator (unchanged protocol)

Offline tooling:
  tools/generate_label_embeddings.py     run once, regenerate when allowlist changes

Backend:
  api/recognize.ts                       deleted — no longer needed
  api/lib/recognition.ts                 deleted — no longer needed
  api/lib/allowlist.ts                   stays (still informs notification themes)
```

## Setup (one-time, manual)

For a working build, follow `docs/CLIP_SETUP.md`. Without the model file,
the recognition service falls back to a deterministic stub so the app still
runs end-to-end — it just always returns the same placeholder picks.

## Failure modes

| Failure | Behavior |
|---|---|
| MobileCLIP model file missing from bundle | Fall back to deterministic stub interpretations; log a startup warning. The app stays functional for dev/testing without the asset. |
| CLIP inference fails at runtime | Log; return the stub interpretations for that scan; no user-visible error. |
| Cloud silhouette is degenerate (too few points) | Skip recognition; show the "Cool cloud!" default state. |
| Top-5 picks all have very low similarity (no good match) | Threshold check: if max similarity < 0.18, return the "Cool cloud!" default rather than a confidently-wrong label. |

## When to revisit

If user feedback says the recognitions feel too repetitive or off-base,
the upgrade path is either:

- **Fine-tune the MobileCLIP image encoder** on labeled cloud silhouettes
  (~10K examples after you've been live for a few months). 1 GPU-hour
  on Modal/Replicate, ~$3 one-time. Quality jump can be significant.

- **Add an optional Tier 2 backend** that calls Claude/GPT/Gemini Vision
  only when on-device confidence is low. Reintroduces vendor cost but
  bounded by how often Tier 1 misses. The architecture already supports
  this — `TieredCloudRecognitionService` is back-compatible.

Neither is needed at launch.
