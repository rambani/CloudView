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


def draw_cloud(draw, cx, cy, scale=1.0):
    """Same 5-cloud-puff bird arrangement as the app icon (see
    generate_appicon.py for design rationale). Keeping both in
    sync so the icon you tapped and the brief launch flash read as
    one continuous moment."""
    ink = (38, 40, 56, 220)

    def e(x1, y1, x2, y2):
        return (cx + int(x1 * scale), cy + int(y1 * scale),
                cx + int(x2 * scale), cy + int(y2 * scale))

    def p(x, y):
        return (cx + int(x * scale), cy + int(y * scale))

    # Body
    draw.ellipse(e(-75, -95, 75, 105), fill=CLOUD)
    draw.ellipse(e(-95, -70, 95, 70), fill=CLOUD)
    # Inner wing puffs
    draw.ellipse(e(-200, -85, -70, 25), fill=CLOUD)
    draw.ellipse(e(70, -85, 200, 25), fill=CLOUD)
    # Wingtip puffs
    draw.ellipse(e(-275, -105, -175, 0), fill=CLOUD)
    draw.ellipse(e(175, -105, 275, 0), fill=CLOUD)
    # Tail puff
    draw.ellipse(e(-45, 130, 45, 180), fill=CLOUD)

    # Bird-in-flight trace
    path = [
        p(40, 10), p(100, -15), p(180, -40), p(245, -75),
        p(205, -60), p(130, -50), p(50, -50),
        p(14, -70), p(-14, -70),
        p(-50, -50), p(-130, -50), p(-205, -60), p(-245, -75),
        p(-180, -40), p(-100, -15), p(-40, 10),
        p(-22, 45), p(0, 80), p(22, 45),
        p(40, 10),
    ]
    draw.line(path, fill=ink, width=max(4, int(11 * scale)), joint='curve')


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
