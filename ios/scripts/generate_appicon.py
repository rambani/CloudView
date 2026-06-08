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
CLOUD_FADE = (250, 247, 240, 165)   # slightly translucent for background wisps


def _puff(draw, cx, cy, w, h, bumps, color=CLOUD_WHITE):
    """Draws an organic cumulus puff at (cx, cy) within a (w, h)
    envelope. Built from a central oval plus a list of edge-lobes
    (the `bumps` parameter), so each call can produce a uniquely
    irregular silhouette rather than a stamp-repeated shape.

    bumps is a list of (x_frac, y_frac, size_mult) where the
    fractions are positions relative to the envelope's half-extent
    and size_mult scales a base lobe radius."""
    # Central body — slightly smaller than the envelope so the
    # edge bumps can extend the silhouette without growing past
    # the requested size.
    draw.ellipse(
        (cx - w * 0.42, cy - h * 0.38, cx + w * 0.42, cy + h * 0.38),
        fill=color,
    )
    base_r = min(w, h) * 0.24
    for x_frac, y_frac, size_mult in bumps:
        bx = cx + x_frac * w * 0.5
        by = cy + y_frac * h * 0.5
        br = base_r * size_mult
        draw.ellipse((bx - br, by - br, bx + br, by + br), fill=color)


# Per-cloud bump recipes. Tuned by hand so each cloud has its own
# personality — heavy on one side, taller on top, flatter on the
# bottom — rather than three copies of the same circular shape.

# BODY: tall central cumulus, broader on top with a flatter base
# (the classic "cauliflower" cumulus profile).
_BODY_BUMPS = [
    (-0.55, -0.70, 0.95),    # upper-left lobe
    (-0.12, -0.85, 1.00),    # crown
    ( 0.35, -0.75, 0.92),    # upper-right lobe
    ( 0.70, -0.40, 0.78),    # right shoulder
    ( 0.88,  0.05, 0.62),    # right side
    ( 0.40,  0.45, 0.55),    # lower-right (smaller, base is flatter)
    (-0.30,  0.55, 0.60),    # lower-left
    (-0.72, -0.20, 0.80),    # left shoulder
]

# LEFT WING: wider than tall, with a wispy outer edge.
# Asymmetric — the puffs sit higher toward the inside, lower out.
_LEFT_WING_BUMPS = [
    (-0.92, -0.05, 0.65),    # outer wisp tip
    (-0.55, -0.55, 0.85),
    (-0.10, -0.80, 0.95),    # peak (near the body, where wing roots)
    ( 0.45, -0.60, 0.85),    # inner-upper
    ( 0.85, -0.20, 0.75),    # inner edge
    ( 0.20,  0.35, 0.60),    # inner-lower
    (-0.50,  0.20, 0.55),    # outer-lower wisp
]

# RIGHT WING: mirror in spirit but DIFFERENT in detail so it
# doesn't look like a stamp. Peak shifted, lower bumps placed
# asymmetrically relative to the left wing.
_RIGHT_WING_BUMPS = [
    ( 0.90,  0.05, 0.70),    # outer wisp tip (lower than left's)
    ( 0.50, -0.50, 0.90),    # rising
    ( 0.05, -0.78, 1.00),    # peak (shifted slightly left vs mirror)
    (-0.40, -0.65, 0.82),
    (-0.82, -0.15, 0.78),    # inner edge
    (-0.20,  0.40, 0.55),
    ( 0.55,  0.25, 0.62),
]


def _wisp(draw, cx, cy, w, h, color=CLOUD_FADE):
    """A small, elongated background wisp — two overlapping
    horizontal ellipses. Reads as a distant background cloud
    without competing visually with the foreground arrangement."""
    draw.ellipse((cx - w * 0.5, cy - h * 0.5, cx + w * 0.5, cy + h * 0.5), fill=color)
    draw.ellipse(
        (cx - w * 0.15, cy - h * 0.8, cx + w * 0.35, cy + h * 0.2),
        fill=color,
    )


def draw_cloud(draw, cx, cy):
    """A simpler, more natural sky scene: three irregular cumulus
    clouds (body + two wing clouds) whose arrangement suggests a
    bird-with-spread-wings, plus a couple of distant background
    wisps for atmosphere.

    Each cloud has its own hand-tuned bump recipe so the three
    don't look like the same stamp repeated; the right wing is
    deliberately not a perfect mirror of the left."""

    # --- Background wisps (just two, for atmosphere not detail) -----------
    _wisp(draw, cx - 215, cy - 215, w=125, h=28)   # upper-left
    _wisp(draw, cx + 195, cy + 180, w=110, h=26)   # lower-right

    # --- Bird arrangement (three irregular cumulus clouds) ----------------
    # Body — central cumulus, not too tall (the previous version
    # had a long stem hanging below the wings that read as a
    # separate vertical cloud).
    _puff(draw, cx, cy - 10, w=165, h=165, bumps=_BODY_BUMPS)
    # Left wing — wider than tall, sized to slightly overlap the
    # body so the bird trace flows through continuous cloud cover
    # rather than threading bare sky between them.
    _puff(draw, cx - 175, cy - 35, w=225, h=135, bumps=_LEFT_WING_BUMPS)
    # Right wing — mirror placement, unique bump pattern.
    _puff(draw, cx + 175, cy - 35, w=225, h=135, bumps=_RIGHT_WING_BUMPS)

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

    # Seagull-style bird in flight: wings peak in the MIDDLE of
    # each wing (not at the tips), with the wingtips drooping
    # lower — the classic bird-from-below silhouette. The previous
    # straight-line wings + sharp V tail read like a longhorn
    # silhouette; this M-shape outline avoids that completely.
    #
    # Closed outline traced clockwise: top edge sweeps up-down-up
    # across both wings, underside threads back through the body
    # with a small fanned tail extending below.
    path = [
        # ---- Top edge (M-shape across both wings) ------------------
        (cx - 250, cy + 5),     # left wingtip (sits low)
        (cx - 205, cy - 18),    # leading edge rising
        (cx - 150, cy - 50),
        (cx - 100, cy - 70),    # LEFT WING PEAK (highest point)
        (cx - 55,  cy - 55),    # descending toward body
        (cx - 25,  cy - 45),    # body shoulder
        (cx,       cy - 60),    # head bump
        (cx + 25,  cy - 45),    # body shoulder
        (cx + 55,  cy - 55),    # rising to right peak
        (cx + 100, cy - 70),    # RIGHT WING PEAK
        (cx + 150, cy - 50),
        (cx + 205, cy - 18),
        (cx + 250, cy + 5),     # right wingtip
        # ---- Underside (back to left wingtip) ----------------------
        (cx + 215, cy + 18),    # bottom of right wingtip
        (cx + 165, cy + 0),     # underside rises (wing thinner here)
        (cx + 115, cy - 30),    # under right wing peak
        (cx + 75,  cy - 32),
        (cx + 45,  cy - 22),    # body right underside
        (cx + 22,  cy + 5),
        # Small fanned tail (rounded, not a sharp V)
        (cx + 18,  cy + 30),
        (cx + 8,   cy + 50),
        (cx,       cy + 55),    # tail center
        (cx - 8,   cy + 50),
        (cx - 18,  cy + 30),
        (cx - 22,  cy + 5),     # body left underside
        (cx - 45,  cy - 22),
        (cx - 75,  cy - 32),
        (cx - 115, cy - 30),    # under left wing peak
        (cx - 165, cy + 0),
        (cx - 215, cy + 18),
        (cx - 250, cy + 5),     # close
    ]

    draw.line(path, fill=ink, width=10, joint='curve')


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
