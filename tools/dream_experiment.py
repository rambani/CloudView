#!/usr/bin/env python3
"""
Dream mode experiment — run THIS before investing in the on-device build.

Reproduces, with PyTorch on a Mac (Apple Silicon, ~20–40 s per image), the
exact generation the app would run on the phone: Stable Diffusion 1.5 +
ControlNet, guided by (a) the real cloud's edges and (b) the app's own
sketch of the creature placed on the cloud, prompted for fine white ink
line art — then composited over the photo. Two styles are rendered so the
comparison is honest:

  ink      line drawing generated on black, composited as white line over the photo
  creature img2img: the cloud itself becomes the creature (photoreal), guided by edges

Setup (once):
  python3 -m venv ~/dream && source ~/dream/bin/activate
  pip install torch diffusers transformers accelerate opencv-python pillow

Run:
  python3 tools/dream_experiment.py --photo sky.jpg --creature dragon --out /tmp/dream
  open /tmp/dream/grid.png

Models (downloaded by diffusers on first run, ~4 GB):
  stable-diffusion-v1-5/stable-diffusion-v1-5     CreativeML OpenRAIL-M (commercial OK, use restrictions)
  lllyasviel/control_v11p_sd15_lineart            same family
  lllyasviel/control_v11p_sd15_scribble

Judge on: does the creature FOLLOW the cloud's forms (the reference's
magic), is the line quality illustrator-grade, and how often (of 4 seeds)
is a result shippable. Below ~1 in 4 means dream mode needs a human
"pick one of four" UI; below ~1 in 8 means C is not the answer.
"""
import argparse
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))


def build_control(photo, contour, paths, size=512):
    """Edges of the cloud + the app's sketch, white on black: what ControlNet
    sees. Mirrors DreamControlImage in Swift."""
    import cv2
    import numpy as np
    from PIL import Image, ImageDraw
    import sculpt_preview as sp

    w, h = photo.size
    gray = cv2.cvtColor(np.array(photo), cv2.COLOR_RGB2GRAY)
    gray = cv2.GaussianBlur(gray, (5, 5), 0)
    edges = cv2.Canny(gray, 40, 120)
    # keep edges only inside (a feathered version of) the cloud
    mask = Image.new("L", (w, h), 0)
    ImageDraw.Draw(mask).polygon(contour, fill=255)
    mask = np.array(mask.filter(sp.ImageFilter.GaussianBlur(8))) / 255.0
    edges = (edges * mask).astype(np.uint8)
    control = Image.fromarray(edges).convert("RGB")
    # the app's sketch on top, slightly bolder than the edges
    lw = max(2, int(max(w, h) * 0.003))
    sketch = sp.rasterize(paths, (w, h), lw)
    control = Image.composite(Image.new("RGB", (w, h), (255, 255, 255)), control, sketch)
    return control


def square_crop(photo, contour, margin=0.15):
    """Crop around the cloud like CloudCropRenderer, for a 512 generation."""
    xs = [p[0] for p in contour]; ys = [p[1] for p in contour]
    bx, by, bw, bh = min(xs), min(ys), max(xs) - min(xs), max(ys) - min(ys)
    side = max(bw, bh) * (1 + 2 * margin)
    side = min(side, photo.width, photo.height)
    cx, cy = bx + bw / 2, by + bh / 2
    x0 = min(max(cx - side / 2, 0), photo.width - side)
    y0 = min(max(cy - side / 2, 0), photo.height - side)
    return (int(x0), int(y0), int(x0 + side), int(y0 + side))


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--photo", required=True)
    ap.add_argument("--creature", default="dragon")
    ap.add_argument("--out", required=True)
    ap.add_argument("--seeds", type=int, default=4)
    ap.add_argument("--steps", type=int, default=20)
    ap.add_argument("--control", choices=["lineart", "scribble"], default="lineart")
    ap.add_argument("--device", default=None, help="mps / cuda / cpu (auto)")
    args = ap.parse_args()

    import torch
    from PIL import Image, ImageDraw
    import sculpt_preview as sp
    from diffusers import (StableDiffusionControlNetPipeline, StableDiffusionControlNetImg2ImgPipeline,
                           ControlNetModel, DPMSolverMultistepScheduler)

    device = args.device or ("mps" if torch.backends.mps.is_available() else "cuda" if torch.cuda.is_available() else "cpu")
    dtype = torch.float16 if device != "cpu" else torch.float32
    os.makedirs(args.out, exist_ok=True)

    photo = Image.open(args.photo).convert("RGB")
    photo.thumbnail((1600, 1600))
    found = sp.contours_from_photo(photo)
    if not found:
        sys.exit("no distinct cloud found")
    (contour, _), neighbor = found[0], (found[1] if len(found) > 1 else (None, None))
    xs = [p[0] for p in contour]; ys = [p[1] for p in contour]
    box = (min(xs), min(ys), max(xs) - min(xs), max(ys) - min(ys))
    paths = sp.creature_paths(args.creature, box, neighbor[0], contour, None, neighbor[1])

    crop = square_crop(photo, contour)
    control_full = build_control(photo, contour, paths)
    control = control_full.crop(crop).resize((512, 512), Image.BILINEAR)
    photo_crop = photo.crop(crop).resize((512, 512), Image.LANCZOS)
    control.save(os.path.join(args.out, "control.png"))
    photo_crop.save(os.path.join(args.out, "crop.png"))

    cn = ControlNetModel.from_pretrained(f"lllyasviel/control_v11p_sd15_{args.control}", torch_dtype=dtype)
    base = "stable-diffusion-v1-5/stable-diffusion-v1-5"
    ink_pipe = StableDiffusionControlNetPipeline.from_pretrained(base, controlnet=cn, torch_dtype=dtype,
                                                                safety_checker=None).to(device)
    ink_pipe.scheduler = DPMSolverMultistepScheduler.from_config(ink_pipe.scheduler.config)
    img_pipe = StableDiffusionControlNetImg2ImgPipeline(**ink_pipe.components).to(device)

    c = args.creature
    ink_prompt = (f"fine white ink line drawing of a {c}, single-weight pen illustration, elegant, "
                  f"highly detailed, children's book illustration, white lines on pure black background")
    creature_prompt = (f"a majestic {c} made of white cumulus clouds in a blue sky, the cloud is shaped like a {c}, "
                       f"natural photograph, soft daylight, realistic")
    negative = "color, colorful, photo, blurry, low quality, text, watermark, scary, gore, extra limbs, deformed"

    tiles = []
    for seed in range(args.seeds):
        g = torch.Generator(device="cpu").manual_seed(1000 + seed)
        ink = ink_pipe(ink_prompt, image=control, negative_prompt=negative, num_inference_steps=args.steps,
                       guidance_scale=7.5, controlnet_conditioning_scale=0.9, generator=g).images[0]
        ink.save(os.path.join(args.out, f"ink-raw-{seed}.png"))
        # composite: generated white lines over the real crop (screen)
        lum = ink.convert("L").point(lambda v: 255 if v > 150 else 0)
        comp = Image.composite(Image.new("RGB", (512, 512), (255, 255, 255)), photo_crop, lum.point(lambda v: int(v * 0.9)))
        comp.save(os.path.join(args.out, f"ink-{seed}.png"))

        g = torch.Generator(device="cpu").manual_seed(2000 + seed)
        cre = img_pipe(creature_prompt, image=photo_crop, control_image=control, negative_prompt="blurry, low quality, text, scary, deformed",
                       strength=0.55, num_inference_steps=args.steps, guidance_scale=7.0,
                       controlnet_conditioning_scale=0.6, generator=g).images[0]
        cre.save(os.path.join(args.out, f"creature-{seed}.png"))
        tiles.append((comp, cre))

    # grid: photo | control | ink×N / creature×N
    n = len(tiles)
    grid = Image.new("RGB", (512 * (n + 2) + 10 * (n + 1), 512 * 2 + 10 + 60), (16, 21, 31))
    d = ImageDraw.Draw(grid)
    grid.paste(photo_crop, (0, 60)); d.text((8, 24), "crop", fill=(232, 237, 245))
    grid.paste(control, (522, 60)); d.text((530, 24), f"control ({args.control}) = cloud edges + app sketch", fill=(232, 237, 245))
    for i, (ink, cre) in enumerate(tiles):
        x = (i + 2) * 522
        grid.paste(ink, (x, 60)); d.text((x + 8, 24), f"ink seed {i}", fill=(232, 237, 245))
        grid.paste(cre, (x, 60 + 522)); d.text((x + 8, 60 + 522 - 24), f"cloud creature seed {i}", fill=(232, 237, 245))
    grid.save(os.path.join(args.out, "grid.png"))
    print("wrote", os.path.join(args.out, "grid.png"))


if __name__ == "__main__":
    main()
