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
# Wider than tall to fit the cumulus silhouette comfortably.
BASE_W = 280
BASE_H = 200

# Cloud color — soft warm white to feel like a Polaroid edge under
# warm light, not a clinical UI white.
CLOUD = (247, 244, 235, 255)
# Faint glow color (subtle haze around the silhouette)
GLOW = (255, 255, 255, 30)


def draw_cloud(draw, cx, cy, scale=1.0):
    """Same cumulus + bird-trace as the app icon (see
    generate_appicon.py for design rationale). Keeping both in
    sync so the icon you tapped and the brief launch flash read as
    one continuous moment."""
    ink = (38, 40, 56, 220)

    def e(x1, y1, x2, y2):
        return (cx + int(x1 * scale), cy + int(y1 * scale),
                cx + int(x2 * scale), cy + int(y2 * scale))

    def p(x, y):
        return (cx + int(x * scale), cy + int(y * scale))

    # Cumulus body
    draw.ellipse(e(-230, 0, 250, 140), fill=CLOUD)
    draw.ellipse(e(-200, -50, -30, 110), fill=CLOUD)
    draw.ellipse(e(30, -50, 220, 110), fill=CLOUD)
    draw.ellipse(e(-140, -140, 40, 50), fill=CLOUD)
    draw.ellipse(e(-20, -170, 170, 50), fill=CLOUD)
    draw.ellipse(e(50, -120, 200, 30), fill=CLOUD)

    # Bird-in-flight trace
    path = [
        p(30, 5), p(70, -10), p(130, -30), p(175, -55),
        p(145, -45), p(90, -35), p(35, -35),
        p(10, -50), p(-10, -50),
        p(-35, -35), p(-90, -35), p(-145, -45), p(-175, -55),
        p(-130, -30), p(-70, -10), p(-30, 5),
        p(-15, 30), p(0, 55), p(15, 30),
        p(30, 5),
    ]
    draw.line(path, fill=ink, width=max(4, int(9 * scale)), joint='curve')


def render(width, height):
    img = Image.new("RGBA", (width, height), (0, 0, 0, 0))
    d = ImageDraw.Draw(img, "RGBA")
    # Cloud scaled to fit the height, centered with a hair of bottom
    # padding so the silhouette doesn't kiss the safe-area edge.
    scale = height / 360.0
    draw_cloud(d, width // 2, height // 2 + int(20 * scale), scale=scale)
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
