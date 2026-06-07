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
# Taller than wide to fit the rabbit silhouette (long ears extend
# upward, body sits below) with breathing room on every edge.
BASE_W = 220
BASE_H = 260

# Cloud color — soft warm white to feel like a Polaroid edge under
# warm light, not a clinical UI white.
CLOUD = (247, 244, 235, 255)
# Faint glow color (subtle haze around the silhouette)
GLOW = (255, 255, 255, 30)


def draw_cloud(draw, cx, cy, scale=1.0):
    """Same rabbit-in-clouds silhouette as the app icon (see
    generate_appicon.py for the design rationale). Keeping both in
    sync so tap-to-launch and the icon you tapped read as one
    continuous moment."""
    eye = (38, 32, 42, 235)

    def e(x1, y1, x2, y2):
        return (cx + int(x1 * scale), cy + int(y1 * scale),
                cx + int(x2 * scale), cy + int(y2 * scale))

    # Ears (drawn first so the head overlaps their base cleanly)
    draw.ellipse(e(-100, -230, -30, -50), fill=CLOUD)
    draw.ellipse(e(30, -230, 100, -50), fill=CLOUD)
    # Head
    draw.ellipse(e(-90, -110, 90, 60), fill=CLOUD)
    draw.ellipse(e(-130, -70, -30, 60), fill=CLOUD)
    draw.ellipse(e(30, -70, 130, 60), fill=CLOUD)
    # Body
    draw.ellipse(e(-160, 10, 160, 150), fill=CLOUD)
    draw.ellipse(e(-110, 60, 110, 160), fill=CLOUD)
    # Eye dot
    eye_r = max(6, int(12 * scale))
    eye_cx = cx + int(-30 * scale)
    eye_cy = cy + int(-10 * scale)
    draw.ellipse(
        (eye_cx - eye_r, eye_cy - eye_r, eye_cx + eye_r, eye_cy + eye_r),
        fill=eye,
    )


def render(width, height):
    img = Image.new("RGBA", (width, height), (0, 0, 0, 0))
    d = ImageDraw.Draw(img, "RGBA")
    # Silhouette bounding box is roughly 320w x 390h; pick scale so
    # the height fits with ~7% padding on top and bottom. Center
    # horizontally; nudge down so the ears clear the top edge.
    scale = (height * 0.86) / 390.0
    draw_cloud(
        d,
        width // 2,
        height // 2 + int(40 * scale),
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
