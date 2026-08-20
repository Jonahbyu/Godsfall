"""Wilds emblems, registered into make_card_art.py's DRAW table.

Same shape as forge_art.py and tempest_art.py: one function per card id,
coordinates in 0-1 space, drawn onto a prepared backdrop.

Wilds' visual grammar, partitioned up front rather than deduplicated later --
the wave-2 lesson every prior faction paid for. Each chain owns ONE object:

    Grum    -- the layered hide: a thick, scarred pelt shape
    Snarl   -- the bared jaw: a single snapping mouth
    Thrash  -- the coiled limb: a whip-tail caught mid-strike
    Whelp   -- the small tooth: a single fang, young and short
    Boar    -- the tusk: one curved point driving up and out
    Scarl   -- the claw mark: three parallel gouges across the hide
    Gnaw    -- the gnawed bone-end: a stub worried down to a rounded stump
    Reave   -- the talon: one large hooked claw, alone

Distinct from the built colours. Hel is bone-white and vertical, Heaven gold
and radially symmetric, Void a hole with a hot rim, Gaia soft green mounds,
Forge warm and angular, Tempest cool blue and built from motion. Wilds is a
RAW RED-BROWN and built from the animal itself -- teeth, hide, claws -- never
a weapon or a tool, because nothing in this faction is forged or cast. It is
grown.

Two rules the earlier waves paid for, restated because they cost real time
twice already:

  * ONE closed object per emblem. Thin linework (a claw drawn as two lines,
    a tooth as a triangle outline) reads as nothing at 78px.
  * No props competing with the subject for the silhouette. A jaw with teeth
    AND a tongue AND a nose loses all three; a jaw with just the bite line
    reads immediately.

A chain shares a silhouette across its stages: the same shape function called
at successive scales, so the Stage 2 reads as the Basic grown up.
"""


def register(m):
    """Install every Wilds emblem into the host module's DRAW table."""
    art = m.art
    poly, line, circle, ellipse = m.poly, m.line, m.circle, m.ellipse
    rect, arc, star = m.rect, m.line, m.star
    dark, light, mix = m.dark, m.light, m.mix
    P = m.P

    WILD = (143, 122, 74)         # Theme.gd wilds.base
    WILD_HOT = (203, 181, 131)    # bright -- the lit edge, matches wilds.bright
    WILD_DEEP = (74, 61, 31)      # deep -- the shadowed underside, wilds.deep
    BLOOD = (168, 68, 47)         # Ferocity's chip colour -- the rage tint
    BLOOD_HOT = (214, 120, 92)
    HIDE_DARK = (52, 42, 30)

    # ---------------------------------------------------------------- energy

    @art("wilds_energy")
    def _energy(d, t):
        # The faction token: a fang, one closed figure. Matches
        # EnergyIcon.gd's `wilds` case exactly -- one broad tooth, tapering
        # down to a point. Kept identical to the in-game hex mark so the
        # card art and the cost icon read as the same faction at a glance.
        poly(d, [(0.30, 0.10), (0.70, 0.10), (0.62, 0.42), (0.54, 0.72),
                 (0.50, 0.92), (0.46, 0.72), (0.38, 0.42)],
             fill=WILD_HOT, outline=dark(WILD_DEEP, 0.3), width=3)

    # ------------------------------------------------------------------ Grum
    #
    # The layered hide. A thick pelt shape built from overlapping scarred
    # bands -- Molt's chain, so the body has to read as something that has
    # been torn open and closed again more than once.

    def hide(d, cx, cy, w, h, col, scars=2):
        # A pelt, unmistakably: a ragged, torn-edge silhouette rather than a
        # smooth polygon. The FIRST draft of this shape was a rounded
        # asymmetric mass and it read as a rock or a box at every size --
        # the torn border is what makes something read as skin rather than
        # as stone, and it is the single thing this redraw adds.
        pts = [
            (cx - w * 0.95, cy - h * 0.10), (cx - w * 0.55, cy - h * 0.55),
            (cx - w * 0.70, cy - h * 0.70), (cx - w * 0.20, cy - h * 0.95),
            (cx - w * 0.05, cy - h * 0.72), (cx + w * 0.35, cy - h * 0.88),
            (cx + w * 0.30, cy - h * 0.58), (cx + w * 0.80, cy - h * 0.60),
            (cx + w * 0.62, cy - h * 0.20), (cx + w * 0.98, cy + h * 0.10),
            (cx + w * 0.68, cy + h * 0.35), (cx + w * 0.82, cy + h * 0.72),
            (cx + w * 0.30, cy + h * 0.60), (cx + w * 0.20, cy + h * 0.95),
            (cx - w * 0.15, cy + h * 0.68), (cx - w * 0.55, cy + h * 0.85),
            (cx - w * 0.45, cy + h * 0.45), (cx - w * 0.85, cy + h * 0.45),
        ]
        poly(d, pts, fill=col, outline=dark(WILD_DEEP, 0.3), width=3)
        # The lit ridge along the top, so the mass reads as having a source
        # of light rather than as a flat sticker.
        poly(d, [(cx - w * 0.30, cy - h * 0.55), (cx + w * 0.05, cy - h * 0.72),
                  (cx + w * 0.30, cy - h * 0.40), (cx - w * 0.05, cy - h * 0.30)],
             fill=light(col, 0.30))
        # Scar lines -- thick enough to survive downscale, never thin strokes.
        for i in range(scars):
            sx = cx - w * 0.25 + i * w * 0.5
            poly(d, [(sx - w * 0.05, cy - h * 0.20), (sx + w * 0.05, cy - h * 0.24),
                     (sx + w * 0.10, cy + h * 0.42), (sx, cy + h * 0.46)],
                 fill=dark(col, 0.45))

    @art("wilds_grumgrub")
    def _grumgrub(d, t):
        hide(d, 0.50, 0.56, 0.30, 0.26, WILD, scars=1)

    @art("wilds_grummaw")
    def _grummaw(d, t):
        hide(d, 0.50, 0.54, 0.36, 0.32, WILD, scars=2)

    @art("wilds_grumbrute")
    def _grumbrute(d, t):
        hide(d, 0.50, 0.52, 0.42, 0.38, WILD, scars=3)
        hide(d, 0.50, 0.52, 0.20, 0.18, WILD_HOT, scars=0)

    # ----------------------------------------------------------------- Snarl
    #
    # The bared jaw. A single open mouth, the bite line as the only interior
    # detail -- Ferocity's clean teach, so the shape has to say "counting
    # kills" without any other reading available.

    def jaw(d, cx, cy, w, h, col, teeth=3):
        # An open V-shaped bite, built from TWO overlapping wedges (upper jaw,
        # lower jaw) rather than one blob split by a line -- the earlier
        # version read as a rounded box with scratches, because a single
        # closed silhouette can't say "open" no matter how the interior is
        # decorated. Two wedges meeting at a point IS the open-mouth shape.
        # Upper jaw: wide at the back, narrowing to the snout tip.
        poly(d, [
            (cx - w, cy - h * 0.75), (cx + w * 0.75, cy - h * 0.55),
            (cx + w, cy - h * 0.15), (cx - w * 0.15, cy - h * 0.02),
            (cx - w * 0.85, cy - h * 0.20),
        ], fill=col, outline=dark(WILD_DEEP, 0.3), width=3)
        # Lower jaw: mirrored, so the two together form the open bite.
        poly(d, [
            (cx - w * 0.85, cy + h * 0.20), (cx - w * 0.15, cy + h * 0.02),
            (cx + w, cy + h * 0.15), (cx + w * 0.75, cy + h * 0.55),
            (cx - w, cy + h * 0.75),
        ], fill=dark(col, 0.18), outline=dark(WILD_DEEP, 0.3), width=3)
        # Teeth: bold triangles along BOTH edges of the gap, large enough to
        # survive downscale -- three or four is plenty, more just muddies.
        n = max(2, min(teeth, 4))
        for i in range(n):
            tt = i / (n - 1) if n > 1 else 0.5
            tx = cx - w * 0.55 + tt * w * 1.05
            # Upper tooth, pointing down into the gap.
            poly(d, [(tx - w * 0.07, cy - h * 0.10), (tx + w * 0.07, cy - h * 0.10),
                      (tx, cy + h * 0.10)], fill=WILD_HOT)
            # Lower tooth, pointing up into the gap, offset so they interlock.
            poly(d, [(tx + w * 0.10, cy + h * 0.12), (tx + w * 0.24, cy + h * 0.12),
                      (tx + w * 0.17, cy - h * 0.06)], fill=WILD_HOT)

    @art("wilds_snarlcub")
    def _snarlcub(d, t):
        jaw(d, 0.50, 0.56, 0.30, 0.24, WILD, teeth=2)

    @art("wilds_snarlhide")
    def _snarlhide(d, t):
        jaw(d, 0.50, 0.54, 0.36, 0.30, WILD, teeth=3)

    @art("wilds_snarlravager")
    def _snarlravager(d, t):
        jaw(d, 0.50, 0.52, 0.42, 0.36, WILD, teeth=4)
        # The rage tint: a single stroke of blood-red along the bite line,
        # the tally the keyword's flavour is built on.
        line(d, [(0.10, 0.60), (0.86, 0.40)], fill=BLOOD, width=int(0.02 * 512))

    # ---------------------------------------------------------------- Thrash
    #
    # The coiled limb. A whip-tail caught mid-strike -- the combo chain, so
    # the shape has to read as motion that has already happened and is about
    # to happen again, which is what Molt-feeding-Ferocity IS.

    def whip(d, cx, cy, r, turns, col):
        import math
        # Built the same way Cirr's curl is in tempest_art.py -- a filled
        # crescent along a spiral path, never a drawn line, because a thin
        # stroke is exactly what vanishes at board size.
        pts = []
        steps = 30
        for i in range(steps + 1):
            tt = i / steps
            a = 0.4 + turns * 4.6 * tt
            rad = r * (0.22 + 0.78 * tt)
            pts.append((cx + rad * math.cos(a), cy + rad * math.sin(a)))
        back = []
        for i in range(steps + 1):
            tt = i / steps
            a = 0.4 + turns * 4.6 * tt
            rad = r * (0.22 + 0.78 * tt) - r * (0.16 + 0.22 * tt)
            back.append((cx + rad * math.cos(a), cy + rad * math.sin(a)))
        poly(d, pts + back[::-1], fill=col, outline=dark(WILD_DEEP, 0.25), width=2)
        # A barb at the tip -- the strike end, so the whip has a direction.
        tip = pts[-1]
        poly(d, [tip, (tip[0] + r * 0.16, tip[1] - r * 0.10),
                  (tip[0] + r * 0.06, tip[1] + r * 0.14)], fill=light(col, 0.3))

    @art("wilds_thrashrunt")
    def _thrashrunt(d, t):
        whip(d, 0.48, 0.56, 0.30, 0.62, WILD)

    @art("wilds_thrashfang")
    def _thrashfang(d, t):
        whip(d, 0.48, 0.54, 0.36, 0.78, WILD)
        whip(d, 0.48, 0.54, 0.16, 0.60, BLOOD)

    @art("wilds_thrashwarden")
    def _thrashwarden(d, t):
        whip(d, 0.48, 0.52, 0.42, 0.94, WILD_DEEP)
        whip(d, 0.48, 0.52, 0.30, 0.84, WILD)
        whip(d, 0.48, 0.52, 0.14, 0.60, BLOOD_HOT)

    # ----------------------------------------------------------------- Whelp
    #
    # The small tooth. A single fang, young and short -- fodder, so the
    # shape is deliberately the smallest, plainest object in the set.

    def milk_tooth(d, cx, cy, w, h, col):
        poly(d, [(cx - w * 0.5, cy - h * 0.6), (cx + w * 0.5, cy - h * 0.6),
                  (cx + w * 0.30, cy + h * 0.3), (cx, cy + h),
                  (cx - w * 0.30, cy + h * 0.3)],
             fill=col, outline=dark(WILD_DEEP, 0.3), width=2)

    @art("wilds_whelpgrub")
    def _whelpgrub(d, t):
        milk_tooth(d, 0.50, 0.56, 0.20, 0.28, WILD_HOT)

    @art("wilds_whelprunt")
    def _whelprunt(d, t):
        milk_tooth(d, 0.42, 0.58, 0.18, 0.26, WILD_HOT)
        milk_tooth(d, 0.62, 0.52, 0.16, 0.22, WILD)

    # ------------------------------------------------------------------ Boar
    #
    # The tusk. One curved point driving up and out -- the vanilla-into-
    # Ferocity chain, so the Basic is unadorned and the Stage 1 adds the
    # second tusk that makes the pair.

    def tusk(d, cx, cy, w, h, col, mirror=False):
        # mirror=True flips the WHOLE shape left-right around cx, rather than
        # negating one offset inside an otherwise unmirrored point list --
        # the earlier version did the latter and the tip ended up on the
        # wrong side of the curve, so a "pair" of tusks collided into one
        # smear instead of forming a matched set either side of a gap.
        s = -1.0 if mirror else 1.0
        poly(d, [
            (cx - w * 0.2 * s, cy + h), (cx + w * 0.2 * s, cy + h * 0.9),
            (cx + w * 0.5 * s, cy + h * 0.2), (cx + w * 0.7 * s, cy - h * 0.5),
            (cx + w * 0.55 * s, cy - h * 0.86), (cx + w * 0.30 * s, cy - h * 0.62),
            (cx + w * 0.30 * s, cy - h * 0.10), (cx, cy + h * 0.55),
        ], fill=col, outline=dark(WILD_DEEP, 0.3), width=3)
        # The lit face along the outer curve.
        poly(d, [(cx + w * 0.10 * s, cy - h * 0.10), (cx + w * 0.42 * s, cy - h * 0.60),
                  (cx + w * 0.55 * s, cy - h * 0.80), (cx + w * 0.30 * s, cy - h * 0.30)],
             fill=light(col, 0.28))

    @art("wilds_boargrub")
    def _boargrub(d, t):
        tusk(d, 0.50, 0.62, 0.26, 0.36, WILD)

    @art("wilds_boarhide")
    def _boarhide(d, t):
        # A matched pair either side of a real gap, mirrored properly and
        # spaced so neither tip crosses into the other's silhouette.
        tusk(d, 0.30, 0.64, 0.22, 0.34, WILD, mirror=False)
        tusk(d, 0.70, 0.64, 0.22, 0.34, WILD, mirror=True)

    # ----------------------------------------------------------------- Scarl
    #
    # The claw mark. Three parallel gouges across the hide -- Molt's utility
    # chain, so the mark is what a body carries FORWARD through the return,
    # not the body itself.

    def claw_mark(d, cx, cy, w, h, col, strokes=3):
        for i in range(strokes):
            off = (i - (strokes - 1) / 2.0) * w * 0.42
            poly(d, [
                (cx + off - w * 0.10, cy - h), (cx + off + w * 0.10, cy - h * 0.92),
                (cx + off + w * 0.16, cy + h * 0.7), (cx + off - w * 0.02, cy + h),
                (cx + off - w * 0.18, cy + h * 0.62),
            ], fill=col if i % 2 == 0 else dark(col, 0.30),
               outline=dark(WILD_DEEP, 0.25), width=2)

    @art("wilds_scarlcub")
    def _scarlcub(d, t):
        claw_mark(d, 0.50, 0.54, 0.30, 0.34, WILD_HOT, strokes=3)

    @art("wilds_scarlfang")
    def _scarlfang(d, t):
        claw_mark(d, 0.50, 0.52, 0.34, 0.38, WILD_HOT, strokes=3)
        # A drop of the rage tint at the base -- the second stage has drawn
        # blood, not just skin.
        circle(d, 0.50, 0.86, 0.05, fill=BLOOD)

    # ------------------------------------------------------------------ Gnaw
    #
    # The gnawed bone-end. A stub worried down to a rounded stump -- the wide
    # Ferocity chain, several cheap bodies rather than one tall investment,
    # so the object itself is small and worked-over rather than dramatic.

    def gnawed_stub(d, cx, cy, w, h, col):
        poly(d, [(cx - w * 0.4, cy - h), (cx + w * 0.4, cy - h),
                  (cx + w * 0.5, cy - h * 0.3), (cx + w * 0.30, cy + h * 0.5),
                  (cx - w * 0.30, cy + h * 0.5), (cx - w * 0.5, cy - h * 0.3)],
             fill=col, outline=dark(WILD_DEEP, 0.3), width=3)
        # Worried bite marks along both edges -- the "gnawed" part, kept as
        # small triangular notches rather than separate teeth objects.
        for sx in (cx - w * 0.42, cx + w * 0.42):
            poly(d, [(sx, cy - h * 0.1), (sx + (0.06 * w if sx < cx else -0.06 * w), cy - h * 0.02),
                      (sx, cy + h * 0.08)], fill=dark(col, 0.4))
        circle(d, cx, cy + h * 0.62, w * 0.22, fill=light(col, 0.25))

    @art("wilds_gnawwhelp")
    def _gnawwhelp(d, t):
        gnawed_stub(d, 0.50, 0.56, 0.26, 0.28, WILD)

    @art("wilds_gnawtusk")
    def _gnawtusk(d, t):
        gnawed_stub(d, 0.50, 0.54, 0.32, 0.34, WILD)
        circle(d, 0.50, 0.60, 0.06, fill=BLOOD)

    # ------------------------------------------------------------------ Reave
    #
    # The talon. One large hooked claw, alone -- the finisher, so it is the
    # single biggest and simplest object in the whole faction.

    def talon(d, cx, cy, w, h, col):
        poly(d, [
            (cx - w * 0.30, cy + h), (cx - w * 0.10, cy + h * 0.30),
            (cx + w * 0.05, cy - h * 0.40), (cx + w * 0.42, cy - h),
            (cx + w * 0.24, cy - h * 0.55), (cx + w * 0.06, cy - h * 0.05),
            (cx - w * 0.02, cy + h * 0.55),
        ], fill=col, outline=dark(WILD_DEEP, 0.3), width=3)
        poly(d, [(cx + w * 0.10, cy - h * 0.40), (cx + w * 0.30, cy - h * 0.86),
                  (cx + w * 0.20, cy - h * 0.60), (cx + w * 0.02, cy - h * 0.20)],
             fill=light(col, 0.32))

    @art("wilds_reavegrub")
    def _reavegrub(d, t):
        talon(d, 0.48, 0.58, 0.22, 0.30, WILD)

    @art("wilds_reavehide")
    def _reavehide(d, t):
        talon(d, 0.48, 0.56, 0.28, 0.38, WILD)

    @art("wilds_reavereaver")
    def _reavereaver(d, t):
        talon(d, 0.48, 0.54, 0.36, 0.48, WILD_DEEP)
        talon(d, 0.46, 0.50, 0.22, 0.30, WILD_HOT)

    # ==================================================================
    # EXPANSION (2026-08-20) -- 14 more chains.
    #
    # The grammar is PARTITIONED, not varied: every chain below gets its
    # own object, chosen so no two share a silhouette at 78px. The wave-2
    # lesson, restated because it has cost real time on every faction:
    # "another tooth" and "another hide" identify nothing once a roster is
    # this large, so the objects were assigned before any of them was drawn.
    #
    #   Bristl -- quills: a spined ridge, points outward
    #   Rend   -- the split: a single deep cleft opening
    #   Lurk   -- the swallowing maw: a dark round throat
    #   Nib    -- the chip: a small broken shard
    #   Grond  -- the boulder-shell: a heavy domed carapace
    #   Skitt  -- the many-legged mass: a clustered body
    #   Hoft   -- the hoof: one blunt cloven print
    #   Vorn   -- the paired blade-claws: two hooks crossed
    #   Thorng -- the barb: a hooked thorn, backward-facing
    #   Yelp   -- the small open mouth: a round cry
    #   Mott   -- the slab: a massive squared block of muscle
    #   Gral   -- the horn: one forward-driving spike
    #   Sket   -- the shed husk: a hollow split casing
    #   Crut   -- the notched bone: a shaft with tally marks
    # ==================================================================

    def quills(d, cx, cy, w, h, col, n=5):
        """A spined ridge -- one closed body with points driven out of it."""
        pts = [(cx - w, cy + h * 0.55), (cx - w * 0.86, cy - h * 0.05)]
        for i in range(n):
            f = i / float(n - 1)
            bx = cx - w * 0.80 + w * 1.60 * f
            pts.append((bx - w * 0.10, cy - h * 0.15))
            pts.append((bx, cy - h * (0.72 + 0.26 * (1 - abs(f - 0.5) * 2))))
            pts.append((bx + w * 0.10, cy - h * 0.15))
        pts += [(cx + w * 0.86, cy - h * 0.05), (cx + w, cy + h * 0.55)]
        poly(d, pts, fill=col, outline=dark(WILD_DEEP, 0.35), width=3)
        poly(d, [(cx - w * 0.55, cy + h * 0.10), (cx + w * 0.55, cy + h * 0.10),
                 (cx + w * 0.40, cy + h * 0.44), (cx - w * 0.40, cy + h * 0.44)],
             fill=dark(col, 0.28))

    @art("wilds_bristlgrub")
    def _bristlgrub(d, t):
        quills(d, 0.50, 0.62, 0.20, 0.24, WILD, n=4)

    @art("wilds_bristlhide")
    def _bristlhide(d, t):
        quills(d, 0.50, 0.62, 0.26, 0.30, WILD, n=5)

    @art("wilds_bristlwarden")
    def _bristlwarden(d, t):
        quills(d, 0.50, 0.64, 0.32, 0.36, WILD_DEEP, n=7)
        quills(d, 0.50, 0.60, 0.18, 0.20, WILD_HOT, n=4)

    # ------------------------------------------------------------------

    def cleft(d, cx, cy, w, h, col):
        """A deep split. The GAP is the subject, so the two halves must never
        meet at the top or bottom -- twice now they have, and each time the
        outlines re-closed into one silhouette that read as a shield with a
        stripe. They are now offset VERTICALLY as well as apart, so no pair of
        vertices lines up and the eye reads two separate pieces of one thing."""
        poly(d, [(cx - w * 0.42, cy - h * 0.86), (cx - w * 1.08, cy - h * 0.30),
                 (cx - w * 0.96, cy + h * 0.62), (cx - w * 0.34, cy + h * 1.00)],
             fill=col, outline=dark(WILD_DEEP, 0.35), width=3)
        poly(d, [(cx + w * 0.34, cy - h * 1.00), (cx + w * 0.96, cy - h * 0.62),
                 (cx + w * 1.08, cy + h * 0.30), (cx + w * 0.42, cy + h * 0.86)],
             fill=dark(col, 0.26), outline=dark(WILD_DEEP, 0.35), width=3)

    @art("wilds_rendcub")
    def _rendcub(d, t):
        cleft(d, 0.50, 0.56, 0.18, 0.26, WILD)

    @art("wilds_rendfang")
    def _rendfang(d, t):
        cleft(d, 0.50, 0.56, 0.24, 0.32, WILD)

    @art("wilds_rendravager")
    def _rendravager(d, t):
        cleft(d, 0.50, 0.55, 0.30, 0.40, WILD_DEEP)
        cleft(d, 0.50, 0.55, 0.15, 0.22, BLOOD_HOT)

    # ------------------------------------------------------------------

    def maw(d, cx, cy, r, col):
        """A swallowing throat.

        First draft drew 8 evenly-spaced radial teeth around a ring, which is
        the definition of a COG -- mechanical, and wrong for a faction that is
        grown rather than forged. A throat is identified by DEPTH, so it is
        drawn as an irregular funnel narrowing inward instead."""
        poly(d, [(cx - r, cy - r * 0.52), (cx - r * 0.44, cy - r),
                 (cx + r * 0.50, cy - r * 0.94), (cx + r, cy - r * 0.30),
                 (cx + r * 0.86, cy + r * 0.66), (cx + r * 0.10, cy + r),
                 (cx - r * 0.70, cy + r * 0.74)],
             fill=col, outline=dark(WILD_DEEP, 0.35), width=3)
        poly(d, [(cx - r * 0.62, cy - r * 0.30), (cx - r * 0.22, cy - r * 0.64),
                 (cx + r * 0.34, cy - r * 0.56), (cx + r * 0.62, cy - r * 0.10),
                 (cx + r * 0.50, cy + r * 0.42), (cx - r * 0.04, cy + r * 0.62),
                 (cx - r * 0.46, cy + r * 0.40)],
             fill=dark(col, 0.42))
        poly(d, [(cx - r * 0.30, cy - r * 0.06), (cx + r * 0.06, cy - r * 0.26),
                 (cx + r * 0.30, cy + r * 0.06), (cx + r * 0.10, cy + r * 0.32),
                 (cx - r * 0.20, cy + r * 0.24)],
             fill=dark(HIDE_DARK, 0.6))

    @art("wilds_lurkgrub")
    def _lurkgrub(d, t):
        maw(d, 0.50, 0.56, 0.22, WILD)

    @art("wilds_lurkmaw")
    def _lurkmaw(d, t):
        maw(d, 0.50, 0.56, 0.28, WILD)

    @art("wilds_lurkbrute")
    def _lurkbrute(d, t):
        maw(d, 0.50, 0.55, 0.34, WILD_DEEP)
        maw(d, 0.50, 0.55, 0.18, WILD_HOT)

    # ------------------------------------------------------------------

    def shard(d, cx, cy, w, h, col):
        """A small broken chip -- one angular closed fragment."""
        poly(d, [(cx - w * 0.20, cy - h), (cx + w * 0.72, cy - h * 0.34),
                 (cx + w * 0.34, cy + h * 0.62), (cx - w * 0.80, cy + h * 0.86),
                 (cx - w * 0.92, cy - h * 0.10)],
             fill=col, outline=dark(WILD_DEEP, 0.35), width=3)
        poly(d, [(cx - w * 0.18, cy - h * 0.80), (cx + w * 0.44, cy - h * 0.28),
                 (cx - w * 0.10, cy + h * 0.10)], fill=light(col, 0.38))

    @art("wilds_nibgrub")
    def _nibgrub(d, t):
        shard(d, 0.50, 0.58, 0.20, 0.24, WILD)

    @art("wilds_nibrunt")
    def _nibrunt(d, t):
        shard(d, 0.50, 0.57, 0.22, 0.27, WILD_HOT)

    # ------------------------------------------------------------------

    def carapace(d, cx, cy, w, h, col):
        """A heavy domed shell -- broad, low, plated."""
        poly(d, [(cx - w, cy + h * 0.60), (cx - w * 0.90, cy - h * 0.12),
                 (cx - w * 0.52, cy - h * 0.78), (cx, cy - h),
                 (cx + w * 0.52, cy - h * 0.78), (cx + w * 0.90, cy - h * 0.12),
                 (cx + w, cy + h * 0.60)],
             fill=col, outline=dark(WILD_DEEP, 0.35), width=3)
        ## Overlapping PLATES, not vertical bars: bars inside a dome read as
        ## a cage. Each plate is a shallow band stepping up the shell.
        for i, f in enumerate((0.46, 0.06, -0.34)):
            sw = 0.94 - i * 0.22
            poly(d, [(cx - w * sw, cy + h * f),
                     (cx + w * sw, cy + h * (f - 0.04)),
                     (cx + w * (sw - 0.10), cy + h * (f - 0.34)),
                     (cx - w * (sw - 0.10), cy + h * (f - 0.30))],
                 fill=dark(col, 0.20 + i * 0.10))

    @art("wilds_grondcub")
    def _grondcub(d, t):
        carapace(d, 0.50, 0.60, 0.22, 0.20, WILD)

    @art("wilds_grondtusk")
    def _grondtusk(d, t):
        carapace(d, 0.50, 0.60, 0.28, 0.25, WILD)

    @art("wilds_grondbrute")
    def _grondbrute(d, t):
        carapace(d, 0.50, 0.62, 0.35, 0.31, WILD_DEEP)
        carapace(d, 0.50, 0.58, 0.19, 0.17, WILD_HOT)

    # ------------------------------------------------------------------

    def cluster(d, cx, cy, r, col):
        """A many-bodied mass -- overlapping rounds, never one clean circle."""
        ## Spread far enough that the rounds do not merge into one blob, and
        ## spiked outward so the silhouette reads as MANY bodies rather than
        ## as a single lumpy one.
        for dx, dy, s in ((-1.05, 0.42, 0.50), (1.05, 0.42, 0.50),
                          (-0.72, -0.62, 0.42), (0.72, -0.62, 0.42),
                          (0.0, 0.02, 0.82)):
            bx, by = cx + r * dx, cy + r * dy
            for ang in (-0.9, -0.3, 0.3, 0.9):
                poly(d, [(bx - r * 0.10, by), (bx + r * 0.10, by),
                         (bx + r * (s + 0.55) * ang, by + r * (s + 0.60))],
                     fill=dark(col, 0.35))
            circle(d, bx, by, r * s,
                   fill=col if s < 0.8 else light(col, 0.25),
                   outline=dark(WILD_DEEP, 0.35), width=3)

    @art("wilds_skittgrub")
    def _skittgrub(d, t):
        cluster(d, 0.50, 0.58, 0.16, WILD)

    @art("wilds_skittwhelp")
    def _skittwhelp(d, t):
        cluster(d, 0.50, 0.58, 0.18, WILD_HOT)

    @art("wilds_skittfang")
    def _skittfang(d, t):
        cluster(d, 0.50, 0.57, 0.23, WILD)

    # ------------------------------------------------------------------

    def hoof(d, cx, cy, w, h, col):
        """One blunt cloven print -- two lobes with a gap between them."""
        ## WEDGES, not rectangles: narrow at the top, splayed and rounded at
        ## the ground. Straight-sided quads read as two plain bars.
        for s in (-1.0, 1.0):
            poly(d, [(cx + s * w * 0.10, cy - h * 0.92),
                     (cx + s * w * 0.46, cy - h * 0.66),
                     (cx + s * w * 0.96, cy + h * 0.34),
                     (cx + s * w * 0.72, cy + h * 0.92),
                     (cx + s * w * 0.18, cy + h * 0.86)],
                 fill=col, outline=dark(WILD_DEEP, 0.35), width=3)

    @art("wilds_hoftgrub")
    def _hoftgrub(d, t):
        hoof(d, 0.50, 0.56, 0.20, 0.26, WILD)

    @art("wilds_hofthide")
    def _hofthide(d, t):
        hoof(d, 0.50, 0.56, 0.26, 0.32, WILD_HOT)

    # ------------------------------------------------------------------

    def hook_blade(d, cx, cy, w, h, col, s=1.0):
        """A broad hooked claw. Deliberately NOT a reuse of Reave's talon():
        that shape is slender by design, and at Vorn's paired widths two of
        them read as thin scratches rather than as claws. This one is wide-
        bellied, so it survives being drawn twice at half size."""
        poly(d, [
            (cx - s * w * 0.55, cy + h * 0.95), (cx - s * w * 0.16, cy + h * 0.10),
            (cx + s * w * 0.20, cy - h * 0.60), (cx + s * w * 0.86, cy - h * 0.98),
            (cx + s * w * 0.44, cy - h * 0.30), (cx + s * w * 0.30, cy + h * 0.36),
            (cx + s * w * 0.10, cy + h * 0.95),
        ], fill=col, outline=dark(WILD_DEEP, 0.35), width=3)
        poly(d, [(cx + s * w * 0.10, cy - h * 0.42), (cx + s * w * 0.60, cy - h * 0.82),
                 (cx + s * w * 0.30, cy - h * 0.28), (cx + s * w * 0.06, cy + h * 0.24)],
             fill=light(col, 0.34))

    @art("wilds_vorncub")
    def _vorncub(d, t):
        hook_blade(d, 0.34, 0.56, 0.24, 0.28, WILD, s=1.0)
        hook_blade(d, 0.66, 0.56, 0.24, 0.28, WILD, s=-1.0)

    @art("wilds_vornfang")
    def _vornfang(d, t):
        hook_blade(d, 0.32, 0.56, 0.30, 0.34, WILD, s=1.0)
        hook_blade(d, 0.68, 0.56, 0.30, 0.34, WILD, s=-1.0)

    @art("wilds_vornreaver")
    def _vornreaver(d, t):
        hook_blade(d, 0.30, 0.58, 0.34, 0.40, WILD_DEEP, s=1.0)
        hook_blade(d, 0.70, 0.58, 0.34, 0.40, WILD_DEEP, s=-1.0)
        hook_blade(d, 0.50, 0.50, 0.22, 0.28, BLOOD_HOT, s=1.0)

    # ------------------------------------------------------------------

    def barb(d, cx, cy, w, h, col):
        """A hooked thorn -- the hook curls BACK, which is what makes it a barb."""
        poly(d, [(cx - w * 0.18, cy + h), (cx - w * 0.06, cy - h * 0.20),
                 (cx + w * 0.34, cy - h), (cx + w * 0.10, cy - h * 0.16),
                 (cx + w * 0.62, cy - h * 0.02), (cx + w * 0.16, cy + h * 0.18),
                 (cx + w * 0.20, cy + h)],
             fill=col, outline=dark(WILD_DEEP, 0.35), width=3)

    @art("wilds_thornggrub")
    def _thornggrub(d, t):
        barb(d, 0.50, 0.56, 0.20, 0.26, WILD)

    @art("wilds_thornghide")
    def _thornghide(d, t):
        barb(d, 0.50, 0.56, 0.25, 0.32, WILD)

    @art("wilds_thorngwarden")
    def _thorngwarden(d, t):
        barb(d, 0.44, 0.58, 0.28, 0.36, WILD_DEEP)
        barb(d, 0.60, 0.52, 0.18, 0.24, BLOOD_HOT)

    # ------------------------------------------------------------------

    def cry(d, cx, cy, r, col):
        """A small open mouth -- a round hole ringed by body. Deliberately
        SMALLER and rounder than Lurk's maw, and toothless, so the two do not
        collide: this one is a noise, that one is a throat."""
        ellipse(d, cx - r, cy - r * 1.15, cx + r, cy + r * 1.15,
                fill=col, outline=dark(WILD_DEEP, 0.35), width=3)
        ellipse(d, cx - r * 0.48, cy - r * 0.62, cx + r * 0.48, cy + r * 0.72,
                fill=dark(HIDE_DARK, 0.5))

    @art("wilds_yelpgrub")
    def _yelpgrub(d, t):
        cry(d, 0.50, 0.57, 0.17, WILD)

    @art("wilds_yelprunt")
    def _yelprunt(d, t):
        cry(d, 0.50, 0.57, 0.19, WILD_HOT)

    @art("wilds_yelpfang")
    def _yelpfang(d, t):
        cry(d, 0.50, 0.56, 0.23, WILD)

    # ------------------------------------------------------------------

    def slab(d, cx, cy, w, h, col):
        """A squared block of muscle -- the biggest, bluntest shape in the set."""
        poly(d, [(cx - w, cy - h * 0.78), (cx + w, cy - h * 0.90),
                 (cx + w * 0.94, cy + h * 0.92), (cx - w * 0.94, cy + h * 0.80)],
             fill=col, outline=dark(WILD_DEEP, 0.35), width=3)
        ## A lit TOP face, not a centered inset panel: an inset inside a quad
        ## is a picture frame, which is exactly how the first draft read. The
        ## top face makes it a solid block seen slightly from above.
        poly(d, [(cx - w, cy - h * 0.78), (cx + w, cy - h * 0.90),
                 (cx + w * 0.80, cy - h * 0.42), (cx - w * 0.84, cy - h * 0.30)],
             fill=light(col, 0.30))
        ## One deep seam across the mass, so it has grain rather than being flat.
        poly(d, [(cx - w * 0.90, cy + h * 0.22), (cx + w * 0.92, cy + h * 0.14),
                 (cx + w * 0.92, cy + h * 0.34), (cx - w * 0.90, cy + h * 0.42)],
             fill=dark(col, 0.34))

    @art("wilds_mottgrub")
    def _mottgrub(d, t):
        slab(d, 0.50, 0.58, 0.22, 0.22, WILD)

    @art("wilds_motttusk")
    def _motttusk(d, t):
        slab(d, 0.50, 0.58, 0.28, 0.27, WILD)

    @art("wilds_mottbrute")
    def _mottbrute(d, t):
        slab(d, 0.50, 0.58, 0.35, 0.33, WILD_DEEP)
        slab(d, 0.50, 0.55, 0.19, 0.18, WILD_HOT)

    # ------------------------------------------------------------------

    def horn(d, cx, cy, w, h, col):
        """One forward-driving spike -- straight where Boar's tusk curves."""
        poly(d, [(cx - w * 0.62, cy + h), (cx - w * 0.30, cy + h * 0.86),
                 (cx + w * 0.72, cy - h), (cx + w * 0.20, cy + h * 0.44),
                 (cx + w * 0.06, cy + h)],
             fill=col, outline=dark(WILD_DEEP, 0.35), width=3)
        poly(d, [(cx - w * 0.10, cy + h * 0.62), (cx + w * 0.54, cy - h * 0.72),
                 (cx + w * 0.18, cy + h * 0.30)], fill=light(col, 0.34))

    @art("wilds_gralcub")
    def _gralcub(d, t):
        horn(d, 0.48, 0.58, 0.20, 0.26, WILD)

    @art("wilds_gralmaw")
    def _gralmaw(d, t):
        horn(d, 0.48, 0.58, 0.26, 0.32, WILD)

    @art("wilds_gralravager")
    def _gralravager(d, t):
        horn(d, 0.44, 0.60, 0.30, 0.38, WILD_DEEP)
        horn(d, 0.56, 0.54, 0.20, 0.26, BLOOD_HOT)

    # ------------------------------------------------------------------

    def husk(d, cx, cy, w, h, col):
        """A hollow split casing -- the shed skin itself, open down one side."""
        poly(d, [(cx - w * 0.10, cy - h), (cx - w * 0.92, cy - h * 0.32),
                 (cx - w * 0.78, cy + h * 0.80), (cx + w * 0.02, cy + h),
                 (cx + w * 0.24, cy + h * 0.30), (cx - w * 0.12, cy - h * 0.30)],
             fill=col, outline=dark(WILD_DEEP, 0.35), width=3)
        poly(d, [(cx + w * 0.16, cy - h * 0.86), (cx + w * 0.90, cy - h * 0.20),
                 (cx + w * 0.82, cy + h * 0.72), (cx + w * 0.30, cy + h * 0.40)],
             fill=dark(col, 0.30), outline=dark(WILD_DEEP, 0.35), width=3)

    @art("wilds_sketgrub")
    def _sketgrub(d, t):
        husk(d, 0.50, 0.57, 0.20, 0.26, WILD)

    @art("wilds_skethide")
    def _skethide(d, t):
        husk(d, 0.50, 0.57, 0.26, 0.32, WILD_HOT)

    # ------------------------------------------------------------------

    def tally_bone(d, cx, cy, w, h, col, marks=4):
        """A shaft cut with tally marks -- the counter, made an object."""
        poly(d, [(cx - w * 0.26, cy - h), (cx + w * 0.26, cy - h),
                 (cx + w * 0.30, cy + h), (cx - w * 0.30, cy + h)],
             fill=col, outline=dark(WILD_DEEP, 0.35), width=3)
        for i in range(marks):
            f = -0.62 + (1.24 / max(1, marks - 1)) * i if marks > 1 else 0.0
            poly(d, [(cx - w * 0.30, cy + h * f),
                     (cx + w * 0.30, cy + h * (f - 0.06)),
                     (cx + w * 0.30, cy + h * (f + 0.10)),
                     (cx - w * 0.30, cy + h * (f + 0.16))],
                 fill=dark(col, 0.42))

    @art("wilds_crutgrub")
    def _crutgrub(d, t):
        tally_bone(d, 0.50, 0.56, 0.15, 0.26, WILD, marks=3)

    @art("wilds_crutcub")
    def _crutcub(d, t):
        tally_bone(d, 0.50, 0.56, 0.16, 0.28, WILD_HOT, marks=4)

    @art("wilds_cruttusk")
    def _cruttusk(d, t):
        tally_bone(d, 0.50, 0.55, 0.19, 0.34, WILD, marks=6)

    # -------------------------------------------------------------- supports

    @art("wilds_second_skin")
    def _second_skin(d, t):
        # A hide draped rather than worn -- borrowed, the card's own text.
        hide(d, 0.50, 0.56, 0.32, 0.26, WILD_HOT, scars=0)

    @art("wilds_cull_the_weak")
    def _cull_the_weak(d, t):
        talon(d, 0.50, 0.56, 0.26, 0.34, BLOOD)

    @art("wilds_running_wound")
    def _running_wound(d, t):
        claw_mark(d, 0.50, 0.54, 0.24, 0.30, BLOOD_HOT, strokes=1)

    @art("wilds_stampede")
    def _stampede(d, t):
        # Several tusks in a row -- many bodies, one shared surge, matching
        # the card's board-wide reach without introducing a new object.
        for i, cx in enumerate((0.28, 0.50, 0.72)):
            tusk(d, cx, 0.62, 0.14, 0.24, WILD if i != 1 else WILD_HOT)

    @art("wilds_shed_the_skin")
    def _shed_the_skin(d, t):
        # A hide with the ridge doubled, mid-shed: one shape peeling from
        # another, which is the card's whole effect.
        hide(d, 0.50, 0.58, 0.26, 0.20, WILD_DEEP, scars=0)
        hide(d, 0.46, 0.50, 0.24, 0.20, WILD_HOT, scars=0)

    @art("wilds_trophy_rack")
    def _trophy_rack(d, t):
        # Several talons mounted together -- a rack is a COLLECTION of the
        # kills it reads, which is the card's printed rule-break.
        talon(d, 0.32, 0.60, 0.14, 0.24, WILD)
        talon(d, 0.50, 0.54, 0.16, 0.30, WILD_HOT)
        talon(d, 0.68, 0.60, 0.14, 0.24, WILD)
