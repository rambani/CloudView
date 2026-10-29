#!/usr/bin/env python3
"""
Export the on-device recognition image encoder to Core ML.

Produces CloudEmbedder.mlpackage: a 224×224 RGB image in, a unit-norm
embedding out ("embedding"). Pair it with LabelEmbeddings.json from
generate_label_embeddings.py, built from the SAME model.

Licensing (read before changing --model): Apple's MobileCLIP and FastVLM
weights are released under the Apple ML Research Model license, which
excludes "use in any commercial product or service". They cannot ship in
this app. The defaults here are permissively licensed:

  google/siglip2-base-patch16-224   Apache-2.0   (default; best zero-shot)
  openai/clip-vit-base-patch32      MIT

Usage (on a Mac, once):
  pip install torch transformers coremltools pillow
  python3 tools/convert_recognition_model.py \
      --output CloudView/Resources/CloudEmbedder.mlpackage
  # optional 8-bit palettization (~half the size, negligible quality loss):
  python3 tools/convert_recognition_model.py --quantize 8 --output ...

Then in Xcode: add the .mlpackage to the CloudView target. For an
On-Demand Resource, select it → File inspector → On Demand Resource Tags:
"recognition-model". The app loads it from the main bundle or via that tag.
"""
import argparse
import sys

import numpy as np


def export(model_id, output, quantize):
    import torch
    import coremltools as ct
    from transformers import AutoModel

    print(f"loading {model_id} …")
    model = AutoModel.from_pretrained(model_id, torch_dtype=torch.float32).eval()

    class ImageTower(torch.nn.Module):
        def __init__(self, m):
            super().__init__()
            self.m = m

        def forward(self, pixel_values):
            feats = self.m.get_image_features(pixel_values=pixel_values)
            return feats / feats.norm(dim=-1, keepdim=True)

    tower = ImageTower(model).eval()
    example = torch.zeros(1, 3, 224, 224)
    with torch.no_grad():
        dim = tower(example).shape[-1]
    traced = torch.jit.trace(tower, example)

    # Pixel preprocessing baked into the model so Swift hands over a plain
    # BGRA pixel buffer. SigLIP normalizes to [-1, 1] (mean .5, std .5);
    # OpenAI CLIP uses ImageNet-ish per-channel stats.
    if "siglip" in model_id.lower():
        scale, bias = 1 / 127.5, [-1.0, -1.0, -1.0]
    else:
        mean = [0.48145466, 0.4578275, 0.40821073]
        std = [0.26862954, 0.26130258, 0.27577711]
        # Core ML applies y = scale * x + bias per channel; with one scalar
        # scale, fold the per-channel std into an average (error < 2%).
        s = 1 / (255 * float(np.mean(std)))
        scale, bias = s, [-m / sd * (sd / float(np.mean(std))) for m, sd in zip(mean, std)]

    mlmodel = ct.convert(
        traced,
        inputs=[ct.ImageType(name="image", shape=(1, 3, 224, 224), scale=scale,
                             bias=bias, color_layout=ct.colorlayout.RGB)],
        outputs=[ct.TensorType(name="embedding")],
        minimum_deployment_target=ct.target.iOS16,
        compute_units=ct.ComputeUnit.ALL,
        convert_to="mlprogram",
    )
    mlmodel.short_description = f"Cloudoodle recognition image encoder ({model_id}), {dim}-dim unit-norm embedding"
    mlmodel.author = "Cloudoodle"
    mlmodel.license = "Apache-2.0" if "siglip" in model_id.lower() else "MIT"

    if quantize:
        import coremltools.optimize.coreml as cto
        cfg = cto.OptimizationConfig(global_config=cto.OpPalettizerConfig(nbits=quantize))
        mlmodel = cto.palettize_weights(mlmodel, cfg)

    mlmodel.save(output)
    print(f"wrote {output}: {dim}-dim embedding, input 'image' 224×224, output 'embedding'")


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--model", default="google/siglip2-base-patch16-224")
    ap.add_argument("--output", required=True, help="path to CloudEmbedder.mlpackage")
    ap.add_argument("--quantize", type=int, choices=[4, 6, 8], help="palettize weights to N bits")
    args = ap.parse_args()
    banned = ("mobileclip", "fastvlm", "fastvit")
    if any(b in args.model.lower() for b in banned):
        sys.exit(f"{args.model}: Apple ML Research Model license — research-only, cannot ship. "
                 "Use a permissively licensed model (see --help).")
    export(args.model, args.output, args.quantize)


if __name__ == "__main__":
    main()
