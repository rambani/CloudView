# On-device recognition model setup

One-time setup that turns on perception: a contrastive image encoder looks
at the **real photo of the cloud** and names what it resembles, and the
drawing library assembles that creature on the cloud. Without it the app
still works — shape matching only, and clouds it can't match get an honest
"Cool cloud!". With it, recognition is fully on-device, $0 per call, no
network, no vendor. See `docs/RECOGNITION.md` for the architecture.

## ⚠️ Licensing — read first

Two Apple models were considered and **cannot ship**:

| Model | Weights license | Verdict |
|---|---|---|
| Apple **MobileCLIP** (all sizes, incl. S0) | Apple ML Research Model license — "exclusively for Research Purposes … does not include … use in any commercial product or service" | ✗ research-only |
| Apple **FastVLM** | same license text | ✗ research-only |

(Their *code* is MIT / sample-code licensed; the *weights* are not. The
earlier revision of this document recommended MobileCLIP-S0 — that was
wrong, and its embedding generator also assumed MobileCLIP shares OpenAI
CLIP's text space, which it does not.)

Shippable defaults, chosen for license first and zero-shot quality second:

| Model | License | Image tower | Notes |
|---|---|---|---|
| `google/siglip2-base-patch16-224` (**default**) | Apache-2.0 | ~86 M params, ~90 MB at 8-bit | Best zero-shot of the two |
| `openai/clip-vit-base-patch32` | MIT | ~88 M params | Fallback if SigLIP's conversion gives trouble |

Both tools refuse MobileCLIP/FastVLM model ids on purpose.

## What you produce

Two files, neither in git:

1. **`CloudEmbedder.mlpackage`** — the Core ML image encoder: input
   `image` (224×224 RGB), output `embedding` (unit-norm, 768-dim for
   SigLIP 2 base). ~90–180 MB depending on quantization.
2. **`CloudView/Resources/LabelEmbeddings.json`** — text embeddings of the
   creatures the drawing library can draw (its labels are the source), from
   the **same model**, plus a `_meta` block (model, dimension, confidence
   floor, sampling temperature). ~100 KB; fine to commit.

## Steps (on a Mac)

```bash
pip install torch transformers coremltools pillow

# 1. Export the image encoder (8-bit palettized: ~half the size).
python3 tools/convert_recognition_model.py --quantize 8 \
    --output CloudView/Resources/CloudEmbedder.mlpackage

# 2. Text embeddings for every drawable creature, same model.
python3 tools/generate_label_embeddings.py
```

3. In Xcode, add `CloudEmbedder.mlpackage` and `LabelEmbeddings.json` to
   the **CloudView** target (Copy Bundle Resources). Xcode compiles the
   package to `CloudEmbedder.mlmodelc`.

4. **Recommended: ship the model as an On-Demand Resource** so the App
   Store download stays small. Select the `.mlpackage` → File inspector →
   *On Demand Resource Tags* → `recognition-model`. The app requests that
   tag at launch (`OnDeviceCloudRecognitionService.prepare()`), keeps the
   request alive for the session, and loads from the main bundle once it
   lands. Apple hosts ODR assets for App Store apps at no cost.

## Re-run when…

- the drawing library gains or loses creatures → step 2 (labels come from
  `DrawingTemplates.json`; the generator warns if a drawable creature is
  missing from the backend's kid-safe allowlist).
- you change models → steps 1 **and** 2 (the app refuses a dimension
  mismatch at load and logs which file to regenerate).

## Calibration

`_meta.confidenceFloor` decides when the top match is "nothing" and the
app shows "Cool cloud!" instead of a creature. The defaults (SigLIP 0.05,
CLIP 0.18 cosine) are starting points. Calibrate on real clouds: record
contours in a DEBUG build (Settings → Developer), and extend
`tools/validate_retrieval.py --photos` to run the exported model over the
crops — the photo path and rating sheet already exist. Raise the floor if
smooth blobs get confident labels; lower it if obvious shapes are missed.

## Verifying

Console at launch:

- silence → model and embeddings loaded.
- `ℹ️ Recognition: model not in bundle; will try On-Demand Resources on first use.` → fine if the ODR tag is set; a download follows.
- `ℹ️ Recognition: no label embeddings bundled; shape matching only.` → step 2 / Copy Bundle Resources.
- `⚠️ Recognition model dim X != label embeddings dim Y` → the two files came from different models; regenerate.
