#!/usr/bin/env python3
"""Generate the Cloudoodle launch-screen mark: the hero cloud with its
doodle-cloud cutout (true transparency via mask) and the white sparkle.
Transparent background so it sits on the LaunchBackground color.

Usage:
    python3 make_launch_mark.py WIDTH HEIGHT [out_dir]

Asset sizes used in Assets.xcassets/LaunchImage.imageset:
    1x 184x130, 2x 368x260, 3x 552x390 (render each, screenshot with
    --default-background-color=00000000 so the cutout stays transparent).
"""

import math
import os
import sys


# Same sparkle as the app icon.
def sparkle(cx, cy, R, r):
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


HERO = '''
      <circle cx="392" cy="392" r="150"/>
      <circle cx="548" cy="330" r="180"/>
      <circle cx="704" cy="410" r="140"/>
      <circle cx="300" cy="508" r="112"/>
      <circle cx="780" cy="516" r="104"/>
      <rect x="238" y="416" width="600" height="204" rx="102"/>
'''

CUTOUT = '''
      <circle cx="474" cy="428" r="86"/>
      <circle cx="580" cy="392" r="96"/>
      <circle cx="676" cy="452" r="66"/>
      <rect x="416" y="428" width="310" height="98" rx="49"/>
'''

W, H = int(sys.argv[1]), int(sys.argv[2])

svg = f'''<svg xmlns="http://www.w3.org/2000/svg" width="{W}" height="{H}" viewBox="168 130 736 520">
  <defs>
    <linearGradient id="cloudshade" x1="0" y1="280" x2="0" y2="720" gradientUnits="userSpaceOnUse">
      <stop offset="0" stop-color="#FFFFFF"/>
      <stop offset="1" stop-color="#E9F1FC"/>
    </linearGradient>
    <mask id="cut">
      <g fill="#FFFFFF">{HERO}</g>
      <g fill="#000000">{CUTOUT}</g>
    </mask>
  </defs>
  <g mask="url(#cut)">
    <g fill="url(#cloudshade)">{HERO}</g>
  </g>
  <path d="{sparkle(574, 448, 62, 16)}" fill="#FFFFFF"/>
</svg>'''

out_dir = sys.argv[3] if len(sys.argv) > 3 else '.'
path = os.path.join(out_dir, 'launch_mark.svg')
open(path, 'w').write(svg)
print("wrote", path, W, H)
