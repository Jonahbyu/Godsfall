"""Generate the desktop shortcut icon and the in-game window/taskbar icon.

Both are the **Crest** - the same mark the main menu draws, a throne under a lit
fracture in a broken ring. This is a direct port of `scripts/ui/Crest.gd`, and
that is the point: the icon a player clicks and the emblem they land on should be
the same object, or the shortcut is advertising a different game than it opens.

Colors mirror `scripts/ui/Theme.gd`. The geometry mirrors `Crest.gd` - offsets
are in fractions of the box, exactly as they are there, so the two can be
compared line by line when either moves.

Run:  python tools/make_icon.py
"""

import math
from PIL import Image, ImageDraw


# --- Palette (scripts/ui/Theme.gd) ---
def hexc(h, a=255):
    return (int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16), a)


BG          = hexc("0b0917")
PANEL       = hexc("141126")
BORDER      = hexc("35304f")
BORDER_LIT  = hexc("4a4370")
ACCENT      = hexc("6ea8ff")
ACCENT_GLOW = hexc("a8ccff")
TEXT_DIM    = hexc("9691ad")

RING_GAP = 0.34    # radians of ring left open at the top
CRACK_W  = 0.028   # crack width as a fraction of the box

S = 1024           # supersample, downscaled at the end for smooth edges
img = Image.new("RGBA", (S, S), (0, 0, 0, 0))
d = ImageDraw.Draw(img)


def alpha(col, a):
    """The GDScript writes Color(c.r, c.g, c.b, a); same here."""
    return (col[0], col[1], col[2], int(round(a * 255)))


def arc(cx, cy, r, start, end, col, width, soft=False):
    """draw_arc, as a thick polyline. Pillow's arc() cannot do sub-pixel
    antialiased thickness the way a supersampled polyline can."""
    n = 96
    pts = []
    for i in range(n + 1):
        t = start + (end - start) * (i / n)
        pts.append((cx + math.cos(t) * r, cy + math.sin(t) * r))
    if soft:
        soft_line(pts, col, width)
    else:
        d.line(pts, fill=col, width=int(round(width)), joint="curve")


def outline(pts, col, width):
    d.line(list(pts) + [pts[0]], fill=col, width=int(round(width)), joint="curve")


def soft_polygon(pts, col):
    """Fill a polygon with a translucent colour.

    Pillow's `polygon(fill=...)` REPLACES the pixels it covers rather than
    blending, so an RGBA fill with alpha<255 paints a flat, partly-transparent
    slab straight over the plate underneath - which is what made the first pass
    render the throne as opaque grey instead of the 30% wash `Crest.gd` draws.
    Drawing onto a scratch layer and compositing is what actually blends.
    """
    global img, d
    layer = Image.new("RGBA", img.size, (0, 0, 0, 0))
    ImageDraw.Draw(layer).polygon(pts, fill=col)
    img = Image.alpha_composite(img, layer)
    d = ImageDraw.Draw(img)


def soft_line(pts, col, width, closed=False):
    """Same problem, same fix, for the translucent glow passes."""
    global img, d
    layer = Image.new("RGBA", img.size, (0, 0, 0, 0))
    seq = list(pts) + [pts[0]] if closed else list(pts)
    ImageDraw.Draw(layer).line(seq, fill=col, width=int(round(width)), joint="curve")
    img = Image.alpha_composite(img, layer)
    d = ImageDraw.Draw(img)


# --- No plate: the icon is the mark alone, on transparency ---
# Everything outside the ring, throne and fracture stays clear so the desktop
# wallpaper shows through, the way a cut-out app icon does.
#
# This changes what the shapes have to do. In `Crest.gd` the throne is a 30%
# wash that reads because the menu's dark panel sits behind it; with nothing
# behind it, a 30% wash against a light wallpaper is nearly invisible. So the
# icon prints the throne and steps as solid fills in the same hues the wash
# resolves to on the menu's ground. The mark is identical where it matters -
# silhouette, ring gap, crack path - and legible on any backdrop.

cx = cy = S / 2.0
box = S * 0.94          # the Crest's own drawing box inside the plate
r = box * 0.46


# --- The broken ring ---
start = -math.pi * 0.5 + RING_GAP
end = -math.pi * 0.5 - RING_GAP + math.tau
arc(cx, cy, r, start, end, BORDER_LIT, max(1.5, r * 0.035))
arc(cx, cy, r * 0.9, start + 0.06, end - 0.06,
    alpha(BORDER_LIT, 0.35), max(1.0, r * 0.018), soft=True)


# --- The throne ---
w = box * 0.26
top = cy - box * 0.30
seat = cy + box * 0.06
base = cy + box * 0.24

def over(fg, bg, a):
    """fg at alpha `a` composited over bg - the colour the menu actually shows."""
    return tuple(int(round(fg[i] * a + bg[i] * (1.0 - a))) for i in range(3)) + (255,)


back = [
    (cx - w * 0.78, top),
    (cx + w * 0.78, top),
    (cx + w, seat),
    (cx - w, seat),
]
d.polygon(back, fill=over(TEXT_DIM, PANEL, 0.30))
outline(back, TEXT_DIM, max(1.0, box * 0.012))

for i in range(2):
    t = float(i)
    hw = w * (1.18 + 0.26 * t)
    y0 = seat + (base - seat) * (t / 2.0)
    y1 = seat + (base - seat) * ((t + 1.0) / 2.0)
    step = [(cx - hw, y0), (cx + hw, y0), (cx + hw, y1), (cx - hw, y1)]
    d.polygon(step, fill=over(TEXT_DIM, PANEL, 0.22 - 0.06 * t))
    soft_line(step, alpha(TEXT_DIM, 0.75), max(1.0, box * 0.010), closed=True)


# --- The fracture ---
# Drawn twice: a wide soft pass for the glow, a thin bright one for the edge.
path = [
    (0.03, 0.30), (-0.02, 0.16), (0.05, 0.02),
    (-0.03, -0.14), (0.02, -0.30), (-0.01, -0.44),
    (0.04, -0.56),
]
pts = [(cx + ox * box, cy + oy * box) for ox, oy in path]
soft_line(pts, alpha(ACCENT, 0.22), max(2.0, box * CRACK_W * 2.2))
d.line(pts, fill=ACCENT_GLOW,
       width=int(round(max(1.0, box * CRACK_W * 0.5))), joint="curve")


big = img.resize((256, 256), Image.LANCZOS)

# .ico for the desktop shortcut
ico = r"c:\Users\Jonah\OneDrive\Desktop\Godsfall\tools\Godsfall.ico"
big.save(ico, format="ICO",
         sizes=[(16, 16), (24, 24), (32, 32), (48, 48), (64, 64), (128, 128), (256, 256)])
print("wrote", ico)

# .png for the in-game window/taskbar icon (Godot can't load .ico at runtime)
png = r"c:\Users\Jonah\OneDrive\Desktop\Godsfall\icon_window.png"
big.save(png, format="PNG")
print("wrote", png)
