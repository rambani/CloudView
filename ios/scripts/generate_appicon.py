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
    """A stylized cumulus with a delicate ink trace on top — mirrors
    what the app actually outputs: an unmodified cloud photo with
    AI-detected creature shapes pointed out in thin ink lines.
    Cloud reads first; on a closer look the trace shows the AI
    noticed a whale-shape inside it.

    Cloud silhouette built from overlapping ellipses arranged to
    read as one continuous shape (no notches) even at 60pt
    home-screen scale. Ink trace sized to survive shrinking."""
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

    _draw_ink_trace(draw, cx, cy)


def _draw_ink_trace(draw, cx, cy):
    """A delicate ink outline tracing a bird-in-flight shape inside
    the cloud — what the AI 'found' in it. A bird silhouette reads
    cleanly at small scale (the two extended wings are unmistakable
    in a way that a whale's outline isn't), and "I see a bird in
    the sky" is as natural a cloud-watching read as any.

    Every waypoint sits well inside the cloud silhouette so the
    trace never appears to leave the cloud."""
    ink = (38, 40, 56, 220)

    # Bird seen from below/behind, wings spread in a gentle V. Body
    # at center, wings sweep up-and-outward to wingtips on either
    # side. Closed loop so the silhouette reads as a single shape.
    path = [
        # Start at the back of the right wing root, tracing up + out
        (cx + 30,  cy + 5),
        (cx + 70,  cy - 10),    # along underside of right wing
        (cx + 130, cy - 30),
        (cx + 175, cy - 55),    # right wingtip
        (cx + 145, cy - 45),    # back across top of right wing
        (cx + 90,  cy - 35),
        (cx + 35,  cy - 35),    # right wing meets shoulder
        # Head (small forward bump between the shoulders)
        (cx + 10,  cy - 50),
        (cx - 10,  cy - 50),
        # Left shoulder
        (cx - 35,  cy - 35),
        (cx - 90,  cy - 35),    # across top of left wing
        (cx - 145, cy - 45),
        (cx - 175, cy - 55),    # left wingtip
        (cx - 130, cy - 30),    # back along underside of left wing
        (cx - 70,  cy - 10),
        (cx - 30,  cy + 5),
        # Body / tail (small triangle hanging down)
        (cx - 15,  cy + 30),
        (cx,       cy + 55),    # tail tip
        (cx + 15,  cy + 30),
        # Close back to start
        (cx + 30,  cy + 5),
    ]

    draw.line(path, fill=ink, width=9, joint='curve')


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
