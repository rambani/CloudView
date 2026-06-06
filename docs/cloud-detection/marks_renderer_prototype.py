"""
Cloud silhouette + Gemini-specified character marks.

The renderer has a fixed visual vocabulary. Each mark type knows
how to draw itself given:
   - an anchor waypoint on the silhouette
   - optional offset/length/direction parameters

Gemini's job: examine the silhouette, decide what creature it suggests,
return a list of {type, anchor_waypoint, ...params}. NOT coordinates.

This prototype acts AS Gemini for the user's photo — I look at the
watershed-detected cumulus puffs and write the mark specs for what
each suggests.
"""
import numpy as np, json
from PIL import Image, ImageDraw, ImageFilter, ImageFont, ImageOps
from scipy.ndimage import gaussian_filter, binary_closing, distance_transform_edt, binary_erosion
from skimage.segmentation import watershed
from skimage.feature import peak_local_max
import math

SRC = "/root/.claude/uploads/5429a3b7-3216-5944-a082-bff4fb6e77e2/5ca02585-photo.jpeg"
photo = Image.open(SRC).convert("RGB")
try: photo = ImageOps.exif_transpose(photo)
except: pass
W, H = photo.size

# Watershed-based candidate detection (same as before)
target = 600; scale = target / max(W, H)
small = photo.resize((int(W*scale), int(H*scale)), Image.LANCZOS)
sw, sh = small.size
gray = np.array(small.convert("L"), dtype=np.float32) / 255.0
blurred = gaussian_filter(gray, sigma=6.0)
hist, _ = np.histogram(blurred, bins=256, range=(0,1))
total = blurred.size; sum_t = (np.arange(256) * hist).sum() / 256.0
sum_b = 0.0; w_b = 0; max_v = 0; ots = 0.5
for tt in range(256):
    w_b += hist[tt]
    if w_b == 0: continue
    w_f = total - w_b
    if w_f == 0: break
    sum_b += (tt/256.0) * hist[tt]
    m_b = sum_b/w_b; m_f = (sum_t - sum_b)/w_f
    v = w_b * w_f * (m_b - m_f) ** 2
    if v > max_v: max_v = v; ots = tt/256.0

mask = (blurred > ots).astype(np.uint8)
mask = binary_closing(mask, structure=np.ones((5,5)))
dist = distance_transform_edt(mask)
peaks = peak_local_max(dist, min_distance=20, threshold_abs=8, exclude_border=False)
markers = np.zeros_like(mask, dtype=int)
for i, (py, px) in enumerate(peaks): markers[py, px] = i+1
basins = watershed(-dist, markers, mask=mask)

def smooth(pts, w=7):
    n = len(pts); out=[]; half=w//2
    for i in range(n):
        ax = sum(pts[(i+j-half)%n][0] for j in range(w))/w
        ay = sum(pts[(i+j-half)%n][1] for j in range(w))/w
        out.append([ax, ay])
    return out

def extract_silhouette(basin_id, n=24):
    m = (basins == basin_id)
    if m.sum() < 100: return None
    boundary = m & ~binary_erosion(m)
    by, bx = np.nonzero(boundary)
    if len(bx) < 16: return None
    cx, cy = float(bx.mean()), float(by.mean())
    angles = np.arctan2(by - cy, bx - cx)
    order = np.argsort(angles)
    bx_o, by_o = bx[order], by[order]
    idx = np.linspace(0, len(bx_o)-1, n, dtype=int)
    raw = [[float(bx_o[k]/sw), float(by_o[k]/sh)] for k in idx]
    return smooth(smooth(raw, w=7), w=5)

candidates = []
for i in range(1, int(basins.max())+1):
    sil = extract_silhouette(i, n=24)
    if not sil: continue
    xs = [p[0] for p in sil]; ys = [p[1] for p in sil]
    bbox = (min(xs), min(ys), max(xs)-min(xs), max(ys)-min(ys))
    area = bbox[2] * bbox[3]
    if 0.005 < area < 0.30:
        candidates.append({"silhouette": sil, "bbox": bbox, "area": area})
candidates.sort(key=lambda c: -c["area"])
print(f"Candidates: {len(candidates)}, sizes: {[round(c['area'],3) for c in candidates[:5]]}")

# ===== MARK RENDERER =====
def render_mark(draw_ink, draw_halo, mark, silhouette, W, H, scale):
    """Render a single character mark.

    mark: dict with 'type' and parameters.
    silhouette: list of [x, y] waypoints in normalized photo coords.
    """
    ink = (28, 38, 60, 255)
    halo = (255, 255, 255, 240)

    def line_with_halo(pts_px, width):
        halo_w = int(width * 2) + 8
        draw_halo.line(pts_px, fill=halo, width=halo_w, joint="curve")
        draw_ink.line(pts_px, fill=ink, width=width, joint="curve")

    def dot_with_halo(cx, cy, r):
        draw_halo.ellipse([cx-r-6, cy-r-6, cx+r+6, cy+r+6], fill=halo)
        draw_ink.ellipse([cx-r, cy-r, cx+r, cy+r], fill=ink)

    def get_normal(idx, n):
        """Unit normal vector pointing OUT of the silhouette at waypoint idx."""
        a = silhouette[(idx - 2) % n]
        b = silhouette[idx % n]
        c = silhouette[(idx + 2) % n]
        # tangent
        tx = c[0] - a[0]; ty = c[1] - a[1]
        tl = math.hypot(tx, ty)
        if tl < 0.001: return 0, 0
        tx /= tl; ty /= tl
        # outward normal (rotate tangent by -90)
        return ty, -tx

    n_wp = len(silhouette)
    typ = mark["type"]

    if typ == "eye":
        # offset inside the silhouette
        wp = silhouette[mark["near_waypoint"] % n_wp]
        nx, ny = get_normal(mark["near_waypoint"], n_wp)
        depth = mark.get("inset", 0.02)
        cx = (wp[0] - nx * depth) * W
        cy = (wp[1] - ny * depth) * H
        r = max(8, int(W * 0.012 * scale))
        dot_with_halo(cx, cy, r)

    elif typ == "mouth_arc":
        a_idx = mark["from_waypoint"] % n_wp
        b_idx = mark["to_waypoint"] % n_wp
        # Sample 4-5 points between
        if b_idx >= a_idx:
            indices = list(range(a_idx, b_idx + 1))
        else:
            indices = list(range(a_idx, n_wp)) + list(range(0, b_idx + 1))
        # Move each point slightly inward to look like a mouth indentation
        pts = []
        for idx in indices:
            wp = silhouette[idx]
            nx, ny = get_normal(idx, n_wp)
            depth = mark.get("inset", 0.012)
            pts.append(((wp[0] - nx*depth) * W, (wp[1] - ny*depth) * H))
        line_with_halo(pts, max(5, int(W * 0.007 * scale)))

    elif typ == "teeth_zigzag":
        a_idx = mark["from_waypoint"] % n_wp
        b_idx = mark["to_waypoint"] % n_wp
        if b_idx >= a_idx:
            indices = list(range(a_idx, b_idx + 1))
        else:
            indices = list(range(a_idx, n_wp)) + list(range(0, b_idx + 1))
        # Zigzag in/out at each index
        pts = []
        amp = mark.get("amplitude", 0.012)
        for k, idx in enumerate(indices):
            wp = silhouette[idx]
            nx, ny = get_normal(idx, n_wp)
            sign = -1 if (k % 2 == 0) else 1
            pts.append(((wp[0] + nx * amp * sign) * W,
                        (wp[1] + ny * amp * sign) * H))
        line_with_halo(pts, max(4, int(W * 0.005 * scale)))

    elif typ == "ear_tip":
        # Triangle pointing outward from anchor waypoint
        wp = silhouette[mark["near_waypoint"] % n_wp]
        nx, ny = get_normal(mark["near_waypoint"], n_wp)
        height = mark.get("height", 0.05)
        tip_x = wp[0] + nx * height; tip_y = wp[1] + ny * height
        # Base width
        bw = mark.get("base_width", 0.04)
        # Tangent
        a = silhouette[(mark["near_waypoint"] - 2) % n_wp]
        c = silhouette[(mark["near_waypoint"] + 2) % n_wp]
        tx = c[0] - a[0]; ty = c[1] - a[1]; tl = math.hypot(tx, ty)
        tx /= max(tl, 0.001); ty /= max(tl, 0.001)
        bl_x = wp[0] - tx * bw/2; bl_y = wp[1] - ty * bw/2
        br_x = wp[0] + tx * bw/2; br_y = wp[1] + ty * bw/2
        pts = [(bl_x * W, bl_y * H), (tip_x * W, tip_y * H),
               (br_x * W, br_y * H)]
        line_with_halo(pts, max(4, int(W * 0.005 * scale)))

    elif typ == "tail_flick":
        wp = silhouette[mark["near_waypoint"] % n_wp]
        nx, ny = get_normal(mark["near_waypoint"], n_wp)
        length = mark.get("length", 0.06)
        curve_dir = mark.get("curve", 1)  # 1 or -1
        a = silhouette[(mark["near_waypoint"] - 2) % n_wp]
        c = silhouette[(mark["near_waypoint"] + 2) % n_wp]
        tx = c[0] - a[0]; ty = c[1] - a[1]; tl = math.hypot(tx, ty)
        tx /= max(tl, 0.001); ty /= max(tl, 0.001)
        # Three-point curve: anchor, mid (offset by curve), tip
        mid_x = wp[0] + nx*length*0.5 + tx*length*0.3*curve_dir
        mid_y = wp[1] + ny*length*0.5 + ty*length*0.3*curve_dir
        tip_x = wp[0] + nx*length; tip_y = wp[1] + ny*length
        pts = [(wp[0]*W, wp[1]*H), (mid_x*W, mid_y*H), (tip_x*W, tip_y*H)]
        line_with_halo(pts, max(4, int(W * 0.006 * scale)))

    elif typ == "spike_row":
        a_idx = mark["from_waypoint"] % n_wp
        b_idx = mark["to_waypoint"] % n_wp
        count = mark.get("count", 4)
        height = mark.get("height", 0.018)
        if b_idx >= a_idx: span = b_idx - a_idx
        else: span = n_wp - a_idx + b_idx
        for k in range(count):
            idx = (a_idx + int(k * span / max(1, count-1))) % n_wp
            wp = silhouette[idx]
            nx, ny = get_normal(idx, n_wp)
            tip = (wp[0] + nx*height, wp[1] + ny*height)
            pts = [(wp[0]*W, wp[1]*H), (tip[0]*W, tip[1]*H)]
            line_with_halo(pts, max(3, int(W * 0.004 * scale)))

    elif typ == "whisker":
        wp = silhouette[mark["near_waypoint"] % n_wp]
        nx, ny = get_normal(mark["near_waypoint"], n_wp)
        length = mark.get("length", 0.05)
        # Whiskers are tangent-ish, slightly outward
        a = silhouette[(mark["near_waypoint"] - 2) % n_wp]
        c = silhouette[(mark["near_waypoint"] + 2) % n_wp]
        tx = c[0] - a[0]; ty = c[1] - a[1]; tl = math.hypot(tx, ty)
        tx /= max(tl, 0.001); ty /= max(tl, 0.001)
        angle_offset = mark.get("angle", 0)  # degrees from outward normal
        rad = math.radians(angle_offset)
        # Rotated direction
        dx = nx*math.cos(rad) - ty*math.sin(rad)*0.3
        dy = ny*math.cos(rad) + tx*math.sin(rad)*0.3
        tip = (wp[0] + dx*length, wp[1] + dy*length)
        pts = [(wp[0]*W, wp[1]*H), (tip[0]*W, tip[1]*H)]
        line_with_halo(pts, max(3, int(W * 0.003 * scale)))


def render_creature(cand, marks, label, out_path):
    """Render cloud silhouette + marks."""
    canvas = photo.convert("RGBA").copy()
    halo_layer = Image.new("RGBA", (W, H), (0,0,0,0))
    ink_layer = Image.new("RGBA", (W, H), (0,0,0,0))
    hd = ImageDraw.Draw(halo_layer)
    sd = ImageDraw.Draw(ink_layer)

    bbox = cand["bbox"]
    silhouette = cand["silhouette"]
    scale = bbox[2] * W / 500.0

    # Silhouette outline (closed)
    pts_px = [(p[0]*W, p[1]*H) for p in silhouette] + [(silhouette[0][0]*W, silhouette[0][1]*H)]
    sw_ = max(6, int(W * 0.008 * scale))
    halo_w = sw_ + 12
    hd.line(pts_px, fill=(255,255,255,240), width=halo_w, joint="curve")
    sd.line(pts_px, fill=(28,38,60,255), width=sw_, joint="curve")

    # Apply each mark
    for mark in marks:
        render_mark(sd, hd, mark, silhouette, W, H, scale)

    halo_layer = halo_layer.filter(ImageFilter.GaussianBlur(radius=3))
    canvas.alpha_composite(halo_layer); canvas.alpha_composite(ink_layer)
    canvas = canvas.convert("RGB")
    pd = ImageDraw.Draw(canvas)
    try: font = ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSansMono.ttf", 32)
    except: font = ImageFont.load_default()
    tb_l = pd.textbbox((0,0), label, font=font)
    pd.rounded_rectangle([50,50,50+tb_l[2]+32,50+50], radius=20, fill=(0,0,0))
    pd.text((66, 58), label, fill=(255,255,255), font=font)
    canvas.save(out_path, "JPEG", quality=92)

# Now ACT AS GEMINI: examine each candidate, decide what creature
# it suggests, write the mark spec.
# Looking at the watershed-found candidates and acting as Gemini:

# Candidate 0 (the biggest puff): a fish swimming left
fish_marks = [
    {"type": "eye", "near_waypoint": 4, "inset": 0.025},
    {"type": "mouth_arc", "from_waypoint": 1, "to_waypoint": 3, "inset": 0.012},
    {"type": "fin", "near_waypoint": 18},  # belly fin, won't be drawn since fin type isn't here yet
    {"type": "tail_flick", "near_waypoint": 12, "length": 0.07, "curve": 1},
    {"type": "spike_row", "from_waypoint": 7, "to_waypoint": 11, "count": 4, "height": 0.015},
]

# Candidate 1: a sleeping cat (rounder, more curled shape)
cat_marks = [
    {"type": "ear_tip", "near_waypoint": 2, "height": 0.05, "base_width": 0.04},
    {"type": "ear_tip", "near_waypoint": 4, "height": 0.05, "base_width": 0.04},
    {"type": "eye", "near_waypoint": 5, "inset": 0.04},
    {"type": "eye", "near_waypoint": 7, "inset": 0.04},
    {"type": "whisker", "near_waypoint": 8, "length": 0.05, "angle": -10},
    {"type": "whisker", "near_waypoint": 9, "length": 0.05, "angle": 0},
    {"type": "whisker", "near_waypoint": 10, "length": 0.05, "angle": 10},
    {"type": "tail_flick", "near_waypoint": 20, "length": 0.06, "curve": -1},
]

# Candidate 2: a bird
bird_marks = [
    {"type": "eye", "near_waypoint": 3, "inset": 0.03},
    {"type": "ear_tip", "near_waypoint": 1, "height": 0.04, "base_width": 0.025},  # beak
    {"type": "spike_row", "from_waypoint": 18, "to_waypoint": 22, "count": 3, "height": 0.012},  # tail feathers
]

if len(candidates) >= 1:
    render_creature(candidates[0], fish_marks, "FISH — silhouette + Gemini marks", "/tmp/marks_fish.jpg")
if len(candidates) >= 2:
    render_creature(candidates[1], cat_marks, "CAT — silhouette + Gemini marks", "/tmp/marks_cat.jpg")
if len(candidates) >= 3:
    render_creature(candidates[2], bird_marks, "BIRD — silhouette + Gemini marks", "/tmp/marks_bird.jpg")
print("Done")
