"""Forge expansion emblems -- the eight new chains, the singles, the supports.

Same contract as forge_art.py: one function per card id, coordinates in 0-1
space, registered into make_card_art.py's DRAW table.

**The grammar is partitioned up front, not deduplicated afterward** -- the
wave-2 lesson, and it matters more here because Forge wave 1 already claimed
five objects (flame, crucible, hammer/anvil, radiating burst, trough+steam).
Reusing any of them would make a 48-unit faction read as one chain drawn 16
times. So each new chain owns an object no other Forge chain uses:

    Bellow    -- the bellows: a hinged wedge with a nozzle
    Char      -- the burnt stump / charred post
    Scoria    -- the cracked slag lump, split open with a hot seam
    Flux      -- the sealed jar / flux pot with a stopper
    Tind      -- the bundle of tinder, bound at the waist
    Drossal   -- the tongs, gripping
    Anneal    -- the shield-plate, dented
    Ingot     -- the bar, stacked and squared

And the two rules both earlier waves learned the hard way:

  * **Exactly one object, and never thin linework.** `Grimkin`'s scales read as
    a cross with two commas at 78px; `Sevsk`'s chain read as a line with two
    dots. Every shape below is closed and reads by its outline.
  * **No props competing with the subject.** Three wave-1 emblems had to be
    redrawn because a shroud, three equal bells and a pair of wings each fought
    the thing they were decorating for the silhouette.
"""


def register(m):
    """Install every expansion emblem into the host module's DRAW table."""
    art = m.art
    poly, line, circle, ellipse = m.poly, m.line, m.circle, m.ellipse
    rect, arc, star, hexagon = m.rect, m.arc, m.star, m.hexagon
    dark, light, mix = m.dark, m.light, m.mix
    P = m.P
    GOLD, BONE, PANEL, RUST = m.GOLD, m.BONE, m.PANEL, m.RUST

    FORGE = (224, 122, 60)
    FORGE_HOT = (255, 179, 122)
    FORGE_DEEP = (122, 51, 18)
    IRON = (86, 82, 92)

    # ------------------------------------------------------ shared shapes

    def flame(d, cx, cy, r, col=FORGE, core=FORGE_HOT):
        """Kept identical to forge_art.py's, so the two files cannot drift."""
        poly(d, [
            (cx, cy - r * 1.05), (cx + r * 0.44, cy - r * 0.34),
            (cx + r * 0.60, cy + r * 0.28), (cx + r * 0.27, cy + r * 0.80),
            (cx - r * 0.24, cy + r * 0.84), (cx - r * 0.58, cy + r * 0.34),
            (cx - r * 0.38, cy - r * 0.24), (cx - r * 0.12, cy - r * 0.58),
        ], fill=col, outline=dark(col, 0.35), width=3)
        poly(d, [
            (cx, cy - r * 0.44), (cx + r * 0.26, cy + r * 0.06),
            (cx + r * 0.14, cy + r * 0.52), (cx - r * 0.16, cy + r * 0.50),
            (cx - r * 0.28, cy + r * 0.04),
        ], fill=core)

    def bellows(d, cx, cy, r, col=RUST):
        """A hinged wedge with a nozzle: the widest part at the back, tapering
        to a hot point. One closed silhouette -- the nozzle is part of the same
        polygon rather than a separate line, or it vanishes at board size."""
        poly(d, [
            (cx - r * 0.30, cy - r * 0.80), (cx + r * 0.52, cy - r * 0.26),
            (cx + r * 1.06, cy - r * 0.06), (cx + r * 1.06, cy + r * 0.10),
            (cx + r * 0.52, cy + r * 0.26), (cx - r * 0.30, cy + r * 0.82),
            (cx - r * 0.74, cy + r * 0.40), (cx - r * 0.74, cy - r * 0.40),
        ], fill=col, outline=dark(col, 0.45), width=3)
        # The hinge plate, and the puff of heat leaving the nozzle.
        line(d, [(cx - r * 0.30, cy - r * 0.74), (cx - r * 0.30, cy + r * 0.76)],
             dark(col, 0.5), width=3)
        circle(d, cx + r * 1.24, cy + r * 0.02, r * 0.20, fill=FORGE_HOT)

    def stump(d, cx, cy, r, col=(58, 48, 46)):
        """A charred post: a broad base narrowing to a split, ragged top, with
        embers still in the crown. Reads as burnt because of the silhouette's
        broken top edge, not because of colour alone."""
        poly(d, [
            (cx - r * 0.52, cy + r * 0.86), (cx - r * 0.40, cy - r * 0.50),
            (cx - r * 0.16, cy - r * 0.84), (cx - r * 0.02, cy - r * 0.44),
            (cx + r * 0.16, cy - r * 0.90), (cx + r * 0.38, cy - r * 0.40),
            (cx + r * 0.50, cy + r * 0.86),
        ], fill=col, outline=dark(col, 0.5), width=3)
        circle(d, cx - r * 0.16, cy - r * 0.60, r * 0.13, fill=FORGE)
        circle(d, cx + r * 0.18, cy - r * 0.64, r * 0.11, fill=FORGE_HOT)

    def slag_lump(d, cx, cy, r, col=IRON):
        """A cracked lump split by a bright seam. The seam is a filled wedge,
        never a drawn line -- at 78px a 2px crack disappears entirely."""
        poly(d, [
            (cx - r * 0.86, cy + r * 0.10), (cx - r * 0.54, cy - r * 0.62),
            (cx + r * 0.20, cy - r * 0.80), (cx + r * 0.82, cy - r * 0.24),
            (cx + r * 0.74, cy + r * 0.54), (cx + r * 0.04, cy + r * 0.84),
            (cx - r * 0.66, cy + r * 0.60),
        ], fill=col, outline=dark(col, 0.5), width=3)
        poly(d, [
            (cx - r * 0.44, cy - r * 0.40), (cx - r * 0.10, cy + r * 0.06),
            (cx + r * 0.34, cy + r * 0.66), (cx + r * 0.06, cy + r * 0.70),
            (cx - r * 0.30, cy + r * 0.10), (cx - r * 0.60, cy - r * 0.30),
        ], fill=FORGE)

    def flux_pot(d, cx, cy, r, col=(96, 78, 62)):
        """A squat sealed jar with a stopper. Shoulders wider than the mouth,
        which is what tells it apart from the Slag crucible's flared brim."""
        poly(d, [
            (cx - r * 0.46, cy - r * 0.44), (cx + r * 0.46, cy - r * 0.44),
            (cx + r * 0.80, cy + r * 0.10), (cx + r * 0.62, cy + r * 0.80),
            (cx - r * 0.62, cy + r * 0.80), (cx - r * 0.80, cy + r * 0.10),
        ], fill=col, outline=dark(col, 0.5), width=3)
        rect(d, cx - r * 0.30, cy - r * 0.80, cx + r * 0.30, cy - r * 0.40,
             fill=RUST, outline=dark(RUST, 0.45), width=2)
        # The glow through the seal, so the jar reads as holding something hot.
        ellipse(d, *P(cx - r * 0.40, cy + r * 0.14), *P(cx + r * 0.40, cy + r * 0.46),
                fill=FORGE)

    def tinder(d, cx, cy, r, col=(150, 116, 70)):
        """A bound bundle: splayed staves with a band at the waist. Drawn as
        three thick wedges rather than many thin sticks -- thin linework is the
        failure mode this whole grammar is written against."""
        for dx, tilt in ((-0.42, -0.30), (0.0, 0.0), (0.42, 0.30)):
            poly(d, [
                (cx + r * (dx - 0.16), cy + r * 0.84),
                (cx + r * (dx + 0.16), cy + r * 0.84),
                (cx + r * (dx + tilt + 0.20), cy - r * 0.84),
                (cx + r * (dx + tilt - 0.06), cy - r * 0.84),
            ], fill=col, outline=dark(col, 0.5), width=2)
        rect(d, cx - r * 0.66, cy + r * 0.06, cx + r * 0.66, cy + r * 0.34,
             fill=RUST, outline=dark(RUST, 0.5), width=3)
        circle(d, cx, cy - r * 0.84, r * 0.20, fill=FORGE_HOT)

    def tongs(d, cx, cy, r, col=IRON):
        """Two thick arms crossing at a pivot, JAWS OPEN AT THE TOP around a
        held ember.

        The first version drew slim tapered arms with the ember floating above
        them, and at 74px it read as a bare inverted V -- the same failure the
        wave-2 emblems hit twice (`thin linework is not one object`). The arms
        are now wide enough to hold their own silhouette, the jaws flare apart
        at the top so the gap is visible, and the ember sits BETWEEN them, which
        is what says "gripping" rather than "crossed".
        """
        # Left arm: broad at the handle, flaring into a jaw at the top.
        poly(d, [
            (cx - r * 0.92, cy + r * 0.88), (cx - r * 0.44, cy + r * 0.88),
            (cx + r * 0.06, cy - r * 0.34), (cx - r * 0.02, cy - r * 0.80),
            (cx - r * 0.40, cy - r * 0.66), (cx - r * 0.34, cy - r * 0.20),
        ], fill=col, outline=dark(col, 0.5), width=3)
        # Right arm: the mirror, in a darker tone so the crossing is legible.
        poly(d, [
            (cx + r * 0.92, cy + r * 0.88), (cx + r * 0.44, cy + r * 0.88),
            (cx - r * 0.06, cy - r * 0.34), (cx + r * 0.02, cy - r * 0.80),
            (cx + r * 0.40, cy - r * 0.66), (cx + r * 0.34, cy - r * 0.20),
        ], fill=dark(col, 0.28), outline=dark(col, 0.55), width=3)
        # The pivot, then the held ember filling the gap between the jaws.
        circle(d, cx, cy + r * 0.20, r * 0.20, fill=dark(col, 0.6))
        circle(d, cx, cy - r * 0.52, r * 0.30, fill=FORGE_HOT)

    def plate(d, cx, cy, r, col=IRON, dents=True):
        """A shield-plate: squared shoulders, tapering to a point, with dents
        struck out of the edge. The dents are notches cut INTO the silhouette,
        which is what makes damage readable at a glance."""
        poly(d, [
            (cx - r * 0.72, cy - r * 0.78), (cx + r * 0.72, cy - r * 0.78),
            (cx + r * 0.66, cy + r * 0.16), (cx, cy + r * 0.92),
            (cx - r * 0.66, cy + r * 0.16),
        ], fill=col, outline=dark(col, 0.5), width=3)
        line(d, [(cx, cy - r * 0.72), (cx, cy + r * 0.80)], dark(col, 0.4), width=3)
        if dents:
            circle(d, cx - r * 0.72, cy - r * 0.20, r * 0.20, fill=PANEL)
            circle(d, cx + r * 0.66, cy + r * 0.06, r * 0.16, fill=PANEL)
        circle(d, cx, cy - r * 0.30, r * 0.16, fill=FORGE)

    def ingot(d, cx, cy, r, col=FORGE, stacked=False):
        """A cast bar: a squat trapezoid, wider at the base. Stacked for the
        larger forms, which is the chain's growth read."""
        def bar(bx, by, s, c):
            poly(d, [
                (bx - r * 0.62 * s, by + r * 0.26 * s),
                (bx + r * 0.62 * s, by + r * 0.26 * s),
                (bx + r * 0.46 * s, by - r * 0.26 * s),
                (bx - r * 0.46 * s, by - r * 0.26 * s),
            ], fill=c, outline=dark(c, 0.45), width=3)
        if stacked:
            bar(cx - r * 0.30, cy + r * 0.52, 1.0, dark(col, 0.25))
            bar(cx + r * 0.34, cy + r * 0.52, 1.0, dark(col, 0.25))
            bar(cx, cy - r * 0.02, 1.0, col)
        else:
            bar(cx, cy + r * 0.24, 1.15, col)

    # ============================================ Bellow -- the bellows

    @art("forge_bellowwick")
    def _(d, t):
        bellows(d, 0.44, 0.54, 0.26)

    @art("forge_bellowbrand")
    def _(d, t):
        bellows(d, 0.42, 0.52, 0.32)

    @art("forge_bellowmaul")
    def _(d, t):
        # Two nozzles, one draught -- the Stage 2 attacks twice.
        bellows(d, 0.40, 0.36, 0.26)
        bellows(d, 0.40, 0.68, 0.26)

    # ============================================== Char -- the burnt post

    @art("forge_charash")
    def _(d, t):
        stump(d, 0.5, 0.52, 0.26)

    @art("forge_charkiln")
    def _(d, t):
        stump(d, 0.5, 0.50, 0.34)

    @art("forge_charpyre")
    def _(d, t):
        # A whole rank of posts, burnt down together: the sweep, as a picture.
        stump(d, 0.22, 0.58, 0.20)
        stump(d, 0.78, 0.58, 0.20)
        stump(d, 0.5, 0.48, 0.32)

    # ========================================= Scoria -- the cracked lump

    @art("forge_scoriaslag")
    def _(d, t):
        slag_lump(d, 0.5, 0.54, 0.26)

    @art("forge_scoriaforge")
    def _(d, t):
        slag_lump(d, 0.5, 0.52, 0.33)

    @art("forge_scoriasmith")
    def _(d, t):
        # The seam has opened all the way through: the lump is split in two.
        slag_lump(d, 0.36, 0.52, 0.26)
        slag_lump(d, 0.68, 0.56, 0.22)

    # =============================================== Flux -- the sealed jar

    @art("forge_fluxwick")
    def _(d, t):
        flux_pot(d, 0.5, 0.54, 0.26)

    @art("forge_fluxbrand")
    def _(d, t):
        flux_pot(d, 0.5, 0.52, 0.32)

    @art("forge_fluxanvil")
    def _(d, t):
        flux_pot(d, 0.34, 0.56, 0.24)
        flux_pot(d, 0.66, 0.50, 0.30)

    # ============================================== Tind -- the tinder bundle

    @art("forge_tindspark")
    def _(d, t):
        tinder(d, 0.5, 0.54, 0.24)

    @art("forge_tindkiln")
    def _(d, t):
        tinder(d, 0.5, 0.52, 0.30)

    @art("forge_tindpyre")
    def _(d, t):
        tinder(d, 0.5, 0.54, 0.34)
        flame(d, 0.5, 0.28, 0.17)

    # ============================================== Drossal -- the tongs

    @art("forge_drossalgnash")
    def _(d, t):
        tongs(d, 0.5, 0.52, 0.26)

    @art("forge_drossalkiln")
    def _(d, t):
        tongs(d, 0.5, 0.50, 0.32)

    @art("forge_drossalsmith")
    def _(d, t):
        tongs(d, 0.5, 0.52, 0.36)
        circle(d, 0.5, 0.24, 0.075, fill=FORGE)

    # ============================================== Anneal -- the plate

    @art("forge_annealash")
    def _(d, t):
        plate(d, 0.5, 0.52, 0.26)

    @art("forge_annealbrand")
    def _(d, t):
        plate(d, 0.5, 0.50, 0.32)

    @art("forge_annealanvil")
    def _(d, t):
        plate(d, 0.5, 0.50, 0.36)
        # Struck sparks leaving the face: Retribution, drawn.
        for dx, dy in ((-0.30, -0.20), (0.30, -0.20), (-0.26, 0.16), (0.26, 0.16)):
            circle(d, 0.5 + dx, 0.50 + dy, 0.035, fill=FORGE_HOT)

    # ================================================ Ingot -- the bar

    @art("forge_ingotspark")
    def _(d, t):
        ingot(d, 0.5, 0.52, 0.28)

    @art("forge_ingotforge")
    def _(d, t):
        ingot(d, 0.5, 0.48, 0.32, stacked=True)

    @art("forge_ingotpyre")
    def _(d, t):
        ingot(d, 0.5, 0.46, 0.36, stacked=True)
        flame(d, 0.5, 0.20, 0.14)

    # ============================================ pairs and singles

    @art("forge_cinderlingwick")
    def _(d, t):
        # A single spark with a long tail -- the smallest thing that gets through.
        circle(d, 0.56, 0.40, 0.085, fill=FORGE_HOT)
        poly(d, [(0.52, 0.44), (0.60, 0.44), (0.36, 0.78), (0.30, 0.72)],
             fill=FORGE, outline=dark(FORGE, 0.4), width=2)

    @art("forge_cinderlingbrand")
    def _(d, t):
        circle(d, 0.60, 0.34, 0.105, fill=FORGE_HOT)
        poly(d, [(0.54, 0.40), (0.66, 0.40), (0.32, 0.82), (0.24, 0.74)],
             fill=FORGE, outline=dark(FORGE, 0.4), width=3)

    @art("forge_sootfallash")
    def _(d, t):
        # Falling embers over a roofline: the tower splash.
        poly(d, [(0.18, 0.82), (0.18, 0.66), (0.50, 0.50), (0.82, 0.66),
                 (0.82, 0.82)], fill=IRON, outline=dark(IRON, 0.45), width=3)
        circle(d, 0.34, 0.34, 0.055, fill=FORGE)
        circle(d, 0.58, 0.24, 0.045, fill=FORGE_HOT)

    @art("forge_sootfallkiln")
    def _(d, t):
        poly(d, [(0.14, 0.84), (0.14, 0.62), (0.50, 0.44), (0.86, 0.62),
                 (0.86, 0.84)], fill=IRON, outline=dark(IRON, 0.45), width=3)
        circle(d, 0.28, 0.30, 0.065, fill=FORGE)
        circle(d, 0.52, 0.18, 0.055, fill=FORGE_HOT)
        circle(d, 0.72, 0.30, 0.050, fill=FORGE)

    def coke_basket(d, cx, cy, r):
        """A raised fire-basket: legs, a flared bowl, and a heaped bright load.

        Drawn with LEGS and an overhanging rim because the first version was a
        plain trapezoid with two dots on it, which at 74px read as an anonymous
        mound. The gap under the bowl is what makes it a vessel standing on the
        ground rather than a hill rising out of it.
        """
        # Legs first, so the bowl overlaps and the silhouette closes.
        for sx in (-0.52, 0.52):
            poly(d, [
                (cx + r * (sx - 0.10), cy + r * 0.94),
                (cx + r * (sx + 0.10), cy + r * 0.94),
                (cx + r * (sx * 0.52 + 0.08), cy + r * 0.10),
                (cx + r * (sx * 0.52 - 0.08), cy + r * 0.10),
            ], fill=dark(IRON, 0.3), outline=dark(IRON, 0.55), width=2)
        # The bowl: a flared basket, wider at the rim than the base.
        poly(d, [
            (cx - r * 0.92, cy - r * 0.20), (cx + r * 0.92, cy - r * 0.20),
            (cx + r * 0.50, cy + r * 0.56), (cx - r * 0.50, cy + r * 0.56),
        ], fill=IRON, outline=dark(IRON, 0.55), width=3)
        # The load, heaped ABOVE the rim so it reads as full.
        poly(d, [
            (cx - r * 0.80, cy - r * 0.22), (cx - r * 0.34, cy - r * 0.72),
            (cx + r * 0.16, cy - r * 0.52), (cx + r * 0.52, cy - r * 0.84),
            (cx + r * 0.80, cy - r * 0.22),
        ], fill=FORGE, outline=dark(FORGE, 0.45), width=2)
        circle(d, cx + r * 0.06, cy - r * 0.44, r * 0.20, fill=FORGE_HOT)

    @art("forge_cokewrightslag")
    def _(d, t):
        coke_basket(d, 0.5, 0.50, 0.28)

    @art("forge_cokewrightforge")
    def _(d, t):
        coke_basket(d, 0.5, 0.48, 0.34)

    @art("forge_forgehand")
    def _(d, t):
        # A gauntlet: one closed mitt shape, no separate fingers to lose.
        poly(d, [(0.34, 0.80), (0.30, 0.50), (0.38, 0.32), (0.62, 0.30),
                 (0.72, 0.46), (0.68, 0.80)],
             fill=IRON, outline=dark(IRON, 0.5), width=3)
        rect(d, 0.32, 0.62, 0.70, 0.70, fill=RUST, outline=dark(RUST, 0.45), width=2)

    @art("forge_slakeling")
    def _(d, t):
        # A droplet meeting heat: the quench, at its smallest.
        poly(d, [(0.50, 0.22), (0.64, 0.48), (0.58, 0.68), (0.42, 0.68),
                 (0.36, 0.48)], fill=(108, 156, 178),
             outline=dark((108, 156, 178), 0.4), width=3)
        ellipse(d, *P(0.30, 0.70), *P(0.70, 0.82), fill=FORGE)

    @art("forge_tapwright")
    def _(d, t):
        # A tap spout with the stream running: where the metal comes out.
        poly(d, [(0.22, 0.34), (0.58, 0.34), (0.58, 0.50), (0.36, 0.50),
                 (0.36, 0.44), (0.22, 0.44)],
             fill=IRON, outline=dark(IRON, 0.5), width=3)
        poly(d, [(0.40, 0.50), (0.56, 0.50), (0.62, 0.82), (0.44, 0.82)],
             fill=FORGE_HOT)

    @art("forge_bloomsmith")
    def _(d, t):
        # The bloom: a rough mass on the anvil face, still glowing.
        poly(d, [(0.28, 0.62), (0.34, 0.36), (0.56, 0.28), (0.72, 0.42),
                 (0.70, 0.62)], fill=FORGE, outline=dark(FORGE, 0.45), width=3)
        rect(d, 0.20, 0.62, 0.80, 0.74, fill=IRON, outline=dark(IRON, 0.5), width=3)

    @art("forge_cindergaunt")
    def _(d, t):
        # Burnt down to the frame and still lit: a hollow ribcage of a shape.
        poly(d, [(0.34, 0.80), (0.28, 0.44), (0.50, 0.22), (0.72, 0.44),
                 (0.66, 0.80)], fill=dark(IRON, 0.3),
             outline=dark(IRON, 0.55), width=3)
        circle(d, 0.50, 0.54, 0.115, fill=FORGE_HOT)

    # ==================================================== supports

    @art("forge_second_wind")
    def _(d, t):
        bellows(d, 0.42, 0.52, 0.30)
        circle(d, 0.86, 0.52, 0.075, fill=FORGE_HOT)

    @art("forge_the_long_shift")
    def _(d, t):
        # Three hammers racked for the night: the shop, not one smith.
        for x in (0.30, 0.50, 0.70):
            poly(d, [(x - 0.055, 0.78), (x + 0.055, 0.78),
                     (x + 0.035, 0.36), (x - 0.035, 0.36)],
                 fill=RUST, outline=dark(RUST, 0.45), width=2)
            rect(d, x - 0.09, 0.26, x + 0.09, 0.38,
                 fill=IRON, outline=dark(IRON, 0.5), width=2)

    @art("forge_cold_shut")
    def _(d, t):
        # A fold that failed to weld: two masses meeting at a dead grey seam.
        poly(d, [(0.16, 0.66), (0.32, 0.36), (0.50, 0.66)], fill=IRON,
             outline=dark(IRON, 0.5), width=3)
        poly(d, [(0.50, 0.66), (0.68, 0.36), (0.84, 0.66)], fill=dark(IRON, 0.25),
             outline=dark(IRON, 0.55), width=3)
        rect(d, 0.46, 0.34, 0.54, 0.76, fill=PANEL)

    @art("forge_draw_the_temper")
    def _(d, t):
        # A blade drawn back out of the fire, colour running up it.
        poly(d, [(0.44, 0.80), (0.56, 0.80), (0.56, 0.30), (0.50, 0.18),
                 (0.44, 0.30)], fill=IRON, outline=dark(IRON, 0.5), width=3)
        rect(d, 0.44, 0.56, 0.56, 0.80, fill=FORGE)
        rect(d, 0.44, 0.44, 0.56, 0.58, fill=FORGE_HOT)

    @art("forge_open_the_doors")
    def _(d, t):
        # Shop doors thrown open on a lit interior.
        rect(d, 0.14, 0.24, 0.40, 0.82, fill=IRON, outline=dark(IRON, 0.5), width=3)
        rect(d, 0.60, 0.24, 0.86, 0.82, fill=IRON, outline=dark(IRON, 0.5), width=3)
        rect(d, 0.40, 0.30, 0.60, 0.82, fill=FORGE)
        flame(d, 0.50, 0.56, 0.14)

    @art("forge_the_reclaim")
    def _(d, t):
        # A broken bar being fed back in: the arrow is the shape, not a line.
        poly(d, [(0.24, 0.62), (0.56, 0.62), (0.56, 0.46), (0.84, 0.70),
                 (0.56, 0.92), (0.56, 0.76), (0.24, 0.76)],
             fill=FORGE, outline=dark(FORGE, 0.45), width=3)
        slag_lump(d, 0.40, 0.30, 0.18)

    @art("forge_murder_holes_hot")
    def _(d, t):
        # Slits cut in a wall, with heat behind them.
        rect(d, 0.18, 0.24, 0.82, 0.82, fill=IRON, outline=dark(IRON, 0.5), width=3)
        for x in (0.32, 0.50, 0.68):
            rect(d, x - 0.045, 0.36, x + 0.045, 0.62, fill=FORGE_HOT)

    @art("forge_bellows_rig")
    def _(d, t):
        bellows(d, 0.46, 0.52, 0.28)
        rect(d, 0.14, 0.76, 0.86, 0.86, fill=RUST, outline=dark(RUST, 0.45), width=2)

    @art("forge_deadmans_hammer")
    def _(d, t):
        # A hammer standing on its head, unheld -- it swings on its own.
        rect(d, 0.30, 0.20, 0.70, 0.40, fill=IRON, outline=dark(IRON, 0.5), width=3)
        poly(d, [(0.46, 0.40), (0.54, 0.40), (0.58, 0.84), (0.42, 0.84)],
             fill=RUST, outline=dark(RUST, 0.45), width=3)
        circle(d, 0.50, 0.30, 0.055, fill=FORGE_HOT)
