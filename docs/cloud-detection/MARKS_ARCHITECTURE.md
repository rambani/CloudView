# Mark-vocabulary architecture for cloud doodles

After iterating through template fitting, silhouette conforming,
and various rendering treatments, the architecture that works
splits the work between Gemini (semantic) and renderer (visual):

## The split

**Gemini** examines the cloud silhouette and answers two questions:
1. What creature does this silhouette suggest?
2. WHERE on the silhouette should each character mark go?

It does NOT generate coordinates. It does NOT pick a template.
It returns a list of marks like:
```json
{
  "shape_name": "Sleeping cat",
  "marks": [
    {"type": "ear_tip", "near_waypoint": 2, "height": 0.05},
    {"type": "ear_tip", "near_waypoint": 4, "height": 0.05},
    {"type": "eye", "near_waypoint": 5, "inset": 0.04},
    {"type": "eye", "near_waypoint": 7, "inset": 0.04},
    {"type": "whisker", "near_waypoint": 8, "length": 0.05, "angle": -10},
    {"type": "tail_flick", "near_waypoint": 20, "length": 0.06, "curve": -1}
  ]
}
```

**Renderer** has a fixed mark vocabulary. Each type knows how to
draw itself given a waypoint anchor + parameters:

| type | params | visual |
|---|---|---|
| `eye` | `near_waypoint`, `inset` | bold dot offset inward from waypoint |
| `mouth_arc` | `from_waypoint`, `to_waypoint`, `inset` | indented curve over consecutive waypoints |
| `teeth_zigzag` | `from_waypoint`, `to_waypoint`, `amplitude` | alternating in/out triangles |
| `ear_tip` | `near_waypoint`, `height`, `base_width` | triangle pointing outward |
| `tail_flick` | `near_waypoint`, `length`, `curve` | curving line extending out |
| `spike_row` | `from_waypoint`, `to_waypoint`, `count`, `height` | row of small perpendicular spikes |
| `whisker` | `near_waypoint`, `length`, `angle` | short tangent-ish line |
| `claw` | `near_waypoint`, `length` | short pointed line at waypoint |
| `fin` | `near_waypoint`, `size`, `direction` | triangle attached perpendicular |

## Why this works

- **Cloud silhouette = body outline** (validated user feedback)
- **Consistent visual style** (the renderer enforces it — no more
  "looks like emoji outline transposed")
- **Semantic placement** (Gemini decides WHERE — not generic 50%
  positions, but "the bulge at waypoint 7 looks like a head, eye
  goes there")
- **Infinite variety from small vocabulary** — same 9 mark types
  produce a fish, a cat, a t-rex, depending on placement + count
- **Each mark type has visual quality baked in by us** — designers
  refine the eye style once, every creature with an eye benefits

## iOS implementation outline

1. `CharacterMark.swift` — Codable struct + type enum mirroring the
   JSON schema.
2. `MarkRenderer.swift` — given a waypoint silhouette + array of
   marks, produce `[CloudAnalysis.DrawingElement]`. Each mark type
   is a small function: `renderEye(at: waypoint, params:) -> Element`.
3. `GeminiService` prompt rewrite — replace the three-layer prompt
   with the new mark-spec prompt. Catalog of available mark types
   gets enumerated in the prompt.
4. `CaptureFlowView` — pipeline becomes:
   - findCandidateRegions → top candidate
   - Gemini receives photo + silhouette waypoints → returns marks
   - MarkRenderer composes silhouette + marks into DrawingElements
   - HandDrawingView animates the strokes

## Prototype

`marks_renderer_prototype.py` shows the rendering vocabulary working
on the user's actual cloud photo. The fish/cat/bird outputs were
authored by me (acting as Gemini) — in production, Gemini Flash
would pick marks based on the silhouette it actually sees.
