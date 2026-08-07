#!/usr/bin/env python3
"""
Build the app's DrawingTemplates.json (schema v2: creatures + parts) from a
directory of SVG art + a manifest.

This is the offline stage of the art pipeline in
docs/GENERATIVE_DRAWING_DESIGN.md: art is produced however you like
(AI image-gen -> vectorizer, an illustrator's SVG export, hand-tracing),
dropped into a directory, described by a manifest, and this tool turns it
into the clean stroke sequences the app animates. Pure standard library —
no pip installs.

Pipeline per SVG:
  parse (paths, polylines, polygons, lines, circles, ellipses, rects,
  nested <g> transforms)
    -> flatten curves to points
    -> normalize into centered 0-1 local space (aspect preserved; the app's
       assembler maps local (0.5, 0.5) to the cloud anchor landmark)
    -> optional Chaikin smoothing
    -> Ramer-Douglas-Peucker simplification
    -> arc-length resample if over the point cap

Manifest (JSON, paths relative to the manifest file):

  {
    "creatures": [
      {
        "label": "dragon",
        "category": "mythical",
        "silhouette": "dragon/silhouette.svg",
        "slots": {
          "head":      { "required": true },
          "eye":       { "required": true },
          "companion": { "required": false, "probability": 0.3 }
        }
      }
    ],
    "parts": [
      {
        "id": "dragon-head-01",
        "kind": "head",
        "creatures": ["dragon"],        // or ["*"] for shared parts
        "anchor": "top",                // see VALID_ANCHORS
        "scale": 0.4,                   // optional, fraction of cloud bbox
        "source": "dragon/head-01.svg"
      }
    ]
  }

Usage:
  python3 build_drawing_templates.py --manifest art/manifest.json \\
      --output ../CloudView/Resources/DrawingTemplates.json
  python3 build_drawing_templates.py --check ../CloudView/Resources/DrawingTemplates.json

Try it on the committed example:
  python3 build_drawing_templates.py --manifest example-art/manifest.json \\
      --output /tmp/example-templates.json
"""

import argparse
import json
import math
import os
import re
import sys
import xml.etree.ElementTree as ET

# Must match PartAnchor in CloudView/Models/DrawingParts.swift.
VALID_ANCHORS = {
    "centroid", "top", "bottom", "left", "right",
    "topLeft", "topRight", "bottomLeft", "bottomRight",
}

CURVE_SAMPLES = 16       # samples per Bezier segment before simplification
CIRCLE_SEGMENTS = 32     # polygon segments approximating circles/ellipses
COORD_DECIMALS = 4       # rounding in the emitted JSON


def warn(msg):
    print(f"warning: {msg}", file=sys.stderr)


def fail(msg):
    print(f"error: {msg}", file=sys.stderr)
    sys.exit(1)


# ---------------------------------------------------------------------------
# Affine transforms (2x3 row-major: [a, c, e, b, d, f] applied as
# x' = a*x + c*y + e ; y' = b*x + d*y + f — SVG matrix order)
# ---------------------------------------------------------------------------

IDENTITY = (1.0, 0.0, 0.0, 1.0, 0.0, 0.0)  # (a, b, c, d, e, f)


def mat_multiply(m1, m2):
    a1, b1, c1, d1, e1, f1 = m1
    a2, b2, c2, d2, e2, f2 = m2
    return (
        a1 * a2 + c1 * b2,
        b1 * a2 + d1 * b2,
        a1 * c2 + c1 * d2,
        b1 * c2 + d1 * d2,
        a1 * e2 + c1 * f2 + e1,
        b1 * e2 + d1 * f2 + f1,
    )


def mat_apply(m, x, y):
    a, b, c, d, e, f = m
    return (a * x + c * y + e, b * x + d * y + f)


_TRANSFORM_RE = re.compile(r"(matrix|translate|scale|rotate)\s*\(([^)]*)\)")


def parse_transform(text):
    """Parse an SVG transform attribute into a single affine matrix."""
    m = IDENTITY
    for kind, argstr in _TRANSFORM_RE.findall(text or ""):
        args = [float(v) for v in re.split(r"[\s,]+", argstr.strip()) if v]
        if kind == "matrix" and len(args) == 6:
            t = (args[0], args[1], args[2], args[3], args[4], args[5])
        elif kind == "translate":
            tx = args[0] if args else 0.0
            ty = args[1] if len(args) > 1 else 0.0
            t = (1, 0, 0, 1, tx, ty)
        elif kind == "scale":
            sx = args[0] if args else 1.0
            sy = args[1] if len(args) > 1 else sx
            t = (sx, 0, 0, sy, 0, 0)
        elif kind == "rotate":
            ang = math.radians(args[0]) if args else 0.0
            cos_a, sin_a = math.cos(ang), math.sin(ang)
            t = (cos_a, sin_a, -sin_a, cos_a, 0, 0)
            if len(args) == 3:
                cx, cy = args[1], args[2]
                t = mat_multiply(mat_multiply((1, 0, 0, 1, cx, cy), t),
                                 (1, 0, 0, 1, -cx, -cy))
        else:
            warn(f"unsupported transform '{kind}({argstr})' ignored")
            continue
        m = mat_multiply(m, t)
    return m


# ---------------------------------------------------------------------------
# SVG path parsing -> subpaths (lists of points, plus closed flag)
# ---------------------------------------------------------------------------

_NUM_RE = re.compile(r"[-+]?(?:\d*\.\d+|\d+\.?)(?:[eE][-+]?\d+)?")


def _tokenize_path(d):
    tokens = []
    i = 0
    while i < len(d):
        ch = d[i]
        if ch.isalpha():
            tokens.append(ch)
            i += 1
        elif ch in " ,\t\n\r":
            i += 1
        else:
            m = _NUM_RE.match(d, i)
            if not m:
                raise ValueError(f"bad path data near '...{d[i:i+16]}'")
            tokens.append(float(m.group(0)))
            i = m.end()
    return tokens


def _sample_cubic(p0, p1, p2, p3, n=CURVE_SAMPLES):
    pts = []
    for k in range(1, n + 1):
        t = k / n
        u = 1 - t
        x = u**3 * p0[0] + 3 * u * u * t * p1[0] + 3 * u * t * t * p2[0] + t**3 * p3[0]
        y = u**3 * p0[1] + 3 * u * u * t * p1[1] + 3 * u * t * t * p2[1] + t**3 * p3[1]
        pts.append((x, y))
    return pts


def _sample_quad(p0, p1, p2, n=CURVE_SAMPLES):
    pts = []
    for k in range(1, n + 1):
        t = k / n
        u = 1 - t
        x = u * u * p0[0] + 2 * u * t * p1[0] + t * t * p2[0]
        y = u * u * p0[1] + 2 * u * t * p1[1] + t * t * p2[1]
        pts.append((x, y))
    return pts


def _sample_arc(p0, rx, ry, phi_deg, large_arc, sweep, p1):
    """W3C endpoint-parameterized elliptical arc -> sampled points."""
    if rx == 0 or ry == 0 or p0 == p1:
        return [p1]
    rx, ry = abs(rx), abs(ry)
    phi = math.radians(phi_deg % 360)
    cos_p, sin_p = math.cos(phi), math.sin(phi)

    dx, dy = (p0[0] - p1[0]) / 2.0, (p0[1] - p1[1]) / 2.0
    x1p = cos_p * dx + sin_p * dy
    y1p = -sin_p * dx + cos_p * dy

    lam = (x1p / rx) ** 2 + (y1p / ry) ** 2
    if lam > 1:  # radii too small: scale up per spec
        s = math.sqrt(lam)
        rx, ry = rx * s, ry * s

    num = rx * rx * ry * ry - rx * rx * y1p * y1p - ry * ry * x1p * x1p
    den = rx * rx * y1p * y1p + ry * ry * x1p * x1p
    coef = math.sqrt(max(0.0, num / den)) if den else 0.0
    if large_arc == sweep:
        coef = -coef
    cxp = coef * rx * y1p / ry
    cyp = -coef * ry * x1p / rx

    cx = cos_p * cxp - sin_p * cyp + (p0[0] + p1[0]) / 2.0
    cy = sin_p * cxp + cos_p * cyp + (p0[1] + p1[1]) / 2.0

    def angle(ux, uy, vx, vy):
        dot = ux * vx + uy * vy
        norm = math.hypot(ux, uy) * math.hypot(vx, vy)
        a = math.acos(max(-1.0, min(1.0, dot / norm))) if norm else 0.0
        return -a if ux * vy - uy * vx < 0 else a

    theta1 = angle(1, 0, (x1p - cxp) / rx, (y1p - cyp) / ry)
    dtheta = angle((x1p - cxp) / rx, (y1p - cyp) / ry,
                   (-x1p - cxp) / rx, (-y1p - cyp) / ry)
    if not sweep and dtheta > 0:
        dtheta -= 2 * math.pi
    elif sweep and dtheta < 0:
        dtheta += 2 * math.pi

    n = max(4, int(math.ceil(abs(dtheta) / (math.pi / CURVE_SAMPLES))))
    pts = []
    for k in range(1, n + 1):
        th = theta1 + dtheta * (k / n)
        x = cos_p * rx * math.cos(th) - sin_p * ry * math.sin(th) + cx
        y = sin_p * rx * math.cos(th) + cos_p * ry * math.sin(th) + cy
        pts.append((x, y))
    pts[-1] = p1  # land exactly on the endpoint
    return pts


def parse_path_d(d):
    """Parse a path `d` attribute into [(points, closed), ...] subpaths."""
    tokens = _tokenize_path(d)
    subpaths = []
    current = []
    closed = False
    pos = (0.0, 0.0)
    start = (0.0, 0.0)
    prev_cubic_ctrl = None
    prev_quad_ctrl = None
    cmd = None
    i = 0

    def flush():
        nonlocal current, closed
        if len(current) >= 2:
            subpaths.append((current, closed))
        current = []
        closed = False

    def take(n):
        nonlocal i
        vals = tokens[i:i + n]
        if len(vals) != n or any(isinstance(v, str) for v in vals):
            raise ValueError(f"path data ended mid-command '{cmd}'")
        i += n
        return vals

    while i < len(tokens):
        if isinstance(tokens[i], str):
            cmd = tokens[i]
            i += 1
        elif cmd is None:
            raise ValueError("path data must start with a command")
        # Implicit repeats: a bare number re-runs the previous command
        # (M/m repeats become L/l per the SVG spec).
        rel = cmd.islower()
        c = cmd.upper()

        if c == "M":
            x, y = take(2)
            pos = (pos[0] + x, pos[1] + y) if rel else (x, y)
            flush()
            current = [pos]
            start = pos
            cmd = "l" if rel else "L"
        elif c == "L":
            x, y = take(2)
            pos = (pos[0] + x, pos[1] + y) if rel else (x, y)
            current.append(pos)
        elif c == "H":
            (x,) = take(1)
            pos = (pos[0] + x if rel else x, pos[1])
            current.append(pos)
        elif c == "V":
            (y,) = take(1)
            pos = (pos[0], pos[1] + y if rel else y)
            current.append(pos)
        elif c in ("C", "S"):
            if c == "C":
                x1, y1, x2, y2, x, y = take(6)
            else:
                x2, y2, x, y = take(4)
                if prev_cubic_ctrl is not None:
                    x1, y1 = 2 * pos[0] - prev_cubic_ctrl[0], 2 * pos[1] - prev_cubic_ctrl[1]
                else:
                    x1, y1 = pos if not rel else (0.0, 0.0)
                if rel and prev_cubic_ctrl is not None:
                    x1, y1 = x1 - pos[0], y1 - pos[1]
            if rel:
                x1, y1 = pos[0] + x1, pos[1] + y1
                x2, y2 = pos[0] + x2, pos[1] + y2
                x, y = pos[0] + x, pos[1] + y
            pts = _sample_cubic(pos, (x1, y1), (x2, y2), (x, y))
            current.extend(pts)
            prev_cubic_ctrl = (x2, y2)
            prev_quad_ctrl = None
            pos = (x, y)
            continue
        elif c in ("Q", "T"):
            if c == "Q":
                x1, y1, x, y = take(4)
            else:
                x, y = take(2)
                if prev_quad_ctrl is not None:
                    x1, y1 = 2 * pos[0] - prev_quad_ctrl[0], 2 * pos[1] - prev_quad_ctrl[1]
                else:
                    x1, y1 = pos if not rel else (0.0, 0.0)
                if rel and prev_quad_ctrl is not None:
                    x1, y1 = x1 - pos[0], y1 - pos[1]
            if rel:
                x1, y1 = pos[0] + x1, pos[1] + y1
                x, y = pos[0] + x, pos[1] + y
            pts = _sample_quad(pos, (x1, y1), (x, y))
            current.extend(pts)
            prev_quad_ctrl = (x1, y1)
            prev_cubic_ctrl = None
            pos = (x, y)
            continue
        elif c == "A":
            rx, ry, rot, laf, sf, x, y = take(7)
            end = (pos[0] + x, pos[1] + y) if rel else (x, y)
            current.extend(_sample_arc(pos, rx, ry, rot, bool(laf), bool(sf), end))
            pos = end
        elif c == "Z":
            closed = True
            pos = start
            flush()
            cmd = None
            prev_cubic_ctrl = None
            prev_quad_ctrl = None
            continue
        else:
            raise ValueError(f"unsupported path command '{cmd}'")

        if c not in ("C", "S"):
            prev_cubic_ctrl = None
        if c not in ("Q", "T"):
            prev_quad_ctrl = None

    flush()
    return subpaths


# ---------------------------------------------------------------------------
# SVG document -> raw strokes
# ---------------------------------------------------------------------------

def _local_name(tag):
    return tag.rsplit("}", 1)[-1]


def _parse_points_attr(text):
    nums = [float(v) for v in _NUM_RE.findall(text or "")]
    return list(zip(nums[0::2], nums[1::2]))


def extract_strokes(svg_path):
    """All drawable geometry from an SVG, in document order, transforms
    applied. Returns [(points, closed, role), ...]."""
    try:
        root = ET.parse(svg_path).getroot()
    except ET.ParseError as exc:
        fail(f"{svg_path}: not parseable as SVG ({exc})")

    strokes = []

    def role_of(el, default="line"):
        return el.get("id") or el.get("class") or default

    def visit(el, transform):
        transform = mat_multiply(transform, parse_transform(el.get("transform")))
        name = _local_name(el.tag)

        if name == "path" and el.get("d"):
            for pts, closed in parse_path_d(el.get("d")):
                strokes.append(([mat_apply(transform, *p) for p in pts], closed, role_of(el)))
        elif name == "polyline":
            pts = _parse_points_attr(el.get("points"))
            if len(pts) >= 2:
                strokes.append(([mat_apply(transform, *p) for p in pts], False, role_of(el)))
        elif name == "polygon":
            pts = _parse_points_attr(el.get("points"))
            if len(pts) >= 3:
                strokes.append(([mat_apply(transform, *p) for p in pts], True, role_of(el)))
        elif name == "line":
            pts = [(float(el.get("x1", 0)), float(el.get("y1", 0))),
                   (float(el.get("x2", 0)), float(el.get("y2", 0)))]
            strokes.append(([mat_apply(transform, *p) for p in pts], False, role_of(el)))
        elif name in ("circle", "ellipse"):
            cx, cy = float(el.get("cx", 0)), float(el.get("cy", 0))
            rx = float(el.get("r", 0)) if name == "circle" else float(el.get("rx", 0))
            ry = rx if name == "circle" else float(el.get("ry", 0))
            if rx > 0 and ry > 0:
                pts = [(cx + rx * math.cos(2 * math.pi * k / CIRCLE_SEGMENTS),
                        cy + ry * math.sin(2 * math.pi * k / CIRCLE_SEGMENTS))
                       for k in range(CIRCLE_SEGMENTS)]
                strokes.append(([mat_apply(transform, *p) for p in pts], True, role_of(el)))
        elif name == "rect":
            x, y = float(el.get("x", 0)), float(el.get("y", 0))
            w, h = float(el.get("width", 0)), float(el.get("height", 0))
            if w > 0 and h > 0:
                pts = [(x, y), (x + w, y), (x + w, y + h), (x, y + h)]
                strokes.append(([mat_apply(transform, *p) for p in pts], True, role_of(el)))

        for child in el:
            visit(child, transform)

    visit(root, IDENTITY)
    return strokes


# ---------------------------------------------------------------------------
# Geometry cleanup
# ---------------------------------------------------------------------------

def rdp(points, tolerance):
    """Ramer-Douglas-Peucker simplification (iterative, order-preserving)."""
    if len(points) < 3:
        return list(points)
    keep = [False] * len(points)
    keep[0] = keep[-1] = True
    stack = [(0, len(points) - 1)]
    while stack:
        lo, hi = stack.pop()
        ax, ay = points[lo]
        bx, by = points[hi]
        seg_len = math.hypot(bx - ax, by - ay)
        max_d, max_i = 0.0, None
        for i in range(lo + 1, hi):
            px, py = points[i]
            if seg_len < 1e-12:
                d = math.hypot(px - ax, py - ay)
            else:
                d = abs((bx - ax) * (ay - py) - (ax - px) * (by - ay)) / seg_len
            if d > max_d:
                max_d, max_i = d, i
        if max_i is not None and max_d > tolerance:
            keep[max_i] = True
            stack.append((lo, max_i))
            stack.append((max_i, hi))
    return [p for p, k in zip(points, keep) if k]


def chaikin(points, closed, iterations):
    """Chaikin corner-cutting smoothing."""
    pts = list(points)
    for _ in range(iterations):
        if len(pts) < 3:
            break
        out = []
        pairs = list(zip(pts, pts[1:] + ([pts[0]] if closed else [])))
        if not closed:
            out.append(pts[0])
        for (ax, ay), (bx, by) in pairs:
            out.append((0.75 * ax + 0.25 * bx, 0.75 * ay + 0.25 * by))
            out.append((0.25 * ax + 0.75 * bx, 0.25 * ay + 0.75 * by))
        if not closed:
            out.append(pts[-1])
        pts = out
    return pts


def resample(points, closed, target):
    """Uniform arc-length resample down to `target` points."""
    if len(points) <= target:
        return list(points)
    path = points + [points[0]] if closed else points
    seg_lens = [math.hypot(b[0] - a[0], b[1] - a[1]) for a, b in zip(path, path[1:])]
    total = sum(seg_lens)
    if total < 1e-12:
        return [points[0], points[-1]]
    n_out = target if not closed else target  # closure implied by flag
    out = []
    step = total / (n_out - 1 if not closed else n_out)
    dist_wanted = 0.0
    acc = 0.0
    seg = 0
    for _ in range(n_out):
        while seg < len(seg_lens) and acc + seg_lens[seg] < dist_wanted - 1e-12:
            acc += seg_lens[seg]
            seg += 1
        if seg >= len(seg_lens):
            out.append(path[-1])
        else:
            t = (dist_wanted - acc) / seg_lens[seg] if seg_lens[seg] > 1e-12 else 0.0
            ax, ay = path[seg]
            bx, by = path[seg + 1]
            out.append((ax + (bx - ax) * t, ay + (by - ay) * t))
        dist_wanted += step
    return out


def normalize_strokes(strokes):
    """Fit all strokes of one SVG jointly into centered 0-1 space, aspect
    preserved, so the art's own layout survives and local (0.5, 0.5) is its
    visual center (which the assembler pins to the cloud anchor)."""
    all_pts = [p for pts, _, _ in strokes for p in pts]
    if not all_pts:
        return []
    min_x = min(p[0] for p in all_pts)
    max_x = max(p[0] for p in all_pts)
    min_y = min(p[1] for p in all_pts)
    max_y = max(p[1] for p in all_pts)
    w, h = max_x - min_x, max_y - min_y
    span = max(w, h)
    if span < 1e-9:
        return []
    s = 1.0 / span
    ox = (1.0 - w * s) / 2.0
    oy = (1.0 - h * s) / 2.0
    return [
        ([((x - min_x) * s + ox, (y - min_y) * s + oy) for x, y in pts], closed, role)
        for pts, closed, role in strokes
    ]


def clean_stroke(points, closed, tolerance, smooth_iterations, max_points):
    pts = list(points)
    # Drop an explicit closing duplicate; the schema closes via the flag.
    if closed and len(pts) > 2 and math.hypot(pts[-1][0] - pts[0][0], pts[-1][1] - pts[0][1]) < 1e-9:
        pts = pts[:-1]
    if smooth_iterations > 0:
        pts = chaikin(pts, closed, smooth_iterations)
    pts = rdp(pts, tolerance)
    pts = resample(pts, closed, max_points)
    return pts


def svg_to_strokes(path, tolerance, smooth, max_points, default_role):
    raw = extract_strokes(path)
    if not raw:
        fail(f"{path}: no drawable geometry found")
    normalized = normalize_strokes(raw)
    out = []
    for pts, closed, role in normalized:
        cleaned = clean_stroke(pts, closed, tolerance, smooth, max_points)
        if len(cleaned) < 2:
            warn(f"{path}: dropping degenerate stroke ({role})")
            continue
        out.append((cleaned, closed, role if role != "line" else default_role))
    if not out:
        fail(f"{path}: all strokes degenerate after cleanup")
    return out


# ---------------------------------------------------------------------------
# Manifest -> DrawingTemplates.json v2
# ---------------------------------------------------------------------------

def round_pts(pts):
    return [[round(x, COORD_DECIMALS), round(y, COORD_DECIMALS)] for x, y in pts]


def build(manifest_path, output_path, tolerance, smooth, max_points):
    base = os.path.dirname(os.path.abspath(manifest_path))
    with open(manifest_path) as fh:
        manifest = json.load(fh)

    creatures_out = []
    for c in manifest.get("creatures", []):
        for key in ("label", "category", "silhouette", "slots"):
            if key not in c:
                fail(f"creature missing '{key}': {c}")
        for kind, spec in c["slots"].items():
            if "required" not in spec:
                fail(f"creature '{c['label']}' slot '{kind}' missing 'required'")

        svg = os.path.join(base, c["silhouette"])
        strokes = svg_to_strokes(svg, tolerance, smooth, max_points, "silhouette")
        closed = [s for s in strokes if s[1] and len(s[0]) >= 3]
        if not closed:
            fail(f"{svg}: silhouette needs at least one closed outline "
                 f"(use Z / <polygon> / <circle>)")
        # Largest closed outline (by bbox area) is the silhouette.
        def bbox_area(pts):
            xs = [p[0] for p in pts]
            ys = [p[1] for p in pts]
            return (max(xs) - min(xs)) * (max(ys) - min(ys))
        silhouette = max(closed, key=lambda s: bbox_area(s[0]))[0]
        if len(closed) > 1 or len(strokes) > len(closed):
            warn(f"{svg}: multiple strokes; using largest closed outline "
                 f"({len(silhouette)} pts) as the silhouette")

        creatures_out.append({
            "label": c["label"],
            "category": c["category"],
            "silhouette": round_pts(silhouette),
            "slots": c["slots"],
        })

    creature_labels = {c["label"] for c in creatures_out}
    seen_ids = set()
    parts_out = []
    for p in manifest.get("parts", []):
        for key in ("id", "kind", "creatures", "anchor", "source"):
            if key not in p:
                fail(f"part missing '{key}': {p}")
        if p["id"] in seen_ids:
            fail(f"duplicate part id '{p['id']}'")
        seen_ids.add(p["id"])
        if p["anchor"] not in VALID_ANCHORS:
            fail(f"part '{p['id']}': anchor '{p['anchor']}' not one of "
                 f"{sorted(VALID_ANCHORS)}")
        for label in p["creatures"]:
            if label != "*" and label not in creature_labels:
                fail(f"part '{p['id']}' references unknown creature '{label}'")

        svg = os.path.join(base, p["source"])
        strokes = svg_to_strokes(svg, tolerance, smooth, max_points, p["kind"])
        part = {
            "id": p["id"],
            "kind": p["kind"],
            "creatures": p["creatures"],
            "anchor": p["anchor"],
            "strokes": [
                {"role": role, "order": i + 1, "closed": closed,
                 "points": round_pts(pts)}
                for i, (pts, closed, role) in enumerate(strokes)
            ],
        }
        if "scale" in p:
            part["scale"] = p["scale"]
        parts_out.append(part)

    for c in creatures_out:
        for kind, spec in c["slots"].items():
            has_part = any(
                pt["kind"] == kind and ("*" in pt["creatures"] or c["label"] in pt["creatures"])
                for pt in parts_out
            )
            if spec.get("required") and not has_part:
                fail(f"creature '{c['label']}': required slot '{kind}' has no part")
            if not has_part:
                warn(f"creature '{c['label']}': optional slot '{kind}' has no part yet")

    doc = {"version": 2, "creatures": creatures_out, "parts": parts_out}
    problems = validate(doc)
    if problems:
        for p in problems:
            print(f"error: {p}", file=sys.stderr)
        sys.exit(1)

    with open(output_path, "w") as fh:
        json.dump(doc, fh, indent=1)
        fh.write("\n")
    total_pts = sum(len(s["points"]) for pt in parts_out for s in pt["strokes"])
    print(f"wrote {output_path}: {len(creatures_out)} creatures, "
          f"{len(parts_out)} parts, {total_pts} part points")


# ---------------------------------------------------------------------------
# Validation (also exposed as --check for an existing file, v1 or v2)
# ---------------------------------------------------------------------------

def _check_points(where, pts, minimum, problems, lo=-0.55, hi=1.55):
    if not isinstance(pts, list) or len(pts) < minimum:
        problems.append(f"{where}: needs >= {minimum} points")
        return
    for p in pts:
        if (not isinstance(p, list) or len(p) != 2
                or not all(isinstance(v, (int, float)) for v in p)):
            problems.append(f"{where}: point must be [x, y]: {p}")
            return
        # Parts may legitimately overhang their local box a little, but far
        # outside means a normalization bug.
        if not (lo <= p[0] <= hi and lo <= p[1] <= hi):
            problems.append(f"{where}: point far out of local space: {p}")
            return


def validate(doc):
    problems = []
    version = doc.get("version")
    if version == 2:
        labels = set()
        for c in doc.get("creatures", []):
            where = f"creature '{c.get('label', '?')}'"
            if c.get("label") in labels:
                problems.append(f"{where}: duplicate label")
            labels.add(c.get("label"))
            _check_points(f"{where} silhouette", c.get("silhouette"), 3, problems)
            for kind, spec in (c.get("slots") or {}).items():
                if not isinstance(spec.get("required"), bool):
                    problems.append(f"{where} slot '{kind}': 'required' must be bool")
        ids = set()
        for p in doc.get("parts", []):
            where = f"part '{p.get('id', '?')}'"
            if p.get("id") in ids:
                problems.append(f"{where}: duplicate id")
            ids.add(p.get("id"))
            if p.get("anchor") not in VALID_ANCHORS:
                problems.append(f"{where}: bad anchor '{p.get('anchor')}'")
            if not p.get("strokes"):
                problems.append(f"{where}: no strokes")
            for s in p.get("strokes", []):
                _check_points(f"{where} stroke {s.get('order')}", s.get("points"), 2, problems)
    elif version == 1:
        for t in doc.get("templates", []):
            where = f"template '{t.get('label', '?')}'"
            _check_points(f"{where} silhouette", t.get("silhouette"), 3, problems)
            for s in t.get("strokes", []):
                _check_points(f"{where} stroke {s.get('order')}", s.get("points"), 2, problems)
    else:
        problems.append(f"unknown version: {version!r}")
    return problems


def check(path):
    with open(path) as fh:
        doc = json.load(fh)
    problems = validate(doc)
    if problems:
        for p in problems:
            print(f"error: {p}", file=sys.stderr)
        sys.exit(1)
    version = doc.get("version")
    n = len(doc.get("creatures", doc.get("templates", [])))
    print(f"{path}: OK (schema v{version}, {n} creatures, "
          f"{len(doc.get('parts', []))} parts)")


def main():
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--manifest", help="manifest JSON describing creatures + part SVGs")
    ap.add_argument("--output", help="path to write DrawingTemplates.json")
    ap.add_argument("--check", metavar="JSON",
                    help="validate an existing DrawingTemplates.json (v1 or v2) and exit")
    ap.add_argument("--tolerance", type=float, default=0.006,
                    help="RDP tolerance in normalized 0-1 units (default 0.006)")
    ap.add_argument("--smooth", type=int, default=0,
                    help="Chaikin smoothing iterations before simplify (default 0)")
    ap.add_argument("--max-points", type=int, default=64,
                    help="max points per stroke after cleanup (default 64)")
    args = ap.parse_args()

    if args.check:
        check(args.check)
        return
    if not args.manifest or not args.output:
        ap.error("either --check, or both --manifest and --output, are required")
    build(args.manifest, args.output, args.tolerance, args.smooth, args.max_points)


if __name__ == "__main__":
    main()
