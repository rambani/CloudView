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
# Aspect tracks the bird-shaped cloud arrangement (~2:1 wider than
# tall) so the silhouette fits with breathing room on every edge.
BASE_W = 320
BASE_H = 180

# Cloud color — soft warm white to feel like a Polaroid edge under
# warm light, not a clinical UI white.
CLOUD = (247, 244, 235, 255)

# Per-cloud bump recipes — kept in sync with generate_appicon.py
# so the launch flash and the icon you tapped match exactly.
_BODY_BUMPS = [
    (-0.55, -0.70, 0.95), (-0.12, -0.85, 1.00),
    ( 0.35, -0.75, 0.92), ( 0.70, -0.40, 0.78),
    ( 0.88,  0.05, 0.62), ( 0.40,  0.45, 0.55),
    (-0.30,  0.55, 0.60), (-0.72, -0.20, 0.80),
]
_LEFT_WING_BUMPS = [
    (-0.92, -0.05, 0.65), (-0.55, -0.55, 0.85),
    (-0.10, -0.80, 0.95), ( 0.45, -0.60, 0.85),
    ( 0.85, -0.20, 0.75), ( 0.20,  0.35, 0.60),
    (-0.50,  0.20, 0.55),
]
_RIGHT_WING_BUMPS = [
    ( 0.90,  0.05, 0.70), ( 0.50, -0.50, 0.90),
    ( 0.05, -0.78, 1.00), (-0.40, -0.65, 0.82),
    (-0.82, -0.15, 0.78), (-0.20,  0.40, 0.55),
    ( 0.55,  0.25, 0.62),
]


def _puff(draw, cx, cy, w, h, bumps, scale):
    """Same as the app icon's `_puff()` — center oval + per-cloud
    asymmetric bump list."""
    def el(x1, y1, x2, y2):
        return (cx + int(x1 * scale), cy + int(y1 * scale),
                cx + int(x2 * scale), cy + int(y2 * scale))
    draw.ellipse(el(-w * 0.42, -h * 0.38, w * 0.42, h * 0.38), fill=CLOUD)
    base_r = min(w, h) * 0.24
    for x_frac, y_frac, size_mult in bumps:
        bx = x_frac * w * 0.5
        by = y_frac * h * 0.5
        br = base_r * size_mult
        draw.ellipse(el(bx - br, by - br, bx + br, by + br), fill=CLOUD)


def draw_cloud(draw, cx, cy, scale=1.0):
    """Same three-cloud bird arrangement as the app icon (see
    generate_appicon.py for design rationale). No background
    wisps — the launch flash is brief; the bird silhouette and
    its host clouds are the whole job."""
    ink = (38, 40, 56, 220)

    def p(x, y):
        return (cx + int(x * scale), cy + int(y * scale))

    # Bird arrangement — three irregular cumulus puffs
    _puff(draw, cx, cy + int(-10 * scale), 165, 165, _BODY_BUMPS, scale)
    _puff(draw, cx + int(-175 * scale), cy + int(-35 * scale),
          225, 135, _LEFT_WING_BUMPS, scale)
    _puff(draw, cx + int( 175 * scale), cy + int(-35 * scale),
          225, 135, _RIGHT_WING_BUMPS, scale)

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
    # Scale so the cloud arrangement (~550w x 240h in design units)
    # fits with breathing room on every edge. Constrained by
    # whichever dimension is tighter.
    scale = min((width * 0.95) / 580.0, (height * 0.95) / 260.0)
    # Vertical center — slightly above geometric center since the
    # bird body sits above the trace's tail tip.
    draw_cloud(d, width // 2, height // 2 - int(5 * scale), scale=scale)
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
