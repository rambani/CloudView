# Cloud Recognition Architecture

How Cloudoodle decides what a cloud "looks like" without any external AI
vendor, per-request cost, or image leaving the device.

## Decision: contrastive embedding match, fully on-device

A permissively licensed contrastive vision-language model (SigLIP 2 base by
default; OpenAI CLIP as the alternative — see `docs/CLIP_SETUP.md` for why
*not* Apple's MobileCLIP or FastVLM) compiled to Core ML. The pipeline:

```
real photo crop of the cloud (224×224, with margin)
        → image encoder → unit-norm embedding
                                   ↓
     pre-computed text embeddings, one per DRAWABLE creature
     (labels from DrawingTemplates.json; checked against the kid-safe allowlist)
                                   ↓
     cosine similarity → top-K → weighted-random sample → up to 5 picks
                                   ↓
     DrawingTemplateLibrary.makeDrawing(forLabel:) assembles that creature's
     parts on the cloud (cloud-as-body) → animated line drawing in AR
```

**$0 per recognition. No network call. No vendor. Fully offline.**

## Why the *photo*, not the silhouette

An earlier revision fed the model a filled silhouette. A silhouette throws
away shading, bumps and texture — most of what makes a cloud look like a
bear. The crop is the real pixels, upright, with 15% margin so the model
sees where cloud ends and sky begins (`CloudCropRenderer`). The silhouette
renderer remains only as a fallback when no frame is at hand.

## Why this works for clouds specifically

Clouds are far from the training distribution, so three things carry the
quality:

1. **Pareidolia prompt ensembles.** Each label is embedded as several
   phrasings — "a cloud shaped like a bear", "a bear made of clouds", "the
   silhouette of a bear in the sky" — averaged and normalized. Saying *it's a
   cloud* in the prompt moves the text embedding toward where cloud photos
   land.
2. **Top-K then weighted sampling.** The top 15 by cosine are sampled with a
   softmax temperature; the first pick is drawn. Same cloud, different
   scans, different (plausible) answers — "five viewers, five things".
3. **Only drawable labels.** The label set is exactly the creatures the
   library can assemble, so a pick is always renderable at reference
   quality, never a bare outline with dots.

## Order of paths in the app

1. **Perception** (this document) when the model is present.
2. **Shape retrieval** — Hu-moment match of the contour against creature
   silhouettes (`docs/DRAWING_SYSTEM.md`). Honest but weak on rounded
   clouds; it is the offline/no-model path.
3. **Outline + marks** for a recognized label the library can't draw.
4. **"Cool cloud!"** — nothing confident; say so rather than invent.

## On-device cost

| Stage | Cost |
|---|---|
| Export + embed labels (offline, once) | minutes on a laptop |
| App impact | ~90 MB model (On-Demand Resource) + ~100 KB embeddings |
| Inference per cloud | tens of ms on A15+ (ANE) |
| API/server cost | $0 |

## What's wired up where

```
iOS:
  Resources/CloudEmbedder.mlmodelc            Core ML encoder (NOT in git; ODR tag "recognition-model")
  Resources/LabelEmbeddings.json              text embeddings + _meta (model, dim, floor, temperature)

  Services/ImageEmbeddingEncoder.swift        Core ML wrapper, bundle or ODR load
  Services/CloudCropRenderer.swift            real-photo crop → 224×224 pixel buffer
  Services/LabelEmbeddingMatcher.swift        cosine + weighted-random top-K; reads _meta
  Services/CloudRecognitionService.swift      orchestrator; [] when the model is absent
  Services/DrawingTemplateLibrary.swift       makeDrawing(forLabel:) — the label → parts seam

Offline tooling:
  tools/convert_recognition_model.py          HF model → CloudEmbedder.mlpackage (refuses research-only models)
  tools/generate_label_embeddings.py          drawable labels → LabelEmbeddings.json (same model)
```

## Failure modes

| Failure | Behavior |
|---|---|
| Model or embeddings missing | Recognition returns `[]`; shape retrieval carries on; unmatched clouds show "Cool cloud!". Info line at launch. |
| ODR download fails / offline | Same as missing; retried on the next launch. |
| Model and embeddings from different models | Dimension mismatch detected at load; recognition off; warning names the file to regenerate. |
| Top match below `_meta.confidenceFloor` | `[]` → "Cool cloud!" rather than a confidently wrong label. |
| Recognized label not in the drawing library | Outline + annotation marks (path 3). The generator warns about such labels, so this should not happen in a shipped build. |

## When to revisit

- **Calibrate the floor and temperature** on recorded real clouds before
  launch (`docs/CLIP_SETUP.md`, Calibration).
- **Fine-tune** the image tower on a few thousand human-rated cloud crops
  once the app has been live — a one-off GPU-hour; the matcher is unchanged.
- **A true VLM** (e.g. SmolVLM, Apache-2.0) could add *where* the head is,
  not just *what* the cloud is, for part placement. Heavier integration
  (MLX); the `Interpretation.annotations` type already has room for it.
