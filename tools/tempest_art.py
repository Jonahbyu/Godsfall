"""Tempest emblems, registered into make_card_art.py's DRAW table.

Same shape as forge_art.py: one function per card id, coordinates in 0-1 space,
drawn onto a prepared backdrop.

Tempest's visual grammar, partitioned up front rather than deduplicated later --
the wave-2 lesson. Each chain owns ONE object and no other chain reuses it:

    Cirr    -- the curl of wind, opening into a spiral
    Nimb    -- the swollen cloud, heavy and about to break
    Foehn   -- the front: two masses meeting along a hard diagonal
    Sirocc  -- the streaking gust, arrowed and moving
    Bora    -- the falling wedge, a downburst striking the ground
    Calm    -- the eye: a clear ring with the storm around it

Distinct from the five built colours. Hel is bone, Heaven gold and radial, Void
an absence with a bright rim, Gaia soft green mounds, Forge warm and angular.
Tempest is COOL BLUE and built from motion -- curves and diagonals, never the
static symmetry Heaven uses and never Forge's struck edges.

Two rules the earlier waves paid for:

  * ONE closed object per emblem. Thin linework reads as nothing at 78px --
    that is why Grimkin's scales and Sevsk's chain had to be redrawn.
  * No props competing with the subject for the silhouette. A figure plus its
    accessories loses both.

A chain shares a silhouette across its stages: the same shape function called at
successive scales, so the Stage 2 reads as the Basic grown up.
"""


def register(m):
    """Install every Tempest emblem into the host module's DRAW table."""
    art = m.art
    poly, line, circle, ellipse = m.poly, m.line, m.circle, m.ellipse
    rect, arc, star = m.rect, m.line, m.star
    dark, light, mix = m.dark, m.light, m.mix
    P = m.P
    GOLD, BONE, PANEL = m.GOLD, m.BONE, m.PANEL

    TEMP = (88, 184, 217)         # Theme.gd tempest
    TEMP_HOT = (160, 224, 245)    # bright — the lit edge of a cloud
    TEMP_DEEP = (30, 74, 102)     # deep — the underside
    SLATE = (58, 70, 88)

    # ---------------------------------------------------------------- energy

    @art("tempest_energy")
    def _energy(d, t):
        # The faction token: a bolt, one closed figure. Named in CLAUDE.md's
        # reserve table and kept, because a bolt survives greyscale and 10px.
        poly(d, [(0.56, 0.14), (0.30, 0.55), (0.46, 0.55), (0.40, 0.88),
                 (0.70, 0.44), (0.53, 0.44), (0.62, 0.14)],
             fill=TEMP_HOT, outline=dark(TEMP_DEEP, 0.3), width=3)

    # ------------------------------------------------------------------ Cirr
    #
    # The curl. A comma of wind that opens into a full spiral as it grows.

    def curl(d, cx, cy, r, turns, col):
        # Built as a filled crescent rather than a drawn line: a spiral stroke
        # is exactly the thin linework that vanishes at board size.
        pts = []
        steps = 34
        for i in range(steps + 1):
            t = i / steps
            a = -1.9 + turns * 5.4 * t
            rad = r * (0.30 + 0.70 * t)
            pts.append((cx + rad * __import__("math").cos(a),
                        cy + rad * __import__("math").sin(a)))
        back = []
        for i in range(steps + 1):
            t = i / steps
            a = -1.9 + turns * 5.4 * t
            rad = r * (0.30 + 0.70 * t) - r * (0.20 + 0.26 * t)
            back.append((cx + rad * __import__("math").cos(a),
                         cy + rad * __import__("math").sin(a)))
        poly(d, pts + back[::-1], fill=col, outline=dark(TEMP_DEEP, 0.25), width=2)

    @art("tempest_cirrsile")
    def _cirrsile(d, t):
        curl(d, 0.50, 0.54, 0.32, 0.72, TEMP)

    @art("tempest_cirrgale")
    def _cirrgale(d, t):
        curl(d, 0.50, 0.53, 0.33, 0.86, TEMP)
        curl(d, 0.50, 0.53, 0.15, 0.70, TEMP_HOT)

    @art("tempest_cirrtempest")
    def _cirrtempest(d, t):
        curl(d, 0.50, 0.52, 0.40, 1.00, TEMP_DEEP)
        curl(d, 0.50, 0.52, 0.29, 0.92, TEMP)
        curl(d, 0.50, 0.52, 0.15, 0.72, TEMP_HOT)

    # ------------------------------------------------------------------ Nimb
    #
    # The swollen cloud. One closed lobed mass, heavier each stage, with the
    # underside darkened so it reads as weight rather than as a puff.

    def thunderhead(d, cx, cy, w, h, col):
        # Lobes have to be DEEP. A shallow arc reads as a dome, and Hel already
        # owns bells -- the first draft of this shape was exactly that mistake.
        # Overlapping circles give a cloud its identity at 74px; a polygon
        # outline does not.
        r1 = h * 0.62
        circle(d, cx - w * 0.52, cy - h * 0.10, r1 * 0.86, fill=col)
        circle(d, cx - w * 0.14, cy - h * 0.46, r1 * 1.10, fill=col)
        circle(d, cx + w * 0.30, cy - h * 0.30, r1 * 0.96, fill=col)
        circle(d, cx + w * 0.62, cy + h * 0.02, r1 * 0.74, fill=col)
        # A flat, heavy base: this is a thunderhead, so the underside is a line.
        rect(d, cx - w * 0.86, cy + h * 0.06, cx + w * 0.86, cy + h * 0.46,
             fill=col)
        rect(d, cx - w * 0.86, cy + h * 0.30, cx + w * 0.86, cy + h * 0.46,
             fill=dark(col, 0.35))
        # The lit crown.
        circle(d, cx - w * 0.14, cy - h * 0.52, r1 * 0.52, fill=light(col, 0.34))

    @art("tempest_nimbwhorl")
    def _nimbwhorl(d, t):
        thunderhead(d, 0.50, 0.60, 0.24, 0.24, TEMP)

    @art("tempest_nimbsquall")
    def _nimbsquall(d, t):
        thunderhead(d, 0.50, 0.56, 0.31, 0.30, TEMP)
        poly(d, [(0.44, 0.76), (0.52, 0.76), (0.46, 0.92)], fill=TEMP_HOT)

    @art("tempest_nimbmaelstrom")
    def _nimbmaelstrom(d, t):
        thunderhead(d, 0.50, 0.40, 0.36, 0.28, TEMP)
        # The break: one bolt BELOW the mass, on clear ground. Drawn inside the
        # cloud it simply disappears -- a prop competing with its own subject.
        poly(d, [(0.57, 0.58), (0.36, 0.82), (0.48, 0.82), (0.40, 1.00),
                 (0.66, 0.74), (0.53, 0.74), (0.62, 0.58)], fill=TEMP_HOT,
             outline=dark(TEMP_DEEP, 0.35), width=2)

    # ----------------------------------------------------------------- Foehn
    #
    # The front. Two air masses meeting on a hard diagonal — the only Tempest
    # emblem built from a straight edge, because a front IS the boundary.

    def front(d, span, col, crest=None):
        # Two failed drafts before this one, and both failures are the same
        # lesson in different costumes:
        #   1. A divided rectangle -- a boundary is not a silhouette.
        #   2. A wave with a curled crest -- the curl detached into a floating
        #      chip beside the body at 74px.
        # What a front actually needs to say is "a mass of air arriving", so it
        # is drawn as ONE solid chevron driving right: a closed arrowhead with a
        # tail, which is unambiguous at any size and shares nothing with the
        # other five chains (Sirocc's dart is thin and diagonal; this is a fat
        # horizontal wedge).
        cy = 0.50
        h = span * 0.5
        poly(d, [(0.06, cy - h * 0.55), (0.52, cy - h),
                 (0.94, cy), (0.52, cy + h), (0.06, cy + h * 0.55),
                 (0.34, cy)],
             fill=col, outline=dark(TEMP_DEEP, 0.3), width=3)
        if crest is not None:
            # The leading edge, lit -- inside the body, never beside it.
            poly(d, [(0.52, cy - h), (0.94, cy), (0.52, cy + h), (0.66, cy)],
                 fill=crest)

    @art("tempest_foehnsile")
    def _foehnsile(d, t):
        front(d, 0.52, TEMP)

    @art("tempest_foehnshear")
    def _foehnshear(d, t):
        front(d, 0.66, TEMP, TEMP_HOT)

    @art("tempest_foehnthunderhead")
    def _foehnthunderhead(d, t):
        front(d, 0.86, TEMP_DEEP)
        front(d, 0.60, TEMP, TEMP_HOT)

    # ---------------------------------------------------------------- Sirocc
    #
    # The streaking gust. A single tapered dart, all motion — this is the relay
    # chain, so the emblem is the thing that does not stay put.

    def gust(d, x0, y0, x1, y1, w, col):
        import math
        a = math.atan2(y1 - y0, x1 - x0)
        nx, ny = -math.sin(a), math.cos(a)
        head = 0.16
        hx, hy = x1 - (x1 - x0) * head, y1 - (y1 - y0) * head
        poly(d, [(x0 + nx * w * 0.35, y0 + ny * w * 0.35),
                 (hx + nx * w, hy + ny * w),
                 (x1, y1),
                 (hx - nx * w, hy - ny * w),
                 (x0 - nx * w * 0.35, y0 - ny * w * 0.35)],
             fill=col, outline=dark(TEMP_DEEP, 0.25), width=2)

    @art("tempest_siroccskirl")
    def _siroccskirl(d, t):
        gust(d, 0.16, 0.66, 0.84, 0.36, 0.10, TEMP)

    @art("tempest_siroccsquall")
    def _siroccsquall(d, t):
        gust(d, 0.12, 0.74, 0.86, 0.40, 0.11, TEMP)
        gust(d, 0.20, 0.46, 0.74, 0.22, 0.07, TEMP_HOT)

    # ------------------------------------------------------------------ Bora
    #
    # The downburst. A wedge driving into the ground and spreading — the
    # executioner chain, so the shape is descent and impact.

    def downburst(d, cx, top, w, bottom, col):
        poly(d, [(cx - w * 0.34, top), (cx + w * 0.34, top),
                 (cx + w, bottom), (cx - w, bottom)],
             fill=col, outline=dark(TEMP_DEEP, 0.3), width=3)

    @art("tempest_borawhorl")
    def _borawhorl(d, t):
        downburst(d, 0.50, 0.18, 0.24, 0.72, TEMP)

    @art("tempest_borashear")
    def _borashear(d, t):
        downburst(d, 0.50, 0.12, 0.30, 0.74, TEMP)
        # The spread along the ground: impact, not just fall.
        poly(d, [(0.16, 0.74), (0.84, 0.74), (0.72, 0.86), (0.28, 0.86)],
             fill=TEMP_HOT, outline=dark(TEMP_DEEP, 0.3), width=2)

    @art("tempest_boramaelstrom")
    def _boramaelstrom(d, t):
        downburst(d, 0.50, 0.06, 0.34, 0.70, TEMP_DEEP)
        downburst(d, 0.50, 0.10, 0.20, 0.66, TEMP)
        poly(d, [(0.10, 0.70), (0.90, 0.70), (0.74, 0.90), (0.26, 0.90)],
             fill=TEMP_HOT, outline=dark(TEMP_DEEP, 0.3), width=3)

    # ------------------------------------------------------------------ Calm
    #
    # The eye. A clear ring with weather packed around it — the support body,
    # and the one Tempest emblem whose subject is an ABSENCE of storm.

    def eye(d, cx, cy, r, col):
        circle(d, cx, cy, r, fill=col, outline=dark(TEMP_DEEP, 0.3), width=3)
        circle(d, cx, cy, r * 0.46, fill=PANEL, outline=dark(TEMP_DEEP, 0.2),
               width=2)

    @art("tempest_calmsile")
    def _calmsile(d, t):
        eye(d, 0.50, 0.54, 0.27, TEMP)

    @art("tempest_calmgale")
    def _calmgale(d, t):
        eye(d, 0.50, 0.52, 0.33, TEMP)
        # Two arms of the wall, so the ring reads as weather rather than a coin.
        poly(d, [(0.17, 0.30), (0.42, 0.20), (0.36, 0.32), (0.20, 0.40)],
             fill=TEMP_HOT)
        poly(d, [(0.83, 0.74), (0.58, 0.84), (0.64, 0.72), (0.80, 0.64)],
             fill=TEMP_HOT)

    # -------------------------------------------------------------- supports

    @art("tempest_front_line")
    def _front_line(d, t):
        front(d, 0.62, TEMP, TEMP_HOT)

    @art("tempest_updraft")
    def _updraft(d, t):
        gust(d, 0.50, 0.88, 0.50, 0.14, 0.13, TEMP_HOT)

    @art("tempest_earthing")
    def _earthing(d, t):
        # A rod taking the strike: one closed figure, bolt into a grounded bar.
        poly(d, [(0.54, 0.08), (0.34, 0.44), (0.47, 0.44), (0.41, 0.68),
                 (0.66, 0.36), (0.53, 0.36), (0.60, 0.08)],
             fill=TEMP_HOT, outline=dark(TEMP_DEEP, 0.3), width=2)
        rect(d, 0.22, 0.72, 0.78, 0.84, fill=SLATE,
             outline=dark(TEMP_DEEP, 0.3), width=2, radius=0.02)
