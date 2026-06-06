# Cloudoodle creature library

Subjects and props are loaded from JSON in this directory at startup.
Drop in new shapes by adding files to `Subjects/` or `Props/`. Every
shape lives in its own file so multiple people can author in parallel
without git conflicts.

## Coordinate system

All coordinates are normalized to `[0, 1] × [0, 1]` in the shape's
own bounding box. At render time the shape is fit to the cloud's
bounding box via affine transform (scale + translate, preserving
aspect ratio).

## Subject schema (`Subjects/<id>.json`)

```json
{
  "id": "penguin",
  "category": "animal",
  "tags": ["bird", "arctic", "waddling"],
  "anchors": {
    "head_top":    [0.50, 0.05],
    "eye_center":  [0.50, 0.22],
    "beak_tip":    [0.62, 0.30],
    "feet_center": [0.50, 0.92],
    "belly":       [0.50, 0.60]
  },
  "strokes": [
    {
      "label": "body-outline",
      "width": 2.4,
      "points": [[0.35, 0.08], [0.25, 0.18], ... ]
    }
  ]
}
```

- `id` — file basename, used as the identifier the Gemini prompt returns.
- `category` — `animal`, `vehicle`, `object`, `person`, `mythical`, etc.
- `tags` — free-form descriptors used for searching / picking.
- `anchors` — named attachment points other shapes can hook into.
  At a minimum, include the anchors props are likely to want
  (`feet_center` if props sit at the feet, `head_top` for hats, etc.).
- `strokes` — array of strokes. Each stroke is rendered as a single
  pen pass by `HandDrawingView`. Stroke width is a multiplier;
  ~1.5 = thin detail, ~2.5 = bold outline. Single-point strokes
  render as dots (eyes, nostrils, freckles).

## Prop schema (`Props/<id>.json`)

```json
{
  "id": "skateboard",
  "category": "vehicle",
  "tags": ["wheels", "deck"],
  "attaches_to": "feet_center",
  "anchor_on_self": [0.50, 0.10],
  "size_relative_to_subject": 0.85,
  "strokes": [...]
}
```

- `attaches_to` — name of the subject anchor this prop hooks onto.
- `anchor_on_self` — point on the prop (in prop-local 0-1 coords)
  that meets the subject's `attaches_to` anchor.
- `size_relative_to_subject` — width of the prop as a fraction of
  the subject's width after fitting. Skateboard at 0.85 means
  it's slightly narrower than the penguin.
- `strokes` — same shape as subject strokes.

## Authoring tips

- A simple, recognizable doodle beats an anatomically correct one.
  Big expressive eye dots, simplified silhouettes, exaggerated
  proportions.
- 5–15 strokes per shape feels right. More than ~20 strokes and the
  reveal animation drags.
- Single-point strokes render as bold dots — perfect for eyes,
  nostrils, freckles, polka dots.
- Test by running the Composition preview script (see /tmp/render_*
  examples in chat history) before checking in.
