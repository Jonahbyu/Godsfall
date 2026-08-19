"""Generate the small emblem image that sits in each card's art box.

One PNG per card in data/cards.json, written to assets/art/<card_id>.png.
Deterministic and regenerable: rerun this script and every image is rebuilt,
so the art can never drift out of sync with the card list.

These are symbolic emblems, not illustrations -- a silhouette that reads at
74x74 in the hand and still holds up scaled to ~296px in the inspector. Each
one is drawn from the card's *name*, so a card reads before you read it.

Palette matches scripts/ui/Theme.gd. Faction tint comes from the card's own
faction so future colors slot in without touching the drawing code.

Art is supersampled 4x and downscaled, the same trick tools/make_icon.py uses.
"""

import json
import math
import os
from PIL import Image, ImageDraw, ImageFilter

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "assets", "art")

# ---------------------------------------------------------------- palette
# Mirrors scripts/ui/Theme.gd. Kept as plain tuples so this script has no
# dependency on the Godot project beyond data/cards.json.
PANEL = (23, 20, 31)
BORDER = (58, 51, 72)
ACCENT = (124, 77, 255)  # Hel purple
ACCENT_DIM = (74, 47, 153)
TEXT = (230, 225, 240)
TEXT_DIM = (143, 136, 163)
GOLD = (217, 180, 91)
BONE = (222, 214, 196)
HP_GREEN = (95, 191, 106)
TOWER = (107, 143, 191)  # support teal-blue
DANGER = (217, 79, 79)
RUST = (150, 92, 60)

FACTION = {
    "hel": ACCENT,
    "forge": (224, 122, 60),   # Theme.gd forge.base -- the set's only warm colour
    "void": (90, 96, 120),
    "gaia": HP_GREEN,
    "heaven": GOLD,
    "neutral": TOWER,
}

SS = 4  # supersample factor
# 128 so the emblem is still native-or-downscaled at the largest size the game
# shows it: the inspector renders a hand card at CARD_SCALE 1.55, which makes
# the 74px art box ~115px. Upscaling is what looks soft, so stay above that.
SIZE = 128
S = SIZE * SS  # working canvas


def mix(a, b, t):
    return tuple(int(round(a[i] + (b[i] - a[i]) * t)) for i in range(3))


def dark(c, t=0.4):
    return mix(c, (0, 0, 0), t)


def light(c, t=0.4):
    return mix(c, (255, 255, 255), t)


# ---------------------------------------------------------------- helpers
# Coordinates are written in 0..1 space and scaled up, so the drawing code
# reads as composition rather than pixel arithmetic.

def P(x, y):
    return (x * S, y * S)


def poly(d, pts, fill=None, outline=None, width=3):
    d.polygon([P(*p) for p in pts], fill=fill, outline=outline,
              width=int(width * SS))


def line(d, pts, fill, width=3, joint="curve"):
    d.line([P(*p) for p in pts], fill=fill, width=int(width * SS), joint=joint)


def ellipse(d, x0, y0, x1, y1, fill=None, outline=None, width=3):
    d.ellipse([P(x0, y0), P(x1, y1)], fill=fill, outline=outline,
              width=int(width * SS))


def circle(d, cx, cy, r, fill=None, outline=None, width=3):
    ellipse(d, cx - r, cy - r, cx + r, cy + r, fill, outline, width)


def rect(d, x0, y0, x1, y1, fill=None, outline=None, width=3, radius=0.0):
    if radius:
        d.rounded_rectangle([P(x0, y0), P(x1, y1)], radius=int(radius * S),
                            fill=fill, outline=outline, width=int(width * SS))
    else:
        d.rectangle([P(x0, y0), P(x1, y1)], fill=fill, outline=outline,
                    width=int(width * SS))


def arc(d, x0, y0, x1, y1, a0, a1, fill, width=3):
    d.arc([P(x0, y0), P(x1, y1)], a0, a1, fill=fill, width=int(width * SS))


def star(d, cx, cy, r, points=4, inner=0.38, fill=None, rot=-90):
    pts = []
    for i in range(points * 2):
        a = math.radians(rot + i * 180.0 / points)
        rr = r if i % 2 == 0 else r * inner
        pts.append((cx + math.cos(a) * rr, cy + math.sin(a) * rr))
    poly(d, pts, fill=fill)


def skull(d, cx, cy, r, col=BONE, eye=PANEL):
    """The faction's recurring motif -- used wherever a card is about death."""
    ellipse(d, cx - r, cy - r, cx + r, cy + r * 0.75, fill=col)
    rect(d, cx - r * 0.52, cy + r * 0.45, cx + r * 0.52, cy + r * 1.05,
         fill=col, radius=r * 0.18)
    ellipse(d, cx - r * 0.62, cy - r * 0.35, cx - r * 0.14, cy + r * 0.22, fill=eye)
    ellipse(d, cx + r * 0.14, cy - r * 0.35, cx + r * 0.62, cy + r * 0.22, fill=eye)
    poly(d, [(cx, cy + r * 0.16), (cx - r * 0.16, cy + r * 0.5),
             (cx + r * 0.16, cy + r * 0.5)], fill=eye)
    for i in (-1, 0, 1):
        rect(d, cx + i * r * 0.3 - r * 0.045, cy + r * 0.62,
             cx + i * r * 0.3 + r * 0.045, cy + r * 1.05, fill=eye)


def bone(d, x0, y0, x1, y1, w=0.035, col=BONE):
    d.line([P(x0, y0), P(x1, y1)], fill=col, width=int(w * S))
    for (x, y) in ((x0, y0), (x1, y1)):
        dx, dy = x1 - x0, y1 - y0
        n = math.hypot(dx, dy) or 1
        px, py = -dy / n * w * 1.0, dx / n * w * 1.0
        circle(d, x + px, y + py, w * 0.95, fill=col)
        circle(d, x - px, y - py, w * 0.95, fill=col)


def hexagon(d, cx, cy, r, fill=None, outline=None, width=3):
    pts = [(cx + math.cos(math.radians(a)) * r, cy + math.sin(math.radians(a)) * r)
           for a in range(-90, 270, 60)]
    poly(d, pts, fill=fill, outline=outline, width=width)


def tower_shape(d, cx, base, w, h, body, trim):
    """A crenellated tower -- the shared silhouette for every tower card."""
    rect(d, cx - w, base - h, cx + w, base, fill=body)
    for i in range(3):
        x = cx - w + (i * 2 + 0.25) * w / 2.6
        rect(d, x, base - h - 0.09, x + w / 2.6, base - h + 0.02, fill=trim)
    rect(d, cx - w * 0.34, base - h * 0.45, cx + w * 0.34, base, fill=dark(body, 0.45))


def arrow(d, x0, y0, x1, y1, col, w=0.035, head=0.075):
    d.line([P(x0, y0), P(x1, y1)], fill=col, width=int(w * S))
    a = math.atan2(y1 - y0, x1 - x0)
    for s in (2.5, -2.5):
        d.line([P(x1, y1), P(x1 - math.cos(a + s) * head, y1 - math.sin(a + s) * head)],
               fill=col, width=int(w * S))


def droplet(d, cx, cy, r, fill):
    poly(d, [(cx, cy - r * 1.7), (cx + r * 0.95, cy + r * 0.35),
             (cx - r * 0.95, cy + r * 0.35)], fill=fill)
    circle(d, cx, cy + r * 0.2, r * 0.95, fill=fill)


def serpent(d, pts, w0, w1, fill, edge=None):
    """A tapering body along a sampled curve.

    Snakes were the one shape arcs and stacked circles could not sell -- the
    segments read as separate hooks. Offsetting a Catmull-Rom path by a
    shrinking half-width gives one continuous silhouette that tapers head to
    tail, which is what actually makes a snake read as a snake.
    """
    def sample(t):
        n = len(pts) - 1
        i = min(int(t * n), n - 1)
        u = t * n - i
        p0 = pts[max(i - 1, 0)]
        p1, p2 = pts[i], pts[i + 1]
        p3 = pts[min(i + 2, n)]
        return tuple(
            0.5 * ((2 * p1[k]) + (-p0[k] + p2[k]) * u
                   + (2 * p0[k] - 5 * p1[k] + 4 * p2[k] - p3[k]) * u * u
                   + (-p0[k] + 3 * p1[k] - 3 * p2[k] + p3[k]) * u ** 3)
            for k in (0, 1))

    N = 60
    curve = [sample(i / N) for i in range(N + 1)]
    left, right = [], []
    for i, (x, y) in enumerate(curve):
        nx, ny = curve[min(i + 1, N)]
        px, py = curve[max(i - 1, 0)]
        dx, dy = nx - px, ny - py
        n = math.hypot(dx, dy) or 1
        hw = (w0 + (w1 - w0) * (i / N)) * 0.5
        ox, oy = -dy / n * hw, dx / n * hw
        left.append((x + ox, y + oy))
        right.append((x - ox, y - oy))
    poly(d, left + right[::-1], fill=fill, outline=edge,
         width=2 if edge else 0)
    return curve


def card_back(d, cx, cy, w, h, fill, edge):
    rect(d, cx - w, cy - h, cx + w, cy + h, fill=fill, outline=edge,
         width=2.5, radius=0.035)


def halo(d, cx, cy, r, col=GOLD, width=3.5):
    """Heaven's recurring motif -- a ring above a figure's head."""
    ellipse(d, cx - r, cy - r * 0.34, cx + r, cy + r * 0.34,
            outline=col, width=width)


def rays(d, cx, cy, r0, r1, col, count=12, width=2.5, rot=0):
    """Radiating light. Heaven's answer to Hel's bone motif."""
    for i in range(count):
        a = math.radians(rot + i * 360.0 / count)
        line(d, [(cx + math.cos(a) * r0, cy + math.sin(a) * r0),
                 (cx + math.cos(a) * r1, cy + math.sin(a) * r1)], col, width)


def wings(d, cx, cy, span, drop, col, edge=None):
    """A pair of folded wings, drawn as stacked feather arcs."""
    for s in (-1, 1):
        for i in range(3):
            f = 1.0 - i * 0.24
            poly(d, [(cx + s * span * 0.10, cy - drop * 0.10 + i * drop * 0.22),
                     (cx + s * span * f, cy + drop * (0.10 + i * 0.20)),
                     (cx + s * span * f * 0.72, cy + drop * (0.42 + i * 0.20)),
                     (cx + s * span * 0.10, cy + drop * (0.22 + i * 0.22))],
                 fill=mix(col, PANEL, i * 0.20), outline=edge,
                 width=1.5 if edge else 0)


def bell(d, cx, cy, r, col=GOLD, clapper=None):
    """The Court's bell -- Judgment restoration reads as a bell everywhere."""
    poly(d, [(cx - r, cy + r * 0.75), (cx - r * 0.80, cy - r * 0.15),
             (cx - r * 0.42, cy - r * 0.72), (cx + r * 0.42, cy - r * 0.72),
             (cx + r * 0.80, cy - r * 0.15), (cx + r, cy + r * 0.75)],
         fill=col)
    rect(d, cx - r * 1.06, cy + r * 0.72, cx + r * 1.06, cy + r * 0.94,
         fill=light(col, 0.22), radius=r * 0.10)
    circle(d, cx, cy - r * 0.84, r * 0.17, fill=light(col, 0.22))
    circle(d, cx, cy + r * 1.10, r * 0.19, fill=clapper or dark(col, 0.45))


def scales(d, cx, cy, r, col=GOLD, tilt=0.0):
    """Balance scales -- Judgment as a weighing, not a blow."""
    line(d, [(cx, cy - r * 1.05), (cx, cy + r * 0.95)], col, 3)
    line(d, [(cx - r, cy - r * 0.62 + tilt), (cx + r, cy - r * 0.62 - tilt)], col, 3)
    for s in (-1, 1):
        y = cy - r * 0.62 + tilt * (-s)
        line(d, [(cx + s * r, y), (cx + s * r, y + r * 0.28)], col, 2)
        poly(d, [(cx + s * r - r * 0.34, y + r * 0.28),
                 (cx + s * r + r * 0.34, y + r * 0.28),
                 (cx + s * r + r * 0.20, y + r * 0.58),
                 (cx + s * r - r * 0.20, y + r * 0.58)], fill=col)
    poly(d, [(cx - r * 0.30, cy + r * 0.95), (cx + r * 0.30, cy + r * 0.95),
             (cx + r * 0.18, cy + r * 0.72), (cx - r * 0.18, cy + r * 0.72)],
         fill=col)


def void_eye(d, cx, cy, r, tint, ring=1.35):
    """Void's recurring motif -- a hole with a rim of what it is eating.

    The faction is *absence*, so the emblem is negative space with a bright
    edge rather than a shape. Drawn as a near-black disc so it reads as a
    hole punched in the backdrop at any size.
    """
    for i in range(5):
        f = ring - i * (ring - 1.0) / 5.0
        circle(d, cx, cy, r * f, fill=mix(light(tint, 0.35), (6, 5, 9), i / 4.5))
    circle(d, cx, cy, r, fill=(4, 4, 7))


# ---------------------------------------------------------------- background

def backdrop(tint, kind):
    """Vignette + faint glow behind the emblem, tinted by faction.

    The art box already has its own tint in CardView, so this stays dark and
    low contrast -- it is a stage for the silhouette, not a picture of its own.
    """
    img = Image.new("RGB", (S, S), dark(PANEL, 0.25))
    d = ImageDraw.Draw(img)

    glow = Image.new("RGB", (S, S), dark(PANEL, 0.35))
    gd = ImageDraw.Draw(glow)
    gd.ellipse([P(0.08, 0.10), P(0.92, 1.02)], fill=dark(tint, 0.62))
    gd.ellipse([P(0.24, 0.26), P(0.76, 0.94)], fill=dark(tint, 0.42))
    glow = glow.filter(ImageFilter.GaussianBlur(S * 0.055))
    img = Image.blend(img, glow, 0.85)
    d = ImageDraw.Draw(img)

    # Horizon line -- gives every emblem something to stand on.
    if kind in ("unit", "tower_support"):
        d.rectangle([P(0, 0.83), P(1, 1)], fill=dark(tint, 0.80))
        d.line([P(0, 0.83), P(1, 0.83)], fill=dark(tint, 0.55), width=int(0.008 * S))
    return img


def finish(img, tint):
    d = ImageDraw.Draw(img)
    # Inner frame keeps the emblem from bleeding into the card's art border.
    d.rounded_rectangle([P(0.012, 0.012), P(0.988, 0.988)], radius=int(0.05 * S),
                        outline=dark(tint, 0.55), width=int(0.014 * S))
    return img.resize((SIZE, SIZE), Image.LANCZOS)


# ---------------------------------------------------------------- the cards
# One function per card, keyed by card id. Each draws onto a prepared
# backdrop. Anything without an entry falls back to a generic emblem, so
# adding a card never breaks the build -- it just gets a plain frame until
# someone draws it.

DRAW = {}


def art(card_id):
    def deco(fn):
        DRAW[card_id] = fn
        return fn
    return deco


# ---- energy -------------------------------------------------------------

@art("hel_energy")
def _(d, t):
    hexagon(d, 0.5, 0.5, 0.30, fill=dark(GOLD, 0.55), outline=GOLD, width=3)
    hexagon(d, 0.5, 0.5, 0.19, fill=GOLD)
    skull(d, 0.5, 0.49, 0.115, col=dark(PANEL, -0.1), eye=GOLD)
    for a in range(0, 360, 60):
        r = math.radians(a)
        circle(d, 0.5 + math.cos(r) * 0.385, 0.5 + math.sin(r) * 0.385, 0.022,
               fill=light(GOLD, 0.2))


# ---- Hel units ----------------------------------------------------------

@art("grave_whelp")
def _(d, t):
    # A tiny four-legged whelp clawing out of the dirt -- chaff, and it looks it.
    poly(d, [(0.30, 0.80), (0.36, 0.52), (0.64, 0.52), (0.70, 0.80)],
         fill=dark(BONE, 0.42))
    for x in (0.34, 0.46, 0.56, 0.68):
        line(d, [(x, 0.74), (x + 0.02, 0.86)], dark(BONE, 0.5), 3)
    line(d, [(0.68, 0.58), (0.86, 0.44)], dark(BONE, 0.48), 3)   # whip tail
    circle(d, 0.36, 0.38, 0.145, fill=BONE)                      # oversized head
    poly(d, [(0.24, 0.32), (0.20, 0.16), (0.34, 0.26)], fill=dark(BONE, 0.3))
    poly(d, [(0.46, 0.30), (0.52, 0.16), (0.36, 0.24)], fill=dark(BONE, 0.3))
    circle(d, 0.31, 0.36, 0.030, fill=ACCENT)
    circle(d, 0.43, 0.36, 0.030, fill=ACCENT)
    poly(d, [(0.26, 0.46), (0.46, 0.46), (0.36, 0.54)], fill=dark(PANEL, -0.2))
    for x in (0.30, 0.36, 0.42):
        poly(d, [(x - 0.018, 0.46), (x + 0.018, 0.46), (x, 0.51)], fill=BONE)


@art("barrow_knight")
def _(d, t):
    # Helm and shield -- a plain armored body.
    poly(d, [(0.34, 0.30), (0.66, 0.30), (0.70, 0.48), (0.50, 0.80),
             (0.30, 0.48)], fill=mix(TOWER, PANEL, 0.35), outline=light(TOWER, 0.1),
         width=2.5)
    rect(d, 0.36, 0.42, 0.64, 0.50, fill=PANEL)
    circle(d, 0.435, 0.46, 0.022, fill=ACCENT)
    circle(d, 0.565, 0.46, 0.022, fill=ACCENT)
    line(d, [(0.5, 0.30), (0.5, 0.42)], light(TOWER, 0.25), 2.5)
    line(d, [(0.5, 0.52), (0.5, 0.74)], light(TOWER, 0.25), 2)


@art("carrion_crawler")
def _(d, t):
    # Segmented grub with legs -- reads as vermin at any size.
    for i, x in enumerate((0.30, 0.42, 0.54, 0.66)):
        r = 0.105 - i * 0.008
        circle(d, x, 0.56 + math.sin(i) * 0.015, r,
               fill=mix(HP_GREEN, PANEL, 0.45 + i * 0.08))
    circle(d, 0.74, 0.53, 0.085, fill=mix(HP_GREEN, BONE, 0.35))
    circle(d, 0.775, 0.505, 0.020, fill=PANEL)
    for x in (0.34, 0.46, 0.58):
        line(d, [(x, 0.63), (x - 0.05, 0.79)], dark(HP_GREEN, 0.45), 2.5)
        line(d, [(x, 0.49), (x - 0.05, 0.33)], dark(HP_GREEN, 0.45), 2.5)


@art("bonepicker")
def _(d, t):
    # A carrion bird with a bone in its beak.
    poly(d, [(0.30, 0.72), (0.44, 0.34), (0.62, 0.44), (0.58, 0.74)],
         fill=dark(PANEL, -0.35))
    poly(d, [(0.44, 0.36), (0.72, 0.24), (0.60, 0.46)], fill=dark(BONE, 0.55))
    circle(d, 0.60, 0.36, 0.055, fill=dark(BONE, 0.25))
    circle(d, 0.625, 0.345, 0.017, fill=DANGER)
    poly(d, [(0.655, 0.365), (0.74, 0.40), (0.655, 0.40)], fill=GOLD)
    bone(d, 0.60, 0.56, 0.80, 0.62, 0.024)


@art("thornshade")
def _(d, t):
    # A shade behind a bristling thorn hedge -- the wall that taxes attackers.
    poly(d, [(0.5, 0.14), (0.70, 0.36), (0.68, 0.72), (0.32, 0.72), (0.30, 0.36)],
         fill=dark(ACCENT, 0.62), outline=dark(ACCENT, 0.30), width=2.5)
    poly(d, [(0.5, 0.18), (0.63, 0.38), (0.37, 0.38)], fill=(6, 5, 9))
    circle(d, 0.462, 0.325, 0.024, fill=DANGER)
    circle(d, 0.538, 0.325, 0.024, fill=DANGER)
    # Thorn hedge across the front, barbs pointing outward at the attacker.
    line(d, [(0.08, 0.76), (0.92, 0.76)], mix(BONE, ACCENT, 0.45), 4)
    for i in range(7):
        x = 0.13 + i * 0.125
        poly(d, [(x - 0.028, 0.76), (x + 0.028, 0.76), (x, 0.60)],
             fill=mix(BONE, ACCENT, 0.30))
        poly(d, [(x + 0.034, 0.76), (x + 0.090, 0.76), (x + 0.062, 0.90)],
             fill=mix(BONE, ACCENT, 0.45))


@art("hollow_servant")
def _(d, t):
    # An empty robe: hood with nothing inside, two hands.
    poly(d, [(0.5, 0.18), (0.72, 0.40), (0.70, 0.84), (0.30, 0.84), (0.28, 0.40)],
         fill=dark(PANEL, -0.45), outline=BORDER, width=2.5)
    poly(d, [(0.5, 0.22), (0.65, 0.42), (0.35, 0.42)], fill=(6, 5, 9))
    circle(d, 0.5, 0.37, 0.030, fill=dark(ACCENT, 0.15))
    circle(d, 0.30, 0.62, 0.042, fill=BONE)
    circle(d, 0.70, 0.62, 0.042, fill=BONE)


@art("charnel_colossus")
def _(d, t):
    # A giant built from corpses -- broad, heavy, skull-headed.
    rect(d, 0.22, 0.44, 0.78, 0.86, fill=dark(BONE, 0.55), radius=0.06)
    rect(d, 0.14, 0.48, 0.26, 0.80, fill=dark(BONE, 0.62), radius=0.05)
    rect(d, 0.74, 0.48, 0.86, 0.80, fill=dark(BONE, 0.62), radius=0.05)
    for y in (0.55, 0.65, 0.75):
        line(d, [(0.28, y), (0.72, y)], dark(BONE, 0.75), 2)
    skull(d, 0.5, 0.28, 0.145)
    circle(d, 0.455, 0.255, 0.026, fill=ACCENT)
    circle(d, 0.545, 0.255, 0.026, fill=ACCENT)


@art("gravebound_reaper")
def _(d, t):
    # Scythe and cowl.
    poly(d, [(0.40, 0.26), (0.60, 0.26), (0.66, 0.86), (0.34, 0.86)],
         fill=dark(PANEL, -0.4), outline=BORDER, width=2.5)
    poly(d, [(0.5, 0.20), (0.62, 0.40), (0.38, 0.40)], fill=(6, 5, 9))
    circle(d, 0.462, 0.34, 0.021, fill=ACCENT)
    circle(d, 0.538, 0.34, 0.021, fill=ACCENT)
    line(d, [(0.72, 0.14), (0.72, 0.88)], dark(RUST, 0.15), 3.5)
    arc(d, 0.34, 0.02, 0.86, 0.42, 200, 340, BONE, 5)


@art("hels_chorus")
def _(d, t):
    # Three singing skulls -- the doubling engine.
    for cx, cy, r in ((0.28, 0.58, 0.135), (0.5, 0.40, 0.155), (0.72, 0.58, 0.135)):
        skull(d, cx, cy, r)
        ellipse(d, cx - r * 0.20, cy + r * 0.52, cx + r * 0.20, cy + r * 1.05,
                fill=PANEL)
    for cx, cy in ((0.28, 0.42), (0.5, 0.22), (0.72, 0.42)):
        for i, rr in enumerate((0.035, 0.055)):
            arc(d, cx - rr, cy - rr, cx + rr, cy + rr, 200, 340,
                light(ACCENT, 0.3 - i * 0.15), 2)


@art("mourning_bell")
def _(d, t):
    # A tolling bell -- the Toll payoff card.
    poly(d, [(0.5, 0.22), (0.74, 0.68), (0.26, 0.68)], fill=GOLD)
    ellipse(d, 0.26, 0.60, 0.74, 0.76, fill=GOLD)
    ellipse(d, 0.26, 0.63, 0.74, 0.79, fill=dark(GOLD, 0.35))
    rect(d, 0.475, 0.14, 0.525, 0.24, fill=dark(GOLD, 0.2), radius=0.02)
    circle(d, 0.5, 0.82, 0.045, fill=dark(GOLD, 0.45))
    for s in (-1, 1):
        arc(d, 0.5 + s * 0.02 - 0.42, 0.22, 0.5 + s * 0.02 + 0.42, 0.86,
            190 if s < 0 else 310, 230 if s < 0 else 350, light(GOLD, 0.35), 2)


@art("nithogg_root_gnawer")
def _(d, t):
    # A serpent chewing through a thick root.
    line(d, [(0.62, 0.04), (0.56, 0.52)], dark(RUST, 0.22), 7)
    line(d, [(0.56, 0.50), (0.34, 0.88)], dark(RUST, 0.30), 5)
    line(d, [(0.56, 0.50), (0.82, 0.86)], dark(RUST, 0.30), 5)
    line(d, [(0.60, 0.22), (0.84, 0.34)], dark(RUST, 0.34), 4)
    # Serpent body: one continuous S from the bottom-left tail up to the bite.
    snake = mix(HP_GREEN, ACCENT, 0.45)
    serpent(d, [(0.06, 0.90), (0.20, 0.74), (0.16, 0.56), (0.30, 0.46),
                (0.44, 0.44)], 0.030, 0.135, snake, dark(snake, 0.45))
    circle(d, 0.50, 0.42, 0.088, fill=light(snake, 0.10))       # head at the root
    poly(d, [(0.50, 0.42), (0.66, 0.34), (0.66, 0.50)], fill=light(snake, 0.10))
    poly(d, [(0.55, 0.40), (0.68, 0.35), (0.68, 0.45)], fill=dark(PANEL, -0.3))
    poly(d, [(0.56, 0.375), (0.63, 0.355), (0.60, 0.425)], fill=BONE)  # fangs
    poly(d, [(0.56, 0.455), (0.63, 0.475), (0.60, 0.405)], fill=BONE)
    circle(d, 0.485, 0.395, 0.026, fill=GOLD)
    circle(d, 0.485, 0.395, 0.011, fill=PANEL)
    for x, y in ((0.74, 0.26), (0.82, 0.46), (0.70, 0.58)):     # gnawed splinters
        circle(d, x, y, 0.022, fill=dark(RUST, 0.05))


@art("grave_tide")
def _(d, t):
    # A wave of hands rising out of the ground.
    for i, x in enumerate((0.20, 0.34, 0.50, 0.66, 0.80)):
        h = 0.30 + (0.14 if i % 2 else 0.0) + (0.06 if i == 2 else 0)
        rect(d, x - 0.035, 0.84 - h, x + 0.035, 0.86, fill=BONE, radius=0.02)
        for j in (-1, 0, 1):
            line(d, [(x + j * 0.032, 0.84 - h + 0.03), (x + j * 0.042, 0.84 - h - 0.07)],
                 dark(BONE, 0.12), 2)
    d.rectangle([P(0, 0.84), P(1, 1)], fill=dark(ACCENT, 0.78))
    for y in (0.87, 0.93):
        arc(d, -0.1, y - 0.05, 0.55, y + 0.05, 0, 180, dark(ACCENT, 0.45), 2)
        arc(d, 0.45, y - 0.05, 1.1, y + 0.05, 0, 180, dark(ACCENT, 0.45), 2)


@art("hel_queen")
def _(d, t):
    # Crowned skull -- the faction's win condition.
    skull(d, 0.5, 0.56, 0.24)
    circle(d, 0.425, 0.51, 0.045, fill=ACCENT)
    circle(d, 0.575, 0.51, 0.045, fill=ACCENT)
    poly(d, [(0.24, 0.34), (0.32, 0.14), (0.41, 0.29), (0.50, 0.08),
             (0.59, 0.29), (0.68, 0.14), (0.76, 0.34)], fill=GOLD)
    rect(d, 0.24, 0.32, 0.76, 0.39, fill=dark(GOLD, 0.2), radius=0.02)
    for x in (0.32, 0.50, 0.68):
        circle(d, x, 0.355, 0.024, fill=ACCENT)


@art("nithogg_ascendant")
def _(d, t):
    # The same serpent risen: coiled tall, crowned, jaws open. Reads as the
    # Root-Gnawer's evolution because it keeps the head and the scale color.
    snake = mix(HP_GREEN, ACCENT, 0.45)
    poly(d, [(0.46, 0.40), (0.04, 0.26), (0.22, 0.58)], fill=dark(ACCENT, 0.42))
    poly(d, [(0.54, 0.40), (0.96, 0.26), (0.78, 0.58)], fill=dark(ACCENT, 0.42))
    # One body, coiled at the base and rearing -- same silhouette language as
    # the Root-Gnawer, which is what makes it read as the same creature risen.
    serpent(d, [(0.80, 0.90), (0.34, 0.86), (0.30, 0.70), (0.62, 0.66),
                (0.58, 0.50), (0.50, 0.42)], 0.032, 0.150, snake,
            dark(snake, 0.45))
    circle(d, 0.5, 0.34, 0.115, fill=light(snake, 0.12))
    poly(d, [(0.40, 0.40), (0.60, 0.40), (0.50, 0.56)], fill=dark(PANEL, -0.3))
    poly(d, [(0.425, 0.40), (0.475, 0.40), (0.455, 0.52)], fill=BONE)
    poly(d, [(0.525, 0.40), (0.575, 0.40), (0.545, 0.52)], fill=BONE)
    circle(d, 0.452, 0.315, 0.028, fill=GOLD)
    circle(d, 0.548, 0.315, 0.028, fill=GOLD)
    circle(d, 0.452, 0.315, 0.011, fill=PANEL)
    circle(d, 0.548, 0.315, 0.011, fill=PANEL)
    poly(d, [(0.34, 0.24), (0.41, 0.07), (0.50, 0.19), (0.59, 0.07), (0.66, 0.24)],
         fill=GOLD)


@art("grand_cacophony")
def _(d, t):
    # Many mouths at once -- a burst of overlapping sound rings and skulls.
    for a in range(0, 360, 72):
        r = math.radians(a - 90)
        skull(d, 0.5 + math.cos(r) * 0.29, 0.5 + math.sin(r) * 0.29, 0.085)
    for i, rr in enumerate((0.13, 0.19, 0.25)):
        circle(d, 0.5, 0.5, rr, outline=light(ACCENT, 0.35 - i * 0.12), width=2.5)
    star(d, 0.5, 0.5, 0.085, points=6, inner=0.42, fill=light(ACCENT, 0.45))


# ---- neutral supports ---------------------------------------------------

@art("gravekeepers_ledger")
def _(d, t):
    # An open book with a bone bookmark.
    poly(d, [(0.08, 0.34), (0.48, 0.28), (0.48, 0.80), (0.08, 0.84)],
         fill=dark(BONE, 0.35))
    poly(d, [(0.92, 0.34), (0.52, 0.28), (0.52, 0.80), (0.92, 0.84)],
         fill=dark(BONE, 0.28))
    rect(d, 0.475, 0.28, 0.525, 0.84, fill=dark(RUST, 0.25))
    for i in range(4):
        y = 0.42 + i * 0.09
        line(d, [(0.14, y + 0.01), (0.43, y - 0.005)], dark(BONE, 0.62), 1.6)
        line(d, [(0.57, y - 0.005), (0.86, y + 0.01)], dark(BONE, 0.62), 1.6)
    poly(d, [(0.62, 0.28), (0.70, 0.28), (0.70, 0.60), (0.66, 0.53), (0.62, 0.60)],
         fill=ACCENT)


@art("scavengers_instinct")
def _(d, t):
    # A skeletal hand closing on a coin, over a scrap heap.
    for x, y, r in ((0.16, 0.86, 0.055), (0.30, 0.90, 0.045), (0.70, 0.88, 0.05),
                    (0.84, 0.84, 0.04)):
        circle(d, x, y, r, fill=dark(BONE, 0.55))
    # A talon gripping a coin. Drawn as claws that wrap *around* the coin's
    # silhouette rather than radiating from a hub -- a hub read as an antenna.
    coin_c, coin_r = (0.50, 0.54), 0.185
    claw = dark(BONE, 0.20)
    circle(d, coin_c[0], coin_c[1], coin_r, fill=GOLD,
           outline=light(GOLD, 0.35), width=2.5)
    circle(d, coin_c[0], coin_c[1], coin_r * 0.38, fill=dark(GOLD, 0.45))
    line(d, [(0.50, 0.06), (0.50, 0.34)], claw, 6)             # leg
    ellipse(d, 0.38, 0.24, 0.62, 0.42, fill=claw)              # ankle
    for s in (-1, 1):
        # Each claw: down the side of the coin, then a hooked tip under it.
        serpent(d, [(0.50 + s * 0.06, 0.34), (0.50 + s * 0.24, 0.44),
                    (0.50 + s * 0.26, 0.64), (0.50 + s * 0.13, 0.78)],
                0.075, 0.020, claw)
        poly(d, [(0.50 + s * 0.16, 0.76), (0.50 + s * 0.06, 0.86),
                 (0.50 + s * 0.14, 0.72)], fill=BONE)
        # Outer claw, splayed wider so the foot reads as more than two prongs.
        serpent(d, [(0.50 + s * 0.08, 0.32), (0.50 + s * 0.30, 0.36),
                    (0.50 + s * 0.40, 0.52)], 0.065, 0.018, claw)
        poly(d, [(0.50 + s * 0.38, 0.50), (0.50 + s * 0.46, 0.60),
                 (0.50 + s * 0.34, 0.54)], fill=BONE)


@art("second_thoughts")
def _(d, t):
    # A hand of cards being swept away and redrawn -- a circular arrow over cards.
    for i, (x, rot) in enumerate(((0.34, -14), (0.5, 0), (0.66, 14))):
        card_back(d, x, 0.60 + abs(i - 1) * 0.03, 0.11, 0.19,
                  dark(TOWER, 0.55), TOWER)
    arc(d, 0.18, 0.10, 0.82, 0.56, 165, 15, light(TOWER, 0.35), 4)
    poly(d, [(0.80, 0.30), (0.90, 0.30), (0.85, 0.42)], fill=light(TOWER, 0.35))


@art("last_rites")
def _(d, t):
    # A candle burned down over a shrouded body.
    rect(d, 0.20, 0.68, 0.80, 0.80, fill=dark(BONE, 0.5), radius=0.05)
    ellipse(d, 0.20, 0.62, 0.44, 0.76, fill=dark(BONE, 0.42))
    rect(d, 0.46, 0.34, 0.54, 0.68, fill=BONE, radius=0.015)
    droplet(d, 0.5, 0.26, 0.055, GOLD)
    droplet(d, 0.5, 0.28, 0.030, light(GOLD, 0.55))


@art("muster")
def _(d, t):
    # Three figures forming a rank behind a banner.
    for x, h in ((0.26, 0.30), (0.5, 0.36), (0.74, 0.30)):
        circle(d, x, 0.86 - h - 0.075, 0.070, fill=dark(BONE, 0.30))
        poly(d, [(x - 0.095, 0.86), (x + 0.095, 0.86), (x + 0.065, 0.86 - h),
                 (x - 0.065, 0.86 - h)], fill=mix(TOWER, PANEL, 0.4))
    line(d, [(0.5, 0.06), (0.5, 0.44)], dark(BONE, 0.2), 2.5)
    poly(d, [(0.5, 0.08), (0.78, 0.15), (0.5, 0.24)], fill=ACCENT)


@art("roll_call")
def _(d, t):
    # A scroll with names ticked off.
    rect(d, 0.24, 0.14, 0.76, 0.86, fill=dark(BONE, 0.25), radius=0.05)
    ellipse(d, 0.20, 0.10, 0.32, 0.90, fill=dark(BONE, 0.45))
    ellipse(d, 0.68, 0.10, 0.80, 0.90, fill=dark(BONE, 0.45))
    for i in range(4):
        y = 0.28 + i * 0.145
        line(d, [(0.40, y), (0.68, y)], dark(BONE, 0.68), 2)
        line(d, [(0.33, y - 0.01), (0.36, y + 0.025)], HP_GREEN, 2.5)
        line(d, [(0.36, y + 0.025), (0.40, y - 0.045)], HP_GREEN, 2.5)


@art("line_of_succession")
def _(d, t):
    # Three crowns in descending order, linked.
    for i, (x, y, s) in enumerate(((0.26, 0.30, 1.0), (0.5, 0.52, 0.85),
                                   (0.74, 0.74, 0.7))):
        w = 0.115 * s
        poly(d, [(x - w, y + w * 0.55), (x - w, y - w * 0.35), (x - w * 0.45, y + w * 0.1),
                 (x, y - w * 0.75), (x + w * 0.45, y + w * 0.1), (x + w, y - w * 0.35),
                 (x + w, y + w * 0.55)], fill=GOLD if i == 0 else dark(GOLD, i * 0.22))
    arrow(d, 0.36, 0.40, 0.44, 0.47, TEXT_DIM, 0.022, 0.05)
    arrow(d, 0.60, 0.62, 0.68, 0.69, TEXT_DIM, 0.022, 0.05)


@art("read_the_bones")
def _(d, t):
    # Cast rune-bones inside a divination circle.
    circle(d, 0.5, 0.52, 0.34, outline=dark(ACCENT, 0.25), width=2.5)
    circle(d, 0.5, 0.52, 0.26, outline=dark(ACCENT, 0.4), width=1.8)
    bone(d, 0.28, 0.44, 0.52, 0.38, 0.030)
    bone(d, 0.42, 0.66, 0.70, 0.60, 0.028)
    bone(d, 0.52, 0.50, 0.60, 0.74, 0.026)
    star(d, 0.5, 0.52, 0.055, points=4, inner=0.3, fill=light(ACCENT, 0.4))


@art("grave_market")
def _(d, t):
    # A stall awning over a coin -- trade with the dead.
    poly(d, [(0.10, 0.42), (0.90, 0.42), (0.82, 0.20), (0.18, 0.20)],
         fill=dark(RUST, 0.2))
    for i in range(4):
        x0 = 0.18 + i * 0.16
        poly(d, [(x0, 0.20), (x0 + 0.08, 0.20), (x0 + 0.06, 0.42), (x0 - 0.02, 0.42)],
             fill=dark(BONE, 0.42) if i % 2 == 0 else dark(RUST, 0.35))
    rect(d, 0.14, 0.42, 0.19, 0.86, fill=dark(BONE, 0.55))
    rect(d, 0.81, 0.42, 0.86, 0.86, fill=dark(BONE, 0.55))
    rect(d, 0.22, 0.60, 0.78, 0.68, fill=dark(BONE, 0.45), radius=0.02)
    circle(d, 0.42, 0.545, 0.055, fill=GOLD)
    circle(d, 0.58, 0.545, 0.055, fill=dark(GOLD, 0.25))


@art("offering")
def _(d, t):
    # Two hands presenting an energy hexagon.
    poly(d, [(0.16, 0.86), (0.30, 0.56), (0.48, 0.64), (0.44, 0.86)],
         fill=dark(BONE, 0.32))
    poly(d, [(0.84, 0.86), (0.70, 0.56), (0.52, 0.64), (0.56, 0.86)],
         fill=dark(BONE, 0.32))
    hexagon(d, 0.5, 0.36, 0.175, fill=GOLD, outline=light(GOLD, 0.35), width=2.5)
    hexagon(d, 0.5, 0.36, 0.085, fill=dark(GOLD, 0.5))
    for a in (-40, 0, 40):
        r = math.radians(a - 90)
        line(d, [(0.5 + math.cos(r) * 0.22, 0.36 + math.sin(r) * 0.22),
                 (0.5 + math.cos(r) * 0.31, 0.36 + math.sin(r) * 0.31)],
             light(GOLD, 0.2), 2)


@art("tithe")
def _(d, t):
    # Energy moving from one unit to another.
    circle(d, 0.22, 0.62, 0.135, fill=dark(TOWER, 0.5), outline=TOWER, width=2)
    circle(d, 0.78, 0.62, 0.135, fill=dark(TOWER, 0.5), outline=TOWER, width=2)
    arrow(d, 0.36, 0.44, 0.64, 0.44, GOLD, 0.028, 0.062)
    hexagon(d, 0.5, 0.26, 0.10, fill=GOLD)
    hexagon(d, 0.22, 0.62, 0.055, fill=dark(GOLD, 0.35))


@art("sift_the_ashes")
def _(d, t):
    # A flat mesh sieve seen face-on, ash falling through it, a card recovered.
    card_back(d, 0.5, 0.24, 0.095, 0.145, dark(ACCENT, 0.35), ACCENT)
    circle(d, 0.5, 0.56, 0.28, fill=dark(PANEL, -0.15), outline=dark(BONE, 0.25),
           width=5)
    for i in range(-3, 4):                       # mesh grid inside the rim
        o = i * 0.068
        h = math.sqrt(max(0.0, 0.27 ** 2 - o ** 2))
        line(d, [(0.5 + o, 0.56 - h), (0.5 + o, 0.56 + h)], dark(BONE, 0.55), 1.4)
        line(d, [(0.5 - h, 0.56 + o), (0.5 + h, 0.56 + o)], dark(BONE, 0.55), 1.4)
    for x, y, r in ((0.30, 0.88, 0.030), (0.46, 0.92, 0.024), (0.62, 0.87, 0.028),
                    (0.74, 0.93, 0.020)):
        circle(d, x, y, r, fill=dark(BONE, 0.55))


@art("escape_route")
def _(d, t):
    # A doorway with a figure stepping through.
    rect(d, 0.22, 0.16, 0.78, 0.86, fill=dark(BONE, 0.62), radius=0.03)
    rect(d, 0.30, 0.24, 0.70, 0.86, fill=(6, 5, 9), radius=0.02)
    poly(d, [(0.44, 0.44), (0.60, 0.44), (0.56, 0.80), (0.40, 0.80)],
         fill=dark(HP_GREEN, 0.3))
    circle(d, 0.51, 0.375, 0.055, fill=dark(HP_GREEN, 0.2))
    arrow(d, 0.36, 0.62, 0.16, 0.62, HP_GREEN, 0.028, 0.065)


@art("withdraw")
def _(d, t):
    # A unit lifted off its slot back toward the hand.
    rect(d, 0.16, 0.74, 0.84, 0.88, fill=dark(BORDER, 0.15), radius=0.03)
    rect(d, 0.20, 0.76, 0.44, 0.86, fill=dark(PANEL, -0.2), radius=0.02)
    rect(d, 0.56, 0.76, 0.80, 0.86, fill=dark(PANEL, -0.2), radius=0.02)
    card_back(d, 0.5, 0.34, 0.14, 0.20, dark(TOWER, 0.5), TOWER)
    arrow(d, 0.5, 0.72, 0.5, 0.56, light(TOWER, 0.3), 0.030, 0.070)


@art("rally_the_line")
def _(d, t):
    # A banner raised over a closed rank.
    for x in (0.22, 0.38, 0.62, 0.78):
        rect(d, x - 0.070, 0.56, x + 0.070, 0.88, fill=mix(TOWER, PANEL, 0.42),
             radius=0.03)
        circle(d, x, 0.50, 0.058, fill=dark(BONE, 0.35))
    line(d, [(0.5, 0.06), (0.5, 0.88)], dark(BONE, 0.2), 3)
    poly(d, [(0.5, 0.08), (0.86, 0.18), (0.5, 0.30)], fill=DANGER)
    star(d, 0.64, 0.185, 0.045, points=4, inner=0.32, fill=GOLD)


@art("ground_give")
def _(d, t):
    # Ground splitting under a unit -- the retreat that costs the energy.
    rect(d, 0.30, 0.26, 0.70, 0.62, fill=mix(TOWER, PANEL, 0.42), radius=0.04)
    circle(d, 0.5, 0.20, 0.070, fill=dark(BONE, 0.32))
    d.rectangle([P(0, 0.70), P(1, 1)], fill=dark(RUST, 0.55))
    poly(d, [(0.5, 0.70), (0.40, 0.80), (0.52, 0.86), (0.42, 1.0), (0.60, 1.0),
             (0.56, 0.84), (0.64, 0.76)], fill=(6, 5, 9))
    hexagon(d, 0.24, 0.84, 0.048, fill=dark(GOLD, 0.4))
    hexagon(d, 0.80, 0.88, 0.042, fill=dark(GOLD, 0.5))


@art("reposition")
def _(d, t):
    # A unit sliding one slot across a three-slot lane.
    rect(d, 0.06, 0.56, 0.94, 0.90, fill=dark(BORDER, 0.2), radius=0.04)
    for i in range(3):
        x = 0.12 + i * 0.28
        rect(d, x, 0.61, x + 0.24, 0.85, fill=dark(PANEL, -0.25), radius=0.03,
             outline=BORDER, width=1.5)
    rect(d, 0.13, 0.62, 0.35, 0.84, fill=dark(TOWER, 0.45), radius=0.03)
    rect(d, 0.69, 0.62, 0.91, 0.84, outline=light(TOWER, 0.2), width=2,
         radius=0.03)
    # The move arc sits clear above the lane so it never crosses the slots.
    arc(d, 0.20, 0.14, 0.84, 0.62, 180, 350, light(TOWER, 0.30), 4)
    poly(d, [(0.74, 0.34), (0.90, 0.36), (0.80, 0.50)], fill=light(TOWER, 0.30))


@art("shore_up")
def _(d, t):
    # A cross-braced shield -- the baseline heal.
    poly(d, [(0.5, 0.12), (0.82, 0.26), (0.78, 0.66), (0.5, 0.88),
             (0.22, 0.66), (0.18, 0.26)], fill=dark(HP_GREEN, 0.55),
         outline=HP_GREEN, width=2.5)
    rect(d, 0.44, 0.30, 0.56, 0.70, fill=light(HP_GREEN, 0.25), radius=0.02)
    rect(d, 0.30, 0.44, 0.70, 0.56, fill=light(HP_GREEN, 0.25), radius=0.02)


@art("field_rites")
def _(d, t):
    # A censer swung over the whole board -- small heals everywhere.
    line(d, [(0.5, 0.06), (0.5, 0.34)], dark(BONE, 0.35), 2)
    poly(d, [(0.34, 0.38), (0.66, 0.38), (0.60, 0.62), (0.40, 0.62)], fill=GOLD)
    ellipse(d, 0.32, 0.32, 0.68, 0.44, fill=dark(GOLD, 0.25))
    for x, y, r in ((0.22, 0.72, 0.055), (0.40, 0.80, 0.045), (0.60, 0.78, 0.05),
                    (0.78, 0.70, 0.042)):
        circle(d, x, y, r, fill=dark(HP_GREEN, 0.35))
        line(d, [(x - r * 0.5, y), (x + r * 0.5, y)], light(HP_GREEN, 0.4), 1.6)
        line(d, [(x, y - r * 0.5), (x, y + r * 0.5)], light(HP_GREEN, 0.4), 1.6)


@art("last_breath")
def _(d, t):
    # A guttering flame cupped in a hand.
    poly(d, [(0.14, 0.88), (0.24, 0.60), (0.76, 0.60), (0.86, 0.88)],
         fill=dark(BONE, 0.38))
    droplet(d, 0.5, 0.40, 0.115, DANGER)
    droplet(d, 0.5, 0.42, 0.065, GOLD)
    droplet(d, 0.5, 0.44, 0.030, light(GOLD, 0.6))


@art("mend")
def _(d, t):
    # A single stitch closing a wound -- the smallest heal in the file.
    line(d, [(0.5, 0.14), (0.5, 0.86)], dark(BONE, 0.30), 5)
    for y in (0.30, 0.44, 0.58, 0.72):           # sutures across the seam
        line(d, [(0.34, y - 0.05), (0.66, y + 0.05)], HP_GREEN, 2.6)
    circle(d, 0.5, 0.5, 0.055, fill=light(HP_GREEN, 0.30))


@art("field_surgery")
def _(d, t):
    # A blade and a cross -- the shield of Shore Up, opened up and worked on.
    poly(d, [(0.5, 0.10), (0.84, 0.24), (0.80, 0.64), (0.5, 0.90),
             (0.20, 0.64), (0.16, 0.24)], fill=dark(HP_GREEN, 0.50),
         outline=HP_GREEN, width=2.5)
    rect(d, 0.43, 0.24, 0.57, 0.76, fill=light(HP_GREEN, 0.35), radius=0.02)
    rect(d, 0.24, 0.43, 0.76, 0.57, fill=light(HP_GREEN, 0.35), radius=0.02)
    line(d, [(0.26, 0.74), (0.74, 0.26)], light(BONE, 0.55), 3)   # the scalpel
    poly(d, [(0.70, 0.20), (0.80, 0.18), (0.78, 0.30)], fill=light(BONE, 0.70))


@art("closing_ranks")
def _(d, t):
    # Four shields locked into a wall -- Field Rites' spread, made solid.
    for i, x in enumerate((0.16, 0.38, 0.60, 0.82)):
        top = 0.30 + (0.04 if i % 2 else 0.0)
        poly(d, [(x, top), (x + 0.14, top + 0.07), (x + 0.12, top + 0.28),
                 (x, top + 0.40), (x - 0.12, top + 0.28), (x - 0.14, top + 0.07)],
             fill=dark(HP_GREEN, 0.45), outline=HP_GREEN, width=1.8)
        line(d, [(x, top + 0.10), (x, top + 0.30)], light(HP_GREEN, 0.35), 1.8)
    line(d, [(0.06, 0.82), (0.94, 0.82)], dark(BONE, 0.40), 3)


@art("vigil")
def _(d, t):
    # A candle burnt down through the night -- healing that grows with the rounds.
    rect(d, 0.40, 0.36, 0.60, 0.86, fill=dark(BONE, 0.34), radius=0.02)
    for y in (0.48, 0.60, 0.72):                 # wax rings: rounds elapsed
        line(d, [(0.40, y), (0.60, y)], dark(BONE, 0.55), 1.8)
    line(d, [(0.5, 0.30), (0.5, 0.36)], dark(BONE, 0.60), 2)
    droplet(d, 0.5, 0.22, 0.10, GOLD)
    droplet(d, 0.5, 0.24, 0.055, light(GOLD, 0.55))
    ellipse(d, 0.30, 0.78, 0.70, 0.92, fill=dark(HP_GREEN, 0.30))


@art("grave_wardens_oath")
def _(d, t):
    # A hand raised over a shield -- a sworn promise, the top of the ladder.
    poly(d, [(0.5, 0.28), (0.84, 0.40), (0.80, 0.72), (0.5, 0.92),
             (0.20, 0.72), (0.16, 0.40)], fill=dark(HP_GREEN, 0.55),
         outline=HP_GREEN, width=2.8)
    rect(d, 0.44, 0.40, 0.56, 0.80, fill=light(HP_GREEN, 0.40), radius=0.02)
    rect(d, 0.30, 0.52, 0.70, 0.64, fill=light(HP_GREEN, 0.40), radius=0.02)
    rect(d, 0.42, 0.06, 0.58, 0.28, fill=dark(BONE, 0.40), radius=0.03)
    for x in (0.34, 0.42, 0.50, 0.58):           # fingers of the raised hand
        rect(d, x - 0.035, 0.10, x + 0.035, 0.24, fill=dark(BONE, 0.36), radius=0.03)
    circle(d, 0.5, 0.58, 0.045, fill=GOLD)


@art("reconsecrate")
def _(d, t):
    # A headstone in the ground under a shaft of clean light.
    poly(d, [(0.34, 0.06), (0.66, 0.06), (0.80, 0.72), (0.20, 0.72)],
         fill=light(GOLD, 0.55))
    rect(d, 0.34, 0.36, 0.66, 0.84, fill=dark(BONE, 0.32), radius=0.0)
    arc(d, 0.34, 0.22, 0.66, 0.54, 180, 360, dark(BONE, 0.32), 0)
    ellipse(d, 0.34, 0.24, 0.66, 0.50, fill=dark(BONE, 0.32))
    for y in (0.52, 0.60, 0.68):                 # worn inscription
        line(d, [(0.41, y), (0.59, y)], dark(BONE, 0.58), 2)
    ellipse(d, 0.14, 0.80, 0.86, 0.94, fill=dark(RUST, 0.55))
    circle(d, 0.5, 0.14, 0.075, fill=light(GOLD, 0.55))


@art("hold_the_slot")
def _(d, t):
    # A shield planted in an occupied slot -- the unit does not die.
    rect(d, 0.06, 0.66, 0.94, 0.90, fill=dark(BORDER, 0.2), radius=0.04)
    for i in range(3):
        x = 0.12 + i * 0.28
        rect(d, x, 0.70, x + 0.24, 0.86, fill=dark(PANEL, -0.25), radius=0.02,
             outline=BORDER, width=1.5)
    poly(d, [(0.5, 0.10), (0.78, 0.24), (0.74, 0.56), (0.5, 0.76),
             (0.26, 0.56), (0.22, 0.24)], fill=dark(TOWER, 0.35),
         outline=light(TOWER, 0.2), width=2.5)
    line(d, [(0.38, 0.40), (0.47, 0.52)], light(TOWER, 0.5), 3)
    line(d, [(0.47, 0.52), (0.64, 0.28)], light(TOWER, 0.5), 3)


@art("collapse")
def _(d, t):
    # A buckled arch giving way, stones tumbling out of it.
    for x, y, r, rot in ((0.20, 0.30, 0.075, 0.5), (0.50, 0.16, 0.090, -0.3),
                         (0.78, 0.28, 0.065, 0.8)):
        poly(d, [(x - r, y + r * 0.6 + rot * 0.02), (x - r * 0.4, y - r),
                 (x + r * 0.85, y - r * 0.45), (x + r * 0.55, y + r * 0.85)],
             fill=dark(BONE, 0.45))
    # The arch: two legs, one snapped, with the keystone dropping out.
    poly(d, [(0.16, 0.92), (0.30, 0.92), (0.32, 0.56), (0.18, 0.54)],
         fill=dark(BONE, 0.38))
    poly(d, [(0.70, 0.92), (0.84, 0.92), (0.80, 0.60), (0.66, 0.64)],
         fill=dark(BONE, 0.38))
    poly(d, [(0.18, 0.54), (0.32, 0.56), (0.40, 0.48), (0.26, 0.44)],
         fill=dark(BONE, 0.30))
    poly(d, [(0.66, 0.64), (0.80, 0.60), (0.74, 0.50), (0.60, 0.54)],
         fill=dark(BONE, 0.30))
    poly(d, [(0.42, 0.62), (0.58, 0.58), (0.62, 0.72), (0.46, 0.76)],
         fill=dark(BONE, 0.22))
    for x, y in ((0.36, 0.86), (0.52, 0.90), (0.64, 0.84)):
        circle(d, x, y, 0.030, fill=dark(BONE, 0.52))


@art("sever")
def _(d, t):
    # A chain cut, energy spilling -- the anti-hoard card.
    for i, y in enumerate((0.18, 0.32, 0.68, 0.82)):
        ellipse(d, 0.42, y - 0.055, 0.58, y + 0.055, outline=dark(GOLD, 0.2),
                width=3.5)
    poly(d, [(0.14, 0.62), (0.86, 0.38), (0.88, 0.46), (0.16, 0.70)],
         fill=light(TOWER, 0.35))
    hexagon(d, 0.28, 0.34, 0.055, fill=dark(GOLD, 0.4))
    hexagon(d, 0.74, 0.68, 0.048, fill=dark(GOLD, 0.5))


@art("toppling_blow")
def _(d, t):
    # A tower falling under a hammer strike.
    tower_shape(d, 0.62, 0.88, 0.14, 0.44, dark(TOWER, 0.5), dark(TOWER, 0.3))
    poly(d, [(0.48, 0.60), (0.76, 0.52), (0.72, 0.66), (0.52, 0.72)],
         fill=(6, 5, 9))
    line(d, [(0.10, 0.14), (0.40, 0.44)], dark(RUST, 0.2), 4)
    rect(d, 0.30, 0.36, 0.52, 0.52, fill=dark(BONE, 0.45), radius=0.03)
    for x, y in ((0.80, 0.32), (0.86, 0.50), (0.74, 0.20)):
        star(d, x, y, 0.035, points=4, inner=0.3, fill=GOLD)


@art("watchfires")
def _(d, t):
    # Three signal fires on a wall -- the search card.
    rect(d, 0.04, 0.66, 0.96, 0.90, fill=dark(BONE, 0.62), radius=0.02)
    for i in range(5):
        x = 0.06 + i * 0.19
        rect(d, x, 0.60, x + 0.13, 0.68, fill=dark(BONE, 0.55), radius=0.01)
    for x, s in ((0.22, 0.85), (0.5, 1.0), (0.78, 0.85)):
        droplet(d, x, 0.44, 0.085 * s, DANGER)
        droplet(d, x, 0.46, 0.048 * s, GOLD)
        droplet(d, x, 0.48, 0.022 * s, light(GOLD, 0.6))


# ---- tools --------------------------------------------------------------

@art("bone_splint")
def _(d, t):
    # A bone bound in splints.
    bone(d, 0.24, 0.74, 0.76, 0.28, 0.048)
    for t0 in (0.34, 0.62):
        x = 0.24 + (0.76 - 0.24) * t0
        y = 0.74 + (0.28 - 0.74) * t0
        poly(d, [(x - 0.10, y - 0.075), (x + 0.02, y - 0.145),
                 (x + 0.10, y + 0.075), (x - 0.02, y + 0.145)],
             fill=dark(RUST, 0.15))
    line(d, [(0.14, 0.86), (0.30, 0.66)], dark(BONE, 0.5), 3)


@art("weighted_chain")
def _(d, t):
    # A chain with a weight on the end.
    for i in range(4):
        y = 0.14 + i * 0.13
        ellipse(d, 0.40, y - 0.06, 0.60, y + 0.06, outline=dark(TOWER, 0.15),
                width=3.5)
    poly(d, [(0.32, 0.64), (0.68, 0.64), (0.76, 0.88), (0.24, 0.88)],
         fill=dark(BORDER, -0.15), outline=BORDER, width=2)
    rect(d, 0.42, 0.60, 0.58, 0.66, fill=dark(TOWER, 0.3), radius=0.01)


@art("grave_anchor")
def _(d, t):
    # An anchor -- paid in advance for an escape.
    line(d, [(0.5, 0.14), (0.5, 0.82)], dark(BONE, 0.25), 4.5)
    line(d, [(0.30, 0.32), (0.70, 0.32)], dark(BONE, 0.25), 3.5)
    circle(d, 0.5, 0.16, 0.070, outline=dark(BONE, 0.25), width=3.5)
    arc(d, 0.20, 0.46, 0.80, 0.92, 20, 160, dark(BONE, 0.25), 4.5)
    poly(d, [(0.20, 0.66), (0.28, 0.60), (0.26, 0.74)], fill=dark(BONE, 0.25))
    poly(d, [(0.80, 0.66), (0.72, 0.60), (0.74, 0.74)], fill=dark(BONE, 0.25))


@art("ration_pack")
def _(d, t):
    # A satchel of stored energy -- the anti-decay tool.
    rect(d, 0.22, 0.38, 0.78, 0.86, fill=dark(RUST, 0.30), radius=0.06,
         outline=dark(RUST, 0.1), width=2)
    poly(d, [(0.22, 0.44), (0.78, 0.44), (0.70, 0.24), (0.30, 0.24)],
         fill=dark(RUST, 0.15))
    arc(d, 0.34, 0.10, 0.66, 0.34, 180, 360, dark(BONE, 0.4), 3)
    hexagon(d, 0.5, 0.64, 0.115, fill=GOLD)
    hexagon(d, 0.5, 0.64, 0.055, fill=dark(GOLD, 0.5))


@art("iron_standard")
def _(d, t):
    # A planted battle standard.
    line(d, [(0.5, 0.08), (0.5, 0.88)], dark(BORDER, -0.2), 3.5)
    poly(d, [(0.5, 0.14), (0.88, 0.24), (0.78, 0.34), (0.88, 0.44), (0.5, 0.52)],
         fill=DANGER)
    star(d, 0.66, 0.32, 0.055, points=4, inner=0.32, fill=GOLD)
    poly(d, [(0.5, 0.06), (0.55, 0.14), (0.45, 0.14)], fill=GOLD)
    ellipse(d, 0.34, 0.82, 0.66, 0.92, fill=dark(BONE, 0.6))


@art("deadweight")
def _(d, t):
    # A block chained to a body -- the enemy-facing Tool.
    rect(d, 0.28, 0.50, 0.72, 0.86, fill=dark(BORDER, -0.1), radius=0.04,
         outline=BORDER, width=2)
    for i in range(3):
        y = 0.20 + i * 0.12
        ellipse(d, 0.42, y - 0.055, 0.58, y + 0.055, outline=dark(TOWER, 0.25),
                width=3)
    line(d, [(0.34, 0.58), (0.66, 0.78)], DANGER, 3)
    line(d, [(0.66, 0.58), (0.34, 0.78)], DANGER, 3)


# ---- tower support ------------------------------------------------------

@art("reinforced_base")
def _(d, t):
    # A tower on a thick plinth.
    tower_shape(d, 0.5, 0.72, 0.17, 0.44, dark(TOWER, 0.35), TOWER)
    rect(d, 0.14, 0.72, 0.86, 0.84, fill=dark(BONE, 0.45), radius=0.02)
    rect(d, 0.08, 0.84, 0.92, 0.94, fill=dark(BONE, 0.35), radius=0.02)
    for x in (0.26, 0.5, 0.74):
        line(d, [(x, 0.84), (x, 0.94)], dark(BONE, 0.62), 2)


@art("murder_holes")
def _(d, t):
    # Arrow slits raining down from a tower face.
    rect(d, 0.16, 0.06, 0.84, 0.56, fill=dark(TOWER, 0.45), radius=0.03,
         outline=TOWER, width=2)
    for i in range(4):
        x = 0.24 + i * 0.15
        rect(d, x, 0.16, x + 0.055, 0.42, fill=(6, 5, 9), radius=0.02)
    for i, x in enumerate((0.26, 0.42, 0.58, 0.74)):
        y0 = 0.60 + (i % 2) * 0.06
        arrow(d, x, y0, x, y0 + 0.26, GOLD, 0.020, 0.045)


@art("crossfire")
def _(d, t):
    # Two towers with crossing lines of fire.
    tower_shape(d, 0.20, 0.86, 0.11, 0.34, dark(TOWER, 0.4), TOWER)
    tower_shape(d, 0.80, 0.86, 0.11, 0.34, dark(TOWER, 0.4), TOWER)
    arrow(d, 0.28, 0.54, 0.74, 0.30, GOLD, 0.024, 0.055)
    arrow(d, 0.72, 0.54, 0.26, 0.30, DANGER, 0.024, 0.055)
    star(d, 0.5, 0.42, 0.055, points=4, inner=0.3, fill=light(GOLD, 0.4))


@art("rebuild")
def _(d, t):
    # A tower being patched -- new stone over a breach.
    tower_shape(d, 0.5, 0.88, 0.19, 0.56, dark(TOWER, 0.45), TOWER)
    poly(d, [(0.36, 0.50), (0.52, 0.44), (0.56, 0.62), (0.38, 0.68)],
         fill=(6, 5, 9))
    for x, y in ((0.36, 0.50), (0.50, 0.46), (0.46, 0.62)):
        rect(d, x, y, x + 0.11, y + 0.075, fill=dark(BONE, 0.35), radius=0.012,
             outline=dark(BONE, 0.55), width=1.5)
    line(d, [(0.66, 0.28), (0.86, 0.18)], dark(RUST, 0.2), 3)
    rect(d, 0.80, 0.10, 0.94, 0.22, fill=dark(BONE, 0.4), radius=0.02)


@art("spite_engine")
def _(d, t):
    # A tower detonating as it dies -- Toll applied to structures.
    for a in range(0, 360, 30):
        r = math.radians(a)
        line(d, [(0.5 + math.cos(r) * 0.20, 0.46 + math.sin(r) * 0.20),
                 (0.5 + math.cos(r) * 0.40, 0.46 + math.sin(r) * 0.40)],
             dark(DANGER, 0.25 if a % 60 else 0.0), 2.5)
    tower_shape(d, 0.5, 0.88, 0.15, 0.30, dark(TOWER, 0.5), dark(TOWER, 0.3))
    star(d, 0.5, 0.42, 0.185, points=8, inner=0.45, fill=DANGER)
    star(d, 0.5, 0.42, 0.105, points=8, inner=0.45, fill=GOLD)


@art("open_the_gate")
def _(d, t):
    # A portcullis raised -- the tower's slot opening on your schedule.
    rect(d, 0.10, 0.10, 0.90, 0.90, fill=dark(BONE, 0.62), radius=0.04)
    rect(d, 0.22, 0.22, 0.78, 0.90, fill=(6, 5, 9), radius=0.02)
    for i in range(4):
        x = 0.25 + i * 0.145
        rect(d, x, 0.22, x + 0.045, 0.46, fill=dark(BONE, 0.30))
    for y in (0.28, 0.40):
        rect(d, 0.22, y, 0.78, y + 0.045, fill=dark(BONE, 0.30))
    for i in range(4):
        x = 0.25 + i * 0.145
        poly(d, [(x, 0.46), (x + 0.045, 0.46), (x + 0.022, 0.53)],
             fill=dark(BONE, 0.30))
    arrow(d, 0.5, 0.74, 0.5, 0.58, HP_GREEN, 0.026, 0.058)


# ---- Heaven -------------------------------------------------------------
# Gold, radial symmetry, and things that hang or hover. Where Hel's emblems
# stand on the horizon line, Heaven's tend to float above it -- the two
# factions read apart at a glance before either is identified.

@art("heaven_energy")
def _(d, t):
    hexagon(d, 0.5, 0.5, 0.30, fill=dark(GOLD, 0.55), outline=GOLD, width=3)
    hexagon(d, 0.5, 0.5, 0.19, fill=GOLD)
    rays(d, 0.5, 0.5, 0.085, 0.165, dark(PANEL, -0.1), count=8, width=3)
    circle(d, 0.5, 0.5, 0.062, fill=light(GOLD, 0.55))
    for a in range(0, 360, 60):
        r = math.radians(a)
        circle(d, 0.5 + math.cos(r) * 0.385, 0.5 + math.sin(r) * 0.385, 0.022,
               fill=light(GOLD, 0.2))


@art("lantern_acolyte")
def _(d, t):
    # The smallest lamp -- a hooded figure carrying one small light.
    poly(d, [(0.34, 0.82), (0.38, 0.44), (0.56, 0.44), (0.60, 0.82)],
         fill=mix(GOLD, PANEL, 0.62))
    circle(d, 0.47, 0.38, 0.115, fill=mix(GOLD, PANEL, 0.48))
    poly(d, [(0.36, 0.40), (0.47, 0.22), (0.58, 0.40)], fill=dark(GOLD, 0.68))
    halo(d, 0.47, 0.20, 0.115, GOLD, 2.5)
    line(d, [(0.58, 0.48), (0.72, 0.52)], mix(GOLD, PANEL, 0.55), 2.5)
    # the lantern itself, the brightest thing on the card
    line(d, [(0.72, 0.44), (0.72, 0.52)], dark(GOLD, 0.5), 2)
    poly(d, [(0.65, 0.56), (0.79, 0.56), (0.77, 0.72), (0.67, 0.72)],
         fill=dark(GOLD, 0.55), outline=GOLD, width=2)
    circle(d, 0.72, 0.64, 0.042, fill=light(GOLD, 0.55))
    rays(d, 0.72, 0.64, 0.055, 0.105, dark(GOLD, 0.15), count=8, width=1.8)


@art("censer_bearer")
def _(d, t):
    # A swinging censer trailing smoke -- a poor first hit, a great second.
    circle(d, 0.36, 0.34, 0.095, fill=mix(GOLD, PANEL, 0.5))
    poly(d, [(0.26, 0.80), (0.29, 0.44), (0.45, 0.44), (0.46, 0.80)],
         fill=mix(GOLD, PANEL, 0.65))
    halo(d, 0.36, 0.20, 0.095, GOLD, 2.2)
    for x in (0.60, 0.66, 0.72):
        line(d, [(0.46, 0.46), (x, 0.30)], dark(GOLD, 0.45), 1.8)
    poly(d, [(0.56, 0.52), (0.78, 0.52), (0.74, 0.70), (0.60, 0.70)],
         fill=GOLD)
    rect(d, 0.55, 0.46, 0.79, 0.53, fill=light(GOLD, 0.25), radius=0.02)
    for i, y in enumerate((0.32, 0.24, 0.17)):
        circle(d, 0.67 + (i % 2) * 0.06 - 0.03, y, 0.045 - i * 0.008,
               fill=mix(GOLD, PANEL, 0.55 + i * 0.12))


@art("warden_of_the_lamp")
def _(d, t):
    # One big hanging lamp, guarded. The figure was competing with the lamp
    # and the spear at 74px, so the lamp is the silhouette and the warden is
    # a low shape beneath it.
    line(d, [(0.5, 0.04), (0.5, 0.16)], dark(GOLD, 0.4), 2.5)
    poly(d, [(0.32, 0.20), (0.68, 0.20), (0.62, 0.54), (0.38, 0.54)],
         fill=dark(GOLD, 0.52), outline=GOLD, width=3)
    rect(d, 0.29, 0.15, 0.71, 0.22, fill=GOLD, radius=0.02)
    rect(d, 0.35, 0.53, 0.65, 0.59, fill=GOLD, radius=0.015)
    circle(d, 0.5, 0.37, 0.088, fill=light(GOLD, 0.6))
    rays(d, 0.5, 0.37, 0.11, 0.20, light(GOLD, 0.1), count=8, width=2)
    # the warden: shoulders and helm only, reading as a base for the lamp
    poly(d, [(0.24, 0.92), (0.30, 0.68), (0.70, 0.68), (0.76, 0.92)],
         fill=mix(GOLD, PANEL, 0.62), outline=dark(GOLD, 0.30), width=2)
    circle(d, 0.5, 0.68, 0.085, fill=mix(GOLD, PANEL, 0.48))


@art("bellringer_of_the_court")
def _(d, t):
    # A figure hauling a bell rope -- the recharge, one line, two jobs.
    bell(d, 0.62, 0.30, 0.155, GOLD)
    line(d, [(0.62, 0.44), (0.44, 0.66)], dark(GOLD, 0.4), 3)
    circle(d, 0.34, 0.44, 0.095, fill=mix(GOLD, PANEL, 0.5))
    poly(d, [(0.24, 0.86), (0.27, 0.54), (0.43, 0.54), (0.46, 0.86)],
         fill=mix(GOLD, PANEL, 0.64))
    line(d, [(0.43, 0.60), (0.46, 0.66)], mix(GOLD, PANEL, 0.5), 3)
    halo(d, 0.34, 0.31, 0.095, GOLD, 2.2)


@art("cherub_of_the_open_gate")
def _(d, t):
    # Small, winged, and mostly shield -- Sanctuary chaff.
    wings(d, 0.5, 0.42, 0.30, 0.24, mix(GOLD, PANEL, 0.42))
    circle(d, 0.5, 0.36, 0.105, fill=mix(GOLD, PANEL, 0.40))
    halo(d, 0.5, 0.21, 0.105, GOLD, 2.2)
    poly(d, [(0.5, 0.50), (0.68, 0.58), (0.66, 0.80), (0.5, 0.90),
             (0.34, 0.80), (0.32, 0.58)],
         fill=dark(GOLD, 0.52), outline=GOLD, width=2.5)
    rays(d, 0.5, 0.68, 0.03, 0.10, light(GOLD, 0.25), count=6, width=2)


@art("arbiter_of_the_third_seal")
def _(d, t):
    # Scales over a broken third seal -- the execute engine.
    scales(d, 0.5, 0.40, 0.26, GOLD, tilt=0.05)
    for i, x in enumerate((0.28, 0.5, 0.72)):
        cracked = i == 2
        circle(d, x, 0.82, 0.078,
               fill=dark(DANGER, 0.35) if cracked else dark(GOLD, 0.5),
               outline=GOLD if not cracked else DANGER, width=2)
        if cracked:
            line(d, [(x - 0.05, 0.76), (x + 0.01, 0.82), (x - 0.02, 0.88)],
                 light(GOLD, 0.5), 2)


@art("hand_of_the_verdict")
def _(d, t):
    # An open hand delivering the sentence, wreathed in the Rise glow.
    rays(d, 0.5, 0.50, 0.28, 0.44, dark(GOLD, 0.42), count=12, width=2)
    poly(d, [(0.34, 0.86), (0.32, 0.52), (0.68, 0.52), (0.66, 0.86)],
         fill=mix(GOLD, PANEL, 0.35), outline=GOLD, width=2)
    for i in range(4):
        x = 0.355 + i * 0.095
        rect(d, x, 0.28, x + 0.062, 0.56, fill=mix(GOLD, PANEL, 0.35),
             outline=GOLD, width=1.6, radius=0.03)
    poly(d, [(0.32, 0.52), (0.20, 0.42), (0.14, 0.52), (0.30, 0.68)],
         fill=mix(GOLD, PANEL, 0.35), outline=GOLD, width=1.6)
    circle(d, 0.5, 0.66, 0.062, fill=light(GOLD, 0.5))


@art("court_of_bells")
def _(d, t):
    # A rack of bells -- the reset engine, and no scales because it holds
    # no Judgment of its own. Centered rather than hung from the top edge,
    # which cropped the rack at board size.
    rect(d, 0.10, 0.22, 0.90, 0.30, fill=dark(GOLD, 0.42), radius=0.02)
    for x in (0.14, 0.86):
        rect(d, x - 0.035, 0.22, x + 0.035, 0.88, fill=dark(GOLD, 0.55),
             radius=0.02)
    for cx, r in ((0.32, 0.135), (0.5, 0.185), (0.68, 0.135)):
        line(d, [(cx, 0.30), (cx, 0.36)], dark(GOLD, 0.35), 2)
        bell(d, cx, 0.38 + r * 0.80, r, GOLD)
    rect(d, 0.10, 0.86, 0.90, 0.92, fill=dark(GOLD, 0.42), radius=0.02)


@art("radiant_bastion")
def _(d, t):
    # A fortress of light -- Sanctuary 60 on the biggest single hit.
    poly(d, [(0.5, 0.08), (0.84, 0.30), (0.84, 0.70), (0.5, 0.92),
             (0.16, 0.70), (0.16, 0.30)],
         fill=dark(GOLD, 0.60), outline=GOLD, width=3)
    poly(d, [(0.5, 0.20), (0.74, 0.36), (0.74, 0.66), (0.5, 0.80),
             (0.26, 0.66), (0.26, 0.36)],
         fill=dark(GOLD, 0.78))
    # A keep with crenellations, not a capsule -- the old centered rect read
    # as a pill at 74px and said nothing about a fortress.
    for i in range(3):
        x = 0.365 + i * 0.09
        rect(d, x, 0.30, x + 0.055, 0.38, fill=GOLD)
    rect(d, 0.35, 0.36, 0.65, 0.78, fill=mix(GOLD, PANEL, 0.20))
    poly(d, [(0.42, 0.78), (0.42, 0.56), (0.5, 0.48), (0.58, 0.56), (0.58, 0.78)],
         fill=light(GOLD, 0.55))
    rays(d, 0.5, 0.50, 0.30, 0.42, light(GOLD, 0.12), count=8, width=2.5)


@art("seraph_of_the_final_ledger")
def _(d, t):
    # Many wings around an open ledger -- it pushes a board into range.
    wings(d, 0.5, 0.30, 0.42, 0.30, mix(GOLD, PANEL, 0.48))
    wings(d, 0.5, 0.52, 0.34, 0.24, mix(GOLD, PANEL, 0.32))
    poly(d, [(0.5, 0.52), (0.24, 0.62), (0.24, 0.84), (0.5, 0.76)],
         fill=BONE, outline=dark(GOLD, 0.3), width=1.8)
    poly(d, [(0.5, 0.52), (0.76, 0.62), (0.76, 0.84), (0.5, 0.76)],
         fill=light(BONE, 0.12), outline=dark(GOLD, 0.3), width=1.8)
    for i in range(3):
        y = 0.66 + i * 0.055
        line(d, [(0.30, y), (0.45, y - 0.035)], dark(GOLD, 0.45), 1.6)
        line(d, [(0.55, y - 0.035), (0.70, y)], dark(GOLD, 0.45), 1.6)
    circle(d, 0.5, 0.30, 0.085, fill=light(GOLD, 0.55))
    halo(d, 0.5, 0.15, 0.115, GOLD, 2.5)


@art("empyrean_sentinel")
def _(d, t):
    # A sentinel behind a shield that relights itself every turn.
    poly(d, [(0.5, 0.10), (0.80, 0.24), (0.78, 0.62), (0.5, 0.88),
             (0.22, 0.62), (0.20, 0.24)],
         fill=dark(GOLD, 0.55), outline=GOLD, width=3)
    circle(d, 0.5, 0.44, 0.135, fill=light(GOLD, 0.45))
    rays(d, 0.5, 0.44, 0.16, 0.30, GOLD, count=16, width=2)
    # the rekindle loop, drawn as a ring of returning motion
    for a in (30, 150, 270):
        r0, r1 = math.radians(a), math.radians(a + 70)
        arrow(d, 0.5 + math.cos(r0) * 0.345, 0.44 + math.sin(r0) * 0.345,
              0.5 + math.cos(r1) * 0.345, 0.44 + math.sin(r1) * 0.345,
              light(GOLD, 0.3), 0.016, 0.042)


@art("throne_of_the_risen_court")
def _(d, t):
    # An empty throne with wings -- it holds a lane forever and does not win.
    wings(d, 0.5, 0.34, 0.40, 0.26, mix(GOLD, PANEL, 0.55))
    rect(d, 0.34, 0.20, 0.66, 0.66, fill=dark(GOLD, 0.55), outline=GOLD,
         width=2.5, radius=0.04)
    for i in range(3):
        x = 0.37 + i * 0.105
        poly(d, [(x, 0.20), (x + 0.075, 0.20), (x + 0.037, 0.11)],
             fill=GOLD)
    rect(d, 0.30, 0.62, 0.70, 0.72, fill=GOLD, radius=0.02)
    rect(d, 0.34, 0.72, 0.42, 0.90, fill=dark(GOLD, 0.45))
    rect(d, 0.58, 0.72, 0.66, 0.90, fill=dark(GOLD, 0.45))
    circle(d, 0.5, 0.40, 0.075, fill=light(GOLD, 0.4))


@art("verdict_of_the_throne")
def _(d, t):
    # The gate cracked open above a throne -- kills convert to throne damage.
    rect(d, 0.30, 0.44, 0.70, 0.72, fill=dark(GOLD, 0.55), outline=GOLD,
         width=2.5, radius=0.03)
    rect(d, 0.26, 0.70, 0.74, 0.79, fill=GOLD, radius=0.02)
    rect(d, 0.31, 0.79, 0.39, 0.92, fill=dark(GOLD, 0.45))
    rect(d, 0.61, 0.79, 0.69, 0.92, fill=dark(GOLD, 0.45))
    # gate leaves, parted
    for s in (-1, 1):
        poly(d, [(0.5 + s * 0.06, 0.06), (0.5 + s * 0.32, 0.14),
                 (0.5 + s * 0.32, 0.42), (0.5 + s * 0.06, 0.38)],
             fill=dark(GOLD, 0.42), outline=GOLD, width=2)
    poly(d, [(0.47, 0.06), (0.53, 0.06), (0.56, 0.44), (0.44, 0.44)],
         fill=light(GOLD, 0.62))
    rays(d, 0.5, 0.24, 0.10, 0.24, light(GOLD, 0.2), count=6, width=2)


@art("aegis_of_the_choir")
def _(d, t):
    # A shield made of voices -- the Sanctuary Tool.
    poly(d, [(0.5, 0.12), (0.78, 0.26), (0.76, 0.62), (0.5, 0.88),
             (0.24, 0.62), (0.22, 0.26)],
         fill=dark(GOLD, 0.58), outline=GOLD, width=3)
    for i, r in enumerate((0.075, 0.135, 0.195)):
        arc(d, 0.5 - r, 0.48 - r, 0.5 + r, 0.48 + r, 200, 340,
            mix(GOLD, PANEL, i * 0.20), 2.5)
    circle(d, 0.5, 0.50, 0.048, fill=light(GOLD, 0.5))
    for x in (0.34, 0.5, 0.66):
        circle(d, x, 0.30, 0.030, fill=mix(GOLD, PANEL, 0.30))


# ---- Void ---------------------------------------------------------------
# Slate-blue, and built out of what is missing rather than what is there.
# Most emblems here punch a near-black hole in the backdrop; the bright edge
# is whatever the hole is currently eating.

@art("void_energy")
def _(d, t):
    hexagon(d, 0.5, 0.5, 0.30, fill=dark(t, 0.55), outline=light(t, 0.25), width=3)
    void_eye(d, 0.5, 0.5, 0.155, t, ring=1.30)
    for a in range(0, 360, 60):
        r = math.radians(a)
        arrow(d, 0.5 + math.cos(r) * 0.375, 0.5 + math.sin(r) * 0.375,
              0.5 + math.cos(r) * 0.255, 0.5 + math.sin(r) * 0.255,
              light(t, 0.2), 0.016, 0.038)


@art("hollow_acolyte")
def _(d, t):
    # A hooded figure with nothing inside the hood -- the cheapest theft.
    poly(d, [(0.5, 0.14), (0.72, 0.44), (0.74, 0.86), (0.26, 0.86),
             (0.28, 0.44)],
         fill=mix(t, PANEL, 0.45), outline=dark(t, 0.15), width=2)
    void_eye(d, 0.5, 0.40, 0.115, t, ring=1.22)
    arrow(d, 0.80, 0.62, 0.62, 0.46, light(t, 0.35), 0.020, 0.048)


@art("rust_crawler")
def _(d, t):
    # Plain vermin, corroding what it walks on. No text, so no void hole.
    for i, x in enumerate((0.30, 0.43, 0.56, 0.69)):
        r = 0.100 - i * 0.007
        circle(d, x, 0.54 + math.sin(i * 1.3) * 0.02, r,
               fill=mix(RUST, PANEL, 0.30 + i * 0.09))
    circle(d, 0.75, 0.50, 0.080, fill=mix(RUST, t, 0.45))
    circle(d, 0.785, 0.478, 0.020, fill=(6, 5, 9))
    for x in (0.34, 0.47, 0.60):
        line(d, [(x, 0.62), (x - 0.05, 0.80)], dark(RUST, 0.35), 2.5)
        line(d, [(x, 0.46), (x - 0.05, 0.30)], dark(RUST, 0.35), 2.5)
    for x in (0.22, 0.36, 0.50):
        circle(d, x, 0.86, 0.022, fill=dark(RUST, 0.25))


@art("ashen_pilgrim")
def _(d, t):
    # A begging bowl held up, with the figure behind it. The bowl is the
    # card -- a free Siphon every turn -- so it gets the readable silhouette
    # instead of competing with a staff at the edge of the frame.
    poly(d, [(0.36, 0.86), (0.34, 0.30), (0.66, 0.30), (0.64, 0.86)],
         fill=mix(t, PANEL, 0.50))
    poly(d, [(0.32, 0.34), (0.5, 0.10), (0.68, 0.34)], fill=mix(t, PANEL, 0.32))
    circle(d, 0.5, 0.30, 0.062, fill=(4, 4, 7))
    line(d, [(0.80, 0.10), (0.78, 0.90)], mix(RUST, PANEL, 0.45), 3)
    # The bowl: a shallow crescent, not a tapered pot -- the straight-sided
    # version read as a flowerpot with the energy hexagons above it as blooms.
    arc(d, 0.20, 0.52, 0.72, 0.92, 0, 180, light(t, 0.35), 4)
    poly(d, [(0.21, 0.70), (0.71, 0.70), (0.64, 0.86), (0.28, 0.86)],
         fill=mix(t, PANEL, 0.18))
    line(d, [(0.19, 0.70), (0.73, 0.70)], light(t, 0.40), 3)
    # what falls in: energy, sideways, so it reads as taking rather than growing
    for i, (x, y) in enumerate(((0.32, 0.56), (0.46, 0.50), (0.60, 0.58))):
        hexagon(d, x, y, 0.046, fill=dark(GOLD, 0.30))
        arrow(d, x, y + 0.06, x + (0.46 - x) * 0.3, 0.67, dark(GOLD, 0.12),
              0.012, 0.026)


@art("gnawing_absence")
def _(d, t):
    # A bite taken out of a charged hexagon -- damage scaled by what it ate.
    hexagon(d, 0.42, 0.52, 0.27, fill=dark(GOLD, 0.42), outline=GOLD, width=2.5)
    circle(d, 0.42, 0.52, 0.105, fill=light(GOLD, 0.35))
    void_eye(d, 0.70, 0.40, 0.185, t, ring=1.28)
    for i in range(7):
        a = math.radians(-180 + i * 40)
        line(d, [(0.70 + math.cos(a) * 0.185, 0.40 + math.sin(a) * 0.185),
                 (0.70 + math.cos(a) * 0.245, 0.40 + math.sin(a) * 0.245)],
             light(t, 0.4), 2.5)


@art("null_adept")
def _(d, t):
    # A robed adept holding a widening tear -- Rift 1 on a Basic.
    poly(d, [(0.34, 0.88), (0.32, 0.46), (0.60, 0.46), (0.62, 0.88)],
         fill=mix(t, PANEL, 0.45))
    circle(d, 0.46, 0.38, 0.100, fill=mix(t, PANEL, 0.28))
    circle(d, 0.46, 0.38, 0.042, fill=(4, 4, 7))
    poly(d, [(0.78, 0.16), (0.86, 0.44), (0.76, 0.72), (0.72, 0.44)],
         fill=(4, 4, 7), outline=light(t, 0.40), width=2)
    line(d, [(0.60, 0.54), (0.74, 0.46)], mix(t, PANEL, 0.42), 3)


@art("sundered_wretch")
def _(d, t):
    # A big body split down the middle and still standing -- Void's wall.
    for s in (-1, 1):
        poly(d, [(0.5 + s * 0.05, 0.18), (0.5 + s * 0.30, 0.30),
                 (0.5 + s * 0.32, 0.86), (0.5 + s * 0.05, 0.86)],
             fill=mix(t, PANEL, 0.34), outline=dark(t, 0.10), width=2)
        circle(d, 0.5 + s * 0.155, 0.36, 0.055, fill=(4, 4, 7))
    line(d, [(0.5, 0.14), (0.5, 0.90)], (4, 4, 7), 4)
    for y in (0.34, 0.52, 0.70):
        line(d, [(0.44, y - 0.03), (0.56, y + 0.03)], dark(t, 0.05), 2)


@art("severance_priest")
def _(d, t):
    # A priest cutting a tether -- the workhorse Siphon body.
    poly(d, [(0.30, 0.90), (0.28, 0.42), (0.58, 0.42), (0.60, 0.90)],
         fill=mix(t, PANEL, 0.40), outline=dark(t, 0.12), width=2)
    circle(d, 0.44, 0.32, 0.110, fill=mix(t, PANEL, 0.24))
    poly(d, [(0.30, 0.34), (0.44, 0.12), (0.58, 0.34)], fill=dark(t, 0.28))
    circle(d, 0.415, 0.33, 0.028, fill=light(t, 0.45))
    circle(d, 0.475, 0.33, 0.028, fill=light(t, 0.45))
    # the severed line, with the take flowing back
    line(d, [(0.62, 0.56), (0.92, 0.44)], dark(GOLD, 0.30), 3)
    line(d, [(0.74, 0.36), (0.80, 0.66)], light(t, 0.45), 3)
    circle(d, 0.90, 0.44, 0.034, fill=dark(GOLD, 0.25))
    arrow(d, 0.70, 0.60, 0.56, 0.64, light(t, 0.35), 0.018, 0.042)


@art("entropy_warden")
def _(d, t):
    # A warden guarding a tear that is already too wide to close.
    poly(d, [(0.66, 0.06), (0.80, 0.48), (0.64, 0.94), (0.54, 0.48)],
         fill=(4, 4, 7), outline=light(t, 0.40), width=2.5)
    for s in (-1, 1):
        line(d, [(0.67 + s * 0.02, 0.30), (0.67 + s * 0.14, 0.22)],
             light(t, 0.25), 2)
    poly(d, [(0.16, 0.88), (0.18, 0.44), (0.44, 0.44), (0.42, 0.88)],
         fill=mix(t, PANEL, 0.42))
    circle(d, 0.30, 0.34, 0.105, fill=mix(t, PANEL, 0.26))
    rect(d, 0.22, 0.30, 0.38, 0.36, fill=(6, 5, 9))
    line(d, [(0.44, 0.52), (0.56, 0.50)], mix(t, PANEL, 0.42), 3)


@art("the_unwritten")
def _(d, t):
    # A page with its text erased off the bottom edge.
    poly(d, [(0.24, 0.10), (0.72, 0.10), (0.72, 0.84), (0.24, 0.84)],
         fill=mix(BONE, PANEL, 0.30), outline=dark(t, 0.10), width=2)
    for i in range(5):
        y = 0.22 + i * 0.10
        w = 0.44 - i * 0.09
        if w <= 0.04:
            break
        line(d, [(0.30, y), (0.30 + w, y)], mix(t, PANEL, 0.20 + i * 0.16), 3)
    void_eye(d, 0.68, 0.68, 0.185, t, ring=1.26)
    for a in (200, 240, 280):
        r = math.radians(a)
        line(d, [(0.68 + math.cos(r) * 0.20, 0.68 + math.sin(r) * 0.20),
                 (0.68 + math.cos(r) * 0.30, 0.68 + math.sin(r) * 0.30)],
             light(t, 0.30), 2)


@art("famine_of_forms")
def _(d, t):
    # A ribcage with nothing in it, drawing two tethers inward. Siphon 2.
    poly(d, [(0.5, 0.20), (0.70, 0.36), (0.66, 0.74), (0.5, 0.86),
             (0.34, 0.74), (0.30, 0.36)],
         fill=mix(t, PANEL, 0.55), outline=dark(t, 0.12), width=2)
    for i in range(4):
        y = 0.34 + i * 0.115
        arc(d, 0.30, y - 0.06, 0.70, y + 0.10, 200, 340, mix(BONE, t, 0.5), 2.5)
    void_eye(d, 0.5, 0.54, 0.095, t, ring=1.30)
    for s in (-1, 1):
        arrow(d, 0.5 + s * 0.42, 0.24, 0.5 + s * 0.16, 0.46,
              dark(GOLD, 0.20), 0.018, 0.044)


@art("hungering_maw")
def _(d, t):
    # A mouth and nothing else -- the honest beater, no rider.
    circle(d, 0.5, 0.52, 0.34, fill=mix(t, PANEL, 0.42))
    void_eye(d, 0.5, 0.52, 0.235, t, ring=1.20)
    n = 10
    for i in range(n):
        a = math.radians(i * 360.0 / n)
        cx = 0.5 + math.cos(a) * 0.235
        cy = 0.52 + math.sin(a) * 0.235
        poly(d, [(cx, cy), (cx - math.sin(a) * 0.05, cy + math.cos(a) * 0.05),
                 (0.5 + math.cos(a) * 0.115, 0.52 + math.sin(a) * 0.115)],
             fill=mix(BONE, t, 0.35))


@art("the_absence")
def _(d, t):
    # The only card holding both signatures, so it is a *figure* -- a robed
    # shape whose whole torso is the hole. Widening Rift is the bare tear;
    # this must not read as the same emblem at board size.
    poly(d, [(0.5, 0.06), (0.78, 0.34), (0.82, 0.94), (0.18, 0.94),
             (0.22, 0.34)],
         fill=mix(t, PANEL, 0.40), outline=dark(t, 0.08), width=2.5)
    poly(d, [(0.30, 0.32), (0.5, 0.06), (0.70, 0.32)], fill=mix(t, PANEL, 0.22))
    void_eye(d, 0.5, 0.56, 0.235, t, ring=1.26)
    # Siphon feeding its own Rift: energy in from both sides, tear widening out
    for s in (-1, 1):
        arrow(d, 0.5 + s * 0.46, 0.30, 0.5 + s * 0.22, 0.50,
              dark(GOLD, 0.15), 0.018, 0.042)
        line(d, [(0.5 + s * 0.16, 0.80), (0.5 + s * 0.34, 0.94)],
             light(t, 0.30), 2.5)
    circle(d, 0.5, 0.26, 0.052, fill=(4, 4, 7))


@art("throat_of_the_void")
def _(d, t):
    # A tunnel receding -- the single Rift 2, drawn as depth.
    for i in range(7):
        f = 1.0 - i * 0.125
        poly(d, [(0.5 - 0.42 * f, 0.50 - 0.44 * f),
                 (0.5 + 0.42 * f, 0.50 - 0.44 * f),
                 (0.5 + 0.26 * f, 0.50 + 0.44 * f),
                 (0.5 - 0.26 * f, 0.50 + 0.44 * f)],
             fill=mix(light(t, 0.30), (4, 4, 7), min(1.0, i / 5.0)))
    for s in (-1, 1):
        line(d, [(0.5 + s * 0.42, 0.06), (0.5 + s * 0.09, 0.94)],
             light(t, 0.20), 2)


@art("unmaker_of_thrones")
def _(d, t):
    # A throne coming apart -- the only card that reaches the pool.
    rect(d, 0.32, 0.30, 0.68, 0.68, fill=mix(t, PANEL, 0.40),
         outline=dark(t, 0.10), width=2.5, radius=0.03)
    rect(d, 0.28, 0.66, 0.72, 0.75, fill=mix(t, PANEL, 0.28), radius=0.02)
    rect(d, 0.33, 0.75, 0.41, 0.90, fill=mix(t, PANEL, 0.48))
    rect(d, 0.59, 0.75, 0.67, 0.90, fill=mix(t, PANEL, 0.48))
    for i in range(3):
        x = 0.36 + i * 0.115
        poly(d, [(x, 0.30), (x + 0.075, 0.30), (x + 0.037, 0.20)],
             fill=mix(t, PANEL, 0.25))
    void_eye(d, 0.5, 0.44, 0.125, t, ring=1.28)
    for a in (20, 90, 160, 250, 320):
        r = math.radians(a)
        poly(d, [(0.5 + math.cos(r) * 0.30, 0.44 + math.sin(r) * 0.30),
                 (0.5 + math.cos(r) * 0.42, 0.44 + math.sin(r) * 0.40),
                 (0.5 + math.cos(r + 0.35) * 0.34, 0.44 + math.sin(r + 0.35) * 0.34)],
             fill=mix(t, PANEL, 0.20))


@art("silence_eternal")
def _(d, t):
    # A throne being swallowed -- the win condition. The throne sits *against*
    # the hole rather than inside it: drawn inside, a dark shape on a darker
    # hole was invisible at board size, which is the one place it has to read.
    void_eye(d, 0.5, 0.40, 0.325, t, ring=1.20)
    for a in range(0, 360, 24):
        r = math.radians(a)
        line(d, [(0.5 + math.cos(r) * 0.345, 0.40 + math.sin(r) * 0.345),
                 (0.5 + math.cos(r) * 0.415, 0.40 + math.sin(r) * 0.415)],
             mix(t, PANEL, 0.30), 2)
    # The throne, sinking in. Kept in Void's own slate rather than bone --
    # bone is Hel's motif and a white throne here read as the wrong faction.
    thr = light(t, 0.42)
    rect(d, 0.38, 0.52, 0.62, 0.80, fill=thr,
         outline=light(t, 0.62), width=2, radius=0.02)
    rect(d, 0.33, 0.78, 0.67, 0.86, fill=light(t, 0.30), radius=0.02)
    rect(d, 0.36, 0.86, 0.43, 0.95, fill=light(t, 0.20))
    rect(d, 0.57, 0.86, 0.64, 0.95, fill=light(t, 0.20))
    for i in range(3):
        x = 0.405 + i * 0.065
        poly(d, [(x, 0.52), (x + 0.042, 0.52), (x + 0.021, 0.44)], fill=thr)
    # dissolving at the top edge, where it meets the hole
    for i, x in enumerate((0.40, 0.50, 0.60)):
        circle(d, x, 0.46 - (i % 2) * 0.04, 0.020, fill=light(t, 0.55))


# ---- Void supports and tool ---------------------------------------------

@art("draw_down")
def _(d, t):
    # Energy pulled off a body along a tether. The free floor.
    hexagon(d, 0.74, 0.30, 0.135, fill=dark(GOLD, 0.42), outline=GOLD, width=2)
    circle(d, 0.74, 0.30, 0.050, fill=light(GOLD, 0.30))
    void_eye(d, 0.28, 0.68, 0.175, t, ring=1.26)
    arrow(d, 0.64, 0.40, 0.40, 0.58, light(t, 0.35), 0.024, 0.055)


@art("exsanguinate")
def _(d, t):
    # The priced variant -- three tethers instead of one.
    void_eye(d, 0.26, 0.62, 0.185, t, ring=1.28)
    for i, (x, y) in enumerate(((0.72, 0.16), (0.84, 0.40), (0.70, 0.62))):
        hexagon(d, x, y, 0.095, fill=dark(GOLD, 0.42), outline=GOLD, width=2)
        arrow(d, x - 0.10, y + 0.03, 0.40, 0.58, light(t, 0.35), 0.018, 0.042)


@art("unwrite")
def _(d, t):
    # All attached energy destroyed -- hexagons shattering, nothing taken back.
    for i, (x, y) in enumerate(((0.30, 0.28), (0.58, 0.22), (0.36, 0.58))):
        hexagon(d, x, y, 0.115, fill=dark(GOLD, 0.55), outline=dark(GOLD, 0.25),
                width=2)
        line(d, [(x - 0.10, y - 0.08), (x + 0.10, y + 0.09)], (4, 4, 7), 3)
        line(d, [(x - 0.06, y + 0.10), (x + 0.09, y - 0.10)], (4, 4, 7), 3)
    for i in range(9):
        a = math.radians(i * 40 + 12)
        r0 = 0.10 + (i % 3) * 0.05
        line(d, [(0.70, 0.72), (0.70 + math.cos(a) * (0.16 + r0),
                                0.72 + math.sin(a) * (0.16 + r0))],
             mix(t, PANEL, 0.25), 2)
    void_eye(d, 0.70, 0.72, 0.115, t, ring=1.22)


@art("widening_rift")
def _(d, t):
    # The tear itself, capped -- reach on a card.
    poly(d, [(0.5, 0.02), (0.64, 0.28), (0.58, 0.52), (0.70, 0.76),
             (0.5, 0.98), (0.34, 0.74), (0.44, 0.50), (0.36, 0.26)],
         fill=(4, 4, 7), outline=light(t, 0.40), width=3)
    for s in (-1, 1):
        for y in (0.22, 0.46, 0.70):
            line(d, [(0.5 + s * 0.16, y), (0.5 + s * 0.36, y - 0.04)],
                 mix(t, PANEL, 0.18), 2)
    circle(d, 0.5, 0.50, 0.055, fill=light(t, 0.45))


@art("event_horizon")
def _(d, t):
    # A ring of stolen light bending around a hole -- the Rift Tool.
    for i in range(4):
        r = 0.44 - i * 0.055
        arc(d, 0.5 - r, 0.5 - r * 0.42, 0.5 + r, 0.5 + r * 0.42, 0, 360,
            mix(light(t, 0.35), PANEL, i * 0.22), 2.5)
    void_eye(d, 0.5, 0.5, 0.185, t, ring=1.22)
    for a in (10, 100, 190, 280):
        r = math.radians(a)
        circle(d, 0.5 + math.cos(r) * 0.42, 0.5 + math.sin(r) * 0.175, 0.028,
               fill=dark(GOLD, 0.20))


# ---- Gaia ---------------------------------------------------------------
#
# Gaia's grammar is STONE AND GROWTH ON THE HORIZON LINE. Where Heaven floats
# above the horizon and Void punches a hole through it, Gaia is rooted *into*
# it -- every emblem touches the ground, and most grow upward out of it.
#
# Two recurring shapes carry the faction:
#   * the standing stone -- a blunt vertical slab, the Earth aura made visible
#   * the root/branch fork -- growth, drawn as a Y that widens as it rises
#
# The 74px board read is the binding constraint, so each emblem commits to ONE
# silhouette and lets the tint do the faction work.


def standing_stone(d, cx, base, w, h, body, trim=None):
    """A blunt megalith, wider at the base. Gaia's answer to tower_shape."""
    poly(d, [(cx - w, base), (cx - w * 0.78, base - h),
             (cx + w * 0.78, base - h), (cx + w, base)], fill=body)
    if trim is not None:
        poly(d, [(cx - w * 0.30, base), (cx - w * 0.24, base - h * 0.94),
                 (cx + w * 0.10, base - h * 0.94), (cx + w * 0.04, base)],
             fill=trim)


def roots(d, cx, y0, y1, spread, col, w=0.030):
    """A root system forking downward -- growth's underside."""
    line(d, [(cx, y0), (cx, y1)], col, width=w)
    for s in (-1, 1):
        line(d, [(cx, y0 + (y1 - y0) * 0.35),
                 (cx + s * spread * 0.60, y1)], col, width=w * 0.8)
        line(d, [(cx, y0 + (y1 - y0) * 0.62),
                 (cx + s * spread, y1 - (y1 - y0) * 0.10)], col, width=w * 0.65)


def leafy_crown(d, cx, cy, r, col, edge=None):
    """Three overlapping lobes -- a canopy that reads at 74px."""
    circle(d, cx, cy + r * 0.16, r * 0.78, fill=col, outline=edge, width=2)
    circle(d, cx - r * 0.62, cy + r * 0.42, r * 0.58, fill=col, outline=edge, width=2)
    circle(d, cx + r * 0.62, cy + r * 0.42, r * 0.58, fill=col, outline=edge, width=2)


GREEN_DEEP = (46, 112, 62)
STONE = (128, 126, 118)
STONE_DARK = (86, 85, 80)
SOIL = (78, 60, 44)


@art("gaia_energy")
def _(d, t):
    hexagon(d, 0.5, 0.5, 0.30, fill=dark(HP_GREEN, 0.58), outline=HP_GREEN, width=3)
    hexagon(d, 0.5, 0.5, 0.19, fill=HP_GREEN)
    # A seed splitting -- the smallest possible statement of "growth".
    droplet(d, 0.5, 0.50, 0.085, dark(SOIL, 0.15))
    line(d, [(0.5, 0.47), (0.5, 0.36)], dark(GREEN_DEEP, 0.1), width=0.028)
    for a in range(0, 360, 60):
        r = math.radians(a)
        circle(d, 0.5 + math.cos(r) * 0.385, 0.5 + math.sin(r) * 0.385, 0.022,
               fill=light(HP_GREEN, 0.25))


# -- chain 1: the stone that shoots ---------------------------------------

@art("gaia_makeshift_tower")
def _(d, t):
    # A cairn: stacked rubble pretending to be a tower. Deliberately lopsided.
    rect(d, 0.30, 0.74, 0.70, 0.82, fill=STONE_DARK, radius=0.02)
    rect(d, 0.34, 0.60, 0.66, 0.74, fill=STONE, radius=0.02)
    rect(d, 0.38, 0.47, 0.62, 0.60, fill=STONE_DARK, radius=0.02)
    rect(d, 0.42, 0.36, 0.58, 0.47, fill=STONE, radius=0.02)
    circle(d, 0.50, 0.30, 0.052, fill=light(HP_GREEN, 0.1))


@art("gaia_bulwark_of_stone")
def _(d, t):
    # One slab now, not a stack -- it has become a single thing.
    standing_stone(d, 0.50, 0.84, 0.20, 0.50, STONE, STONE_DARK)
    # Moss on the windward side: the green is what makes it Gaia's.
    poly(d, [(0.31, 0.84), (0.33, 0.52), (0.40, 0.54), (0.38, 0.84)],
         fill=GREEN_DEEP)
    circle(d, 0.50, 0.28, 0.055, fill=light(HP_GREEN, 0.15))


@art("gaia_the_standing_stone")
def _(d, t):
    # The megalith, filling the frame, with two lesser stones flanking.
    standing_stone(d, 0.24, 0.86, 0.10, 0.26, STONE_DARK)
    standing_stone(d, 0.76, 0.86, 0.10, 0.26, STONE_DARK)
    standing_stone(d, 0.50, 0.88, 0.22, 0.64, STONE, STONE_DARK)
    poly(d, [(0.29, 0.88), (0.31, 0.40), (0.40, 0.43), (0.37, 0.88)],
         fill=GREEN_DEEP)
    circle(d, 0.50, 0.19, 0.062, fill=light(HP_GREEN, 0.2))
    rays(d, 0.50, 0.19, 0.075, 0.115, light(HP_GREEN, 0.05), count=8, width=2.0)


# -- chain 2: energy into earth -------------------------------------------

@art("gaia_living_conduit")
def _(d, t):
    # A hollow trunk with energy visibly running up it.
    poly(d, [(0.40, 0.86), (0.43, 0.34), (0.57, 0.34), (0.60, 0.86)],
         fill=dark(SOIL, 0.1))
    roots(d, 0.50, 0.80, 0.90, 0.17, dark(SOIL, 0.3))
    # The charge inside -- three rising motes, the card's whole mechanic.
    for i, y in enumerate((0.72, 0.58, 0.44)):
        circle(d, 0.50, y, 0.036 + i * 0.006, fill=light(HP_GREEN, 0.25))
    leafy_crown(d, 0.50, 0.26, 0.15, GREEN_DEEP)


@art("gaia_deep_roots")
def _(d, t):
    # Root-dominant: the mass is below the line, which is the card's point.
    leafy_crown(d, 0.50, 0.26, 0.14, GREEN_DEEP)
    line(d, [(0.50, 0.34), (0.50, 0.56)], dark(SOIL, 0.1), width=0.055)
    roots(d, 0.50, 0.52, 0.92, 0.30, dark(SOIL, 0.05), w=0.040)
    # A second, wider fork so the system reads as *deep* at a glance.
    for s in (-1, 1):
        line(d, [(0.50, 0.62), (0.50 + s * 0.34, 0.86)], SOIL, width=0.026)


@art("gaia_heartwood_ancient")
def _(d, t):
    # A vast trunk with a glowing core -- the heartwood itself.
    poly(d, [(0.32, 0.90), (0.38, 0.30), (0.62, 0.30), (0.68, 0.90)],
         fill=dark(SOIL, 0.05))
    roots(d, 0.50, 0.84, 0.95, 0.28, dark(SOIL, 0.3), w=0.034)
    # Growth rings, then the lit core.
    for r in (0.115, 0.082):
        circle(d, 0.50, 0.58, r, outline=dark(GREEN_DEEP, 0.2), width=2.5)
    circle(d, 0.50, 0.58, 0.050, fill=light(HP_GREEN, 0.3))
    leafy_crown(d, 0.50, 0.20, 0.19, GREEN_DEEP)


# -- chain 3: the grove ----------------------------------------------------

@art("gaia_sapling_warden")
def _(d, t):
    # Small and upright: one stem, two leaves, a lot of empty frame.
    line(d, [(0.50, 0.84), (0.50, 0.48)], dark(SOIL, 0.1), width=0.034)
    roots(d, 0.50, 0.80, 0.90, 0.11, dark(SOIL, 0.35), w=0.022)
    for s in (-1, 1):
        poly(d, [(0.50, 0.60), (0.50 + s * 0.20, 0.50), (0.50 + s * 0.07, 0.44)],
             fill=GREEN_DEEP)
    circle(d, 0.50, 0.40, 0.045, fill=light(HP_GREEN, 0.2))


@art("gaia_grovekeeper")
def _(d, t):
    # A hooded figure made of branches -- the silhouette is a robe plus a canopy.
    poly(d, [(0.32, 0.88), (0.40, 0.46), (0.60, 0.46), (0.68, 0.88)],
         fill=GREEN_DEEP)
    leafy_crown(d, 0.50, 0.30, 0.155, dark(GREEN_DEEP, 0.18))
    # The staff: the one straight line in a card full of organic shapes.
    line(d, [(0.74, 0.90), (0.74, 0.30)], dark(SOIL, 0.05), width=0.028)
    circle(d, 0.74, 0.26, 0.048, fill=light(HP_GREEN, 0.25))


@art("gaia_elder_of_the_grove")
def _(d, t):
    # The same figure, grown into the canopy it tends.
    poly(d, [(0.26, 0.92), (0.38, 0.44), (0.62, 0.44), (0.74, 0.92)],
         fill=GREEN_DEEP)
    leafy_crown(d, 0.50, 0.26, 0.215, dark(GREEN_DEEP, 0.22))
    circle(d, 0.50, 0.30, 0.058, fill=light(HP_GREEN, 0.28))
    rays(d, 0.50, 0.30, 0.072, 0.108, light(HP_GREEN, 0.0), count=10, width=2.0)
    roots(d, 0.50, 0.86, 0.96, 0.24, dark(SOIL, 0.25), w=0.026)


# -- chain 4: stoneskin ----------------------------------------------------

@art("gaia_mossback_tortoise")
def _(d, t):
    # A shell dome with moss on top. Low, wide, immovable.
    arc(d, 0.18, 0.36, 0.82, 1.00, 180, 360, fill=STONE)
    ellipse(d, 0.18, 0.62, 0.82, 0.78, fill=dark(STONE, 0.35))
    # Moss patches read as the green that makes it Gaia rather than neutral.
    circle(d, 0.38, 0.50, 0.070, fill=GREEN_DEEP)
    circle(d, 0.58, 0.46, 0.055, fill=GREEN_DEEP)
    circle(d, 0.68, 0.56, 0.042, fill=dark(GREEN_DEEP, 0.15))
    # Head, small, to the right -- keeps the shell the silhouette.
    circle(d, 0.84, 0.68, 0.055, fill=dark(STONE, 0.2))


@art("gaia_granite_colossus")
def _(d, t):
    # A hulking figure: the read is ARMS, not a torso. Long slab limbs hanging
    # past a squat body is what separates a colossus from a piece of furniture,
    # which is exactly how the first attempt failed at 74px.
    rect(d, 0.14, 0.34, 0.30, 0.80, fill=STONE_DARK, radius=0.04)
    rect(d, 0.70, 0.34, 0.86, 0.80, fill=STONE_DARK, radius=0.04)
    rect(d, 0.32, 0.38, 0.68, 0.86, fill=STONE, radius=0.04)
    # Head sunk between the shoulders -- no neck.
    rect(d, 0.40, 0.16, 0.60, 0.38, fill=STONE, radius=0.03)
    circle(d, 0.455, 0.26, 0.024, fill=light(HP_GREEN, 0.25))
    circle(d, 0.545, 0.26, 0.024, fill=light(HP_GREEN, 0.25))
    # Cracks across the chest: the Retribution promise, drawn.
    line(d, [(0.40, 0.50), (0.52, 0.62), (0.44, 0.78)], dark(STONE_DARK, 0.35), width=0.020)
    # Moss on the shoulders keeps it Gaia rather than a neutral golem.
    circle(d, 0.36, 0.41, 0.045, fill=GREEN_DEEP)
    circle(d, 0.64, 0.41, 0.038, fill=GREEN_DEEP)


# -- chain 5: the bloom ----------------------------------------------------

@art("gaia_seedbearer")
def _(d, t):
    # A pod holding a bright seed -- it exists to be spent.
    droplet(d, 0.50, 0.54, 0.20, GREEN_DEEP)
    circle(d, 0.50, 0.58, 0.072, fill=light(HP_GREEN, 0.3))
    line(d, [(0.50, 0.74), (0.50, 0.88)], dark(SOIL, 0.15), width=0.026)
    for s in (-1, 1):
        line(d, [(0.50, 0.86), (0.50 + s * 0.14, 0.92)], dark(SOIL, 0.3), width=0.020)


@art("gaia_vernal_rite")
def _(d, t):
    # Two vessels, one pouring into the other. An hourglass read rather than a
    # botanical one: at 74px "this thing empties into that thing" survives, and
    # two plants of different sizes does not -- both earlier passes proved it.
    #
    # Left: a spent pod, tipped and hollow.
    poly(d, [(0.14, 0.42), (0.40, 0.36), (0.36, 0.66), (0.18, 0.68)],
         fill=dark(SOIL, 0.05))
    poly(d, [(0.17, 0.45), (0.36, 0.40), (0.33, 0.62), (0.20, 0.63)],
         fill=dark(PANEL, -0.15))
    # The stream, thick and unmistakably going right-and-down.
    poly(d, [(0.35, 0.52), (0.62, 0.66), (0.60, 0.74), (0.34, 0.60)],
         fill=light(HP_GREEN, 0.25))
    # Right: a full pod, upright, lit from within.
    droplet(d, 0.68, 0.66, 0.19, GREEN_DEEP)
    circle(d, 0.68, 0.70, 0.070, fill=light(HP_GREEN, 0.35))
    line(d, [(0.68, 0.85), (0.68, 0.94)], dark(SOIL, 0.2), width=0.024)


# -- Gaia supports and tool ------------------------------------------------

@art("gaia_bedrock")
def _(d, t):
    # Strata: the card is literally layers of ground.
    rect(d, 0.12, 0.68, 0.88, 0.80, fill=STONE_DARK, radius=0.01)
    rect(d, 0.12, 0.80, 0.88, 0.90, fill=dark(STONE_DARK, 0.3), radius=0.01)
    rect(d, 0.12, 0.56, 0.88, 0.68, fill=STONE, radius=0.01)
    rect(d, 0.12, 0.46, 0.88, 0.56, fill=SOIL, radius=0.01)
    # One shoot pushing up out of it.
    line(d, [(0.50, 0.46), (0.50, 0.24)], GREEN_DEEP, width=0.030)
    leafy_crown(d, 0.50, 0.18, 0.10, light(HP_GREEN, 0.1))


@art("gaia_deep_communion")
def _(d, t):
    # Roots reaching toward a light below -- listening, not taking.
    roots(d, 0.50, 0.16, 0.62, 0.28, dark(SOIL, 0.05), w=0.032)
    circle(d, 0.50, 0.74, 0.115, fill=dark(HP_GREEN, 0.45))
    circle(d, 0.50, 0.74, 0.062, fill=light(HP_GREEN, 0.3))
    rays(d, 0.50, 0.74, 0.078, 0.125, dark(HP_GREEN, 0.1), count=10, width=2.0)


@art("gaia_terraform")
def _(d, t):
    # A curved horizon with growth along its whole length -- board-wide, visibly.
    arc(d, -0.10, 0.62, 1.10, 1.30, 180, 360, fill=SOIL)
    for x, h in ((0.22, 0.12), (0.38, 0.17), (0.54, 0.15), (0.70, 0.19), (0.84, 0.11)):
        y = 0.70 - abs(x - 0.53) * 0.14
        line(d, [(x, y), (x, y - h)], GREEN_DEEP, width=0.024)
        circle(d, x, y - h - 0.022, 0.038, fill=light(HP_GREEN, 0.15))


@art("gaia_cairn")
def _(d, t):
    # Balanced stones, largest at the bottom. A marker, not a fortification.
    ellipse(d, 0.28, 0.76, 0.72, 0.88, fill=STONE_DARK)
    ellipse(d, 0.33, 0.62, 0.67, 0.76, fill=STONE)
    ellipse(d, 0.38, 0.50, 0.62, 0.62, fill=STONE_DARK)
    ellipse(d, 0.42, 0.40, 0.58, 0.50, fill=STONE)
    ellipse(d, 0.45, 0.33, 0.55, 0.40, fill=light(STONE, 0.15))


@art("gaia_verdant_anchor")
def _(d, t):
    # A root coiled around a ring -- a Tool, so it reads as equipment.
    circle(d, 0.50, 0.44, 0.19, outline=dark(SOIL, 0.05), width=0.048)
    roots(d, 0.50, 0.60, 0.92, 0.26, GREEN_DEEP, w=0.030)
    circle(d, 0.50, 0.44, 0.075, fill=light(HP_GREEN, 0.2))


# ---------------------------------------------------------------- fallback

def generic(d, tint, kind):
    """Used for any card with no hand-drawn emblem yet."""
    if kind == "unit":
        skull(d, 0.5, 0.5, 0.22, col=dark(BONE, 0.25))
    else:
        hexagon(d, 0.5, 0.5, 0.26, outline=tint, width=3)
        circle(d, 0.5, 0.5, 0.075, fill=tint)


# ---------------------------------------------------------------- driver

def build(card):
    tint = FACTION.get(card.get("faction", "neutral"), TOWER)
    kind = card.get("type", "unit")
    img = backdrop(tint, kind)
    d = ImageDraw.Draw(img)
    fn = DRAW.get(card["id"])
    if fn is not None:
        fn(d, tint)
    else:
        generic(d, tint, kind)
    return finish(img, tint)


## The 58 bestiary creatures (2026-08-15) live in their own module -- this file
## was already 2029 lines and doubling it in place would have made both halves
## harder to read. Registered here rather than at import time so DRAW and every
## helper above already exist when it runs.
def _register_bestiary():
    import sys
    sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
    import bestiary_art
    bestiary_art.register(sys.modules[__name__])
    import bestiary_art2
    bestiary_art2.register(sys.modules[__name__])
    import forge_art
    forge_art.register(sys.modules[__name__])
    import forge_art2
    forge_art2.register(sys.modules[__name__])
    import tempest_art
    tempest_art.register(sys.modules[__name__])
    import tempest_art2
    tempest_art2.register(sys.modules[__name__])


def main():
    _register_bestiary()
    os.makedirs(OUT, exist_ok=True)
    with open(os.path.join(ROOT, "data", "cards.json"), encoding="utf-8") as f:
        cards = json.load(f)["cards"]

    missing = []
    for c in cards:
        build(c).save(os.path.join(OUT, c["id"] + ".png"))
        if c["id"] not in DRAW:
            missing.append(c["id"])

    print("wrote %d emblems to assets/art/" % len(cards))
    if missing:
        print("no emblem yet (generic fallback): " + ", ".join(missing))


if __name__ == "__main__":
    main()
