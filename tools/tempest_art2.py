"""Tempest expansion emblems, registered into make_card_art.py's DRAW table.

The launch set (tempest_art.py) established six objects: curl, cloud, chevron,
dart, wedge, eye. This wave adds fourteen chains and must not reuse any of them,
which is the wave-2 lesson stated plainly:

    "A visual grammar has to be partitioned before it is drawn, not
     deduplicated afterward."

So each family here is assigned a distinct object up front:

    Zephyr  -- a leaf carried on air (the lightest thing that moves)
    Haar    -- a low bank, flat-topped and horizontal
    Squame  -- overlapping scales
    Virga   -- a hanging fringe that does not reach the ground
    Aeol    -- a struck bell-curve of sound, as concentric arcs made solid
    Levin   -- a jagged fork (distinct from the ENERGY bolt: two prongs, not one)
    Roke    -- a heavy rounded boulder of fog
    Skirl   -- a thin crescent blade
    Gale    -- a doubled dart (Sirocc is single; this is a pair)
    Murk    -- a squat dome with a dark core
    Sleet   -- a field of falling shards
    Baro    -- a dial with a fallen needle
    Squall  -- a rank of vertical bars, the squall LINE
    Anvil   -- the flat-topped anvil head
    Thrum   -- concentric rings radiating
    Keraun  -- a downward spear striking a base
    Nephel  -- a rounded cloud with a bright open underside
    Bluster -- a fat multi-lobed puff

Two rules the earlier waves paid for, and which cost this file three redraws in
the launch set alone:

  * ONE closed object per emblem. Thin linework reads as nothing at 78px.
  * No props competing with the subject for the silhouette.
"""

import math


def register(m):
    """Install every Tempest expansion emblem into the host module's DRAW table."""
    art = m.art
    poly, circle, ellipse = m.poly, m.circle, m.ellipse
    rect, star = m.rect, m.star
    dark, light, mix = m.dark, m.light, m.mix
    PANEL = m.PANEL

    TEMP = (88, 184, 217)
    TEMP_HOT = (160, 224, 245)
    TEMP_DEEP = (30, 74, 102)
    SLATE = (58, 70, 88)
    EDGE = dark(TEMP_DEEP, 0.3)

    # ------------------------------------------------------------------ Zephyr
    # A leaf on the air. The lightest object in the set.

    def leaf(d, cx, cy, r, col):
        # A plain lens reads as a blob at 74px. The notched tip and the darker
        # half-spine are what make it a leaf rather than an ellipse.
        pts = []
        for i in range(25):
            t = i / 24.0
            a = -0.9 + t * 3.6
            rad = r * (0.35 + 0.75 * math.sin(t * math.pi))
            pts.append((cx + rad * math.cos(a), cy + rad * math.sin(a) * 0.80))
        pts.append((cx + r * 1.15, cy + r * 0.62))
        poly(d, pts, fill=col, outline=EDGE, width=3)
        poly(d, [(cx + r * 1.15, cy + r * 0.62), (cx - r * 0.55, cy - r * 0.30),
                 (cx - r * 0.20, cy + r * 0.14)], fill=dark(col, 0.38))

    @art("tempest_zephyrwisp")
    def _(d, t):
        leaf(d, 0.42, 0.44, 0.34, TEMP)

    @art("tempest_zephyrrush")
    def _(d, t):
        leaf(d, 0.38, 0.52, 0.36, TEMP)
        leaf(d, 0.60, 0.26, 0.22, TEMP_HOT)

    # -------------------------------------------------------------------- Haar
    # A low flat bank. Horizontal where everything else is diagonal or round.

    def bank(d, cy, h, col):
        rect(d, 0.08, cy - h, 0.92, cy + h, fill=col, outline=EDGE,
             width=3, radius=0.05)
        rect(d, 0.08, cy + h * 0.25, 0.92, cy + h, fill=dark(col, 0.3), radius=0.04)

    @art("tempest_haarmote")
    def _(d, t):
        bank(d, 0.56, 0.13, TEMP)

    @art("tempest_haarshear")
    def _(d, t):
        bank(d, 0.62, 0.15, TEMP)
        bank(d, 0.34, 0.10, TEMP_HOT)

    # ------------------------------------------------------------------ Squame
    # Overlapping scales.

    def scale(d, cx, cy, r, col):
        poly(d, [(cx - r, cy + r * 0.5), (cx - r * 0.75, cy - r * 0.35),
                 (cx, cy - r * 0.75), (cx + r * 0.75, cy - r * 0.35),
                 (cx + r, cy + r * 0.5), (cx, cy + r * 0.85)],
             fill=col, outline=EDGE, width=2)

    @art("tempest_squamewisp")
    def _(d, t):
        scale(d, 0.50, 0.52, 0.26, TEMP)

    @art("tempest_squamesquall")
    def _(d, t):
        scale(d, 0.36, 0.60, 0.24, TEMP)
        scale(d, 0.62, 0.56, 0.24, TEMP)
        scale(d, 0.50, 0.34, 0.24, TEMP_HOT)

    # ------------------------------------------------------------------- Virga
    # A hanging fringe that stops short of the ground.

    def fringe(d, top, depth, n, col):
        rect(d, 0.12, top - 0.10, 0.88, top + 0.04, fill=col,
             outline=EDGE, width=3, radius=0.03)
        w = 0.76 / n
        for i in range(n):
            x = 0.12 + w * (i + 0.5)
            poly(d, [(x - w * 0.30, top + 0.02), (x + w * 0.30, top + 0.02),
                     (x, top + depth)], fill=col, outline=EDGE, width=2)

    @art("tempest_virgamote")
    def _(d, t):
        fringe(d, 0.40, 0.26, 3, TEMP)

    @art("tempest_virgagale")
    def _(d, t):
        fringe(d, 0.34, 0.38, 4, TEMP)

    # -------------------------------------------------------------------- Aeol
    # Sound off a ridge: solid concentric arcs, thickest at the source.

    def reed(d, w, h, col):
        # Was a pair of arcs, which rendered as a CHEVRON and collided with
        # Foehn -- the exact duplication the partition rule exists to prevent.
        # A reed is one closed vertical object and shares nothing with the set.
        cx = 0.50
        poly(d, [(cx - w, 0.86), (cx - w * 0.42, 0.20), (cx, 0.08),
                 (cx + w * 0.42, 0.20), (cx + w, 0.86)],
             fill=col, outline=EDGE, width=3)
        poly(d, [(cx - w * 0.34, 0.86), (cx - w * 0.14, 0.30), (cx, 0.22),
                 (cx + w * 0.14, 0.30), (cx + w * 0.34, 0.86)],
             fill=dark(col, 0.38))

    @art("tempest_aeolskirl")
    def _(d, t):
        reed(d, 0.24, 0.0, TEMP)

    @art("tempest_aeolrush")
    def _(d, t):
        reed(d, 0.30, 0.0, TEMP)
        circle(d, 0.50, 0.10, 0.10, fill=TEMP_HOT, outline=EDGE, width=2)

    # ------------------------------------------------------------------- Levin
    # A forked bolt -- TWO prongs, so it is not the single-bolt energy token.

    def fork(d, cx, top, h, w, col):
        poly(d, [(cx + w * 0.20, top), (cx - w, top + h * 0.44),
                 (cx - w * 0.24, top + h * 0.44), (cx - w * 0.62, top + h),
                 (cx + w * 0.30, top + h * 0.52), (cx - w * 0.16, top + h * 0.52),
                 (cx + w * 0.52, top)],
             fill=col, outline=EDGE, width=3)
        poly(d, [(cx + w * 0.30, top + h * 0.52), (cx + w * 1.0, top + h * 0.96),
                 (cx + w * 0.44, top + h * 0.62)],
             fill=col, outline=EDGE, width=2)

    @art("tempest_levinskirl")
    def _(d, t):
        fork(d, 0.46, 0.14, 0.68, 0.24, TEMP)

    @art("tempest_levinsquall")
    def _(d, t):
        fork(d, 0.44, 0.10, 0.76, 0.28, TEMP_HOT)

    @art("tempest_levintempest")
    def _(d, t):
        fork(d, 0.40, 0.06, 0.84, 0.30, TEMP_DEEP)
        fork(d, 0.48, 0.12, 0.72, 0.24, TEMP_HOT)

    # -------------------------------------------------------------------- Roke
    # A heavy rounded boulder of fog. Round where Haar is flat.

    @art("tempest_rokewhorl")
    def _(d, t):
        circle(d, 0.50, 0.56, 0.28, fill=TEMP, outline=EDGE, width=3)
        circle(d, 0.42, 0.46, 0.11, fill=light(TEMP, 0.28))

    @art("tempest_rokeshear")
    def _(d, t):
        circle(d, 0.44, 0.58, 0.30, fill=TEMP, outline=EDGE, width=3)
        circle(d, 0.66, 0.42, 0.19, fill=TEMP, outline=EDGE, width=3)
        circle(d, 0.38, 0.48, 0.11, fill=light(TEMP, 0.28))

    @art("tempest_rokemaelstrom")
    def _(d, t):
        circle(d, 0.42, 0.60, 0.32, fill=TEMP_DEEP, outline=EDGE, width=3)
        circle(d, 0.64, 0.42, 0.24, fill=TEMP, outline=EDGE, width=3)
        circle(d, 0.36, 0.44, 0.15, fill=TEMP_HOT)

    # ------------------------------------------------------------------- Skirl
    # A thin crescent BLADE -- a closed sickle, not a stroke.

    def blade(d, cx, cy, r, col):
        outer = []
        inner = []
        for i in range(21):
            a = -2.5 + (i / 20.0) * 3.4
            outer.append((cx + r * math.cos(a), cy + r * math.sin(a)))
            rr = r * 0.30
            inner.append((cx + rr * math.cos(a) + r * 0.16,
                          cy + rr * math.sin(a) - r * 0.10))
        poly(d, outer + inner[::-1], fill=col, outline=EDGE, width=3)

    @art("tempest_skirlwisp")
    def _(d, t):
        blade(d, 0.52, 0.50, 0.34, TEMP)

    @art("tempest_skirlsquall")
    def _(d, t):
        blade(d, 0.56, 0.54, 0.36, TEMP)
        blade(d, 0.44, 0.40, 0.19, TEMP_HOT)

    # -------------------------------------------------------------------- Gale
    # A PAIR of darts. Sirocc's is single, so the count is the difference.

    def dart(d, x0, y0, x1, y1, w, col):
        a = math.atan2(y1 - y0, x1 - x0)
        nx, ny = -math.sin(a), math.cos(a)
        hx, hy = x1 - (x1 - x0) * 0.20, y1 - (y1 - y0) * 0.20
        poly(d, [(x0 + nx * w * 0.30, y0 + ny * w * 0.30),
                 (hx + nx * w, hy + ny * w), (x1, y1),
                 (hx - nx * w, hy - ny * w),
                 (x0 - nx * w * 0.30, y0 - ny * w * 0.30)],
             fill=col, outline=EDGE, width=2)

    @art("tempest_galewhorl")
    def _(d, t):
        dart(d, 0.12, 0.62, 0.80, 0.36, 0.10, TEMP)
        dart(d, 0.18, 0.84, 0.68, 0.62, 0.07, TEMP)

    @art("tempest_galerush")
    def _(d, t):
        dart(d, 0.10, 0.66, 0.86, 0.34, 0.11, TEMP)
        dart(d, 0.16, 0.88, 0.74, 0.62, 0.08, TEMP_HOT)
        dart(d, 0.20, 0.42, 0.62, 0.20, 0.06, TEMP_HOT)

    # -------------------------------------------------------------------- Murk
    # A squat dome with a dark core -- the "stand behind it" body.

    @art("tempest_murkmote")
    def _(d, t):
        poly(d, [(0.16, 0.74), (0.16, 0.56), (0.34, 0.36), (0.66, 0.36),
                 (0.84, 0.56), (0.84, 0.74)], fill=TEMP, outline=EDGE, width=3)
        circle(d, 0.50, 0.58, 0.12, fill=TEMP_DEEP)

    @art("tempest_murkshear")
    def _(d, t):
        poly(d, [(0.10, 0.80), (0.10, 0.54), (0.32, 0.28), (0.68, 0.28),
                 (0.90, 0.54), (0.90, 0.80)], fill=TEMP, outline=EDGE, width=3)
        circle(d, 0.50, 0.56, 0.17, fill=TEMP_DEEP)
        circle(d, 0.50, 0.56, 0.07, fill=TEMP_HOT)

    # ------------------------------------------------------------------- Sleet
    # A field of falling shards. Many small closed figures reading as one mass.

    def shards(d, rows, col):
        for r in range(rows):
            for i in range(4 - (r % 2)):
                x = 0.18 + i * 0.21 + (0.10 if r % 2 else 0.0)
                y = 0.20 + r * 0.22
                poly(d, [(x, y), (x + 0.055, y + 0.05), (x - 0.02, y + 0.17)],
                     fill=col, outline=EDGE, width=1)

    @art("tempest_sleetskirl")
    def _(d, t):
        shards(d, 2, TEMP)

    @art("tempest_sleetsquall")
    def _(d, t):
        shards(d, 3, TEMP)

    @art("tempest_sleetdeluge")
    def _(d, t):
        shards(d, 3, TEMP_DEEP)
        shards(d, 2, TEMP_HOT)

    # -------------------------------------------------------------------- Baro
    # A dial with a fallen needle: pressure made an instrument.

    def dial(d, r, ang, col):
        circle(d, 0.50, 0.52, r, fill=col, outline=EDGE, width=3)
        circle(d, 0.50, 0.52, r * 0.62, fill=dark(col, 0.45))
        a = math.radians(ang)
        w = r * 0.16
        nx, ny = -math.sin(a), math.cos(a)
        poly(d, [(0.50 + nx * w, 0.52 + ny * w),
                 (0.50 + r * 0.58 * math.cos(a), 0.52 + r * 0.58 * math.sin(a)),
                 (0.50 - nx * w, 0.52 - ny * w)], fill=TEMP_HOT)

    @art("tempest_baromote")
    def _(d, t):
        dial(d, 0.27, 200, TEMP)

    @art("tempest_baroshear")
    def _(d, t):
        dial(d, 0.32, 150, TEMP)

    @art("tempest_barothunderhead")
    def _(d, t):
        dial(d, 0.36, 110, TEMP_HOT)

    # ------------------------------------------------------------------ Squall
    # The squall LINE: a rank of vertical bars, leaning.

    def line_rank(d, n, h, col):
        for i in range(n):
            x = 0.16 + i * (0.68 / max(1, n - 1))
            poly(d, [(x, 0.50 - h), (x + 0.09, 0.50 - h),
                     (x - 0.05, 0.50 + h), (x - 0.14, 0.50 + h)],
                 fill=col if i % 2 == 0 else light(col, 0.22),
                 outline=EDGE, width=2)

    @art("tempest_squallwisp")
    def _(d, t):
        line_rank(d, 3, 0.28, TEMP)

    @art("tempest_squallgale")
    def _(d, t):
        line_rank(d, 4, 0.36, TEMP)

    # ------------------------------------------------------------------- Anvil
    # The flat-topped anvil head. Wide crown, narrow stem: unmistakable.

    def anvil_head(d, w, col):
        # A wide crown over a narrowing stem reads as a FUNNEL unless it sits on
        # a broad foot -- the first draft was upside-down at 74px. Crown, waist,
        # foot, in one closed figure.
        poly(d, [(0.50 - w, 0.24), (0.50 + w, 0.24),
                 (0.50 + w * 0.52, 0.40), (0.50 + w * 0.30, 0.62),
                 (0.50 + w * 0.86, 0.78), (0.50 + w * 0.86, 0.86),
                 (0.50 - w * 0.86, 0.86), (0.50 - w * 0.86, 0.78),
                 (0.50 - w * 0.30, 0.62), (0.50 - w * 0.52, 0.40)],
             fill=col, outline=EDGE, width=3)
        poly(d, [(0.50 - w, 0.24), (0.50 + w, 0.24), (0.50 + w * 0.78, 0.34),
                 (0.50 - w * 0.78, 0.34)], fill=light(col, 0.28))

    @art("tempest_anvilwhorl")
    def _(d, t):
        anvil_head(d, 0.28, TEMP)

    @art("tempest_anvilthunderhead")
    def _(d, t):
        anvil_head(d, 0.40, TEMP)
        rect(d, 0.16, 0.18, 0.84, 0.27, fill=TEMP_HOT, outline=EDGE,
             width=2, radius=0.03)

    # ------------------------------------------------------------------- Thrum
    # Concentric rings radiating. Distinct from Calm's eye: rings, not a disc.

    def rings(d, n, r, col):
        for i in range(n, 0, -1):
            rr = r * i / n
            circle(d, 0.50, 0.52, rr,
                   fill=col if i % 2 else dark(col, 0.42),
                   outline=EDGE if i == n else None, width=3)

    @art("tempest_thrumwisp")
    def _(d, t):
        rings(d, 2, 0.26, TEMP)

    @art("tempest_thrumrush")
    def _(d, t):
        rings(d, 3, 0.33, TEMP)

    @art("tempest_thrummaelstrom")
    def _(d, t):
        rings(d, 4, 0.40, TEMP)
        circle(d, 0.50, 0.52, 0.08, fill=TEMP_HOT)

    # ------------------------------------------------------------------ Keraun
    # A downward spear striking a base. Vertical where Bora's wedge is broad.

    def spear(d, w, base, col):
        # A plain arrow duplicates Sirocc's and Gale's darts. The BARBS and the
        # downward point are what separate it: this strikes rather than travels.
        poly(d, [(0.50, base + 0.10),
                 (0.50 - w, 0.52), (0.50 - w * 0.40, 0.52),
                 (0.50 - w * 1.15, 0.30), (0.50 - w * 0.40, 0.34),
                 (0.50 - w * 0.34, 0.06), (0.50 + w * 0.34, 0.06),
                 (0.50 + w * 0.40, 0.34), (0.50 + w * 1.15, 0.30),
                 (0.50 + w * 0.40, 0.52), (0.50 + w, 0.52)],
             fill=col, outline=EDGE, width=3)

    @art("tempest_keraunskirl")
    def _(d, t):
        spear(d, 0.22, 0.62, TEMP)

    @art("tempest_keraunsquall")
    def _(d, t):
        spear(d, 0.26, 0.62, TEMP)
        rect(d, 0.22, 0.78, 0.78, 0.88, fill=SLATE, outline=EDGE,
             width=2, radius=0.02)

    @art("tempest_kerauntempest")
    def _(d, t):
        spear(d, 0.30, 0.60, TEMP_HOT)
        rect(d, 0.14, 0.76, 0.86, 0.92, fill=SLATE, outline=EDGE,
             width=3, radius=0.03)

    # ------------------------------------------------------------------ Nephel
    # A cloud with a BRIGHT open underside -- the healer, so it gives light back.

    def open_cloud(d, w, h, col, under):
        cy = 0.48
        circle(d, 0.50 - w * 0.48, cy, h * 0.72, fill=col)
        circle(d, 0.50, cy - h * 0.30, h * 0.92, fill=col)
        circle(d, 0.50 + w * 0.48, cy, h * 0.76, fill=col)
        rect(d, 0.50 - w, cy, 0.50 + w, cy + h * 0.42, fill=col)
        poly(d, [(0.50 - w * 0.86, cy + h * 0.40), (0.50 + w * 0.86, cy + h * 0.40),
                 (0.50 + w * 0.50, cy + h * 0.90), (0.50 - w * 0.50, cy + h * 0.90)],
             fill=under)

    @art("tempest_nephelmote")
    def _(d, t):
        open_cloud(d, 0.26, 0.26, TEMP, TEMP_HOT)

    @art("tempest_nephelgale")
    def _(d, t):
        open_cloud(d, 0.32, 0.30, TEMP, TEMP_HOT)

    @art("tempest_nepheldeluge")
    def _(d, t):
        open_cloud(d, 0.38, 0.34, TEMP_DEEP, TEMP_HOT)
        open_cloud(d, 0.22, 0.20, TEMP, TEMP_HOT)

    # ----------------------------------------------------------------- Bluster
    # A fat multi-lobed puff. Roundest thing in the set, and the loudest.

    def puff(d, r, col):
        for dx, dy, k in [(-0.20, 0.06, 0.62), (0.20, 0.06, 0.62),
                          (0.0, -0.14, 0.78), (-0.10, 0.20, 0.50),
                          (0.12, 0.20, 0.50)]:
            circle(d, 0.50 + dx, 0.52 + dy, r * k, fill=col)
        circle(d, 0.44, 0.42, r * 0.30, fill=light(col, 0.30))

    @art("tempest_blusterwhorl")
    def _(d, t):
        puff(d, 0.34, TEMP)

    @art("tempest_blustershear")
    def _(d, t):
        puff(d, 0.42, TEMP_DEEP)
        puff(d, 0.26, TEMP)

    # -------------------------------------------------------------- supports

    @art("tempest_bank_the_gale")
    def _(d, t):
        dart(d, 0.12, 0.80, 0.62, 0.50, 0.11, TEMP)
        circle(d, 0.72, 0.36, 0.20, fill=TEMP_HOT, outline=EDGE, width=3)

    @art("tempest_standing_front")
    def _(d, t):
        # The launch set's chevron, doubled and held: a front that has stopped.
        for k, col in [(0.0, TEMP_DEEP), (-0.14, TEMP)]:
            poly(d, [(0.10 + k, 0.22), (0.52 + k, 0.34), (0.86 + k, 0.52),
                     (0.52 + k, 0.70), (0.10 + k, 0.82), (0.34 + k, 0.52)],
                 fill=col, outline=EDGE, width=3)

    @art("tempest_conductor")
    def _(d, t):
        rect(d, 0.44, 0.20, 0.56, 0.78, fill=SLATE, outline=EDGE,
             width=3, radius=0.02)
        circle(d, 0.50, 0.18, 0.11, fill=TEMP_HOT, outline=EDGE, width=2)
        rect(d, 0.24, 0.78, 0.76, 0.88, fill=TEMP, outline=EDGE,
             width=2, radius=0.02)
