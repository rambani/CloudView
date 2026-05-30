#!/usr/bin/env python3
"""
Generate CloudView/Resources/LabelEmbeddings.json from the kid-safe label
allowlist. Run once at setup; re-run whenever the allowlist changes.

What it does:
1. Parses the allowlist out of backend/api/lib/allowlist.ts (single source
   of truth for what's kid-safe; we never want it to drift between the
   backend and the iOS bundle).
2. Loads OpenAI's CLIP ViT-B/32 (used in tandem with Apple's MobileCLIP-S0
   on device; both share the same 512-dim text embedding space, so text
   embeddings computed here are compatible with image embeddings produced
   by MobileCLIP at runtime).
3. For each label, embeds N phrasings ("a dragon", "a cloud that looks
   like a dragon", "the silhouette of a dragon flying", ...) and averages
   them. Averaging multiple prompts is a small quality bump for
   unusual-domain inputs like silhouettes.
4. L2-normalizes and writes one JSON file.

Usage:
    pip install torch open_clip_torch
    python tools/generate_label_embeddings.py

If you prefer to avoid PyTorch, the same idea works with any CLIP
implementation that emits 512-dim float embeddings. Just keep the same
model family on device (MobileCLIP-S0 is the recommendation).
"""

from __future__ import annotations

import json
import re
import sys
from pathlib import Path
from typing import List

REPO_ROOT = Path(__file__).resolve().parent.parent
ALLOWLIST_TS = REPO_ROOT / "backend/api/lib/allowlist.ts"
OUTPUT_JSON = REPO_ROOT / "CloudView/Resources/LabelEmbeddings.json"

# Phrasings averaged per label. Each %s is filled with the label string.
# Adding more variants improves robustness for unusual inputs (cloud
# silhouettes are quite far from CLIP's training distribution).
PROMPT_TEMPLATES = [
    "a %s",
    "a silhouette of a %s",
    "a cloud that looks like a %s",
    "the outline of a %s",
    "an illustration of a %s",
]


def parse_allowlist() -> List[str]:
    """Extract the labels from allowlist.ts. Tolerant of comments and
    whitespace; matches single-quoted strings inside the KID_SAFE_LABELS
    Set literal."""
    text = ALLOWLIST_TS.read_text()
    # Slice to just the Set literal so we don't accidentally grab strings
    # from other parts of the file.
    start = text.find("KID_SAFE_LABELS")
    end = text.find("]", start)
    body = text[start:end]
    labels = re.findall(r"'([^']+)'", body)
    if not labels:
        sys.exit(f"Could not parse any labels from {ALLOWLIST_TS}")
    return sorted(set(labels))


def embed_labels(labels: List[str]) -> dict[str, list[float]]:
    import torch
    import open_clip

    print(f"Loading CLIP model ViT-B-32 (laion2b_s34b_b79k)…")
    model, _, _ = open_clip.create_model_and_transforms(
        "ViT-B-32", pretrained="laion2b_s34b_b79k"
    )
    tokenizer = open_clip.get_tokenizer("ViT-B-32")
    model.eval()

    out: dict[str, list[float]] = {}
    for label in labels:
        prompts = [tmpl % label for tmpl in PROMPT_TEMPLATES]
        tokens = tokenizer(prompts)
        with torch.no_grad():
            feats = model.encode_text(tokens)
            # L2-normalize each phrasing, then average, then re-normalize.
            feats = feats / feats.norm(dim=-1, keepdim=True)
            avg = feats.mean(dim=0)
            avg = avg / avg.norm()
        out[label] = avg.tolist()
        print(f"  {label}: ok ({len(out[label])} dims)")
    return out


def main() -> int:
    labels = parse_allowlist()
    print(f"Embedding {len(labels)} labels from {ALLOWLIST_TS.name}…")
    embeddings = embed_labels(labels)
    OUTPUT_JSON.parent.mkdir(parents=True, exist_ok=True)
    with OUTPUT_JSON.open("w") as f:
        json.dump(embeddings, f)
    print(f"Wrote {OUTPUT_JSON.relative_to(REPO_ROOT)} ({len(embeddings)} entries)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
