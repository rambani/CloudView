"""
End-to-end render: watershed-found candidates + Lucide creatures
positioned at each candidate's actual silhouette.
"""
import numpy as np, json, glob
from PIL import Image, ImageDraw, ImageFilter, ImageFont, ImageOps
from scipy.ndimage import (
    gaussian_filter, binary_closing, binary_erosion, distance_transform_edt
)
from skimage.segmentation import watershed
from skimage.feature import peak_local_max

SRC = "/root/.claude/uploads/5429a3b7-3216-5944-a082-bff4fb6e77e2/5ca02585-photo.jpeg"
LIB = "/home/user/CloudView/ios/Cloudoodle/Resources/Library"

photo = Image.open(SRC).convert("RGB")
try: photo = ImageOps.exif_transpose(photo)
except: pass
W, H = photo.size
target = 600
scale = target / max(W, H)
small = photo.resize((int(W*scale), int(H*scale)), Image.LANCZOS)
sw, sh = small.size

gray = np.array(small.convert("L"), dtype=np.float32) / 255.0
blurred = gaussian_filter(gray, sigma=6.0)

def otsu(img):
    hist, _ = np.histogram(img, bins=256, range=(0, 1))
    total = img.size; sum_total = (np.arange(256) * hist).sum() / 256.0
    sum_b = 0.0; w_b = 0; max_var = 0; best = 0.5
    for t in range(256):
        w_b += hist[t]
        if w_b == 0: continue
        w_f = total - w_b
        if w_f == 0: break
        sum_b += (t / 256.0) * hist[t]
        m_b = sum_b / w_b; m_f = (sum_total - sum_b) / w_f
        var = w_b * w_f * (m_b - m_f) ** 2
        if var > max_var: max_var = var; best = t / 256.0
    return best

threshold = otsu(blurred)
mask = (blurred > threshold).astype(np.uint8)
mask = binary_closing(mask, structure=np.ones((5,5)))
dist = distance_transform_edt(mask)
peaks = peak_local_max(dist, min_distance=20, threshold_abs=8, exclude_border=False)
markers = np.zeros_like(mask, dtype=int)
for i, (py, px) in enumerate(peaks): markers[py, px] = i + 1
basins = watershed(-dist, markers, mask=mask)
n_basins = int(basins.max())

def smooth_contour(points, window=7):
    n = len(points)
    if n < window: return points
    out = []; half = window // 2
    for i in range(n):
        ax = sum(points[(i + j - half) % n][0] for j in range(window)) / window
        ay = sum(points[(i + j - half) % n][1] for j in range(window)) / window
        out.append([ax, ay])
    return out

def basin_data(i):
    m = (basins == i)
    if m.sum() < 100: return None
    boundary = m & ~binary_erosion(m)
    by, bx = np.nonzero(boundary)
    if len(bx) < 12: return None
    cx, cy = float(bx.mean()), float(by.mean())
    angles = np.arctan2(by - cy, bx - cx)
    order = np.argsort(angles)
    bx_o, by_o = bx[order], by[order]
    idx = np.linspace(0, len(bx_o) - 1, 20, dtype=int)
    raw = [[float(bx_o[k] / sw), float(by_o[k] / sh)] for k in idx]
    contour = smooth_contour(raw, window=7)
    size_frac = m.sum() / (sw * sh)
    xs = [p[0] for p in contour]; ys = [p[1] for p in contour]
    bbox = (min(xs), min(ys), max(xs)-min(xs), max(ys)-min(ys))
    # Score
    size_score = np.exp(-((size_frac - 0.07) / 0.06) ** 2)
    # Use bbox fill ratio in lieu of true polygon area
    fill = size_frac / max(0.0001, bbox[2]*bbox[3])
    fill_score = np.exp(-((fill - 0.65) / 0.20) ** 2)
    score = size_score * 0.55 + fill_score * 0.45
    return {"contour": contour, "bbox": bbox, "size": size_frac,
            "fill": fill, "score": score}

candidates = []
for i in range(1, n_basins + 1):
    d = basin_data(i)
    if d and 0.005 < d["size"] < 0.30:
        candidates.append(d)
candidates.sort(key=lambda c: -c["score"])

print(f"Found {len(candidates)} good candidates")
for c in candidates[:4]:
    print(f"  size={c['size']:.3f} fill={c['fill']:.2f} score={c['score']:.2f}")

def load_dir(folder):
    out = {}
    for p in glob.glob(f"{LIB}/{folder}/*.json"):
        with open(p) as f:
            t = json.load(f); out[t["id"]] = t
    return out
subjects = load_dir("Subjects")

def bbox_pts(pts):
    xs=[p[0] for p in pts]; ys=[p[1] for p in pts]
    return (min(xs),min(ys),max(xs)-min(xs),max(ys)-min(ys))
def template_bbox(t):
    pts = [p for s in t["strokes"] for p in s["points"]]
    return bbox_pts(pts) if pts else (0,0,1,1)
def map_point(p, src, dst):
    sx, sy, sw_, sh_ = src; dx, dy, dw, dh = dst
    return [dx + (p[0]-sx)/max(sw_, 0.001) * dw,
            dy + (p[1]-sy)/max(sh_, 0.001) * dh]
def smooth_polyline(pts, samples=14):
    if len(pts) < 4: return pts
    out = [pts[0]]
    for i in range(len(pts) - 1):
        p0=pts[max(0, i-1)]; p1=pts[i]; p2=pts[i+1]; p3=pts[min(len(pts)-1, i+2)]
        for j in range(1, samples + 1):
            t = j / samples
            x = 0.5 * ((2*p1[0]) + (-p0[0] + p2[0]) * t +
                      (2*p0[0] - 5*p1[0] + 4*p2[0] - p3[0]) * t**2 +
                      (-p0[0] + 3*p1[0] - 3*p2[0] + p3[0]) * t**3)
            y = 0.5 * ((2*p1[1]) + (-p0[1] + p2[1]) * t +
                      (2*p0[1] - 5*p1[1] + 4*p2[1] - p3[1]) * t**2 +
                      (-p0[1] + 3*p1[1] - 3*p2[1] + p3[1]) * t**3)
            out.append([x, y])
    return out

def compose(sub_id, cand):
    sub = subjects[sub_id]; tb = template_bbox(sub); cb = cand["bbox"]
    is_lucide = sub.get("source", "").startswith("lucide")
    largest_idx = max(range(len(sub["strokes"])),
                      key=lambda i: len(sub["strokes"][i]["points"])) if is_lucide else -1
    strokes = []
    closed = cand["contour"] + [cand["contour"][0]]
    strokes.append({"label":"cloud-silhouette", "width":2.4, "points":closed})
    for i, s in enumerate(sub["strokes"]):
        if i == largest_idx: continue
        mapped = [map_point(p, tb, cb) for p in s["points"]]
        strokes.append({"label":s["label"], "width":s["width"], "points":mapped})
    return strokes

def render_one(rank, sub_id, label_text):
    cand = candidates[rank]
    strokes = compose(sub_id, cand)
    canvas = photo.convert("RGBA").copy()
    w_scale = cand["bbox"][2] * W / 800.0
    ink = (28, 38, 60, 250); halo = (255, 255, 255, 235)
    halo_layer = Image.new("RGBA", (W, H), (0,0,0,0)); hd = ImageDraw.Draw(halo_layer)
    ink_layer  = Image.new("RGBA", (W, H), (0,0,0,0)); sd = ImageDraw.Draw(ink_layer)
    for s in strokes:
        pts_px = [(p[0]*W, p[1]*H) for p in s["points"]]
        sw_ = max(3, int(s["width"] * 4 * w_scale))
        halo_w = sw_ + max(6, int(sw_ * 1.4))
        if len(pts_px) == 1:
            x, y = pts_px[0]; r = max(5, sw_)
            hd.ellipse([x-r-5, y-r-5, x+r+5, y+r+5], fill=halo)
            sd.ellipse([x-r, y-r, x+r, y+r], fill=ink)
        else:
            smooth = smooth_polyline(pts_px) if len(pts_px) >= 3 else pts_px
            hd.line(smooth, fill=halo, width=halo_w, joint="curve")
            sd.line(smooth, fill=ink, width=sw_, joint="curve")
    halo_layer = halo_layer.filter(ImageFilter.GaussianBlur(radius=2))
    canvas.alpha_composite(halo_layer); canvas.alpha_composite(ink_layer)
    canvas = canvas.convert("RGB")
    pd = ImageDraw.Draw(canvas)
    try: font = ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSansMono.ttf", 26)
    except: font = ImageFont.load_default()
    tb_l = pd.textbbox((0,0), label_text, font=font)
    pd.rounded_rectangle([50, 50, 50 + tb_l[2] + 28, 50 + 44], radius=18, fill=(0,0,0))
    pd.text((64, 58), label_text, fill=(255,255,255), font=font)
    out = f"/tmp/final_{rank}_{sub_id}.jpg"
    canvas.save(out, "JPEG", quality=90)
    print(f"  {label_text} -> {out}")

print("\nRenders:")
render_one(0, "fish-lucide",   "FISH on cloud #1 (highest-score puff)")
render_one(1, "rabbit-lucide", "RABBIT on cloud #2")
render_one(2, "cat-lucide",    "CAT on cloud #3")
render_one(3, "bird-lucide",   "BIRD on cloud #4")
