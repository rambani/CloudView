# Dream mode — on-device generative keepsake (experimental)

The reference image for Cloudoodle was made by an image model drawing a
creature *into* a photo of a cloud. Dream mode runs that method on the
phone: Stable Diffusion 1.5 + a ControlNet, guided by the real cloud's edges
and the app's own sketch of the creature, prompted for fine white ink line
art, composited over the photo. $0 per image, nothing leaves the device.

**Set expectations before building:** ~2 GB of model to download once,
15–40 s per image on an A16/A17, the phone runs warm, and the output swings
between striking and unusable. That is why step 1 is an experiment, not a
build.

## Step 1 — the 15-minute experiment (do this first)

On a Mac with Apple Silicon:

```bash
python3 -m venv ~/dream && source ~/dream/bin/activate
pip install torch diffusers transformers accelerate opencv-python pillow
python3 tools/dream_experiment.py --photo sky.jpg --creature dragon --out /tmp/dream
open /tmp/dream/grid.png
```

The grid shows the crop, the control image (cloud edges + app sketch), and
for four seeds both styles: **ink** (line art over the photo) and **cloud
creature** (the cloud itself becomes the creature). First run downloads
~4 GB; each image takes 20–40 s on an M-series Mac.

Judge three things, honestly:

1. Does the creature **follow the cloud's forms** — the reference's magic —
   or sit on top of it?
2. Is the line quality illustrator-grade?
3. **How many of the four seeds are shippable?** ~1 in 4 means the app needs
   a "pick one of four" moment (4× the time). Below ~1 in 8, C is not the
   answer and the paid path (A) is.

Try `--control scribble` and a couple of creatures. Everything in the app
(prompts, control image, compositing) is the same recipe
(`DreamDeveloper.swift`), so what you see here is what the phone will do,
only slower on the phone.

## Step 2 — the on-device build (only if step 1 passes)

### Package

`DreamDeveloper.swift` compiles with or without Apple's Swift package —
it's guarded by `#if canImport(StableDiffusion)`. To turn it on, add the
package in Xcode: File → Add Package Dependencies →
`https://github.com/apple/ml-stable-diffusion` (product `StableDiffusion`),
and raise the deployment target to iOS 16.2 (the package's minimum).

### Models → Core ML

Apple's converter, on the Mac from step 1:

```bash
pip install -e git+https://github.com/apple/ml-stable-diffusion#egg=python_coreml_stable_diffusion
python -m python_coreml_stable_diffusion.torch2coreml \
    --model-version stable-diffusion-v1-5/stable-diffusion-v1-5 \
    --convert-unet --convert-text-encoder --convert-vae-decoder --convert-vae-encoder \
    --convert-controlnet lllyasviel/control_v11p_sd15_lineart \
    --unet-support-controlnet --chunk-unet \
    --attention-implementation SPLIT_EINSUM_V2 --compute-unit CPU_AND_NE \
    --bundle-resources-for-swift-cli -o DreamModel
```

`DreamModel/Resources` is what the app loads (`DreamDeveloper.resourcesURL`
looks for a `DreamModel` folder reference in the bundle). The ControlNet
model must be named `LineartControlNet.mlmodelc` inside `controlnet/`.

### Shipping ~2 GB

On-Demand Resources are the right mechanism (Apple-hosted, free), but a
single asset pack is capped at 512 MB — split the folder across tags
(`dream-unet-1`, `dream-unet-2`, `dream-vae`, `dream-text`, `dream-cn`)
and request them all before first use. For a TestFlight experiment, just
bundle the folder; the download size is acceptable for testers.

### Device gate

`DreamDeveloper.deviceIsCapable` requires ≥ 6 GB RAM (iPhone 13 Pro / 14
and later). On other devices the Settings toggle doesn't appear.

## How it's wired

`ARViewModel` → after the sculpt keepsake is on screen, if dream mode is on
and the model is present, `startDreamIfEnabled` runs diffusion in the
background from the same frame; a small ring on the capsule shows progress;
the dreamed image replaces the sculpt when it lands (`ShareableDrawing.kind
== .dreamed`). Failure of any kind leaves the sculpt — nothing blocks.

## Licenses

- Stable Diffusion 1.5: CreativeML OpenRAIL-M (commercial use permitted,
  with use-based restrictions you must pass on — read it).
- ControlNet 1.1 (lllyasviel): same family.
- Apple `ml-stable-diffusion` Swift package: MIT.
