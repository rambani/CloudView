#!/usr/bin/env python3
"""
Generate Cloudoodle's app icon (1024x1024 PNG).

The icon is a tilted Polaroid sitting against a sky-blue gradient,
with the photo area showing a stylized cloud at sunset. Built with
Pillow so we can re-render any time the design needs a tweak —
no external dependencies beyond `pip install Pillow`.

Usage:
    python3 ios/scripts/generate_appicon.py

Writes to:
    ios/Cloudoodle/Resources/Assets.xcassets/AppIcon.appiconset/AppIcon.png

Apple recommendations honoured:
  * 1024x1024 source, RGB (no alpha — iOS dislikes alpha at 1024)
  * No pre-rounded corners (iOS rounds them at runtime)
  * Subject centered, readable down to 60pt home-screen size
"""

import os
import sys
from PIL import Image, ImageDraw, ImageFilter, ImageFont

# Resolve the project paths off this script's location so it works
# regardless of where you run it from.
HERE = os.path.dirname(os.path.abspath(__file__))
PROJECT_ROOT = os.path.abspath(os.path.join(HERE, ".."))
OUT_PATH = os.path.join(
    PROJECT_ROOT,
    "Cloudoodle/Resources/Assets.xcassets/AppIcon.appiconset/AppIcon.png",
)

SIZE = 1024

# --- Palette ----------------------------------------------------------------

SKY_TOP = (158, 196, 224)        # high, daylight blue
SKY_BOTTOM = (66, 100, 150)      # low, twilight
PHOTO_TOP = (236, 196, 165)      # warm sunset wash
PHOTO_BOTTOM = (122, 158, 200)   # cooler sky below
POLAROID_PAPER = (247, 244, 235) # warm white, matches the app's PolaroidCard
INK = (0, 0, 0)
SHADOW = (10, 8, 14)


def load_font(paths, size):
    """Find the first available font from a list of candidate paths."""
    for p in paths:
        if os.path.exists(p):
            return ImageFont.truetype(p, size)
    return ImageFont.load_default()


def make_vertical_gradient(size, top_rgb, bottom_rgb):
    """1024-tall vertical gradient. Built one row at a time — slow
    in pure Python but only runs once at icon-render time."""
    w, h = size
    img = Image.new("RGB", size)
    d = ImageDraw.Draw(img)
    for y in range(h):
        t = y / max(1, h - 1)
        r = int(top_rgb[0] * (1 - t) + bottom_rgb[0] * t)
        g = int(top_rgb[1] * (1 - t) + bottom_rgb[1] * t)
        b = int(top_rgb[2] * (1 - t) + bottom_rgb[2] * t)
        d.line([(0, y), (w, y)], fill=(r, g, b))
    return img


def draw_cloud(draw, cx, cy):
    """A stylized cumulus — the classic "sky shape" the app's whole
    premise pivots on. Pure white so it pops against the sunset
    gradient behind. Built from overlapping ellipses arranged to
    read as one continuous silhouette (no notches) at 60pt
    home-screen scale, where individual lobes can't be resolved."""
    cloud = (252, 250, 245, 255)
    # Wide flat base — single ellipse so there's no center notch
    draw.ellipse((cx - 230, cy + 0, cx + 250, cy + 140), fill=cloud)
    # Mid-row lobes (fluffy middle)
    draw.ellipse((cx - 200, cy - 50, cx - 30, cy + 110), fill=cloud)
    draw.ellipse((cx + 30, cy - 50, cx + 220, cy + 110), fill=cloud)
    # Upper lobes (tall fluffy top)
    draw.ellipse((cx - 140, cy - 140, cx + 40, cy + 50), fill=cloud)
    draw.ellipse((cx - 20, cy - 170, cx + 170, cy + 50), fill=cloud)
    draw.ellipse((cx + 50, cy - 120, cx + 200, cy + 30), fill=cloud)


def build_polaroid():
    """Render the Polaroid onto its own RGBA canvas so we can rotate
    + shadow + composite it cleanly onto the background.

    Layout intentionally spare: thin top border, square photo, wider
    bottom border with the headline temperature. At home-screen
    scale (60pt), only the silhouette + cloud + 72° will register —
    so those are the only things that matter."""
    pad = 50
    photo_size = 560
    top_border = 36
    bottom_border = 150
    pw = photo_size + 2 * pad
    ph = top_border + photo_size + bottom_border

    img = Image.new("RGBA", (pw, ph), (0, 0, 0, 0))
    d = ImageDraw.Draw(img, "RGBA")

    # Card body
    d.rounded_rectangle((0, 0, pw, ph), radius=22, fill=(*POLAROID_PAPER, 255))

    # Photo area (square) — sunset gradient with the cloud on top
    photo = make_vertical_gradient(
        (photo_size, photo_size),
        PHOTO_TOP, PHOTO_BOTTOM,
    ).convert("RGBA")

    cd = ImageDraw.Draw(photo, "RGBA")
    draw_cloud(cd, photo_size // 2, photo_size // 2 + 40)

    img.paste(photo, (pad, top_border), photo)

    # Single accent line at the top of the bottom border so the
    # photo edge is articulated without adding ink that wouldn't
    # survive shrinking to 60pt.
    line_y = top_border + photo_size + 4
    d.line((pad, line_y, pw - pad, line_y), fill=(*INK, 25), width=2)

    # The headline "72°" — large serif numeral in the bottom border.
    # Drops out gracefully at small sizes (still legible as a glyph,
    # even if specifics blur) and pulls the icon's color story
    # together since the gradient inside also implies temperature.
    serif_big = load_font([
        "/usr/share/fonts/truetype/liberation/LiberationSerif-Regular.ttf",
        "/System/Library/Fonts/Georgia.ttc",
    ], 96)
    d.text((pad + 4, top_border + photo_size + 22), "72°",
           fill=(*INK, 195), font=serif_big)

    return img


def main():
    # 1. Background gradient
    bg = make_vertical_gradient((SIZE, SIZE), SKY_TOP, SKY_BOTTOM).convert("RGBA")

    # 2. Polaroid card
    polaroid = build_polaroid()

    # 3. Drop shadow — solid dark version blurred + offset
    shadow_alpha = polaroid.split()[-1].point(lambda a: int(a * 0.55))
    shadow = Image.merge(
        "RGBA",
        (
            Image.new("L", polaroid.size, SHADOW[0]),
            Image.new("L", polaroid.size, SHADOW[1]),
            Image.new("L", polaroid.size, SHADOW[2]),
            shadow_alpha,
        ),
    ).filter(ImageFilter.GaussianBlur(26))

    # 4. Rotate Polaroid + shadow together so they stay aligned
    angle = -4.5
    polaroid_rot = polaroid.rotate(angle, resample=Image.BICUBIC, expand=True)
    shadow_rot = shadow.rotate(angle, resample=Image.BICUBIC, expand=True)

    # 5. Composite — shadow offset down-right
    px = (SIZE - polaroid_rot.size[0]) // 2
    py = (SIZE - polaroid_rot.size[1]) // 2

    bg.alpha_composite(shadow_rot, (px + 18, py + 36))
    bg.alpha_composite(polaroid_rot, (px, py))

    # Flatten to RGB — Apple doesn't accept alpha at 1024x1024
    final = bg.convert("RGB")
    final.save(OUT_PATH, "PNG", optimize=True)
    print(f"Wrote {OUT_PATH} ({final.size[0]}x{final.size[1]})")


if __name__ == "__main__":
    main()
