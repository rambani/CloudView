#!/usr/bin/env python3
"""
Lobe splitting — twin of CloudView/Services/CloudLobeSplitter.swift.

A big cloud bank arrives from the detector as one blob. Visually it is
several lobes: a bulbous head-puff, a tower, a long body. This splits the
blob where the eye splits it, using the brightness field itself:

  1. smooth the whiteness map (box blur, twice ≈ gaussian)
  2. peaks: local maxima inside the blob, non-max suppressed over a radius
  3. marker watershed: flood from the peaks in order of decreasing
     brightness; each pixel joins the lobe that reaches it first
  4. merge lobes whose shared valley is shallow (the saddle between the
     peaks is nearly as bright as the dimmer peak)
  5. drop/merge tiny lobes; trace each lobe's outline

Pure standard library; works on a small grid (≈256 px wide). Keep the
constants in sync with the Swift.
"""
import heapq
import math

SMOOTH_RADIUS_FRACTION = 0.025   # of grid width
PEAK_MIN_DISTANCE_FRACTION = 0.09
MIN_VALLEY_DEPTH = 0.10          # saddle must be ≥ this × below the dimmer peak
MIN_LOBE_AREA_FRACTION = 0.12    # of the blob's area, else merged into a neighbor
SUMMIT_FALLOFF = 0.8             # climb from the peak while field ≥ this × peak


def box_blur(img, w, h, r):
    if r < 1:
        return list(img)
    out = [0.0] * (w * h)
    # horizontal
    tmp = [0.0] * (w * h)
    for y in range(h):
        row = y * w
        acc = 0.0
        for x in range(-r, w):
            if x + r < w:
                acc += img[row + x + r]
            if x - r - 1 >= 0:
                acc -= img[row + x - r - 1]
            if x >= 0:
                lo, hi = max(0, x - r), min(w - 1, x + r)
                tmp[row + x] = acc / (hi - lo + 1)
    # vertical
    for x in range(w):
        acc = 0.0
        for y in range(-r, h):
            if y + r < h:
                acc += tmp[(y + r) * w + x]
            if y - r - 1 >= 0:
                acc -= tmp[(y - r - 1) * w + x]
            if y >= 0:
                lo, hi = max(0, y - r), min(h - 1, y + r)
                out[y * w + x] = acc / (hi - lo + 1)
    return out


def smooth(img, w, h):
    r = max(1, int(round(w * SMOOTH_RADIUS_FRACTION)))
    return box_blur(box_blur(img, w, h, r), w, h, r)


def find_peaks(field, w, h, mask, min_dist):
    """Local maxima inside the mask, strongest first, non-max suppressed."""
    cands = []
    for y in range(h):
        for x in range(w):
            i = y * w + x
            if not mask[i]:
                continue
            v = field[i]
            ok = True
            for dy in (-1, 0, 1):
                for dx in (-1, 0, 1):
                    if dx == 0 and dy == 0:
                        continue
                    nx, ny = x + dx, y + dy
                    if 0 <= nx < w and 0 <= ny < h and field[ny * w + nx] > v:
                        ok = False
                        break
                if not ok:
                    break
            if ok:
                cands.append((v, x, y))
    cands.sort(reverse=True)
    peaks = []
    for v, x, y in cands:
        if all(math.hypot(x - px, y - py) >= min_dist for _, px, py in peaks):
            peaks.append((v, x, y))
    return peaks


def watershed(field, w, h, mask, peaks):
    """Marker-based flood by decreasing brightness. Returns labels (0 = none)."""
    labels = [0] * (w * h)
    heap = []
    for k, (v, x, y) in enumerate(peaks, start=1):
        labels[y * w + x] = k
        heapq.heappush(heap, (-v, y * w + x))
    while heap:
        _, i = heapq.heappop(heap)
        lab = labels[i]
        x, y = i % w, i // w
        for nx, ny in ((x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)):
            if 0 <= nx < w and 0 <= ny < h:
                j = ny * w + nx
                if mask[j] and labels[j] == 0:
                    labels[j] = lab
                    heapq.heappush(heap, (-field[j], j))
    return labels


def merge_shallow(field, w, h, labels, peaks):
    """Union lobes whose saddle is nearly as bright as the dimmer peak."""
    n = len(peaks)
    saddle = {}
    for y in range(h):
        for x in range(w):
            i = y * w + x
            a = labels[i]
            if a == 0:
                continue
            for nx, ny in ((x + 1, y), (x, y + 1)):
                if nx < w and ny < h:
                    j = ny * w + nx
                    b = labels[j]
                    if b and b != a:
                        key = (min(a, b), max(a, b))
                        s = min(field[i], field[j])
                        if s > saddle.get(key, -1):
                            saddle[key] = s
    parent = list(range(n + 1))

    def find(u):
        while parent[u] != u:
            parent[u] = parent[parent[u]]
            u = parent[u]
        return u

    # Merge the shallowest valleys first.
    pairs = sorted(saddle.items(), key=lambda kv: -kv[1])
    for (a, b), s in pairs:
        ra, rb = find(a), find(b)
        if ra == rb:
            continue
        dimmer = min(peaks[a - 1][0], peaks[b - 1][0])
        if s >= dimmer * (1 - MIN_VALLEY_DEPTH):
            parent[rb] = ra
    return [find(l) if l else 0 for l in labels]


def merge_small(labels, w, h, min_area):
    """Fold lobes below min_area into the neighbor they touch most."""
    while True:
        areas = {}
        for l in labels:
            if l:
                areas[l] = areas.get(l, 0) + 1
        small = [l for l, a in areas.items() if a < min_area]
        if not small or len(areas) == 1:
            return labels
        l = min(small, key=lambda k: areas[k])
        touch = {}
        for y in range(h):
            for x in range(w):
                i = y * w + x
                if labels[i] != l:
                    continue
                for nx, ny in ((x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)):
                    if 0 <= nx < w and 0 <= ny < h:
                        b = labels[ny * w + nx]
                        if b and b != l:
                            touch[b] = touch.get(b, 0) + 1
        if not touch:
            # isolated small lobe: drop it
            labels = [0 if v == l else v for v in labels]
            continue
        target = max(touch, key=touch.get)
        labels = [target if v == l else v for v in labels]


def trace_outline(labels, w, h, label, max_points=100):
    """Moore-neighbour boundary trace of one label → ordered outline."""
    cells = {(x, y) for y in range(h) for x in range(w) if labels[y * w + x] == label}
    if not cells:
        return []
    start = min(cells, key=lambda p: (p[1], p[0]))
    nbrs = [(-1, 0), (-1, -1), (0, -1), (1, -1), (1, 0), (1, 1), (0, 1), (-1, 1)]
    outline = [start]
    cur, back = start, 0
    for _ in range(len(cells) * 4 + 8):
        found = False
        for k in range(8):
            idx = (back + k) % 8
            nxt = (cur[0] + nbrs[idx][0], cur[1] + nbrs[idx][1])
            if nxt in cells:
                cur = nxt
                back = (idx + 5) % 8
                found = True
                break
        if not found or cur == start:
            break
        outline.append(cur)
    if len(outline) > max_points:
        step = len(outline) / max_points
        outline = [outline[int(i * step)] for i in range(max_points)]
    return outline


def summit(field, w, h, labels, label):
    """Top of the bright mass: straight up from the brightest pixel while
    the field stays within SUMMIT_FALLOFF of the peak (a dim wisp attached
    above the mass stops the climb)."""
    best, bv = -1, -1.0
    for i in range(w * h):
        if labels[i] == label and field[i] > bv:
            best, bv = i, field[i]
    if best < 0:
        return (0, 0)
    x, y = best % w, best // w
    floor = bv * SUMMIT_FALLOFF
    while y > 0 and labels[(y - 1) * w + x] == label and field[(y - 1) * w + x] >= floor:
        y -= 1
    return (x, y)


def split_lobes(whiteness, w, h, mask):
    """whiteness: w*h floats 0..1 (upright). mask: w*h bools for the blob.
    Returns [(outline_in_grid_px, area_px, peak_value, summit_xy)], biggest first."""
    field = smooth(whiteness, w, h)
    area = sum(1 for m in mask if m)
    if area == 0:
        return []
    peaks = find_peaks(field, w, h, mask, max(2, int(round(w * PEAK_MIN_DISTANCE_FRACTION))))
    if len(peaks) <= 1:
        labels = [1 if m else 0 for m in mask]
        return [(trace_outline(labels, w, h, 1), area, peaks[0][0] if peaks else 0.0,
                 summit(field, w, h, labels, 1))]
    labels = watershed(field, w, h, mask, peaks)
    labels = merge_shallow(field, w, h, labels, peaks)
    labels = merge_small(labels, w, h, int(MIN_LOBE_AREA_FRACTION * area))
    out = []
    for l in sorted(set(labels) - {0}):
        pts = trace_outline(labels, w, h, l)
        a = sum(1 for v in labels if v == l)
        pv = max(field[i] for i in range(w * h) if labels[i] == l)
        if len(pts) >= 3:
            out.append((pts, a, pv, summit(field, w, h, labels, l)))
    out.sort(key=lambda t: -t[1])
    return out
