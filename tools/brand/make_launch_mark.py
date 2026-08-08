#!/usr/bin/env python3
"""Generate the Cloudoodle launch-screen mark: the hero cloud with its
doodle-cloud cutout (true transparency via mask) and the white sparkle.
Transparent background so it sits on the LaunchBackground color.

Usage:
    python3 make_launch_mark.py WIDTH HEIGHT [out_dir]

Asset sizes used in Assets.xcassets/LaunchImage.imageset:
    1x 187x134, 2x 374x268, 3x 561x402 (render each, screenshot with
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
      <circle cx="400" cy="400" r="155"/>
      <circle cx="560" cy="330" r="185"/>
      <circle cx="710" cy="420" r="145"/>
      <circle cx="305" cy="520" r="115"/>
      <circle cx="790" cy="530" r="105"/>
      <rect x="240" y="430" width="610" height="210" rx="105"/>
'''

CUTOUT = '''
      <circle cx="495" cy="435" r="80"/>
      <circle cx="600" cy="405" r="95"/>
      <circle cx="685" cy="470" r="65"/>
      <rect x="445" y="445" width="300" height="95" rx="47.5"/>
      <circle cx="560" cy="545" r="42"/>
      <circle cx="552" cy="578" r="26"/>
'''

W, H = int(sys.argv[1]), int(sys.argv[2])

svg = f'''<svg xmlns="http://www.w3.org/2000/svg" width="{W}" height="{H}" viewBox="168 124 748 536">
  <defs>
    <linearGradient id="cloudshade" x1="0" y1="230" x2="0" y2="660" gradientUnits="userSpaceOnUse">
      <stop offset="0" stop-color="#FFFFFF"/>
      <stop offset="1" stop-color="#EAF2FC"/>
    </linearGradient>
    <mask id="cut">
      <g fill="#FFFFFF">{HERO}</g>
      <g fill="#000000">{CUTOUT}</g>
    </mask>
  </defs>
  <g mask="url(#cut)">
    <g fill="url(#cloudshade)">{HERO}</g>
  </g>
  <path d="{sparkle(538, 448, 56, 11)}" fill="#FFFFFF"/>
</svg>'''

out_dir = sys.argv[3] if len(sys.argv) > 3 else '.'
path = os.path.join(out_dir, 'launch_mark.svg')
open(path, 'w').write(svg)
print("wrote", path, W, H)
