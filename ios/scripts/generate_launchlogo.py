#!/usr/bin/env python3
"""
Generate the launch screen logo — a centered cloud silhouette
shown briefly during cold start. Matches the cloud silhouette
inside the app icon so launch → home feels continuous.

Writes 1x/2x/3x PNGs into the LaunchLogo.imageset and updates
its Contents.json.
"""

import os
import json
from PIL import Image, ImageDraw

HERE = os.path.dirname(os.path.abspath(__file__))
PROJECT_ROOT = os.path.abspath(os.path.join(HERE, ".."))
OUT_DIR = os.path.join(
    PROJECT_ROOT,
    "Cloudoodle/Resources/Assets.xcassets/LaunchLogo.imageset",
)

# Base size in points. iOS asset catalog will pick 1x/2x/3x at runtime.
# Aspect tracks the bird-shaped cloud arrangement (~1.9:1 wider
# than tall) so the silhouette fits with breathing room on every
# edge at any size.
BASE_W = 320
BASE_H = 180

# Cloud color — soft warm white to feel like a Polaroid edge under
# warm light, not a clinical UI white.
CLOUD = (247, 244, 235, 255)
# Faint glow color (subtle haze around the silhouette)
GLOW = (255, 255, 255, 30)


def _puff(draw, cx, cy, w, h, scale):
    """Organic cumulus puff — same recipe as the app icon's
    `_puff()`: center oval + asymmetric edge bumps so the
    silhouette reads as a real cloud, not a circle."""
    def el(x1, y1, x2, y2):
        return (cx + int(x1 * scale), cy + int(y1 * scale),
                cx + int(x2 * scale), cy + int(y2 * scale))
    draw.ellipse(el(-w * 0.42, -h * 0.38, w * 0.42, h * 0.38), fill=CLOUD)
    base_r = min(w, h) * 0.24
    bumps = [
        (-0.86, -0.25, 0.95), (-0.62, -0.65, 0.85),
        (-0.18, -0.82, 1.00), ( 0.22, -0.78, 0.92),
        ( 0.58, -0.55, 0.80), ( 0.88, -0.18, 0.88),
        ( 0.78,  0.30, 0.78), ( 0.40,  0.62, 0.86),
        (-0.10,  0.72, 0.92), (-0.55,  0.58, 0.84),
        (-0.85,  0.20, 0.80),
    ]
    for x_frac, y_frac, size_mult in bumps:
        bx = x_frac * w * 0.5
        by = y_frac * h * 0.5
        br = base_r * size_mult
        draw.ellipse(el(bx - br, by - br, bx + br, by + br), fill=CLOUD)


def draw_cloud(draw, cx, cy, scale=1.0):
    """Same organic-cloud bird arrangement as the app icon (see
    generate_appicon.py for design rationale). Keeping both in
    sync so the icon you tapped and the brief launch flash read as
    one continuous moment.

    No background wisps here — the launch flash is brief; the
    viewer sees the silhouette for ~500ms and doesn't need a
    full sky scene."""
    ink = (38, 40, 56, 220)

    def p(x, y):
        return (cx + int(x * scale), cy + int(y * scale))

    # Bird arrangement — five organic puffs
    _puff(draw, cx,        cy + int(5 * scale),   170, 200, scale)   # body
    _puff(draw, cx + int(-135 * scale), cy + int(-30 * scale), 145, 125, scale)
    _puff(draw, cx + int( 135 * scale), cy + int(-30 * scale), 145, 125, scale)
    _puff(draw, cx + int(-225 * scale), cy + int(-55 * scale), 115, 110, scale)
    _puff(draw, cx + int( 225 * scale), cy + int(-55 * scale), 115, 110, scale)

    # Tail puff — small wispy streak
    draw.ellipse(
        (cx + int(-45 * scale), cy + int(140 * scale),
         cx + int( 45 * scale), cy + int(175 * scale)),
        fill=CLOUD,
    )

    # Seagull-in-flight trace (matches generate_appicon.py exactly)
    path = [
        p(-250, 5), p(-205, -18), p(-150, -50), p(-100, -70),
        p(-55, -55), p(-25, -45), p(0, -60), p(25, -45),
        p(55, -55), p(100, -70), p(150, -50), p(205, -18),
        p(250, 5),
        p(215, 18), p(165, 0), p(115, -30), p(75, -32),
        p(45, -22), p(22, 5),
        p(18, 30), p(8, 50), p(0, 55), p(-8, 50), p(-18, 30),
        p(-22, 5), p(-45, -22), p(-75, -32), p(-115, -30),
        p(-165, 0), p(-215, 18), p(-250, 5),
    ]
    draw.line(path, fill=ink, width=max(4, int(10 * scale)), joint='curve')


def render(width, height):
    img = Image.new("RGBA", (width, height), (0, 0, 0, 0))
    d = ImageDraw.Draw(img, "RGBA")
    # Pick scale so the cloud arrangement (550w x 285h in design
    # units) fits in the canvas with breathing room on every edge.
    # Constrain by whichever dimension is tighter.
    scale = min((width * 0.95) / 580.0, (height * 0.95) / 320.0)
    # Vertical center: nudge up slightly so the bird body sits
    # above the canvas center (the tail puff extends downward and
    # would otherwise drag the visual weight).
    draw_cloud(
        d,
        width // 2,
        height // 2 - int(20 * scale),
        scale=scale,
    )
    return img


def main():
    os.makedirs(OUT_DIR, exist_ok=True)
    for factor, suffix in [(1, ""), (2, "@2x"), (3, "@3x")]:
        w = BASE_W * factor
        h = BASE_H * factor
        img = render(w, h)
        path = os.path.join(OUT_DIR, f"LaunchLogo{suffix}.png")
        img.save(path, "PNG", optimize=True)
        print(f"Wrote {path} ({w}x{h})")

    contents = {
        "images": [
            {"idiom": "universal", "filename": "LaunchLogo.png", "scale": "1x"},
            {"idiom": "universal", "filename": "LaunchLogo@2x.png", "scale": "2x"},
            {"idiom": "universal", "filename": "LaunchLogo@3x.png", "scale": "3x"},
        ],
        "info": {"author": "xcode", "version": 1},
    }
    with open(os.path.join(OUT_DIR, "Contents.json"), "w") as f:
        json.dump(contents, f, indent=2)
    print(f"Wrote {os.path.join(OUT_DIR, 'Contents.json')}")


if __name__ == "__main__":
    main()
