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

**Dragon set** (the flagship — match the reference's spirit):
- "ONLY a dragon's head in profile facing left: fierce keen eye, brow
  ridge, open jaw with small triangular teeth, small nostril. No neck, no
  body."
- "ONLY a dragon's crest: a flowing ridge of swept-back horn spikes, drawn
  as a decorative band much wider than tall."
- "ONLY three wispy breath-streams flowing to the left, tapering, like
  visible wind from a mouth. Much wider than tall."
- "ONLY a fairy-tale castle with three turrets, conical roofs, a small
  flag, arched gate and one window — rising from a soft cloud base.
  Taller than wide."

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
