# Cloud silhouette detection — what works

## Problem

Cumulus clouds are soft-edged, layered, and often connected by thin
filaments. Naive threshold-and-connected-components on a busy sky
collapses everything into one giant blob. Even when it doesn't,
real cloud silhouettes are noisy (jagged at the pixel level) and
need smoothing to read as creature outlines.

## Pipeline that works

Demonstrated in `watershed_demo.py`. Steps:

1. **Downsample to ~600px max dim** — speeds processing 4-10×, and
   the silhouettes are inherently low-frequency so we don't lose
   anything useful.

2. **Strong Gaussian blur (σ ≈ 6 px)** — flattens cloud texture so
   bright bodies become continuous regions.

3. **Otsu threshold** — adaptive (not a magic number), separates
   cloud body from sky based on the actual luminance distribution
   of this specific photo.

4. **Morphological closing (5×5 kernel)** — fills small interior
   holes so cloud bodies are solid.

5. **Euclidean distance transform** on the binary mask — each
   pixel's distance to the nearest dark pixel. Cloud "cores" are
   the points furthest inside the mask.

6. **Local-maxima detection on the distance transform** (min
   distance ≈ 20 px between peaks) — each peak is the center of a
   distinct cloud body. This is what naively-connected components
   miss: clouds connected by thin bridges have separate distance
   peaks even though they're in one connected region.

7. **Watershed segmentation** seeded by the peaks — pours water
   from each peak and lets each basin grow until they touch. The
   result: each distinct cumulus puff becomes its own basin even
   though they were originally connected.

8. **Contour extraction per basin** — boundary pixels sorted by
   angle from the basin centroid, then sampled to ~20 points.

9. **Rolling-mean smoothing** on the contour (window=7) — eliminates
   pixel-level jaggies so the silhouette reads as a smooth curve.

10. **Score and rank** by size (peak at 5-10% of image area) and
    bbox fill ratio (peak at ~0.65 — round-ish but not perfect circles).

## iOS port path

Vision has the pieces in different forms:

- Threshold + closing: CIColorClamp + CIMorphologyMaximum (already in `preprocessForContours`)
- Distance transform: Vision has none; can use vImage from Accelerate
  framework: `vImageDistanceTransform_Planar8`.
- Local maxima: simple convolution with a maxFilter (vImage also)
- Watershed: NOT in iOS frameworks. Two options:
  - Implement classical watershed in Swift (~200 lines, uses a
    priority queue + visit map)
  - Approximate with iterative dilation from each seed until basins
    touch — simpler but less accurate

For an MVP, the iterative-dilation approximation is enough. The
exact watershed algorithm matters more for biology/medical imaging
where boundaries need to be precise.
