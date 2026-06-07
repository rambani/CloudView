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


CLOUD_WHITE = (252, 250, 245, 255)
CLOUD_FADE = (250, 247, 240, 175)   # slightly translucent for background wisps


def _puff(draw, cx, cy, w, h, color=CLOUD_WHITE):
    """Draws one organic cumulus puff at (cx, cy) within a (w, h)
    envelope. Built from a central oval plus a ring of asymmetric
    edge-lobes, so the silhouette has the irregular bumpy edges of
    a real cumulus rather than reading as concentric ellipses.

    Bump positions are hand-tuned (not random) so the icon renders
    identically every time."""
    # Central body — slightly smaller than the envelope so the
    # edge bumps can extend the silhouette without growing past
    # the requested size.
    draw.ellipse(
        (cx - w * 0.42, cy - h * 0.38, cx + w * 0.42, cy + h * 0.38),
        fill=color,
    )

    # Edge bumps. Each entry: (x_frac, y_frac, size_mult) — fraction
    # of (w, h) from center, plus a multiplier on the base bump size.
    # The set is deliberately asymmetric so left/right edges don't
    # mirror perfectly (real clouds don't).
    base_r = min(w, h) * 0.24
    bumps = [
        (-0.86, -0.25, 0.95),    # left
        (-0.62, -0.65, 0.85),    # upper-left
        (-0.18, -0.82, 1.00),    # top-left of crown
        ( 0.22, -0.78, 0.92),    # top-right of crown
        ( 0.58, -0.55, 0.80),    # upper-right
        ( 0.88, -0.18, 0.88),    # right
        ( 0.78,  0.30, 0.78),    # lower-right
        ( 0.40,  0.62, 0.86),    # bottom-right
        (-0.10,  0.72, 0.92),    # bottom
        (-0.55,  0.58, 0.84),    # bottom-left
        (-0.85,  0.20, 0.80),    # lower-left
    ]
    for x_frac, y_frac, size_mult in bumps:
        bx = cx + x_frac * w * 0.5
        by = cy + y_frac * h * 0.5
        br = base_r * size_mult
        draw.ellipse((bx - br, by - br, bx + br, by + br), fill=color)


def _wisp(draw, cx, cy, w, h, color=CLOUD_FADE):
    """A small, elongated background wisp — just two overlapping
    horizontal ellipses. Reads as a distant background cloud
    without competing visually with the bird-arrangement clouds
    in the foreground."""
    draw.ellipse((cx - w * 0.5, cy - h * 0.5, cx + w * 0.5, cy + h * 0.5), fill=color)
    # A second smaller lobe nudged off-center so the wisp isn't a
    # bare ellipse.
    draw.ellipse(
        (cx - w * 0.15, cy - h * 0.8, cx + w * 0.35, cy + h * 0.2),
        fill=color,
    )


def draw_cloud(draw, cx, cy):
    """A sky scene: a handful of cumulus clouds plus some smaller
    background wisps, with the central five-puff arrangement
    forming a bird-with-spread-wings the AI has noticed and traced.

    Each puff is built from a center oval + asymmetric edge bumps
    so the silhouettes read as organic clouds rather than as
    overlapping circles. The faded background wisps fill out the
    sky so the bird-arrangement doesn't sit in an empty frame."""

    # --- Background wisps ---------------------------------------------------
    # Scattered in the corners + bottom edges so the bird-cluster
    # is the visual subject but the sky around it isn't bare.
    _wisp(draw, cx - 215, cy - 200, w=110, h=28)   # top-left, far
    _wisp(draw, cx + 165, cy - 220, w=95,  h=24)   # top-right, far
    _wisp(draw, cx - 180, cy + 90,  w=85,  h=22)   # mid-left, behind wing
    _wisp(draw, cx + 195, cy + 100, w=95,  h=25)   # mid-right, behind wing
    _wisp(draw, cx + 30,  cy + 220, w=110, h=28)   # bottom, distant

    # --- Bird arrangement ---------------------------------------------------
    # Five organic puffs that together suggest a bird-with-spread-
    # wings shape. Sizes tuned so wingtips stay inside the photo
    # edge and gaps between puffs are visible (sky shows through).

    # Body — vertical-ish puff at center
    _puff(draw, cx,        cy + 5,   w=170, h=200)

    # Inner wing roots — horizontal puffs flanking the body
    _puff(draw, cx - 135,  cy - 30,  w=145, h=125)
    _puff(draw, cx + 135,  cy - 30,  w=145, h=125)

    # Wingtip puffs — smaller and higher, out at the wingtips
    _puff(draw, cx - 225,  cy - 55,  w=115, h=110)
    _puff(draw, cx + 225,  cy - 55,  w=115, h=110)

    # Tail puff — small wispy streak below the body
    _wisp(draw, cx,        cy + 155, w=85,  h=32, color=CLOUD_WHITE)

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

    # Bird seen from below/behind, wings spread in a gentle V.
    # Body at center, wings sweep up-and-outward to wingtips on
    # either side. Closed loop so the silhouette reads as a single
    # shape. Scaled to span the 5-cloud arrangement so the trace
    # flows through each cloud rather than floating between them.
    path = [
        # Start at the back of the right wing root, tracing up + out
        (cx + 40,  cy + 10),
        (cx + 100, cy - 15),    # along underside of right wing
        (cx + 180, cy - 40),
        (cx + 245, cy - 75),    # right wingtip
        (cx + 205, cy - 60),    # back across top of right wing
        (cx + 130, cy - 50),
        (cx + 50,  cy - 50),    # right wing meets shoulder
        # Head (small forward bump between the shoulders)
        (cx + 14,  cy - 70),
        (cx - 14,  cy - 70),
        # Left shoulder
        (cx - 50,  cy - 50),
        (cx - 130, cy - 50),    # across top of left wing
        (cx - 205, cy - 60),
        (cx - 245, cy - 75),    # left wingtip
        (cx - 180, cy - 40),    # back along underside of left wing
        (cx - 100, cy - 15),
        (cx - 40,  cy + 10),
        # Body / tail (small triangle hanging down)
        (cx - 22,  cy + 45),
        (cx,       cy + 80),    # tail tip
        (cx + 22,  cy + 45),
        # Close back to start
        (cx + 40,  cy + 10),
    ]

    draw.line(path, fill=ink, width=11, joint='curve')


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
