#!/usr/bin/env python3
"""
Generate static mockups of Cloudoodle's main surfaces. These are
NOT screenshots — they're Pillow renderings that follow the same
geometry/colors/proportions as the SwiftUI code, intended to give
a visual sense of the composition. Real shots come from running
the app on device/Simulator.

Writes PNGs into /tmp/cloudoodle_mockups/.
"""

import os
from PIL import Image, ImageDraw, ImageFilter, ImageFont

OUT = "/tmp/cloudoodle_mockups"
os.makedirs(OUT, exist_ok=True)

# iPhone-15-class viewport. Real device pixels would be 3x; we
# render at 1x for a manageable file size and let the viewer scale.
W, H = 390, 844

# ----- Palette (matches DesignTokens.swift) ---------------------------------
DARKROOM_TOP = (26, 18, 23)
DARKROOM_BOTTOM = (10, 5, 8)
POLAROID = (247, 245, 237)
INK = (38, 40, 56)
ACCENT = (250, 217, 140)
TEXT_PRIMARY = (255, 255, 255)
TEXT_SECONDARY = (255, 255, 255, 165)
TEXT_TERTIARY = (255, 255, 255, 100)

FONT_DIR = "/usr/share/fonts/truetype/liberation"
def font(family, size):
    return ImageFont.truetype(f"{FONT_DIR}/Liberation{family}.ttf", size)

SERIF   = lambda s: font("Serif-Regular", s)
SERIF_I = lambda s: font("Serif-Italic", s)
SANS    = lambda s: font("Sans-Regular", s)
SANS_B  = lambda s: font("Sans-Bold", s)
MONO    = lambda s: font("Mono-Bold", s)


# ---------- helpers ----------

def darkroom_bg():
    """The warm darkroom gradient used everywhere."""
    img = Image.new("RGB", (W, H))
    d = ImageDraw.Draw(img)
    for y in range(H):
        t = y / H
        r = int(DARKROOM_TOP[0] * (1-t) + DARKROOM_BOTTOM[0] * t)
        g = int(DARKROOM_TOP[1] * (1-t) + DARKROOM_BOTTOM[1] * t)
        b = int(DARKROOM_TOP[2] * (1-t) + DARKROOM_BOTTOM[2] * t)
        d.line([(0, y), (W, y)], fill=(r, g, b))
    return img


def rounded_rect_mask(size, radius):
    mask = Image.new("L", size, 0)
    ImageDraw.Draw(mask).rounded_rectangle((0, 0, size[0], size[1]), radius, fill=255)
    return mask


def sky_gradient(size, palette="sunset"):
    """Procedural sky stand-in for the Polaroid photo area."""
    w, h = size
    img = Image.new("RGB", size)
    d = ImageDraw.Draw(img)
    if palette == "sunset":
        top, bot = (236, 196, 165), (122, 158, 200)
    else:
        top, bot = (158, 196, 224), (66, 100, 150)
    for y in range(h):
        t = y / max(1, h-1)
        r = int(top[0] * (1-t) + bot[0] * t)
        g = int(top[1] * (1-t) + bot[1] * t)
        b = int(top[2] * (1-t) + bot[2] * t)
        d.line([(0, y), (w, y)], fill=(r, g, b))
    return img


def draw_cloud_on_photo(draw, cx, cy, scale=1.0):
    """The same 3-cumulus arrangement the app icon uses."""
    cloud = (252, 250, 245, 255)
    def e(x1, y1, x2, y2):
        return (cx + int(x1 * scale), cy + int(y1 * scale),
                cx + int(x2 * scale), cy + int(y2 * scale))
    # Body
    for bx in [(-30, -55, 30, 65), (-50, -40, 50, 50)]:
        draw.ellipse(e(*bx), fill=cloud)
    # Left + right wings
    for cluster in [(-80, -45, 25, 25), (-110, -25, 0, 40),
                    (15, -45, 110, 25), (0, -25, 105, 40)]:
        draw.ellipse(e(*cluster), fill=cloud)


def draw_ink_seagull(draw, cx, cy, scale=1.0):
    """Compact ink-line bird tracing — matches the icon trace."""
    def p(x, y): return (cx + int(x * scale), cy + int(y * scale))
    path = [
        p(-90, 0), p(-72, -8), p(-55, -18), p(-36, -25),
        p(-20, -20), p(-9, -16), p(0, -22), p(9, -16),
        p(20, -20), p(36, -25), p(55, -18), p(72, -8), p(90, 0),
        p(78, 7), p(60, 0), p(40, -10), p(25, -10),
        p(15, -3), p(8, 2), p(3, 12), p(0, 20), p(-3, 12), p(-8, 2),
        p(-15, -3), p(-25, -10), p(-40, -10), p(-60, 0), p(-78, 7), p(-90, 0),
    ]
    draw.line(path, fill=(38, 40, 56, 220), width=3, joint='curve')


def polaroid(card_w, card_h, palette="sunset",
             day="TUESDAY", date="JUN 7, 2026", time="4:18pm",
             temp="72°", conditions="scattered cumulus · brooklyn"):
    """One Polaroid card, faithful to PolaroidCard.swift's layout."""
    img = Image.new("RGBA", (card_w, card_h), (0, 0, 0, 0))
    d = ImageDraw.Draw(img, "RGBA")
    d.rounded_rectangle((0, 0, card_w, card_h), radius=8, fill=POLAROID + (255,))

    # Top border: day + date/time
    pad = 14
    d.text((pad, 10), day, font=SERIF_I(11), fill=(0, 0, 0, 140))
    date_str = f"{date} · {time}"
    bbox = d.textbbox((0, 0), date_str, font=MONO(11))
    d.text((card_w - pad - (bbox[2] - bbox[0]), 10), date_str,
           font=MONO(11), fill=(0, 0, 0, 150))

    # Photo
    photo_top = 36
    photo_side = card_w - 2 * pad
    photo = sky_gradient((photo_side, photo_side), palette)
    img.paste(photo, (pad, photo_top))

    # Cumulus arrangement
    photo_layer = Image.new("RGBA", (photo_side, photo_side), (0, 0, 0, 0))
    pd = ImageDraw.Draw(photo_layer, "RGBA")
    draw_cloud_on_photo(pd, photo_side // 2, photo_side // 2, scale=0.85)
    # Ink trace
    draw_ink_seagull(pd, photo_side // 2, photo_side // 2 - 5, scale=0.85)
    img.paste(photo_layer, (pad, photo_top), photo_layer)

    # Bottom border: temp + conditions
    bot_y = photo_top + photo_side + 8
    d.text((pad, bot_y), temp, font=SERIF(22), fill=(0, 0, 0, 200))
    d.text((pad, bot_y + 28), conditions, font=SERIF_I(11), fill=(0, 0, 0, 140))
    return img


def shadowed_polaroid(card, tilt=-2):
    """Drop shadow + tilt, returns a larger RGBA canvas."""
    pad = 40
    canvas = Image.new("RGBA",
                       (card.size[0] + pad*2, card.size[1] + pad*2),
                       (0, 0, 0, 0))
    # Shadow
    shadow_alpha = card.split()[-1].point(lambda a: int(a * 0.55))
    shadow = Image.merge("RGBA", (
        Image.new("L", card.size, 12),
        Image.new("L", card.size, 8),
        Image.new("L", card.size, 14),
        shadow_alpha,
    )).filter(ImageFilter.GaussianBlur(14))
    canvas.alpha_composite(shadow, (pad + 4, pad + 14))
    canvas.alpha_composite(card, (pad, pad))
    return canvas.rotate(tilt, resample=Image.BICUBIC, expand=True)


def status_bar(draw):
    """Subtle iOS status bar facsimile so the mockups read as iPhone."""
    draw.text((20, 16), "9:41", font=SANS_B(15), fill=TEXT_PRIMARY)
    # Right cluster (simplified)
    draw.rectangle((W - 80, 21, W - 65, 28), outline=TEXT_PRIMARY, width=1)
    draw.rectangle((W - 63, 21, W - 60, 28), fill=TEXT_PRIMARY)
    draw.rectangle((W - 50, 18, W - 28, 30), outline=TEXT_PRIMARY, width=1)
    draw.rectangle((W - 47, 21, W - 31, 27), fill=TEXT_PRIMARY)


def topbar_today(draw, streak=None):
    """Today's-view top bar: gear · TODAY · stack."""
    # Gear circle
    draw.ellipse((20, 56, 56, 92), fill=(255, 255, 255, 26))
    draw.text((30, 65), "⚙", font=SANS(18), fill=TEXT_PRIMARY)
    # Stack icon circle
    draw.ellipse((W - 56, 56, W - 20, 92), fill=(255, 255, 255, 26))
    draw.text((W - 47, 65), "▤", font=SANS(18), fill=TEXT_PRIMARY)
    # Center title
    title = "TODAY"
    bbox = draw.textbbox((0, 0), title, font=MONO(11))
    tx = (W - (bbox[2] - bbox[0])) // 2
    draw.text((tx, 60), title, font=MONO(11), fill=(255, 255, 255, 140))
    sub = f"{streak}-DAY STREAK" if streak else "tuesday, jun 7"
    bbox = draw.textbbox((0, 0), sub, font=MONO(10))
    sx = (W - (bbox[2] - bbox[0])) // 2
    color = ACCENT if streak else (255, 255, 255, 100)
    draw.text((sx, 78), sub, font=MONO(10), fill=color)


# ---------- Screen 1: Today's Polaroid view ----------

def screen_today():
    img = darkroom_bg().convert("RGBA")
    d = ImageDraw.Draw(img, "RGBA")
    status_bar(d)
    topbar_today(d, streak=5)

    # Polaroid
    card = polaroid(220, 290)
    shadowed = shadowed_polaroid(card, tilt=-1.5)
    pos = ((W - shadowed.size[0]) // 2, 120)
    img.alpha_composite(shadowed, pos)

    # Drawer peek (always-visible TL;DR: temp + quip)
    peek_top = H - 180
    drawer = Image.new("RGBA", (W, H - peek_top), (255, 255, 255, 18))
    dd = ImageDraw.Draw(drawer, "RGBA")
    # Mask out top corners
    drawer_masked = Image.new("RGBA", drawer.size, (0, 0, 0, 0))
    mask = Image.new("L", drawer.size, 0)
    ImageDraw.Draw(mask).rounded_rectangle((0, 0, drawer.size[0], drawer.size[1]),
                                           radius=28, fill=255)
    drawer_masked.paste(drawer, mask=mask)
    img.alpha_composite(drawer_masked, (0, peek_top))

    dd2 = ImageDraw.Draw(img, "RGBA")
    # Handle
    dd2.rounded_rectangle((W//2 - 18, peek_top + 10, W//2 + 18, peek_top + 14),
                          radius=2, fill=(255, 255, 255, 80))
    # Temperature
    dd2.text((28, peek_top + 30), "72°", font=SERIF(48), fill=TEXT_PRIMARY)
    # Quip
    quip = "Let the dragon sleep —\nrain rolls in within the hour."
    dd2.multiline_text((130, peek_top + 50), quip,
                       font=SERIF_I(14), fill=(255, 255, 255, 230), spacing=4)
    dd2.text((130, peek_top + 105), "35% cover · ideal for shapes",
             font=SANS(11), fill=(255, 255, 255, 130))

    img.convert("RGB").save(f"{OUT}/01_today.png", "PNG", optimize=True)


# ---------- Screen 2: Camera viewfinder ----------

def screen_viewfinder():
    # Sky-blue mock camera feed
    img = Image.new("RGB", (W, H), (130, 175, 215))
    d = ImageDraw.Draw(img, "RGBA")
    # Vertical sky gradient
    for y in range(H):
        t = y / H
        r = int(170 * (1-t) + 100 * t)
        g = int(200 * (1-t) + 145 * t)
        b = int(225 * (1-t) + 195 * t)
        d.line([(0, y), (W, y)], fill=(r, g, b))
    # A real cumulus painted on
    draw_cloud_on_photo(d, W // 2, 280, scale=1.6)

    # Bottom fade
    fade = Image.new("RGBA", (W, 240), (0, 0, 0, 0))
    fd = ImageDraw.Draw(fade, "RGBA")
    for i in range(240):
        fd.line([(0, i), (W, i)], fill=(0, 0, 0, int(140 * i / 240)))
    img = img.convert("RGBA")
    img.alpha_composite(fade, (0, H - 240))

    d2 = ImageDraw.Draw(img, "RGBA")
    status_bar(d2)

    # Top bar: gear + location chip + stack
    d2.ellipse((20, 56, 56, 92), fill=(0, 0, 0, 90))
    d2.text((30, 65), "⚙", font=SANS(18), fill=TEXT_PRIMARY)
    # Location chip
    chip_w = 110
    chip_x = (W - chip_w) // 2 - 30
    d2.rounded_rectangle((chip_x, 64, chip_x + chip_w, 86), radius=11, fill=(0, 0, 0, 90))
    d2.text((chip_x + 12, 68), "Brooklyn", font=SANS_B(12), fill=TEXT_PRIMARY)
    d2.ellipse((W - 56, 56, W - 20, 92), fill=(0, 0, 0, 90))
    d2.text((W - 47, 65), "▤", font=SANS(18), fill=TEXT_PRIMARY)

    # "Point at the sky" hint
    hint = "Point at the sky"
    bbox = d2.textbbox((0, 0), hint, font=SANS(13))
    d2.text(((W - (bbox[2] - bbox[0])) // 2, H - 305), hint,
            font=SANS(13), fill=(255, 255, 255, 140))

    # Shutter button
    cx, cy = W // 2, H - 240
    d2.ellipse((cx - 38, cy - 38, cx + 38, cy + 38), outline=TEXT_PRIMARY, width=3)
    d2.ellipse((cx - 31, cy - 31, cx + 31, cy + 31), fill=TEXT_PRIMARY)

    # Drawer peek (current conditions, no quip yet)
    peek_top = H - 130
    drawer_layer = Image.new("RGBA", (W, H - peek_top), (255, 255, 255, 18))
    mask = Image.new("L", drawer_layer.size, 0)
    ImageDraw.Draw(mask).rounded_rectangle((0, 0, drawer_layer.size[0],
                                            drawer_layer.size[1]),
                                            radius=28, fill=255)
    masked = Image.new("RGBA", drawer_layer.size, (0, 0, 0, 0))
    masked.paste(drawer_layer, mask=mask)
    img.alpha_composite(masked, (0, peek_top))

    d3 = ImageDraw.Draw(img, "RGBA")
    d3.rounded_rectangle((W//2 - 18, peek_top + 10, W//2 + 18, peek_top + 14),
                         radius=2, fill=(255, 255, 255, 80))
    d3.text((28, peek_top + 24), "72°", font=SERIF(38), fill=TEXT_PRIMARY)
    d3.text((110, peek_top + 32), "Scattered cumulus", font=SANS_B(15), fill=TEXT_PRIMARY)
    d3.text((110, peek_top + 56), "35% cover · ideal for shapes",
            font=SANS(11), fill=(255, 255, 255, 130))

    img.convert("RGB").save(f"{OUT}/02_viewfinder.png", "PNG", optimize=True)


# ---------- Screen 3: Gallery stack ----------

def screen_gallery():
    img = darkroom_bg().convert("RGBA")
    d = ImageDraw.Draw(img, "RGBA")
    status_bar(d)

    # Top bar
    d.rounded_rectangle((20, 60, 96, 92), radius=16, fill=(255, 255, 255, 26))
    d.text((32, 67), "‹  Today", font=SANS_B(12), fill=(255, 255, 255, 220))
    title = "YOUR CLOUDS"
    bbox = d.textbbox((0, 0), title, font=MONO(11))
    d.text(((W - (bbox[2] - bbox[0])) // 2, 62), title,
           font=MONO(11), fill=(255, 255, 255, 140))
    d.text(((W - 70) // 2, 80), "23 Polaroids",
           font=MONO(10), fill=(255, 255, 255, 100))

    # Month divider
    y = 116
    d.line([(28, y + 7), (130, y + 7)], fill=(255, 255, 255, 30), width=1)
    d.text((142, y), "JUNE 2026", font=MONO(11), fill=(255, 255, 255, 110))
    d.line([(225, y + 7), (W - 28, y + 7)], fill=(255, 255, 255, 30), width=1)

    # Three Polaroids in the stack
    configs = [
        (160, 215, -1.8, "sunset", "TUESDAY", "JUN 7", "4:18pm",
         "72°", "scattered cumulus"),
        (160, 215,  1.4, "day",    "MONDAY",  "JUN 6", "3:02pm",
         "68°", "broken cloud"),
        (160, 215, -0.9, "sunset", "SUNDAY",  "JUN 5", "5:55pm",
         "75°", "clear sky"),
    ]
    cy = 240
    for cfg in configs:
        card = polaroid(cfg[0], cfg[1], palette=cfg[3],
                        day=cfg[4], date=cfg[5], time=cfg[6],
                        temp=cfg[7], conditions=cfg[8])
        shadowed = shadowed_polaroid(card, tilt=cfg[2])
        pos = ((W - shadowed.size[0]) // 2, cy - 30)
        img.alpha_composite(shadowed, pos)
        cy += 210

    img.convert("RGB").save(f"{OUT}/03_gallery.png", "PNG", optimize=True)


# ---------- Screen 4: Detail view ----------

def screen_detail():
    img = darkroom_bg().convert("RGBA")
    d = ImageDraw.Draw(img, "RGBA")
    status_bar(d)

    # Chrome row
    for x in [(20, 56), (W - 100, W - 64), (W - 56, W - 20)]:
        d.ellipse((x[0], 60, x[1], 96), fill=(255, 255, 255, 26))
    d.text((31, 70), "‹", font=SANS_B(16), fill=TEXT_PRIMARY)
    d.text((W - 90, 71), "↗", font=SANS(16), fill=TEXT_PRIMARY)
    d.text((W - 46, 70), "🗑", font=SANS(14), fill=TEXT_PRIMARY)
    d.text(((W - 100) // 2, 71), "TUE, JUN 7", font=MONO(11),
           fill=(255, 255, 255, 140))

    # Polaroid (large, untilted)
    card = polaroid(280, 370)
    shadowed = shadowed_polaroid(card, tilt=0)
    img.alpha_composite(shadowed, ((W - shadowed.size[0]) // 2, 100))

    # Ink / Original segmented chip
    chip_y = 510
    chip_w = 160
    chip_x = (W - chip_w) // 2
    d.rounded_rectangle((chip_x, chip_y, chip_x + chip_w, chip_y + 32),
                        radius=16, fill=(255, 255, 255, 20))
    # Active segment: Ink
    d.rounded_rectangle((chip_x + 4, chip_y + 4, chip_x + 78, chip_y + 28),
                        radius=12, fill=ACCENT + (255,))
    d.text((chip_x + 24, chip_y + 9), "INK", font=MONO(11), fill=(0, 0, 0, 220))
    d.text((chip_x + 92, chip_y + 9), "ORIGINAL", font=MONO(11),
           fill=(255, 255, 255, 180))

    # Quip
    quip = "Let the dragon sleep — rain rolls in within the hour."
    d.multiline_text((32, 560), quip, font=SERIF_I(14),
                     fill=(255, 255, 255, 200), spacing=3)

    # Note row
    note_y = 640
    d.rounded_rectangle((24, note_y, W - 24, note_y + 130),
                        radius=14, fill=(255, 255, 255, 18))
    d.multiline_text((38, note_y + 16),
                     "Walked Sammy by the river before the rain.\n"
                     "The dragon was overhead the whole time —\n"
                     "I think she saw it too.",
                     font=SERIF_I(13), fill=(255, 255, 255, 220), spacing=4)
    d.text((38, note_y + 102), "TAP TO EDIT", font=MONO(9),
           fill=(255, 255, 255, 80))

    img.convert("RGB").save(f"{OUT}/04_detail.png", "PNG", optimize=True)


# ---------- Screen 5: Develop reveal ----------

def screen_develop():
    img = darkroom_bg().convert("RGBA")
    d = ImageDraw.Draw(img, "RGBA")
    status_bar(d)

    # Polaroid in tilted-developing state
    card = polaroid(240, 320)
    # Apply a "developing" dimmer over the photo area
    overlay = Image.new("RGBA", card.size, (0, 0, 0, 0))
    od = ImageDraw.Draw(overlay, "RGBA")
    od.rectangle((14, 36, 240 - 14, 36 + (240 - 28)), fill=(40, 30, 25, 80))
    card.alpha_composite(overlay)
    shadowed = shadowed_polaroid(card, tilt=-2.5)
    img.alpha_composite(shadowed, ((W - shadowed.size[0]) // 2, 130))

    # Status line + guessing prompt
    status_y = 550
    # Blinking dot stand-in
    d.ellipse((W//2 - 70, status_y + 4, W//2 - 62, status_y + 12),
              fill=(255, 255, 255, 200))
    d.text((W//2 - 50, status_y), "DRAWING WHAT'S ALREADY THERE",
           font=MONO(11), fill=(255, 255, 255, 180))
    prompt = "What do you think it is?"
    bbox = d.textbbox((0, 0), prompt, font=SERIF_I(14))
    d.text(((W - (bbox[2] - bbox[0])) // 2, status_y + 30),
           prompt, font=SERIF_I(14), fill=(255, 255, 255, 130))

    img.convert("RGB").save(f"{OUT}/05_develop.png", "PNG", optimize=True)


if __name__ == "__main__":
    screen_today()
    screen_viewfinder()
    screen_gallery()
    screen_detail()
    screen_develop()
    print(f"wrote 5 mockups to {OUT}")
