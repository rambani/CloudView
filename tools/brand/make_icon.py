#!/usr/bin/env python3
"""Generate the Cloudoodle app icon (full-bleed 1024x1024) as SVG: blue sky
gradient, white puffy cloud with a doodle-cloud cutout holding a sparkle,
subtle sun + rain-cloud accents, soft cloud bank at the bottom, hand-drawn
rounded 'cloudoodle' wordmark.

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
def letters(word_cx, baseline, xh=60, stroke=20):
    """Rounded geometric lowercase letterforms as SVG elements.
    xh = x-height; circles have outer radius xh/2."""
    r = xh / 2
    asc = xh * 1.55          # ascender height for l, d
    gap = 30                 # inter-letter gap (covers stroke overhang)
    els = []
    # advance widths per letter
    widths = {'c': xh, 'l': 0.0, 'o': xh, 'u': xh, 'd': xh, 'e': xh}
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
      <stop offset="0" stop-color="#2453C6"/>
      <stop offset="0.55" stop-color="#3E82E6"/>
      <stop offset="1" stop-color="#8FBDF2"/>
    </linearGradient>
    <linearGradient id="cloudshade" x1="0" y1="280" x2="0" y2="720" gradientUnits="userSpaceOnUse">
      <stop offset="0" stop-color="#FFFFFF"/>
      <stop offset="1" stop-color="#E9F1FC"/>
    </linearGradient>
    <filter id="soft" x="-30%" y="-30%" width="160%" height="160%">
      <feDropShadow dx="0" dy="14" stdDeviation="22" flood-color="#123B8A" flood-opacity="0.28"/>
    </filter>
    <filter id="blur18"><feGaussianBlur stdDeviation="18"/></filter>
  </defs>

  <!-- sky -->
  <rect width="{S}" height="{S}" fill="url(#sky)"/>

  <!-- accent: sun (top-left, subtle darker blue) -->
  <g stroke="#1C489F" stroke-opacity="0.55" stroke-width="14" stroke-linecap="round" fill="none">
    <circle cx="200" cy="196" r="52" fill="#1C489F" fill-opacity="0.5" stroke="none"/>
    <g>
      <line x1="200" y1="102" x2="200" y2="72"/>
      <line x1="200" y1="290" x2="200" y2="320"/>
      <line x1="106" y1="196" x2="76" y2="196"/>
      <line x1="294" y1="196" x2="324" y2="196"/>
      <line x1="134" y1="130" x2="113" y2="109"/>
      <line x1="266" y1="130" x2="287" y2="109"/>
      <line x1="134" y1="262" x2="113" y2="283"/>
      <line x1="266" y1="262" x2="287" y2="283"/>
    </g>
  </g>

  <!-- accent: rain cloud (top-right, subtle). Group opacity so the
       overlapping circles merge without dark stacking. -->
  <g opacity="0.5">
    <g fill="#1C489F">
      <circle cx="800" cy="208" r="44"/>
      <circle cx="852" cy="184" r="56"/>
      <circle cx="906" cy="210" r="42"/>
      <rect x="796" y="206" width="152" height="44" rx="22"/>
    </g>
    <g stroke="#1C489F" stroke-width="12" stroke-linecap="round">
      <line x1="816" y1="286" x2="806" y2="322"/>
      <line x1="868" y1="292" x2="858" y2="328"/>
      <line x1="920" y1="286" x2="910" y2="322"/>
    </g>
  </g>

  <!-- hero cloud -->
  <g filter="url(#soft)">
    <g fill="url(#cloudshade)">
      <circle cx="392" cy="392" r="150"/>
      <circle cx="548" cy="330" r="180"/>
      <circle cx="704" cy="410" r="140"/>
      <circle cx="300" cy="508" r="112"/>
      <circle cx="780" cy="516" r="104"/>
      <rect x="238" y="416" width="600" height="204" rx="102"/>
    </g>
  </g>

  <!-- doodle cutout inside the cloud (sky shows through) -->
  <g fill="url(#sky)">
    <circle cx="474" cy="428" r="86"/>
    <circle cx="580" cy="392" r="96"/>
    <circle cx="676" cy="452" r="66"/>
    <rect x="416" y="428" width="310" height="98" rx="49"/>
  </g>

  <!-- sparkle in the cutout -->
  <path d="{sparkle(574, 448, 62, 16)}" fill="#FFFFFF"/>

  <!-- bottom cloud bank -->
  <g filter="url(#blur18)">
    <g fill="#CDE2F8" fill-opacity="0.85">
      <circle cx="60" cy="1010" r="150"/>
      <circle cx="280" cy="1040" r="190"/>
      <circle cx="530" cy="1010" r="170"/>
      <circle cx="770" cy="1050" r="200"/>
      <circle cx="980" cy="1000" r="150"/>
    </g>
    <g fill="#E8F2FD" fill-opacity="0.95">
      <circle cx="150" cy="1080" r="170"/>
      <circle cx="420" cy="1110" r="200"/>
      <circle cx="700" cy="1090" r="180"/>
      <circle cx="950" cy="1110" r="180"/>
    </g>
  </g>

  <!-- wordmark -->
  <g stroke="#FFFFFF" stroke-width="20" stroke-linecap="round" stroke-linejoin="round" fill="none">
    {letters(S/2, 856)}
  </g>
</svg>'''

out_dir = sys.argv[1] if len(sys.argv) > 1 else '.'
path = os.path.join(out_dir, 'icon.svg')
open(path, 'w').write(svg)
print("wrote", path)
