#!/usr/bin/env python3
"""Generate the Cloudoodle app icon (full-bleed 1024x1024) as SVG: royal-blue
sky fading to pale at the bottom, white puffy cloud with an organic
doodle-cloud cutout (melty drip at the bottom) holding a slender sparkle,
soft cloud bank in the corners, hand-drawn rounded 'cloudoodle' wordmark.

Usage:
    python3 make_icon.py [out_dir]        # writes out_dir/icon.svg

Render to PNG (headless Chromium), then flatten to RGB and install:
    chromium --headless --disable-gpu --no-sandbox --hide-scrollbars \
        --window-size=1024,1024 --screenshot=icon.png file://$PWD/icon.svg
    # iOS masks the corners itself: ship full-bleed, RGB, no alpha.
"""

import math
import os
import sys

S = 1024  # canvas


# ---------------------------------------------------------------- wordmark
def letters(word_cx, baseline, xh=70, stroke=24):
    """Rounded geometric lowercase letterforms as SVG elements.
    xh = x-height; circles have outer radius xh/2."""
    r = xh / 2
    asc = xh * 1.55          # ascender height for l, d
    gap = 26                 # inter-letter gap (covers stroke overhang)
    els = []
    # advance widths per letter
    # 'c' advances slightly tighter: its open right side reads narrower.
    widths = {'c': xh - 12, 'l': 0.0, 'o': xh, 'u': xh, 'd': xh, 'e': xh}
    word = "cloudoodle"
    total = sum(widths[ch] if widths[ch] else stroke for ch in word) + gap * (len(word) - 1)
    x = word_cx - total / 2
    B = baseline
    cy = B - r
    for ch in word:
        if ch == 'o':
            els.append(f'<circle cx="{x+r:.1f}" cy="{cy:.1f}" r="{r:.1f}"/>')
            x += xh + gap
        elif ch == 'c':
            a0, a1 = math.radians(48), math.radians(312)
            x0, y0 = x + r + r * math.cos(a0), cy + r * math.sin(a0)
            x1, y1 = x + r + r * math.cos(a1), cy + r * math.sin(a1)
            els.append(f'<path d="M {x0:.1f} {y0:.1f} A {r:.1f} {r:.1f} 0 1 1 {x1:.1f} {y1:.1f}"/>')
            x += widths['c'] + gap
        elif ch == 'l':
            lx = x + stroke / 2
            els.append(f'<path d="M {lx:.1f} {B-asc:.1f} L {lx:.1f} {B:.1f}"/>')
            x += stroke + gap - 12
        elif ch == 'u':
            lx, rx = x, x + xh
            els.append(
                f'<path d="M {lx:.1f} {B-xh:.1f} L {lx:.1f} {B-r:.1f} '
                f'A {r:.1f} {r:.1f} 0 0 0 {rx:.1f} {B-r:.1f} L {rx:.1f} {B-xh:.1f}"/>'
            )
            els.append(f'<path d="M {rx:.1f} {B-r:.1f} L {rx:.1f} {B:.1f}"/>')
            x += xh + gap
        elif ch == 'd':
            els.append(f'<circle cx="{x+r:.1f}" cy="{cy:.1f}" r="{r:.1f}"/>')
            sx = x + xh
            els.append(f'<path d="M {sx:.1f} {B-asc:.1f} L {sx:.1f} {B:.1f}"/>')
            x += xh + gap
        elif ch == 'e':
            # crossbar + arc sweeping the long way from crossbar-right,
            # over the top, around to lower-right opening
            ex0, ey0 = x + xh, cy
            aend = math.radians(38)
            ex1 = x + r + r * math.cos(aend)
            ey1 = cy + r * math.sin(aend)
            els.append(f'<path d="M {x:.1f} {cy:.1f} L {ex0:.1f} {ey0:.1f}"/>')
            els.append(f'<path d="M {ex0:.1f} {ey0:.1f} A {r:.1f} {r:.1f} 0 1 0 {ex1:.1f} {ey1:.1f}"/>')
            x += xh + gap
    return "\n    ".join(els)


def sparkle(cx, cy, R, r):
    """4-point star with concave sides."""
    pts = []
    for i in range(4):
        a = math.radians(90 * i - 90)
        pts.append((cx + R * math.cos(a), cy + R * math.sin(a)))
        b = math.radians(90 * i - 45)
        pts.append((cx + r * math.cos(b), cy + r * math.sin(b)))
    d = f"M {pts[0][0]:.1f} {pts[0][1]:.1f} "
    for i in range(1, 8, 2):
        qx, qy = pts[i]
        nx, ny = pts[(i + 1) % 8]
        d += f"Q {qx:.1f} {qy:.1f} {nx:.1f} {ny:.1f} "
    return d + "Z"


svg = f'''<svg xmlns="http://www.w3.org/2000/svg" width="{S}" height="{S}" viewBox="0 0 {S} {S}">
  <defs>
    <linearGradient id="sky" x1="0" y1="0" x2="0" y2="{S}" gradientUnits="userSpaceOnUse">
      <stop offset="0" stop-color="#1D55D8"/>
      <stop offset="0.5" stop-color="#3B7EE6"/>
      <stop offset="0.82" stop-color="#6FA6EF"/>
      <stop offset="1" stop-color="#C4DEFA"/>
    </linearGradient>
    <linearGradient id="cloudshade" x1="0" y1="230" x2="0" y2="660" gradientUnits="userSpaceOnUse">
      <stop offset="0" stop-color="#FFFFFF"/>
      <stop offset="1" stop-color="#EAF2FC"/>
    </linearGradient>
    <filter id="soft" x="-30%" y="-30%" width="160%" height="160%">
      <feDropShadow dx="0" dy="14" stdDeviation="22" flood-color="#123B8A" flood-opacity="0.22"/>
    </filter>
    <filter id="blur18"><feGaussianBlur stdDeviation="18"/></filter>
  </defs>

  <!-- sky -->
  <rect width="{S}" height="{S}" fill="url(#sky)"/>

  <!-- hero cloud -->
  <g filter="url(#soft)">
    <g fill="url(#cloudshade)">
      <circle cx="400" cy="400" r="155"/>
      <circle cx="560" cy="330" r="185"/>
      <circle cx="710" cy="420" r="145"/>
      <circle cx="305" cy="520" r="115"/>
      <circle cx="790" cy="530" r="105"/>
      <rect x="240" y="430" width="610" height="210" rx="105"/>
    </g>
  </g>

  <!-- organic doodle cutout inside the cloud (sky shows through),
       with a melty drip at the bottom -->
  <g fill="url(#sky)">
    <circle cx="495" cy="435" r="80"/>
    <circle cx="600" cy="405" r="95"/>
    <circle cx="685" cy="470" r="65"/>
    <rect x="445" y="445" width="300" height="95" rx="47.5"/>
    <circle cx="560" cy="545" r="42"/>
    <circle cx="552" cy="578" r="26"/>
  </g>

  <!-- slender sparkle in the cutout -->
  <path d="{sparkle(538, 448, 56, 11)}" fill="#FFFFFF"/>

  <!-- bottom cloud bank, heavier in the corners -->
  <g filter="url(#blur18)">
    <g fill="#E4F0FC" fill-opacity="0.9">
      <circle cx="30" cy="1010" r="150"/>
      <circle cx="200" cy="1035" r="170"/>
      <circle cx="830" cy="1030" r="180"/>
      <circle cx="1000" cy="1000" r="160"/>
    </g>
    <g fill="#F7FBFF" fill-opacity="0.95">
      <circle cx="90" cy="1090" r="190"/>
      <circle cx="450" cy="1110" r="180"/>
      <circle cx="650" cy="1120" r="190"/>
      <circle cx="940" cy="1090" r="190"/>
    </g>
  </g>

  <!-- wordmark -->
  <g stroke="#FFFFFF" stroke-width="24" stroke-linecap="round" stroke-linejoin="round" fill="none">
    {letters(S/2, 880)}
  </g>
</svg>'''

out_dir = sys.argv[1] if len(sys.argv) > 1 else '.'
path = os.path.join(out_dir, 'icon.svg')
open(path, 'w').write(svg)
print("wrote", path)
