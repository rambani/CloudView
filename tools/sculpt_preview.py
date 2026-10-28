#!/usr/bin/env python3
"""
Pillow twin of CloudView/Services/CloudSculptor.swift — the "develop" recipe
that carves a creature into a cloud photo using the cloud's own light, so the
keepsake stays a real photo of a real cloud.

Same steps, same constants as the Swift (keep them in sync):

  stroke mask  ──► narrow + wide blurs, mixed by local luminance ──► SHADOW
  (inside cloud) shifted up ──► RIM LIGHT above each crease
  (outside cloud) wide blur ──► WISP (thin cloud where an ear overhangs sky)
  local contrast inside the cloud, soft vignette toward it

Usage:
  python3 sculpt_preview.py --out /tmp/sculpt.png            # synthetic cloud
  python3 sculpt_preview.py --photo sky.jpg --out /tmp/s.png  # your photo; the
          creature is placed on the brightest big blob, like the app would
"""
import argparse
import math
import random

from PIL import Image, ImageChops, ImageDraw, ImageFilter

# ---- recipe (mirror of SculptRecipe in Swift) ------------------------------
STROKE_WIDTH_CLOUD = 0.030  # sculpt width as a fraction of the cloud's short side…
STROKE_WIDTH_MIN_INK = 2.4  # …but never thinner than this many ink widths
POOL_MAX_AREA = 0.02        # closed paths smaller than this (× box area) fill as pools
SHADOW_BLUR_FACTOR = 0.8    # narrow shadow blur, in sculpt widths
SHADOW_WIDE_FACTOR = 2.4    # wide, soft spread added on bright puff
SHADOW_WIDE_GAIN = 0.8
BRIGHT_FADE = 0.3           # how much bright puff softens the narrow crease (0 = none)
SHADOW_STRENGTH = 0.78
SHADOW_TINT = (0.42, 0.50, 0.64)   # cloud shade is blue-grey, never black
RIM_OFFSET_FACTOR = 0.8     # rim light sits this many widths above a crease
RIM_STRENGTH = 0.45
WISP_BLUR_FACTOR = 1.2
WISP_STRENGTH = 0.85
WISP_TINT = (0.97, 0.98, 1.0)
CLOUD_FEATHER = 0.04        # fraction of the cloud box's short side
LUMINANCE_BLUR_FACTOR = 3.0
LOCAL_CONTRAST_RADIUS = 0.08  # fraction of short side
LOCAL_CONTRAST = 0.35
VIGNETTE = 0.22
MAX_SIDE = 1600


def synthetic_sky(w=900, h=1200, seed=3):
    rng = random.Random(seed)
    sky = Image.new("RGB", (w, h))
    px = sky.load()
    for y in range(h):
        t = y / h
        r = int(70 + 90 * t); g = int(130 + 70 * t); b = int(215 + 25 * t)
        for x in range(w):
            px[x, y] = (r, g, b)
    # cloud: overlapping puffs, lit from top-left, grey underside
    cloud = Image.new("L", (w, h), 0)
    d = ImageDraw.Draw(cloud)
    cx, cy = w * 0.5, h * 0.45
    puffs = [(0, 0, 220, 170), (-150, 40, 150, 120), (160, 50, 170, 130),
             (-60, -110, 140, 110), (80, -120, 120, 100), (-220, 110, 110, 90),
             (230, 130, 120, 90), (0, 120, 260, 110)]
    for dx, dy, rx, ry in puffs:
        d.ellipse([cx + dx - rx, cy + dy - ry, cx + dx + rx, cy + dy + ry], fill=255)
    cloud = cloud.filter(ImageFilter.GaussianBlur(14))
    # shading: top-left bright, lower-right grey, plus blurred speckle texture
    shade = Image.new("L", (w, h), 0)
    sp = shade.load()
    for y in range(h):
        for x in range(w):
            sp[x, y] = max(0, min(255, int(235 - 0.09 * (x - cx) - 0.22 * (y - cy))))
    noise = Image.effect_noise((w, h), 40).filter(ImageFilter.GaussianBlur(6))
    shade = ImageChops.add(shade, ImageChops.subtract(noise, Image.new("L", (w, h), 128)), 1.0)
    cloud_rgb = Image.merge("RGB", (shade, shade, ImageChops.add(shade, Image.new("L", (w, h), 10))))
    out = Image.composite(cloud_rgb, sky, cloud)
    contour = _mask_contour(cloud)
    return out, contour


def _mask_contour(mask, thresh=110, n=140):
    """Approximate outline of a soft mask as a polygon (polar sampling)."""
    w, h = mask.size
    px = mask.load()
    cx = sum(x for y in range(0, h, 4) for x in range(0, w, 4) if px[x, y] > thresh)
    cy = sum(y for y in range(0, h, 4) for x in range(0, w, 4) if px[x, y] > thresh)
    cnt = sum(1 for y in range(0, h, 4) for x in range(0, w, 4) if px[x, y] > thresh)
    cx, cy = cx / cnt, cy / cnt
    pts = []
    for i in range(n):
        a = 2 * math.pi * i / n
        r = 0
        for rr in range(0, max(w, h)):
            x, y = int(cx + rr * math.cos(a)), int(cy + rr * math.sin(a))
            if not (0 <= x < w and 0 <= y < h) or px[x, y] < thresh:
                break
            r = rr
        pts.append((cx + r * math.cos(a), cy + r * math.sin(a)))
    return pts


def contour_from_photo(im, gain=3.0):
    """Same cloud/sky split as CloudDetector: red channel vs frame mean."""
    r = im.split()[0]
    mean = sum(r.getdata()) / (r.width * r.height) / 255.0
    lut = [max(0, min(255, int(((v / 255.0 - mean) * gain + 0.5) * 255))) for v in range(256)]
    whiteness = r.point(lut)
    mask = whiteness.point(lambda v: 255 if v > 190 else 0).filter(ImageFilter.GaussianBlur(3))
    return _mask_contour(mask, 128)


def bear_paths(box):
    """A bear's signature + face, in normalized box space (y-down), as the
    app's assembler would emit: ears on the top edge, face at the centroid."""
    x0, y0, w, h = box
    def P(nx, ny): return (x0 + nx * w, y0 + ny * h)
    ear = lambda cx: [P(cx - 0.07, 0.14), P(cx - 0.08, 0.02), P(cx - 0.02, -0.04),
                      P(cx + 0.05, -0.02), P(cx + 0.08, 0.08), P(cx + 0.06, 0.15)]
    return [
        (ear(0.33), False), (ear(0.67), False),
        ([P(0.40, 0.38), P(0.43, 0.36), P(0.46, 0.38), P(0.43, 0.41)], True),  # eye
        ([P(0.54, 0.38), P(0.57, 0.36), P(0.60, 0.38), P(0.57, 0.41)], True),  # eye
        ([P(0.46, 0.52), P(0.50, 0.50), P(0.54, 0.52), P(0.50, 0.56)], True),  # nose
        ([P(0.42, 0.60), P(0.46, 0.65), P(0.50, 0.62), P(0.54, 0.65), P(0.58, 0.60)], False),  # mouth
    ]


def poly_area(pts):
    return abs(sum(pts[i][0] * pts[(i + 1) % len(pts)][1] - pts[(i + 1) % len(pts)][0] * pts[i][1]
                   for i in range(len(pts)))) / 2


def rasterize(paths, size, width, pool_area=None):
    """Strokes as a mask. Small closed paths (eyes, nose) fill as solid
    pools when `pool_area` is given — an outlined diamond reads as a drawing,
    a dark pool reads as an eye."""
    m = Image.new("L", size, 0)
    d = ImageDraw.Draw(m)
    for pts, closed in paths:
        seq = pts + ([pts[0]] if closed else [])
        if closed and pool_area is not None and len(pts) >= 3 and poly_area(pts) <= pool_area:
            d.polygon(pts, fill=255)
        d.line(seq, fill=255, width=max(1, int(round(width))), joint="curve")
        for p in seq:  # round caps
            d.ellipse([p[0] - width / 2, p[1] - width / 2, p[0] + width / 2, p[1] + width / 2], fill=255)
    return m


def scale(img, k):
    return img.point(lambda v: max(0, min(255, int(v * k))))


def tint_multiply(base, rgb):
    r, g, b = base.split()
    return Image.merge("RGB", (scale(r, rgb[0]), scale(g, rgb[1]), scale(b, rgb[2])))


def brighten(base, amount):
    return base.point(lambda v: min(255, int(v + amount * 255)))


def develop(photo, contour, paths, line_width_px):
    w, h = photo.size
    xs = [p[0] for p in contour]; ys = [p[1] for p in contour]
    box = (min(xs), min(ys), max(xs) - min(xs), max(ys) - min(ys))
    short = min(box[2], box[3])
    sw = max(short * STROKE_WIDTH_CLOUD, line_width_px * STROKE_WIDTH_MIN_INK)

    stroke = rasterize(paths, (w, h), sw, pool_area=POOL_MAX_AREA * box[2] * box[3])
    cloud = Image.new("L", (w, h), 0)
    ImageDraw.Draw(cloud).polygon(contour, fill=255)
    cloud = cloud.filter(ImageFilter.GaussianBlur(CLOUD_FEATHER * short))
    not_cloud = ImageChops.invert(cloud)

    lum = photo.convert("L").filter(ImageFilter.GaussianBlur(sw * LUMINANCE_BLUR_FACTOR))

    narrow = stroke.filter(ImageFilter.GaussianBlur(sw * SHADOW_BLUR_FACTOR))
    wide = scale(stroke.filter(ImageFilter.GaussianBlur(sw * SHADOW_WIDE_FACTOR)), SHADOW_WIDE_GAIN)
    # Bright puff: keep the crease (faded a little) and add the soft spread,
    # so a feature on a white dome is broader, not fainter.
    faded = Image.composite(scale(narrow, 1 - BRIGHT_FADE), narrow, lum)
    shadow = ImageChops.lighter(faded, wide)
    shadow_in = ImageChops.multiply(shadow, cloud)

    # 1. shadow: blend toward a blue-grey-tinted copy where the mask says so
    out = Image.composite(tint_multiply(photo, SHADOW_TINT), photo, scale(shadow_in, SHADOW_STRENGTH))

    # 2. rim light just above each crease (light comes from above)
    rim = ImageChops.offset(narrow, 0, -int(round(sw * RIM_OFFSET_FACTOR)))
    rim = ImageChops.multiply(ImageChops.multiply(rim, ImageChops.invert(narrow)), cloud)
    out = Image.composite(brighten(out, 0.35), out, scale(rim, RIM_STRENGTH))

    # 3. wisp: strokes over sky become thin cloud
    wisp = ImageChops.multiply(stroke.filter(ImageFilter.GaussianBlur(sw * WISP_BLUR_FACTOR)), not_cloud)
    out = Image.composite(Image.new("RGB", (w, h), tuple(int(c * 255) for c in WISP_TINT)), out,
                          scale(wisp, WISP_STRENGTH))

    # 4. local contrast inside the cloud
    sharp = out.filter(ImageFilter.UnsharpMask(radius=LOCAL_CONTRAST_RADIUS * short,
                                               percent=int(LOCAL_CONTRAST * 100), threshold=0))
    out = Image.composite(sharp, out, cloud)

    # 5. vignette toward the cloud
    vig = Image.new("L", (w, h), 0)
    cx, cy = box[0] + box[2] / 2, box[1] + box[3] / 2
    vd = ImageDraw.Draw(vig)
    R = max(w, h) * 0.8
    vd.ellipse([cx - R, cy - R, cx + R, cy + R], fill=255)
    vig = vig.filter(ImageFilter.GaussianBlur(R * 0.5))
    out = Image.composite(out, tint_multiply(out, (1 - VIGNETTE,) * 3), vig)
    return out, box


def ink_overlay(photo, paths, line_width_px):
    """What the AR snapshot shows today: ink + halo on top."""
    halo = rasterize(paths, photo.size, line_width_px * 2.6)
    ink = rasterize(paths, photo.size, line_width_px)
    out = Image.composite(Image.new("RGB", photo.size, (255, 255, 255)), photo, scale(halo, 0.55))
    return Image.composite(Image.new("RGB", photo.size, (31, 46, 82)), out, scale(ink, 0.92))


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--photo")
    ap.add_argument("--out", required=True)
    ap.add_argument("--line-width", type=float, default=4.0, help="ink width in px (app default 4)")
    args = ap.parse_args()

    if args.photo:
        photo = Image.open(args.photo).convert("RGB")
        photo.thumbnail((MAX_SIDE, MAX_SIDE))
        contour = contour_from_photo(photo)
    else:
        photo, contour = synthetic_sky()

    xs = [p[0] for p in contour]; ys = [p[1] for p in contour]
    box = (min(xs), min(ys), max(xs) - min(xs), max(ys) - min(ys))
    paths = bear_paths(box)
    # the app scales ink width with the frame; synthetic frame is ~1200 tall
    lw = args.line_width * photo.height / 1920 * 1.6

    before = ink_overlay(photo, paths, lw)
    after, _ = develop(photo, contour, paths, lw)

    w, h = photo.size
    sheet = Image.new("RGB", (w * 3 + 40, h + 60), (16, 21, 31))
    for i, (im, label) in enumerate([(photo, "frame"), (before, "today: ink on top"), (after, "develop: sculpted")]):
        sheet.paste(im, (i * (w + 20), 60))
        ImageDraw.Draw(sheet).text((i * (w + 20) + 12, 22), label, fill=(232, 237, 245))
    sheet.save(args.out)
    print("wrote", args.out)


if __name__ == "__main__":
    main()
