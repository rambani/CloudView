#!/usr/bin/env python3
"""
Generate CloudView/Resources/LabelEmbeddings.json — text embeddings of the
creatures the app can draw, from the SAME model family as the on-device
image encoder (convert_recognition_model.py). Re-run whenever the drawing
library or the model changes.

What it does:
1. Labels come from the drawing library (CloudView/Resources/
   DrawingTemplates.json) — only creatures the app can actually draw —
   and each is checked against the backend's kid-safe allowlist.
2. Embeds several pareidolia phrasings per label ("a cloud shaped like a
   bear", "a bear made of clouds", …), averages, L2-normalizes. Prompt
   ensembles matter a lot for an out-of-distribution input like a cloud.
3. Writes the JSON with a `_meta` block (model, dimension, confidence
   floor, sampling temperature) so Swift never hard-codes model facts.

Usage (on a Mac, once):
    pip install torch transformers
    python3 tools/generate_label_embeddings.py            # SigLIP 2 base
    python3 tools/generate_label_embeddings.py --model openai/clip-vit-base-patch32

Licensing: Apple's MobileCLIP / FastVLM weights are research-only and are
refused here on purpose. Defaults are Apache-2.0 / MIT models.
"""
from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent
ALLOWLIST_TS = REPO_ROOT / "backend/api/lib/allowlist.ts"
TEMPLATES_JSON = REPO_ROOT / "CloudView/Resources/DrawingTemplates.json"
OUTPUT_JSON = REPO_ROOT / "CloudView/Resources/LabelEmbeddings.json"

# Pareidolia phrasings — the input is a photo of a cloud, so say so.
PROMPT_TEMPLATES = [
    "a cloud shaped like a {}",
    "a cloud that looks like a {}",
    "a {} made of clouds",
    "a white cloud in the shape of a {}",
    "the silhouette of a {} in the sky",
    "a photo of a {}",
]

# Starting confidence floors (cosine) per model family — calibrate on
# real clouds with the contour/photo harness, then edit here.
DEFAULT_FLOOR = {"siglip": 0.05, "clip": 0.18}
DEFAULT_TEMPERATURE = {"siglip": 0.02, "clip": 0.07}


def parse_allowlist() -> set[str]:
    text = ALLOWLIST_TS.read_text()
    start = text.find("KID_SAFE_LABELS")
    end = text.find("]", start)
    return {s.lower() for s in re.findall(r"'([^']+)'", text[start:end])}


def template_labels() -> list[str]:
    doc = json.loads(TEMPLATES_JSON.read_text())
    entries = doc.get("creatures", doc.get("templates", []))
    return sorted({c["label"].lower() for c in entries})


def embed_labels(model_id: str, labels: list[str]) -> tuple[dict[str, list[float]], int]:
    import torch
    from transformers import AutoModel, AutoTokenizer

    print(f"loading {model_id} …")
    model = AutoModel.from_pretrained(model_id, torch_dtype=torch.float32).eval()
    tokenizer = AutoTokenizer.from_pretrained(model_id)
    is_siglip = "siglip" in model_id.lower()

    out: dict[str, list[float]] = {}
    dim = 0
    for label in labels:
        prompts = [t.format(label) for t in PROMPT_TEMPLATES]
        if is_siglip:
            tokens = tokenizer(prompts, padding="max_length", max_length=64, truncation=True, return_tensors="pt")
        else:
            tokens = tokenizer(prompts, padding=True, truncation=True, return_tensors="pt")
        with torch.no_grad():
            feats = model.get_text_features(**tokens)
            feats = feats / feats.norm(dim=-1, keepdim=True)
            avg = feats.mean(dim=0)
            avg = avg / avg.norm()
        out[label] = [float(v) for v in avg.tolist()]
        dim = len(out[label])
        print(f"  {label}: ok")
    return out, dim


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--model", default="google/siglip2-base-patch16-224")
    ap.add_argument("--floor", type=float, help="override the confidence floor written to _meta")
    ap.add_argument("--temperature", type=float, help="override the sampling temperature in _meta")
    args = ap.parse_args()

    if any(b in args.model.lower() for b in ("mobileclip", "fastvlm", "fastvit")):
        sys.exit(f"{args.model}: Apple ML Research Model license — research-only, cannot ship.")

    labels = template_labels()
    allow = parse_allowlist()
    for label in labels:
        if label not in allow:
            print(f"warning: '{label}' is drawable but not in the kid-safe allowlist "
                  f"({ALLOWLIST_TS.name}); add it there or remove the creature.", file=sys.stderr)
    print(f"embedding {len(labels)} drawable labels with {args.model} …")

    embeddings, dim = embed_labels(args.model, labels)
    family = "siglip" if "siglip" in args.model.lower() else "clip"
    doc = {
        "_meta": {
            "model": args.model,
            "dimension": dim,
            "confidenceFloor": args.floor if args.floor is not None else DEFAULT_FLOOR[family],
            "temperature": args.temperature if args.temperature is not None else DEFAULT_TEMPERATURE[family],
            "prompts": PROMPT_TEMPLATES,
        },
        **embeddings,
    }
    OUTPUT_JSON.parent.mkdir(parents=True, exist_ok=True)
    OUTPUT_JSON.write_text(json.dumps(doc))
    print(f"wrote {OUTPUT_JSON.relative_to(REPO_ROOT)} ({len(embeddings)} labels, {dim} dims)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
