"""Forge emblems, registered into make_card_art.py's DRAW table.

Same shape as bestiary_art.py / bestiary_art2.py: one function per card id,
coordinates in 0-1 space, drawn onto a prepared backdrop.

Forge's visual grammar, partitioned up front rather than deduplicated later --
the wave-2 lesson. Each chain owns ONE object and no other chain reuses it:

    Cind    -- the flame itself, growing from spark to pyre
    Slag    -- the crucible / pouring vessel
    Grist   -- the hammer, and what it comes down on
    Emb     -- the radiating burst (cleave made visible)
    Quench  -- the trough and the rising steam

The other four factions are cold: Hel is bone, Heaven gold and radial, Void an
absence with a rim, Gaia soft green mounds. Forge is the only warm colour, so
its emblems lean on the ORANGE and on hard angular silhouettes -- struck metal,
never organic curves.

A chain shares a silhouette across its stages: the same shape function called at
successive scales, so the Stage 2 reads as the Basic grown up. Drawing each stage
independently is what lets a chain drift apart, which the evolution read cannot
survive.
"""


def register(m):
    """Install every Forge emblem into the host module's DRAW table."""
    art = m.art
    poly, line, circle, ellipse = m.poly, m.line, m.circle, m.ellipse
    rect, arc, star, hexagon = m.rect, m.arc, m.star, m.hexagon
    dark, light, mix = m.dark, m.light, m.mix
    P = m.P
    GOLD, BONE, PANEL, RUST = m.GOLD, m.BONE, m.PANEL, m.RUST

    FORGE = (224, 122, 60)        # Theme.gd forge.base
    FORGE_HOT = (255, 179, 122)   # forge.bright
    FORGE_DEEP = (122, 51, 18)    # forge.deep
    IRON = (86, 82, 92)

    # ---------------------------------------------------------- shared shapes

    def flame(d, cx, cy, r, col=FORGE, core=FORGE_HOT):
        """A leaning teardrop with a hot core. One closed figure -- a flame is
        identified by its outline, so it must never be drawn as linework."""
        outer = [
            (cx, cy - r * 1.05), (cx + r * 0.44, cy - r * 0.34),
            (cx + r * 0.60, cy + r * 0.28), (cx + r * 0.27, cy + r * 0.80),
            (cx - r * 0.24, cy + r * 0.84), (cx - r * 0.58, cy + r * 0.34),
            (cx - r * 0.38, cy - r * 0.24), (cx - r * 0.12, cy - r * 0.58),
        ]
        poly(d, outer, fill=col, outline=dark(col, 0.35), width=3)
        inner = [
            (cx, cy - r * 0.44), (cx + r * 0.26, cy + r * 0.06),
            (cx + r * 0.14, cy + r * 0.52), (cx - r * 0.16, cy + r * 0.50),
            (cx - r * 0.28, cy + r * 0.04),
        ]
        poly(d, inner, fill=core)

    def anvil(d, cx, cy, w, h, col=IRON):
        """The classic anvil silhouette: horn, waist, splayed foot."""
        top = cy - h * 0.5
        poly(d, [
            (cx - w * 0.46, top), (cx + w * 0.34, top),
            (cx + w * 0.62, top + h * 0.16), (cx + w * 0.34, top + h * 0.26),
            (cx + w * 0.20, top + h * 0.30), (cx + w * 0.14, top + h * 0.72),
            (cx + w * 0.40, cy + h * 0.5), (cx - w * 0.44, cy + h * 0.5),
            (cx - w * 0.20, top + h * 0.72), (cx - w * 0.26, top + h * 0.30),
            (cx - w * 0.46, top + h * 0.26),
        ], fill=col, outline=dark(col, 0.4), width=3)
        line(d, [(cx - w * 0.44, top + h * 0.06), (cx + w * 0.30, top + h * 0.06)],
             light(col, 0.30), width=3)

    def crucible(d, cx, cy, r, col=IRON, pour=True):
        """An UPRIGHT tapered vessel, brim full of molten metal, tipping a pour
        off its right lip.

        Drawn upright rather than tipped: the tipped version read as a plain
        grey rectangle at 78px because a rotated quad has no distinguishing
        outline once it is 20 pixels across. The taper plus the bright brim is
        what identifies the object, so both are exaggerated.
        """
        # Body: clearly narrower at the base than the mouth.
        poly(d, [
            (cx - r * 0.80, cy - r * 0.40), (cx + r * 0.80, cy - r * 0.40),
            (cx + r * 0.50, cy + r * 0.74), (cx - r * 0.50, cy + r * 0.74),
        ], fill=col, outline=dark(col, 0.45), width=3)
        # Brim: the molten surface, the brightest thing in the emblem.
        poly(d, [
            (cx - r * 0.86, cy - r * 0.52), (cx + r * 0.86, cy - r * 0.52),
            (cx + r * 0.78, cy - r * 0.24), (cx - r * 0.78, cy - r * 0.24),
        ], fill=FORGE_HOT, outline=dark(FORGE, 0.35), width=2)
        if pour:
            # A thick stream off the right lip, widening as it falls.
            poly(d, [
                (cx + r * 0.70, cy - r * 0.40), (cx + r * 0.96, cy - r * 0.34),
                (cx + r * 1.16, cy + r * 0.86), (cx + r * 0.80, cy + r * 0.86),
            ], fill=FORGE)

    def hammer(d, cx, cy, r, col=IRON, haft=RUST):
        """Head plus haft as ONE connected silhouette.

        The first version drew them as two separate polygons with a gap, and at
        78px it read as two grey blobs -- the same failure the wave-2 emblems hit
        (`a silhouette needs exactly one object, and thin linework is not one`).
        The haft is drawn first and the head overlaps it, so the outline closes.
        """
        # Haft: thick, running bottom-right to upper-left, well into the head.
        poly(d, [
            (cx + r * 0.30, cy + r * 0.86), (cx + r * 0.62, cy + r * 0.60),
            (cx - r * 0.16, cy - r * 0.28), (cx - r * 0.46, cy - r * 0.02),
        ], fill=haft, outline=dark(haft, 0.42), width=3)
        # Head: a broad rectangle across the top of the haft, deliberately large.
        poly(d, [
            (cx - r * 0.94, cy - r * 0.44), (cx - r * 0.30, cy - r * 0.96),
            (cx + r * 0.34, cy - r * 0.32), (cx - r * 0.30, cy + r * 0.20),
        ], fill=col, outline=dark(col, 0.45), width=3)
        line(d, [(cx - r * 0.82, cy - r * 0.46), (cx - r * 0.34, cy - r * 0.84)],
             light(col, 0.30), width=4)

    def burst(d, cx, cy, r, spokes=8, col=FORGE):
        """A radiating splash -- Emb's object, cleave made visible.
        Thick wedges rather than lines: thin linework is not a silhouette."""
        import math
        for i in range(spokes):
            a = (math.tau * i / spokes) - math.pi / 2
            wide = 0.30
            poly(d, [
                (cx + math.cos(a) * r * 0.26, cy + math.sin(a) * r * 0.26),
                (cx + math.cos(a - wide) * r * 0.52, cy + math.sin(a - wide) * r * 0.52),
                (cx + math.cos(a) * r * 1.02, cy + math.sin(a) * r * 1.02),
                (cx + math.cos(a + wide) * r * 0.52, cy + math.sin(a + wide) * r * 0.52),
            ], fill=col)
        circle(d, cx, cy, r * 0.30, fill=FORGE_HOT, outline=dark(col, 0.4), width=3)

    def trough(d, cx, cy, r, col=IRON, steam=True):
        """A quenching trough with steam rising. Quench's object."""
        if steam:
            # Overlapping circles, not tapered spikes: at board size a spike
            # reads as a blade. Vapour has to be round to read as vapour.
            for dx, dy, rad in ((-0.40, -0.52, 0.20), (-0.10, -0.82, 0.24),
                                (0.30, -0.60, 0.19), (0.06, -0.40, 0.17)):
                circle(d, cx + r * dx, cy + r * dy, r * rad, fill=dark(BONE, 0.50))
        poly(d, [
            (cx - r * 0.96, cy - r * 0.26), (cx + r * 0.96, cy - r * 0.26),
            (cx + r * 0.74, cy + r * 0.62), (cx - r * 0.74, cy + r * 0.62),
        ], fill=col, outline=dark(col, 0.42), width=3)
        poly(d, [
            (cx - r * 0.88, cy - r * 0.20), (cx + r * 0.88, cy - r * 0.20),
            (cx + r * 0.80, cy - r * 0.02), (cx - r * 0.80, cy - r * 0.02),
        ], fill=dark(FORGE, 0.55))

    # ------------------------------------------------------------- energy

    @art("forge_energy")
    def _(d, t):
        hexagon(d, 0.5, 0.5, 0.30, fill=dark(FORGE, 0.55), outline=FORGE, width=3)
        flame(d, 0.5, 0.52, 0.20)

    # ---------------------------------------------- Cind -- the flame itself

    @art("forge_cindspark")
    def _(d, t):
        flame(d, 0.5, 0.56, 0.20)

    @art("forge_cindbrand")
    def _(d, t):
        flame(d, 0.5, 0.52, 0.30)

    @art("forge_cindpyre")
    def _(d, t):
        # The full pyre: one large flame flanked by two smaller, on a log bed.
        rect(d, 0.20, 0.74, 0.80, 0.80, fill=RUST, outline=dark(RUST, 0.4), width=2)
        flame(d, 0.28, 0.62, 0.15)
        flame(d, 0.72, 0.62, 0.15)
        flame(d, 0.5, 0.48, 0.34)

    # ------------------------------------------- Slag -- crucible and pour

    @art("forge_slagash")
    def _(d, t):
        # Keeps the pour: without it the vessel reads as a plain bucket and says
        # nothing about fire. The molten line IS what identifies the object.
        crucible(d, 0.42, 0.48, 0.26)

    @art("forge_slagkiln")
    def _(d, t):
        crucible(d, 0.40, 0.46, 0.32)
        # The pour pooling on the horizon.
        ellipse(d, *P(0.56, 0.78), *P(0.90, 0.85), fill=FORGE)

    # ------------------------------------------ Grist -- hammer and anvil

    @art("forge_gristgnash")
    def _(d, t):
        hammer(d, 0.52, 0.52, 0.26)

    @art("forge_gristforge")
    def _(d, t):
        anvil(d, 0.5, 0.66, 0.46, 0.24)
        hammer(d, 0.54, 0.36, 0.26)

    @art("forge_gristsmith")
    def _(d, t):
        anvil(d, 0.5, 0.64, 0.58, 0.30)
        hammer(d, 0.56, 0.32, 0.30)
        # Sparks off the strike point.
        for x, y, r in ((0.34, 0.44, 0.022), (0.30, 0.52, 0.016), (0.40, 0.38, 0.014)):
            circle(d, x, y, r, fill=FORGE_HOT)

    # ------------------------------------------- Emb -- the radiating burst

    @art("forge_embash")
    def _(d, t):
        burst(d, 0.5, 0.54, 0.24, spokes=6)

    @art("forge_embkiln")
    def _(d, t):
        burst(d, 0.5, 0.52, 0.34, spokes=8)

    # ---------------------------------------- Quench -- trough and steam

    @art("forge_quenchwick")
    def _(d, t):
        trough(d, 0.5, 0.60, 0.26)

    @art("forge_quenchbrand")
    def _(d, t):
        trough(d, 0.5, 0.58, 0.32)

    @art("forge_quenchanvil")
    def _(d, t):
        trough(d, 0.5, 0.62, 0.36)
        # A blade being lowered in -- the finished work.
        poly(d, [
            (0.50, 0.14), (0.55, 0.22), (0.53, 0.50), (0.47, 0.50), (0.45, 0.22),
        ], fill=BONE, outline=dark(BONE, 0.45), width=3)

    # ----------------------------------------------------------- supports

    @art("forge_bank_the_coals")
    def _(d, t):
        # Coals under ash: a low mound with heat still showing through.
        poly(d, [(0.18, 0.70), (0.34, 0.52), (0.52, 0.60),
                 (0.70, 0.50), (0.84, 0.70)], fill=dark(BONE, 0.55))
        for x, y, r in ((0.34, 0.66, 0.045), (0.52, 0.68, 0.052), (0.68, 0.65, 0.042)):
            circle(d, x, y, r, fill=FORGE)
            circle(d, x, y, r * 0.5, fill=FORGE_HOT)

    @art("forge_quenching_trough")
    def _(d, t):
        trough(d, 0.5, 0.58, 0.34)

    @art("forge_stoke_the_works")
    def _(d, t):
        # Bellows: a wedge with a nozzle, blowing into a flame.
        poly(d, [(0.10, 0.42), (0.44, 0.34), (0.46, 0.66), (0.10, 0.60)],
             fill=RUST, outline=dark(RUST, 0.42), width=3)
        rect(d, 0.44, 0.47, 0.58, 0.53, fill=IRON)
        flame(d, 0.74, 0.52, 0.20)

    @art("forge_scrap_heap")
    def _(d, t):
        # A pile of broken stock: overlapping angular shards, one still hot.
        poly(d, [(0.16, 0.74), (0.30, 0.48), (0.44, 0.74)], fill=IRON,
             outline=dark(IRON, 0.4), width=3)
        poly(d, [(0.36, 0.74), (0.56, 0.40), (0.70, 0.74)], fill=dark(IRON, 0.2),
             outline=dark(IRON, 0.45), width=3)
        poly(d, [(0.60, 0.74), (0.74, 0.54), (0.88, 0.74)], fill=RUST,
             outline=dark(RUST, 0.4), width=3)
        circle(d, 0.56, 0.62, 0.045, fill=FORGE_HOT)

    @art("forge_hearthstone")
    def _(d, t):
        # A stone with a fire inside it -- the flavour, literally.
        poly(d, [(0.24, 0.72), (0.20, 0.44), (0.38, 0.26),
                 (0.66, 0.26), (0.82, 0.46), (0.76, 0.72)],
             fill=IRON, outline=dark(IRON, 0.45), width=3)
        flame(d, 0.5, 0.56, 0.17)
