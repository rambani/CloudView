#!/usr/bin/env python3
"""
Offline harness for the shape-retrieval step: does the Hu-moment matcher
actually tell creatures apart, and what does it pick for real clouds?

Exact port of the app's CloudShapeSignature.huMoments (Green's-theorem
polygon moments → seven Hu invariants) and ShapeMatcher (sign-preserving
log-L1 distance → exp(-d/6) score), run against the shipped
DrawingTemplates.json. Pure standard library + Pillow (for --photos).

Modes (combine freely):

  --matrix                creature-vs-creature: for every silhouette, its
                          nearest other creature and how many others clear
                          the confidence floor. Low numbers = distinguishable.
  --synthetic N           N random cloud-like blobs (fixed seed): score
                          spread, winner-vs-runner-up gap, pick histogram.
  --log FILE.jsonl        contours recorded on-device (Settings → Developer →
                          Record cloud contours → Export). Ranks each one and
                          cross-checks the label the app actually chose.
  --photos DIR            sky photos; extracts the dominant cloud contour the
                          way the app does (red channel vs frame mean) and
                          ranks it. Writes contour overlays next to --html.
  --html OUT.html         contact sheet for --log / --photos: cloud outline,
                          top-3 creature silhouettes, scores, and a notes
                          column for a human "does it look like that?" pass.

Examples:
  python3 validate_retrieval.py --matrix --synthetic 300
  python3 validate_retrieval.py --log ~/Downloads/cloudoodle-contours.jsonl --html /tmp/clouds.html
"""

import argparse
import json
import math
import os
import random
import sys
from collections import Counter, deque

# --------------------------------------------------------------------------
# Ports of CloudShapeSignature / ShapeMatcher (keep in sync with Swift)
# --------------------------------------------------------------------------

def hu_moments(contour):
    if len(contour) < 3:
        return [0.0] * 7
    n = len(contour)
    vx = sum(p[0] for p in contour) / n
    vy = sum(p[1] for p in contour) / n
    pts = [(p[0] - vx, p[1] - vy) for p in contour]

    m00 = m10 = m01 = m20 = m02 = m11 = m30 = m03 = m21 = m12 = 0.0
    for i in range(n):
        xi, yi = pts[i]
        xj, yj = pts[(i + 1) % n]
        cross = xi * yj - xj * yi
        m00 += cross
        m10 += (xi + xj) * cross
        m01 += (yi + yj) * cross
        m20 += (xi * xi + xi * xj + xj * xj) * cross
        m02 += (yi * yi + yi * yj + yj * yj) * cross
        m11 += (2 * xi * yi + xi * yj + xj * yi + 2 * xj * yj) * cross
        m30 += (xi**3 + xi * xi * xj + xi * xj * xj + xj**3) * cross
        m03 += (yi**3 + yi * yi * yj + yi * yj * yj + yj**3) * cross
        m21 += (3 * xi * xi * yi + 2 * xi * xj * yi + xj * xj * yi
                + xi * xi * yj + 2 * xi * xj * yj + 3 * xj * xj * yj) * cross
        m12 += (3 * xi * yi * yi + 2 * xi * yi * yj + xi * yj * yj
                + xj * yi * yi + 2 * xj * yi * yj + 3 * xj * yj * yj) * cross
    m00 /= 2.0; m10 /= 6.0; m01 /= 6.0; m20 /= 12.0; m02 /= 12.0; m11 /= 24.0
    m30 /= 20.0; m03 /= 20.0; m21 /= 60.0; m12 /= 60.0
    if abs(m00) <= 1e-12:
        return [0.0] * 7
    cx, cy = m10 / m00, m01 / m00
    mu00 = m00
    mu20 = m20 - cx * m10
    mu02 = m02 - cy * m01
    mu11 = m11 - cx * m01
    mu30 = m30 - 3 * cx * m20 + 2 * cx * cx * m10
    mu03 = m03 - 3 * cy * m02 + 2 * cy * cy * m01
    mu21 = m21 - 2 * cx * m11 - cy * m20 + 2 * cx * cx * m01
    mu12 = m12 - 2 * cy * m11 - cx * m02 + 2 * cy * cy * m10

    def eta(mu, p, q):
        return mu / (abs(mu00) ** ((p + q) / 2.0 + 1.0))
    n20, n02, n11 = eta(mu20, 2, 0), eta(mu02, 0, 2), eta(mu11, 1, 1)
    n30, n03, n21, n12 = eta(mu30, 3, 0), eta(mu03, 0, 3), eta(mu21, 2, 1), eta(mu12, 1, 2)

    h1 = n20 + n02
    h2 = (n20 - n02) ** 2 + 4 * n11 ** 2
    h3 = (n30 - 3 * n12) ** 2 + (3 * n21 - n03) ** 2
    h4 = (n30 + n12) ** 2 + (n21 + n03) ** 2
    h5 = ((n30 - 3 * n12) * (n30 + n12) * ((n30 + n12) ** 2 - 3 * (n21 + n03) ** 2)
          + (3 * n21 - n03) * (n21 + n03) * (3 * (n30 + n12) ** 2 - (n21 + n03) ** 2))
    h6 = ((n20 - n02) * ((n30 + n12) ** 2 - (n21 + n03) ** 2)
          + 4 * n11 * (n30 + n12) * (n21 + n03))
    h7 = abs((3 * n21 - n03) * (n30 + n12) * ((n30 + n12) ** 2 - 3 * (n21 + n03) ** 2)
             - (n30 - 3 * n12) * (n21 + n03) * (3 * (n30 + n12) ** 2 - (n21 + n03) ** 2))
    return [h1, h2, h3, h4, h5, h6, h7]


def log_moments(hu):
    out = []
    for v in hu:
        if not math.isfinite(v) or abs(v) <= 1e-30:
            out.append(0.0)
        else:
            out.append((-1.0 if v < 0 else 1.0) * math.log10(abs(v)))
    return out


SCORE_SCALE = 6.0          # ShapeMatcher.scoreScale
CONFIDENCE_FLOOR = 0.30    # DrawingTemplateLibrary.confidenceFloor
STRONG_THRESHOLD = 0.55    # TemplateDrawingComposer.defaultStrongThreshold


def distance(a, b):
    la, lb = log_moments(a), log_moments(b)
    return sum(abs(x - y) for x, y in zip(la, lb))


def score(d):
    return math.exp(-d / SCORE_SCALE)


# --------------------------------------------------------------------------
# Library
# --------------------------------------------------------------------------

def load_library(path):
    with open(path) as fh:
        doc = json.load(fh)
    if doc.get("version") == 2:
        entries = [(c["label"], c["silhouette"]) for c in doc["creatures"]]
    else:
        entries = [(t["label"], t["silhouette"]) for t in doc["templates"]]
    return [(label, [tuple(p) for p in sil], hu_moments([tuple(p) for p in sil]))
            for label, sil in entries]


def rank(library, contour):
    hu = hu_moments(contour)
    scored = [(label, score(distance(hu, lhu))) for label, _, lhu in library]
    scored.sort(key=lambda t: -t[1])
    return scored


# --------------------------------------------------------------------------
# Synthetic clouds
# --------------------------------------------------------------------------

def synthetic_cloud(rng, n_points=72):
    """A blobby closed contour: unit circle modulated by a few low-frequency
    sinusoids (cumulus bumps) plus a little jitter, normalized to its bbox
    the way the detector normalizes a real contour."""
    harmonics = [(k, rng.uniform(0.0, 0.35 / k), rng.uniform(0, 2 * math.pi))
                 for k in range(2, 7)]
    stretch = rng.uniform(0.6, 1.8)
    pts = []
    for i in range(n_points):
        t = 2 * math.pi * i / n_points
        r = 1.0 + sum(a * math.sin(k * t + phi) for k, a, phi in harmonics)
        r += rng.uniform(-0.03, 0.03)
        pts.append((math.cos(t) * r * stretch, math.sin(t) * r))
    return normalize(pts)


def normalize(pts):
    xs = [p[0] for p in pts]; ys = [p[1] for p in pts]
    w = max(xs) - min(xs) or 1.0; h = max(ys) - min(ys) or 1.0
    return [((x - min(xs)) / w, (y - min(ys)) / h) for x, y in pts]


# --------------------------------------------------------------------------
# Photo → contour (mirrors CloudDetector: red channel vs. frame mean)
# --------------------------------------------------------------------------

def contour_from_photo(path, max_side=320, gain=3.0):
    from PIL import Image
    im = Image.open(path).convert("RGB")
    im.thumbnail((max_side, max_side))
    w, h = im.size
    px = im.load()
    reds = [px[x, y][0] / 255.0 for y in range(h) for x in range(w)]
    mean = sum(reds) / len(reds)
    # Same mapping as the app: (R - mean) * gain + 0.5, then "bright" > 0.75.
    mask = [[((px[x, y][0] / 255.0 - mean) * gain + 0.5) > 0.75 for x in range(w)] for y in range(h)]

    # Connected components (4-neighbour flood fill); keep the best by the
    # app's rule: sqrt(area fraction) / (1 + 4 * off-center).
    seen = [[False] * w for _ in range(h)]
    best, best_score = None, -1.0
    for sy in range(h):
        for sx in range(w):
            if not mask[sy][sx] or seen[sy][sx]:
                continue
            comp = []
            dq = deque([(sx, sy)])
            seen[sy][sx] = True
            while dq:
                x, y = dq.popleft()
                comp.append((x, y))
                for nx, ny in ((x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)):
                    if 0 <= nx < w and 0 <= ny < h and mask[ny][nx] and not seen[ny][nx]:
                        seen[ny][nx] = True
                        dq.append((nx, ny))
            area = len(comp) / (w * h)
            if area < 0.02 or area > 0.60:
                continue
            cx = sum(p[0] for p in comp) / len(comp); cy = sum(p[1] for p in comp) / len(comp)
            off = math.hypot((cx - w / 2) / w, (cy - h / 2) / h)
            s = math.sqrt(area) / (1 + 4 * off)
            if s > best_score:
                best, best_score = comp, s
    if best is None:
        return None, (w, h), mean
    return trace_boundary(set(best), w, h), (w, h), mean


def trace_boundary(cells, w, h, max_points=100):
    """Moore-neighbour boundary tracing of a pixel set → ordered outline."""
    start = min(cells, key=lambda p: (p[1], p[0]))
    nbrs = [(-1, 0), (-1, -1), (0, -1), (1, -1), (1, 0), (1, 1), (0, 1), (-1, 1)]  # clockwise from W
    boundary = [start]
    cur = start
    back = 0  # index into nbrs of the backtrack direction (start looking west)
    for _ in range(50000):
        found = False
        for k in range(8):
            idx = (back + k) % 8
            nx, ny = cur[0] + nbrs[idx][0], cur[1] + nbrs[idx][1]
            if (nx, ny) in cells:
                cur = (nx, ny)
                back = (idx + 5) % 8  # start next search from the pixel before the one we entered from
                found = True
                break
        if not found:
            break
        if cur == start:
            break
        boundary.append(cur)
    if len(boundary) > max_points:
        step = len(boundary) / max_points
        boundary = [boundary[int(i * step)] for i in range(max_points)]
    return normalize(boundary)


# --------------------------------------------------------------------------
# Reports
# --------------------------------------------------------------------------

def report_matrix(library):
    print("== Creature-vs-creature (shipped silhouettes) ==")
    print(f"{'creature':<16}{'nearest other':<18}{'score':>7}{'  #others ≥ floor':>18}{'  #others ≥ strong':>19}")
    confusable = Counter()
    for label, _, hu in library:
        others = [(l2, score(distance(hu, hu2))) for l2, _, hu2 in library if l2 != label]
        others.sort(key=lambda t: -t[1])
        above_floor = sum(1 for _, s in others if s >= CONFIDENCE_FLOOR)
        above_strong = sum(1 for _, s in others if s >= STRONG_THRESHOLD)
        confusable[label] = above_strong
        print(f"{label:<16}{others[0][0]:<18}{others[0][1]:>7.2f}{above_floor:>18}{above_strong:>19}")
    n = len(library)
    print(f"\n{n} creatures; floor {CONFIDENCE_FLOOR}, strong {STRONG_THRESHOLD}.")
    print(f"Mean #other creatures a silhouette would match 'strongly': "
          f"{sum(confusable.values()) / n:.1f} of {n - 1}")


def report_rankings(name, items, library, floor=CONFIDENCE_FLOOR):
    """items: list of (id, contour, chosen_label_or_None)."""
    print(f"\n== {name}: {len(items)} contours ==")
    picks = Counter()
    gaps, tops, n_floor, n_strong, agree, labelled = [], [], [], 0, 0, 0
    for _, contour, chosen in items:
        ranked = rank(library, contour)
        top = ranked[0]
        tops.append(top[1])
        gaps.append(top[1] - ranked[1][1] if len(ranked) > 1 else 0.0)
        n_floor.append(sum(1 for _, s in ranked if s >= floor))
        n_strong += 1 if top[1] >= STRONG_THRESHOLD else 0
        if top[1] >= floor:
            picks[top[0]] += 1
        if chosen:
            labelled += 1
            if chosen.lower() == top[0].lower():
                agree += 1
    m = len(items)
    print(f"top-1 score: mean {sum(tops)/m:.2f}, min {min(tops):.2f}, max {max(tops):.2f}")
    print(f"top-1 ≥ strong ({STRONG_THRESHOLD}): {n_strong}/{m}   "
          f"top-1 < floor ({floor}): {sum(1 for t in tops if t < floor)}/{m}")
    print(f"creatures ≥ floor per cloud: mean {sum(n_floor)/m:.1f} of {len(library)}")
    print(f"winner − runner-up gap: mean {sum(gaps)/m:.3f}, median {sorted(gaps)[m//2]:.3f}")
    if labelled:
        print(f"app's chosen label == harness top-1: {agree}/{labelled} "
              f"(differences come from the seeded 80/15/5 category temperature)")
    print("pick histogram:", ", ".join(f"{k} {v}" for k, v in picks.most_common()))
    return picks


def write_html(path, items, library, images=None):
    """items: list of (id, contour, chosen). images: id → relative image path."""
    def poly(pts, cls, closed=True):
        d = "M " + " L ".join(f"{x:.4f} {y:.4f}" for x, y in pts) + (" Z" if closed else "")
        return f'<path d="{d}" class="{cls}"/>'
    tiles = []
    for ident, contour, chosen in items:
        ranked = rank(library, contour)[:3]
        sils = {l: s for l, s, _ in library}
        overlays = "".join(
            f'<figure><svg viewBox="-0.1 -0.1 1.2 1.2">{poly(contour, "cloud")}{poly(sils[l], "sil")}</svg>'
            f'<figcaption>{l} · {s:.2f}{" ✓" if chosen and chosen.lower() == l.lower() else ""}</figcaption></figure>'
            for l, s in ranked)
        img = f'<img src="{images[ident]}">' if images and ident in images else ""
        tiles.append(
            f'<section><h3>{ident}{(" — app drew: " + chosen) if chosen else ""}</h3>'
            f'<div class="row">{img}<figure><svg viewBox="-0.1 -0.1 1.2 1.2">{poly(contour, "cloud")}</svg>'
            f'<figcaption>extracted contour</figcaption></figure>{overlays}'
            f'<div class="notes" contenteditable="true">notes…</div></div></section>')
    html = f"""<!DOCTYPE html><html><head><meta charset="utf-8"><title>Cloudoodle retrieval check</title>
<style>
 body{{background:#10151f;color:#e8edf5;font-family:-apple-system,'Segoe UI',sans-serif;padding:24px}}
 h3{{margin:18px 0 6px;font-size:15px;font-weight:600}} .row{{display:flex;gap:12px;align-items:flex-start;flex-wrap:wrap}}
 img{{height:150px;border-radius:10px}} figure{{margin:0;width:150px}}
 svg{{width:150px;height:150px;border-radius:10px;background:linear-gradient(165deg,#7db4e8,#4a86c9 55%,#38699f)}}
 .cloud{{fill:rgba(255,255,255,.35);stroke:#fff;stroke-width:.012}} .sil{{fill:none;stroke:#ffd966;stroke-width:.014;stroke-dasharray:.03 .02}}
 figcaption{{font-size:12px;color:#b9c4d6;margin-top:4px}} .notes{{min-width:180px;min-height:60px;background:#1b2230;border-radius:10px;padding:8px;font-size:13px;color:#9fb0c8}}
</style></head><body><h1>Retrieval check</h1>
<p>White: the cloud contour. Dashed yellow: the top-3 creature silhouettes by Hu-moment score. Rate honestly — does the cloud look like the creature?</p>
{"".join(tiles)}</body></html>"""
    with open(path, "w") as fh:
        fh.write(html)
    print(f"wrote {path}")


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    here = os.path.dirname(os.path.abspath(__file__))
    ap.add_argument("--templates", default=os.path.join(here, "..", "CloudView", "Resources", "DrawingTemplates.json"))
    ap.add_argument("--matrix", action="store_true")
    ap.add_argument("--synthetic", type=int, metavar="N")
    ap.add_argument("--seed", type=int, default=7)
    ap.add_argument("--log", metavar="JSONL")
    ap.add_argument("--photos", metavar="DIR")
    ap.add_argument("--html", metavar="OUT")
    args = ap.parse_args()

    library = load_library(args.templates)
    print(f"library: {len(library)} creatures from {os.path.relpath(args.templates)}")

    if args.matrix:
        report_matrix(library)

    if args.synthetic:
        rng = random.Random(args.seed)
        items = [(f"synthetic-{i}", synthetic_cloud(rng), None) for i in range(args.synthetic)]
        report_rankings("synthetic clouds", items, library)

    sheet_items, images = [], {}
    if args.log:
        items = []
        with open(args.log) as fh:
            for i, line in enumerate(fh):
                line = line.strip()
                if not line:
                    continue
                rec = json.loads(line)
                contour = [tuple(p) for p in rec["contour"]]
                items.append((f"log-{i} {rec.get('t', '')}", contour, rec.get("label")))
        report_rankings("on-device contours", items, library)
        sheet_items += items

    if args.photos:
        if not args.html:
            ap.error("--photos needs --html for the overlays")
        out_dir = os.path.dirname(os.path.abspath(args.html)) or "."
        items = []
        for name in sorted(os.listdir(args.photos)):
            if not name.lower().endswith((".jpg", ".jpeg", ".png", ".heic")):
                continue
            path = os.path.join(args.photos, name)
            try:
                contour, size, mean = contour_from_photo(path)
            except Exception as exc:  # noqa: BLE001
                print(f"skip {name}: {exc}")
                continue
            if not contour:
                print(f"{name}: no distinct cloud found (mean red {mean:.2f})")
                continue
            items.append((name, contour, None))
            from PIL import Image
            thumb = Image.open(path).convert("RGB"); thumb.thumbnail((300, 300))
            rel = f"thumb-{os.path.splitext(name)[0]}.jpg"
            thumb.save(os.path.join(out_dir, rel), quality=80)
            images[name] = rel
        if items:
            report_rankings("photos", items, library)
            sheet_items += items

    if args.html and sheet_items:
        write_html(args.html, sheet_items, library, images)

    if not (args.matrix or args.synthetic or args.log or args.photos):
        ap.error("nothing to do — see --help")


if __name__ == "__main__":
    main()
