# ChatGPT art-generation prompt pack

Copy-paste prompts for producing the real Cloudoodle art library with
ChatGPT's image generation — the same tool that made the reference image.
Generating is your half; everything after (vectorize → clean → manifest →
rebuild → preview → distinctness check) is automated, so the handoff is
just: **generate, pick winners, send them back**.

## How to send results back

Either works; the first is lowest-friction:

1. **SVG as text (preferred).** After ChatGPT shows a design you like, send
   the follow-up prompt in §5 to get it as SVG code, and paste that code
   into the Claude session. Text arrives losslessly and skips vectorization
   entirely.
2. **PNG upload.** Download the PNGs and upload them to the repo via the
   GitHub web UI (Add file → Upload files) into `tools/art/incoming/`,
   any branch. They get vectorized with vtracer (validated: thin strokes
   survive as clean curves).

## 0. What "reference grade" means (read this first)

The bar is the dragon-and-castle reference image: a *dense* fine-line
drawing — scales, a brow ridge, a keen eye with a pupil, rows of small
teeth, flowing swept spikes, wing membranes with ribs, a breath-stream
that curls — in which every form rides a real cloud edge. The app now
renders exactly that medium (thin white line, slight transparency, faint
glow, over the real photo) and places parts on the cloud's real bumps and
companions on the *neighboring* cloud. What it cannot do is invent the
drawing. Rendered on the reference sky, the current hand-made dragon parts
(a zigzag crest, two arcs for eyes) sit next to the reference's dragon and
look like a child's placeholder — because they are. **Art density is the
whole remaining gap.** Generating it is a one-time cost; runtime stays $0.

Three rules that follow from the reference:

1. **Dense, not sparse.** Aim for 30–120 strokes per signature part (a head
   alone can be 60+). The build tool simplifies; it never adds.
2. **Parts, still.** A head in profile, a crest band, a wing, a tail, a
   breath-stream, a companion — each alone. The app composes them onto the
   cloud; a whole dragon on a white square cannot be draped onto a bank.
3. **Edge-riding shapes.** Crests, spines and fins should be *bands* (much
   wider than tall) whose bottom edge is roughly straight — they're placed
   with their base on the cloud's top contour, so a flat base reads as
   "growing out of" the cloud.

Order of work: **dragon set first** (it's the one users will screenshot),
then whale, rabbit, cat, bear — the five creatures with the most
recognizable silhouettes — before breadth.

## 1. Global style block — paste once at the start of a session

> You are illustrating assets for a whimsical children's AR app that draws
> creatures over real clouds. House style, for EVERY image in this session:
> elegant fine-line pen illustration, a single uniform thin black stroke on
> a pure white background. No shading, no hatching, no fills, no gray, no
> texture, no background elements, no color. Stroke weight about 1/100 of
> the canvas width (thin!). Whimsical, warm, storybook — like a children's
> book illustrator's confident single-pass ink drawing. One subject only,
> centered, filling ~80% of a square canvas with clean margins. Kid-friendly
> (ages 4+), never scary, and never resembling any branded or franchise
> character.

## 2. Detail parts (the main event) — one prompt per part

Parts are drawn ALONE — the accent, not the whole animal. The app attaches
them to the cloud's real bumps. Template:

> [style block applies] Draw ONLY a {part description} as an isolated
> element — no body, no other features. {orientation/aspect note}

Concrete prompts to run (2–4 candidates each; pick the best):

**Dragon set** (the flagship — match the reference image itself; attach
the reference to the chat and say "in exactly this drawing style"):
- "ONLY a dragon's head in profile facing LEFT, richly detailed: keen
  almond eye with a pupil and a heavy brow ridge, scaled snout, nostril,
  open jaw with two rows of small triangular teeth, a few scale rows along
  the cheek and jawline, two swept-back horns. No neck, no body. About
  1.3× wider than tall."
- "ONLY a dragon's crest: a flowing band of swept-back horn spikes and mane
  wisps, 8–12 spikes of varying height, drawn as a decorative band about
  4× wider than tall with a nearly straight bottom edge."
- "ONLY a dragon's row of back spines: a band of 10–14 small curved spikes
  with a straight base, 5× wider than tall."
- "ONLY a bat-like dragon wing seen from the side, raised: membrane with
  4 ribs ending in small claws, a few fold lines. Wider than tall."
- "ONLY a dragon's tail: a long S-curve tapering to a leaf-shaped tip, with
  a few spine spikes along the top. Much wider than tall."
- "ONLY a dragon's foreleg and clawed foot, reaching down and forward,
  with three claws and scale rows. Taller than wide."
- "ONLY three wispy breath-streams flowing to the LEFT, tapering and
  curling at the ends, like visible wind from a mouth. 3× wider than tall."
- "ONLY a fairy-tale castle: five slender turrets of different heights with
  conical roofs, tiny flags, an arched gate, a few windows, crenellated
  walls — rising from a soft cloud base. About 1.4× wider than tall."
- "ONLY a second castle variant: a single tall keep with two side towers."

**Shared faces** (eyes + mouth together in ONE image so the layout is kept):
- "ONLY a friendly face floating on white: two round eyes with pupils and a
  gentle smile, arranged as they'd sit on a face. Nothing else."
- "ONLY a sleepy face: two closed curved-line eyes with tiny lashes and a
  small round yawning mouth."
- "ONLY a joyful laughing face: two arced happy-shut eyes and a wide open
  smile."
- "ONLY a curious face: two round eyes looking to one side and a small 'o'
  mouth."

**Props** (each alone, centered):
- "ONLY a slightly floppy wizard hat with a star on it."
- "ONLY a striped cone party hat with a pom-pom on top."
- "ONLY a skateboard seen from the side, deck with a slight upturn and two
  wheels. Much wider than tall."
- "ONLY a round balloon on a long wavy string. Much taller than wide."
- More prop ideas when these land: umbrella, bowtie, crown, ice-cream cone
  held aloft, tiny rocket backpack, kite on a string.

**Per-creature accents** (optional round 2, one distinctive piece each):
rabbit ear-pair · cat whisker-set · whale spout · turtle shell-pattern
band · bird wing · swan neck curve · unicorn horn with spiral.

## 3. Silhouettes (matching prototypes) — different rule: FILLED

Silhouettes drive shape-matching, not display, and a filled shape
vectorizes into one perfect closed outline:

> [ignore the line-art rule for this one] A SOLID BLACK filled silhouette
> of a {creature}, side view, on pure white. Bold recognizable gesture —
> exaggerate the {signature feature}. No interior detail, no outline
> stroke, just the filled shape.

Only needed where the current silhouette feels weak; the signature feature
matters more than beauty (giraffe = the neck, elephant = the trunk,
sailboat = the sail).

## 4. Judging candidates (before sending)

- Squint test: still reads at thumbnail size?
- Uniform thin stroke — no thick/thin variation, no accidental fills?
- The part alone — did a body sneak in? Regenerate with "ONLY".
- Nothing brand-adjacent (no franchise dragons/wizards).
- Would a 5-year-old smile?

## 5. The SVG follow-up (preferred return path)

After picking a winner, in the same chat:

> Convert exactly this drawing into clean SVG code: a single square viewBox,
> `fill="none" stroke="black"` paths only (cubic Béziers), preserving the
> drawing's character with the fewest strokes that keep it faithful. Give
> each path an id naming what it is (e.g. id="eye"). Output only the SVG.

Paste the SVG code into the Claude session with a note of what it is
("dragon crest, candidate 2"). Element `id`s become stroke roles; stroke
order becomes the draw-on animation order — ask ChatGPT to order paths the
way a hand would draw them if you care about the reveal.

## 6. What happens on the other side

For each accepted asset: vectorize if raster (vtracer, binary mode) →
normalize/simplify through `build_drawing_templates.py` → manifest entry
with anchor + scale → rebuild → `--preview` contact sheet back to you for
approval → Hu-distinctness check if it's a silhouette. No code changes;
rejected art costs nothing but the prompt.
