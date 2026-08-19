"""Emblems for the 114 wave-2 creatures (2026-08-15).

Companion to bestiary_art.py; same contract, registered by make_card_art.py.

**The problem this file has to solve that wave 1 did not: collision.** With 234
units in four colour families, "another purple skull" and "another green mound"
stop identifying anything. Wave 1 already hit this once -- Rime and Oss were
both purple skulls with radiating marks and had to be pulled apart after the
fact -- so wave 2 assigns each family a distinct *object* up front rather than
varying a shared one.

Object vocabulary, by faction:

    Hel     rot and cold -- fen bubbles, hanging shrouds, embers, husks,
            drips, cracked ground. Deliberately NOT skulls; wave 1 owns those.
    Heaven  liturgy -- open books, chalices, keys, standing candles, arches.
            Wave 1 owns halos, bells and wings.
    Void    geometry -- lacunae, spirals, shear lines, negative wedges.
            Wave 1 owns the round hole-with-a-rim.
    Gaia    specific plants -- ferns, sedge blades, amber beads, burrs,
            tussocks. Wave 1 owns mushrooms, crystals and generic mounds.

The chain rule is unchanged and still does the most work: a family is one shape
function called at two or three weights, so a Stage 1 is visibly its Basic grown
up. A vanilla Basic and its keyworded evolution are the most important pair to
keep legible, because that relationship is the whole reason the vanilla exists.
"""

import math


def register(env):
    art = env.art
    poly, line = env.poly, env.line
    ellipse, circle, rect = env.ellipse, env.circle, env.rect
    arc, star, skull, bone = env.arc, env.star, env.skull, env.bone
    hexagon, halo = env.hexagon, env.halo
    rays, wings, bell = env.rays, env.wings, env.bell
    void_eye, droplet = env.void_eye, env.droplet
    mix, dark, light = env.mix, env.dark, env.light
    PANEL, TEXT = env.PANEL, env.TEXT
    GOLD, BONE, HP_GREEN = env.GOLD, env.BONE, env.HP_GREEN
    TOWER, DANGER, RUST = env.TOWER, env.DANGER, env.RUST
    ACCENT = env.ACCENT

    # ================================================================= HEL
    # Rot and cold. Low, wet, settling. No skulls -- wave 1 owns those.

    def fen_form(d, bubbles, r, col):
        """Standing water with things surfacing in it."""
        ellipse(d, 0.14, 0.60, 0.86, 0.92, fill=dark(col, 0.55))
        ellipse(d, 0.18, 0.63, 0.82, 0.88, fill=dark(col, 0.38))
        for i in range(bubbles):
            a = 0.26 + i * (0.48 / max(1, bubbles - 1))
            rr = r * (0.72 + 0.35 * ((i * 7) % 3) / 2.0)
            cy = 0.70 + ((i * 5) % 3) * 0.045
            circle(d, a + 0.02, cy, rr, fill=mix(col, BONE, 0.30),
                   outline=light(col, 0.20), width=2)

    @art("blighthusk")
    def _(d, t):
        fen_form(d, 3, 0.055, HP_GREEN)
        circle(d, 0.5, 0.44, 0.10, fill=mix(HP_GREEN, PANEL, 0.35))
        circle(d, 0.47, 0.425, 0.017, fill=DANGER)
        circle(d, 0.54, 0.425, 0.017, fill=DANGER)

    @art("blightfen")
    def _(d, t):
        fen_form(d, 5, 0.07, HP_GREEN)
        circle(d, 0.5, 0.40, 0.135, fill=mix(HP_GREEN, PANEL, 0.30))
        circle(d, 0.455, 0.38, 0.021, fill=DANGER)
        circle(d, 0.545, 0.38, 0.021, fill=DANGER)
        for x in (0.36, 0.64):
            line(d, [(x, 0.32), (x, 0.20)], dark(HP_GREEN, 0.35), 2.4)

    @art("blightknell")
    def _(d, t):
        fen_form(d, 7, 0.08, HP_GREEN)
        circle(d, 0.5, 0.36, 0.165, fill=mix(HP_GREEN, PANEL, 0.26))
        circle(d, 0.445, 0.34, 0.024, fill=DANGER)
        circle(d, 0.555, 0.34, 0.024, fill=DANGER)
        for a in range(0, 360, 45):
            r = math.radians(a)
            line(d, [(0.5 + math.cos(r) * 0.19, 0.36 + math.sin(r) * 0.19),
                     (0.5 + math.cos(r) * 0.27, 0.36 + math.sin(r) * 0.27)],
                 dark(HP_GREEN, 0.30), 2.2)

    def shroud_form(d, w, h, folds, col):
        """A hanging cloth -- Tomb's silhouette."""
        poly(d, [(0.5 - w, 0.32), (0.5 + w, 0.32),
                 (0.5 + w * 0.86, 0.90), (0.5 - w * 0.86, 0.90)],
             fill=dark(col, 0.52))
        for i in range(folds):
            x = 0.5 - w * 0.62 + i * (w * 1.24 / max(1, folds - 1))
            line(d, [(x, 0.35), (x - 0.012, 0.88)], dark(col, 0.68), 2.0)
        arc(d, 0.5 - w, 0.32 - h, 0.5 + w, 0.32 + h, 180, 360,
            mix(col, BONE, 0.30), 3.0)

    @art("tomblit")
    def _(d, t):
        shroud_form(d, 0.17, 0.10, 3, ACCENT)

    @art("tombshroud")
    def _(d, t):
        shroud_form(d, 0.22, 0.13, 4, ACCENT)
        circle(d, 0.5, 0.44, 0.048, fill=dark(PANEL, -0.25))
        circle(d, 0.5, 0.44, 0.020, fill=light(ACCENT, 0.40))

    @art("tombthane")
    def _(d, t):
        shroud_form(d, 0.265, 0.16, 6, ACCENT)
        circle(d, 0.5, 0.42, 0.062, fill=dark(PANEL, -0.30))
        circle(d, 0.5, 0.42, 0.026, fill=light(ACCENT, 0.45))
        for x in (0.30, 0.70):
            bone(d, x, 0.62, x, 0.84, w=0.024, col=dark(BONE, 0.30))

    def drip_form(d, n, r, col, cy=0.36):
        """Murk / Rot: droplets falling into a pooled line."""
        rect(d, 0.16, 0.82, 0.84, 0.88, fill=dark(col, 0.50), radius=0.02)
        for i in range(n):
            x = 0.24 + i * (0.52 / max(1, n - 1))
            y = cy + ((i * 3) % 4) * 0.075
            droplet(d, x, y, r, mix(col, BONE, 0.22 + 0.10 * (i % 2)))

    @art("murklit")
    def _(d, t):
        drip_form(d, 3, 0.062, TOWER)

    @art("murkmire")
    def _(d, t):
        drip_form(d, 5, 0.078, TOWER)
        ellipse(d, 0.22, 0.74, 0.78, 0.90, fill=dark(TOWER, 0.45))

    @art("rotwisp")
    def _(d, t):
        drip_form(d, 3, 0.060, HP_GREEN, cy=0.34)

    @art("rotfen")
    def _(d, t):
        drip_form(d, 5, 0.075, HP_GREEN, cy=0.32)
        ellipse(d, 0.20, 0.72, 0.80, 0.90, fill=dark(HP_GREEN, 0.50))

    def ember_form(d, n, r, glow):
        """Char: a bed of coals under a rising heat shimmer."""
        rect(d, 0.18, 0.78, 0.82, 0.88, fill=dark(RUST, 0.55), radius=0.02)
        for i in range(n):
            x = 0.24 + i * (0.52 / max(1, n - 1))
            circle(d, x, 0.82 - ((i * 5) % 3) * 0.022, r,
                   fill=mix(RUST, GOLD, 0.25 + 0.20 * (i % 3)))
        for i in range(3):
            x = 0.34 + i * 0.16
            pts = [(x + math.sin(j * 0.9) * 0.028, 0.74 - j * 0.075)
                   for j in range(5)]
            line(d, pts, dark(GOLD, glow), 2.2)

    @art("chargrub")
    def _(d, t):
        ember_form(d, 4, 0.048, 0.55)

    @art("chargaunt")
    def _(d, t):
        ember_form(d, 6, 0.060, 0.40)
        circle(d, 0.5, 0.48, 0.085, fill=mix(RUST, GOLD, 0.35))
        circle(d, 0.5, 0.48, 0.034, fill=dark(PANEL, -0.2))

    def husk_form(d, w, h, ribs):
        """Wither / Cairn: a dry hollow shell."""
        poly(d, [(0.5, 0.28), (0.5 + w, 0.50), (0.5 + w * 0.68, 0.86),
                 (0.5 - w * 0.68, 0.86), (0.5 - w, 0.50)],
             fill=mix(BONE, PANEL, 0.52), outline=dark(BONE, 0.25), width=3)
        for i in range(ribs):
            y = 0.42 + i * (0.38 / max(1, ribs))
            line(d, [(0.5 - w * 0.72, y), (0.5 + w * 0.72, y)],
                 dark(BONE, 0.42), 1.8)

    @art("witherling")
    def _(d, t):
        husk_form(d, 0.17, 0.0, 3)

    @art("witherhusk")
    def _(d, t):
        husk_form(d, 0.225, 0.0, 5)
        circle(d, 0.455, 0.50, 0.019, fill=dark(PANEL, -0.3))
        circle(d, 0.545, 0.50, 0.019, fill=dark(PANEL, -0.3))

    @art("cairnwisp")
    def _(d, t):
        for i, w in enumerate((0.16, 0.12)):
            rect(d, 0.5 - w / 2, 0.80 - i * 0.10, 0.5 + w / 2, 0.88 - i * 0.10,
                 fill=mix(BONE, PANEL, 0.45 + i * 0.08), radius=0.016)

    @art("cairnhusk")
    def _(d, t):
        ws = (0.26, 0.22, 0.175, 0.13, 0.09)
        y = 0.88
        for i, w in enumerate(ws):
            h = 0.078 - i * 0.006
            rect(d, 0.5 - w / 2, y - h, 0.5 + w / 2, y,
                 fill=mix(BONE, PANEL, 0.40 + i * 0.06), radius=0.016)
            y -= h + 0.010
        circle(d, 0.466, 0.60, 0.015, fill=light(ACCENT, 0.35))
        circle(d, 0.534, 0.60, 0.015, fill=light(ACCENT, 0.35))

    def mote_swarm(d, n, r, col, spread=0.20):
        for i in range(n):
            a = math.radians(i * (360.0 / n) + i * 11)
            rr = spread * (0.45 + 0.55 * ((i * 3) % 4) / 3.0)
            circle(d, 0.5 + math.cos(a) * rr, 0.54 + math.sin(a) * rr * 0.85,
                   r, fill=mix(col, BONE, 0.20 + 0.12 * (i % 3)))

    @art("morlit")
    def _(d, t):
        mote_swarm(d, 5, 0.030, ACCENT, 0.13)

    @art("morknell")
    def _(d, t):
        mote_swarm(d, 14, 0.034, ACCENT, 0.24)
        circle(d, 0.5, 0.54, 0.052, fill=dark(PANEL, -0.25))

    @art("ashlit")
    def _(d, t):
        mote_swarm(d, 6, 0.026, BONE, 0.15)

    @art("ashloam")
    def _(d, t):
        rect(d, 0.16, 0.76, 0.84, 0.90, fill=dark(RUST, 0.60), radius=0.02)
        mote_swarm(d, 11, 0.030, BONE, 0.22)

    def crack_form(d, w, depth, branches):
        """Sepul / Grist / Gnaw / Oss wave-2: split ground."""
        rect(d, 0.12, 0.72, 0.88, 0.90, fill=mix(BONE, PANEL, 0.55), radius=0.02)
        line(d, [(0.5, 0.72), (0.5 - w * 0.2, 0.90)], dark(PANEL, -0.35), 3.4)
        for i in range(branches):
            x0 = 0.5 - w * 0.2 * (i / max(1, branches))
            y0 = 0.75 + i * (0.13 / max(1, branches))
            s = -1 if i % 2 else 1
            line(d, [(x0, y0), (x0 + s * w * 0.5, y0 + 0.07)],
                 dark(PANEL, -0.30), 2.4)
        for i in range(depth):
            circle(d, 0.5 + (i - depth / 2.0) * 0.09, 0.62 - i * 0.02, 0.030,
                   fill=mix(ACCENT, BONE, 0.25))

    @art("sepulgrub")
    def _(d, t):
        crack_form(d, 0.30, 2, 2)

    @art("sepulknell")
    def _(d, t):
        crack_form(d, 0.44, 4, 4)
        bell(d, 0.5, 0.42, 0.105, col=mix(BONE, ACCENT, 0.30))

    @art("gristlit")
    def _(d, t):
        circle(d, 0.5, 0.56, 0.135, fill=dark(BONE, 0.48), outline=BONE, width=3)
        circle(d, 0.5, 0.56, 0.036, fill=dark(PANEL, -0.25))

    @art("gristfen")
    def _(d, t):
        for i, (x, r) in enumerate(((0.36, 0.115), (0.64, 0.115))):
            circle(d, x, 0.56, r, fill=dark(BONE, 0.45), outline=BONE, width=3)
            circle(d, x, 0.56, r * 0.28, fill=dark(PANEL, -0.25))
        for i in range(4):
            circle(d, 0.32 + i * 0.12, 0.80, 0.026,
                   fill=mix(BONE, PANEL, 0.45))

    @art("gnawhusk")
    def _(d, t):
        husk_form(d, 0.155, 0.0, 2)
        line(d, [(0.42, 0.56), (0.58, 0.60)], dark(PANEL, -0.30), 2.6)

    @art("gnawloam")
    def _(d, t):
        husk_form(d, 0.215, 0.0, 4)
        for x in (0.40, 0.60):
            poly(d, [(x, 0.52), (x + 0.05, 0.44), (x + 0.02, 0.56)],
                 fill=dark(BONE, 0.20))

    @art("osswisp")
    def _(d, t):
        for i, (x, y) in enumerate(((0.40, 0.60), (0.55, 0.50), (0.62, 0.68))):
            bone(d, x, y, x + 0.10, y - 0.06, w=0.022, col=dark(BONE, 0.20))

    @art("ossloam")
    def _(d, t):
        for i, (x, y) in enumerate(((0.30, 0.66), (0.44, 0.48), (0.58, 0.62),
                                    (0.66, 0.44), (0.38, 0.78))):
            bone(d, x, y, x + 0.12, y - 0.07, w=0.024, col=dark(BONE, 0.18))

    def grim_form(d, r, spikes, pan):
        """Grim: a spiked iron collar -- Retribution as a worn object.

        Was a pair of scales, which at 78px is a thin cross with two commas
        hanging off it. Retribution is about hurting whatever touches you, so
        an outward-facing ring of spikes says it in one shape.
        """
        circle(d, 0.5, 0.54, r, fill=dark(PANEL, -0.18),
               outline=mix(BONE, ACCENT, 0.30), width=4)
        for i in range(spikes):
            a = math.radians(i * (360.0 / spikes) - 90)
            poly(d, [(0.5 + math.cos(a - 0.13) * r, 0.54 + math.sin(a - 0.13) * r),
                     (0.5 + math.cos(a) * r * 1.52, 0.54 + math.sin(a) * r * 1.52),
                     (0.5 + math.cos(a + 0.13) * r, 0.54 + math.sin(a + 0.13) * r)],
                 fill=mix(BONE, ACCENT, 0.34))
        if pan:
            circle(d, 0.5, 0.54, r * 0.34, fill=light(ACCENT, 0.35))

    @art("grimkin")
    def _(d, t):
        grim_form(d, 0.125, 8, False)

    @art("grimshroud")
    def _(d, t):
        grim_form(d, 0.165, 11, True)

    # ============================================================== HEAVEN
    # Liturgy: books, chalices, keys, candles, arches.

    def book_form(d, w, h, rays_n=0):
        poly(d, [(0.5 - w, 0.44), (0.5, 0.50), (0.5, 0.50 + h), (0.5 - w, 0.44 + h)],
             fill=mix(GOLD, BONE, 0.30))
        poly(d, [(0.5 + w, 0.44), (0.5, 0.50), (0.5, 0.50 + h), (0.5 + w, 0.44 + h)],
             fill=mix(GOLD, BONE, 0.15))
        line(d, [(0.5, 0.50), (0.5, 0.50 + h)], dark(GOLD, 0.35), 2.4)
        if rays_n:
            rays(d, 0.5, 0.40, 0.06, 0.20, light(GOLD, 0.30), rays_n, 2.2)

    @art("gloriamote")
    def _(d, t):
        book_form(d, 0.19, 0.24, 0)
        circle(d, 0.5, 0.36, 0.045, fill=GOLD)

    @art("glorialumen")
    def _(d, t):
        book_form(d, 0.235, 0.28, 8)
        circle(d, 0.5, 0.36, 0.055, fill=GOLD)

    @art("gloriathrone")
    def _(d, t):
        halo(d, 0.5, 0.42, 0.30, col=dark(GOLD, 0.30), width=2.4)
        book_form(d, 0.27, 0.32, 12)
        circle(d, 0.5, 0.34, 0.068, fill=GOLD)

    def chalice_form(d, r, stem_h, glow):
        arc(d, 0.5 - r, 0.36, 0.5 + r, 0.36 + r * 1.5, 0, 180, GOLD, 3.4)
        poly(d, [(0.5 - r, 0.42), (0.5 + r, 0.42), (0.5 + r * 0.30, 0.42 + r * 0.95),
                 (0.5 - r * 0.30, 0.42 + r * 0.95)], fill=mix(GOLD, BONE, 0.20))
        line(d, [(0.5, 0.42 + r * 0.95), (0.5, 0.42 + r * 0.95 + stem_h)],
             GOLD, 3.2)
        rect(d, 0.5 - r * 0.62, 0.42 + r * 0.95 + stem_h,
             0.5 + r * 0.62, 0.46 + r * 0.95 + stem_h,
             fill=GOLD, radius=0.012)
        if glow:
            circle(d, 0.5, 0.42, r * 0.55, fill=light(GOLD, 0.45))

    @art("sanctim")
    def _(d, t):
        chalice_form(d, 0.135, 0.10, False)

    @art("sanctcant")
    def _(d, t):
        chalice_form(d, 0.165, 0.13, True)

    @art("sanctthrone")
    def _(d, t):
        halo(d, 0.5, 0.48, 0.31, col=dark(GOLD, 0.32), width=2.4)
        chalice_form(d, 0.195, 0.15, True)
        rays(d, 0.5, 0.42, 0.22, 0.31, light(GOLD, 0.28), 10, 2.0)

    def candle_form(d, n, h, lit=True):
        base = 0.88
        for i in range(n):
            x = 0.5 + (i - (n - 1) / 2.0) * 0.15
            hh = h * (1.0 if i == (n - 1) // 2 else 0.78)
            rect(d, x - 0.032, base - hh, x + 0.032, base,
                 fill=mix(BONE, GOLD, 0.20), radius=0.010)
            if lit:
                circle(d, x, base - hh - 0.035, 0.030, fill=GOLD)
                circle(d, x, base - hh - 0.042, 0.014, fill=light(GOLD, 0.55))

    @art("psalmiel")
    def _(d, t):
        candle_form(d, 1, 0.34)

    @art("psalmcant")
    def _(d, t):
        candle_form(d, 3, 0.40)

    @art("cantmote")
    def _(d, t):
        candle_form(d, 1, 0.28, lit=False)

    @art("cantlumen")
    def _(d, t):
        candle_form(d, 3, 0.36)
        halo(d, 0.5, 0.44, 0.24, col=dark(GOLD, 0.35), width=2.2)

    def key_form(d, r, teeth):
        circle(d, 0.5, 0.36, r, outline=GOLD, width=4)
        line(d, [(0.5, 0.36 + r), (0.5, 0.84)], GOLD, 3.6)
        for i in range(teeth):
            y = 0.72 - i * 0.075
            line(d, [(0.5, y), (0.5 + 0.09, y)], GOLD, 3.0)

    @art("oratim")
    def _(d, t):
        key_form(d, 0.105, 1)

    @art("oratora")
    def _(d, t):
        key_form(d, 0.125, 2)
        rays(d, 0.5, 0.36, 0.16, 0.24, dark(GOLD, 0.25), 8, 2.0)

    def arch_form(d, w, h, keystone):
        line(d, [(0.5 - w, 0.88), (0.5 - w, 0.52)], mix(GOLD, BONE, 0.25), 3.4)
        line(d, [(0.5 + w, 0.88), (0.5 + w, 0.52)], mix(GOLD, BONE, 0.25), 3.4)
        arc(d, 0.5 - w, 0.52 - h, 0.5 + w, 0.52 + h, 180, 360,
            mix(GOLD, BONE, 0.25), 3.4)
        if keystone:
            circle(d, 0.5, 0.52 - h + 0.02, 0.042, fill=GOLD)

    @art("empyriel")
    def _(d, t):
        arch_form(d, 0.20, 0.16, False)

    @art("empyrseraph")
    def _(d, t):
        arch_form(d, 0.25, 0.20, True)
        wings(d, 0.5, 0.62, 0.34, 0.10, dark(GOLD, 0.30))

    @art("lucenmote")
    def _(d, t):
        circle(d, 0.5, 0.52, 0.085, fill=GOLD)
        halo(d, 0.5, 0.52, 0.16, col=dark(GOLD, 0.30), width=2.4)

    @art("lucenlumen")
    def _(d, t):
        circle(d, 0.5, 0.50, 0.115, fill=GOLD)
        circle(d, 0.5, 0.50, 0.052, fill=light(GOLD, 0.55))
        for i, r in enumerate((0.19, 0.26)):
            halo(d, 0.5, 0.50, r, col=dark(GOLD, 0.24 + i * 0.14), width=2.4)

    @art("matinkin")
    def _(d, t):
        # Sunrise over a line.
        rect(d, 0.12, 0.72, 0.88, 0.76, fill=dark(GOLD, 0.45), radius=0.008)
        arc(d, 0.30, 0.50, 0.70, 0.94, 180, 360, GOLD, 3.6)
        circle(d, 0.5, 0.72, 0.075, fill=GOLD)

    @art("matinora")
    def _(d, t):
        rect(d, 0.10, 0.72, 0.90, 0.76, fill=dark(GOLD, 0.45), radius=0.008)
        arc(d, 0.24, 0.44, 0.76, 1.00, 180, 360, GOLD, 3.8)
        circle(d, 0.5, 0.72, 0.105, fill=GOLD)
        rays(d, 0.5, 0.72, 0.14, 0.24, light(GOLD, 0.30), 7, 2.2, rot=180)

    @art("vesperkin")
    def _(d, t):
        rect(d, 0.12, 0.70, 0.88, 0.74, fill=dark(GOLD, 0.50), radius=0.008)
        arc(d, 0.32, 0.52, 0.68, 0.88, 180, 360, dark(GOLD, 0.20), 3.2)
        circle(d, 0.5, 0.70, 0.058, fill=dark(GOLD, 0.15))

    @art("vespercant")
    def _(d, t):
        rect(d, 0.10, 0.70, 0.90, 0.74, fill=dark(GOLD, 0.50), radius=0.008)
        arc(d, 0.26, 0.46, 0.74, 0.94, 180, 360, dark(GOLD, 0.12), 3.4)
        circle(d, 0.5, 0.70, 0.085, fill=GOLD)
        for i in range(3):
            circle(d, 0.24 + i * 0.26, 0.36, 0.020, fill=light(GOLD, 0.30))

    @art("auriel")
    def _(d, t):
        droplet(d, 0.5, 0.50, 0.145, mix(GOLD, BONE, 0.25))

    @art("aurora")
    def _(d, t):
        droplet(d, 0.5, 0.48, 0.175, GOLD)
        circle(d, 0.462, 0.455, 0.032, fill=light(GOLD, 0.55))
        halo(d, 0.5, 0.52, 0.25, col=dark(GOLD, 0.28), width=2.2)

    @art("bellkin")
    def _(d, t):
        bell(d, 0.5, 0.52, 0.115, col=dark(GOLD, 0.20), clapper=dark(GOLD, 0.5))

    @art("bellthrone")
    def _(d, t):
        bell(d, 0.5, 0.50, 0.165, col=GOLD, clapper=dark(GOLD, 0.40))
        for a in (212, 328):
            r = math.radians(a)
            line(d, [(0.5 + math.cos(r) * 0.24, 0.50 + math.sin(r) * 0.24),
                     (0.5 + math.cos(r) * 0.33, 0.50 + math.sin(r) * 0.33)],
                 light(GOLD, 0.35), 2.4)

    @art("clarmote")
    def _(d, t):
        star(d, 0.5, 0.52, 0.135, points=4, inner=0.34, fill=GOLD)

    @art("clarseraph")
    def _(d, t):
        star(d, 0.5, 0.50, 0.185, points=4, inner=0.32, fill=GOLD)
        halo(d, 0.5, 0.50, 0.27, col=dark(GOLD, 0.30), width=2.2)

    @art("seramote")
    def _(d, t):
        wings(d, 0.5, 0.54, 0.40, 0.12, dark(GOLD, 0.22))

    @art("seralumen")
    def _(d, t):
        wings(d, 0.5, 0.48, 0.48, 0.14, mix(GOLD, BONE, 0.35))
        wings(d, 0.5, 0.62, 0.34, 0.10, dark(GOLD, 0.30))
        circle(d, 0.5, 0.52, 0.058, fill=GOLD)

    @art("solemkin")
    def _(d, t):
        poly(d, [(0.5, 0.32), (0.5 + 0.17, 0.44), (0.5 + 0.14, 0.76),
                 (0.5, 0.86), (0.5 - 0.14, 0.76), (0.5 - 0.17, 0.44)],
             fill=dark(GOLD, 0.50), outline=dark(GOLD, 0.20), width=3)

    @art("solemthrone")
    def _(d, t):
        poly(d, [(0.5, 0.26), (0.5 + 0.225, 0.42), (0.5 + 0.185, 0.80),
                 (0.5, 0.92), (0.5 - 0.185, 0.80), (0.5 - 0.225, 0.42)],
             fill=dark(GOLD, 0.42), outline=GOLD, width=3)
        halo(d, 0.5, 0.54, 0.125, col=light(GOLD, 0.30), width=2.8)

    # ================================================================ VOID
    # Geometry: lacunae, spirals, shear lines, negative wedges.

    def lacuna_form(d, w, h, marks):
        """A block of text with a hole cut in it."""
        for i in range(marks):
            y = 0.36 + i * (0.42 / max(1, marks - 1))
            line(d, [(0.22, y), (0.78, y)], mix(TOWER, BONE, 0.22), 2.4)
        poly(d, [(0.5 - w, 0.50 - h), (0.5 + w, 0.50 - h * 0.7),
                 (0.5 + w * 0.85, 0.50 + h), (0.5 - w * 0.9, 0.50 + h * 0.8)],
             fill=dark(PANEL, -0.38))

    @art("lacunith")
    def _(d, t):
        lacuna_form(d, 0.115, 0.115, 4)

    @art("lacunlack")
    def _(d, t):
        lacuna_form(d, 0.155, 0.16, 5)

    @art("lacunabyss")
    def _(d, t):
        lacuna_form(d, 0.195, 0.21, 6)
        halo(d, 0.5, 0.50, 0.28, col=dark(TOWER, 0.35), width=2.0)

    def gyre_form(d, turns, r0, r1, w):
        pts = []
        n = int(turns * 26)
        for i in range(n):
            th = i * (turns * 2 * math.pi / n)
            rr = r0 + (r1 - r0) * i / n
            pts.append((0.5 + math.cos(th) * rr, 0.52 + math.sin(th) * rr))
        line(d, pts, mix(TOWER, BONE, 0.30), w)

    @art("gyresk")
    def _(d, t):
        gyre_form(d, 1.6, 0.03, 0.19, 2.8)

    @art("gyrerift")
    def _(d, t):
        gyre_form(d, 2.2, 0.03, 0.25, 3.0)
        circle(d, 0.5, 0.52, 0.035, fill=dark(PANEL, -0.35))

    @art("gyreshear")
    def _(d, t):
        gyre_form(d, 2.8, 0.03, 0.31, 3.2)
        circle(d, 0.5, 0.52, 0.055, fill=dark(PANEL, -0.40))
        circle(d, 0.5, 0.52, 0.055, outline=light(TOWER, 0.25), width=2)

    def shear_form(d, n, off, w):
        """Rive / Wane: a shape cut and offset along a diagonal."""
        for i in range(n):
            y0 = 0.32 + i * (0.44 / max(1, n - 1))
            s = off if i % 2 else -off
            line(d, [(0.24 + s, y0), (0.76 + s, y0 + 0.05)],
                 mix(TOWER, BONE, 0.26 + 0.06 * (i % 2)), w)

    @art("rivewane")
    def _(d, t):
        shear_form(d, 4, 0.035, 2.8)

    @art("riveshear")
    def _(d, t):
        shear_form(d, 6, 0.055, 3.0)
        line(d, [(0.5, 0.26), (0.44, 0.86)], dark(PANEL, -0.35), 3.4)

    @art("wanesk2")
    def _(d, t):
        circle(d, 0.5, 0.52, 0.155, fill=mix(TOWER, BONE, 0.26))
        circle(d, 0.565, 0.492, 0.145, fill=dark(t, 0.42))

    @art("waneshear")
    def _(d, t):
        circle(d, 0.5, 0.52, 0.185, fill=mix(TOWER, BONE, 0.30))
        circle(d, 0.60, 0.485, 0.175, fill=dark(t, 0.42))
        shear_form(d, 3, 0.03, 2.2)

    def wedge_form(d, n, r, tint):
        """Ebon / Pall / Stark: negative wedges taken out of a disc."""
        circle(d, 0.5, 0.52, r, fill=mix(tint, BONE, 0.24))
        for i in range(n):
            a0 = i * (360.0 / n) - 14
            a1 = a0 + 28
            pts = [(0.5, 0.52)]
            for a in (a0, (a0 + a1) / 2, a1):
                rad = math.radians(a)
                pts.append((0.5 + math.cos(rad) * r * 1.06,
                            0.52 + math.sin(rad) * r * 1.06))
            poly(d, pts, fill=dark(PANEL, -0.36))

    @art("ebonith")
    def _(d, t):
        wedge_form(d, 3, 0.145, TOWER)

    @art("ebonlack")
    def _(d, t):
        wedge_form(d, 5, 0.180, TOWER)

    @art("pallith")
    def _(d, t):
        wedge_form(d, 4, 0.150, TOWER)
        halo(d, 0.5, 0.52, 0.24, col=dark(TOWER, 0.40), width=2.0)

    @art("pallgaunt")
    def _(d, t):
        wedge_form(d, 6, 0.185, TOWER)
        halo(d, 0.5, 0.52, 0.28, col=dark(TOWER, 0.34), width=2.2)

    @art("starksk")
    def _(d, t):
        # Stark: everything inessential removed -- a bare cross-hair.
        line(d, [(0.5, 0.30), (0.5, 0.74)], mix(TOWER, BONE, 0.34), 3.0)
        line(d, [(0.28, 0.52), (0.72, 0.52)], mix(TOWER, BONE, 0.34), 3.0)
        circle(d, 0.5, 0.52, 0.048, fill=dark(PANEL, -0.35))

    @art("starkrift")
    def _(d, t):
        line(d, [(0.5, 0.24), (0.5, 0.80)], mix(TOWER, BONE, 0.38), 3.2)
        line(d, [(0.22, 0.52), (0.78, 0.52)], mix(TOWER, BONE, 0.38), 3.2)
        circle(d, 0.5, 0.52, 0.075, fill=dark(PANEL, -0.40))
        circle(d, 0.5, 0.52, 0.075, outline=light(TOWER, 0.22), width=2)

    def slag_form(d, n, r):
        for i in range(n):
            a = math.radians(i * (360.0 / n) + 20)
            rr = 0.13 * (0.6 + 0.4 * ((i * 5) % 3) / 2.0)
            poly(d, [(0.5 + math.cos(a) * rr, 0.54 + math.sin(a) * rr),
                     (0.5 + math.cos(a + 0.5) * (rr + r), 0.54 + math.sin(a + 0.5) * (rr + r)),
                     (0.5 + math.cos(a + 1.0) * rr, 0.54 + math.sin(a + 1.0) * rr)],
                 fill=mix(RUST, TOWER, 0.35 + 0.12 * (i % 3)))

    @art("drosssk")
    def _(d, t):
        slag_form(d, 5, 0.085)

    @art("drossebb")
    def _(d, t):
        slag_form(d, 8, 0.105)
        circle(d, 0.5, 0.54, 0.042, fill=dark(PANEL, -0.30))

    @art("cesssk")
    def _(d, t):
        ellipse(d, 0.22, 0.58, 0.78, 0.86, fill=dark(TOWER, 0.55))
        ellipse(d, 0.28, 0.62, 0.72, 0.82, fill=dark(TOWER, 0.40))

    @art("cessebb")
    def _(d, t):
        ellipse(d, 0.16, 0.54, 0.84, 0.88, fill=dark(TOWER, 0.58))
        ellipse(d, 0.22, 0.58, 0.78, 0.84, fill=dark(TOWER, 0.42))
        void_eye(d, 0.5, 0.68, 0.075, TOWER, ring=1.25)

    @art("nullsk")
    def _(d, t):
        circle(d, 0.5, 0.52, 0.145, outline=mix(TOWER, BONE, 0.28), width=3)

    @art("nulllack")
    def _(d, t):
        circle(d, 0.5, 0.52, 0.175, fill=dark(TOWER, 0.52),
               outline=mix(TOWER, BONE, 0.28), width=3)
        rect(d, 0.39, 0.497, 0.61, 0.543, fill=dark(PANEL, -0.35), radius=0.010)

    @art("umbrwane")
    def _(d, t):
        circle(d, 0.5, 0.52, 0.155, fill=dark(PANEL, -0.28))
        arc(d, 0.345, 0.365, 0.655, 0.675, 250, 350, dark(GOLD, 0.40), 2.6)

    @art("umbrabyss")
    def _(d, t):
        circle(d, 0.5, 0.52, 0.195, fill=dark(PANEL, -0.34))
        arc(d, 0.305, 0.325, 0.695, 0.715, 240, 360, dark(GOLD, 0.32), 2.8)
        void_eye(d, 0.5, 0.52, 0.085, TOWER, ring=1.30)

    @art("fanewane")
    def _(d, t):
        arch_form(d, 0.185, 0.15, False)

    @art("fanerift")
    def _(d, t):
        arch_form(d, 0.235, 0.19, False)
        void_eye(d, 0.5, 0.62, 0.095, TOWER, ring=1.30)

    @art("vastwane")
    def _(d, t):
        for i, r in enumerate((0.10, 0.17, 0.24)):
            circle(d, 0.5, 0.52, r, outline=dark(TOWER, 0.28 + i * 0.14), width=2)

    @art("vastabyss")
    def _(d, t):
        for i, r in enumerate((0.09, 0.16, 0.23, 0.30)):
            circle(d, 0.5, 0.52, r, outline=dark(TOWER, 0.22 + i * 0.13), width=2)
        void_eye(d, 0.5, 0.52, 0.075, TOWER, ring=1.28)

    def sev_form(d, r, gap, links):
        """Sev: a chain of links with one severed.

        A bare line with two dots reads as nothing at 78px -- it needs an object
        for the cut to be a cut *of*. A chain makes the break legible.
        """
        for i in range(links):
            x = 0.5 + (i - (links - 1) / 2.0) * r * 1.75
            if abs(i - (links - 1) / 2.0) < 0.6:
                # the severed link: two arcs pulled apart
                arc(d, x - r - gap, 0.52 - r, x + r - gap, 0.52 + r,
                    300, 240, mix(TOWER, BONE, 0.32), 3.0)
                arc(d, x - r + gap, 0.52 - r, x + r + gap, 0.52 + r,
                    120, 60, mix(TOWER, BONE, 0.32), 3.0)
            else:
                circle(d, x, 0.52, r, outline=mix(TOWER, BONE, 0.26), width=3)

    @art("sevsk")
    def _(d, t):
        sev_form(d, 0.085, 0.022, 3)

    @art("sevlack")
    def _(d, t):
        sev_form(d, 0.095, 0.042, 5)
        circle(d, 0.5, 0.52, 0.032, fill=dark(PANEL, -0.35))

    # ================================================================ GAIA
    # Specific plants: ferns, sedge, amber, burrs, tussocks.

    def fern_form(d, pairs, h, w):
        line(d, [(0.5, 0.88), (0.5, 0.88 - h)], dark(HP_GREEN, 0.28), 3.0)
        for i in range(pairs):
            y = 0.84 - i * (h / (pairs + 0.5))
            s = w * (1.0 - i * 0.11)
            for sign in (-1, 1):
                poly(d, [(0.5, y), (0.5 + sign * s, y - 0.045),
                         (0.5 + sign * s * 0.55, y + 0.035)],
                     fill=mix(HP_GREEN, BONE, 0.16 + 0.06 * (i % 3)))

    @art("gaia_fernshoot")
    def _(d, t):
        fern_form(d, 4, 0.38, 0.16)

    @art("gaia_fernbough")
    def _(d, t):
        fern_form(d, 6, 0.50, 0.21)

    def amber_form(d, beads, r, inclusion):
        for i in range(beads):
            a = math.radians(i * (360.0 / beads) - 90)
            rr = 0.14 if beads > 1 else 0.0
            x, y = 0.5 + math.cos(a) * rr, 0.54 + math.sin(a) * rr
            circle(d, x, y, r, fill=mix(GOLD, RUST, 0.30))
            circle(d, x - r * 0.28, y - r * 0.30, r * 0.30,
                   fill=light(GOLD, 0.40))
        if inclusion:
            line(d, [(0.46, 0.50), (0.54, 0.58)], dark(RUST, 0.40), 2.0)
            line(d, [(0.54, 0.50), (0.46, 0.58)], dark(RUST, 0.40), 2.0)

    @art("gaia_ambershoot")
    def _(d, t):
        amber_form(d, 1, 0.135, False)

    @art("gaia_amberbole")
    def _(d, t):
        amber_form(d, 1, 0.175, True)

    @art("gaia_amberwold")
    def _(d, t):
        amber_form(d, 4, 0.095, False)
        circle(d, 0.5, 0.54, 0.085, fill=mix(GOLD, RUST, 0.20))
        line(d, [(0.46, 0.50), (0.54, 0.58)], dark(RUST, 0.45), 2.2)

    def cald_form(d, w, h, cracks, glow):
        base = 0.90
        poly(d, [(0.5 - w, base), (0.5 - w * 0.55, base - h),
                 (0.5 + w * 0.5, base - h * 1.02), (0.5 + w, base)],
             fill=mix(BONE, PANEL, 0.58))
        for i in range(cracks):
            x = 0.5 - w * 0.4 + i * (w * 0.8 / max(1, cracks - 1))
            line(d, [(x, base), (x + w * 0.10, base - h * 0.80)],
                 mix(RUST, GOLD, glow), 2.4)

    @art("gaia_caldling")
    def _(d, t):
        cald_form(d, 0.19, 0.32, 3, 0.35)

    @art("gaia_caldcrag")
    def _(d, t):
        cald_form(d, 0.235, 0.42, 4, 0.45)

    @art("gaia_caldthane")
    def _(d, t):
        cald_form(d, 0.285, 0.54, 5, 0.55)
        circle(d, 0.5, 0.36, 0.055, fill=mix(RUST, GOLD, 0.50))

    def sedge_form(d, blades, h):
        for i in range(blades):
            x = 0.5 + (i - (blades - 1) / 2.0) * 0.075
            hh = h * (1.0 - abs(i - (blades - 1) / 2.0) * 0.13)
            s = 0.05 if i % 2 else -0.04
            line(d, [(x, 0.90), (x + s, 0.90 - hh)],
                 mix(HP_GREEN, BONE, 0.14 + 0.07 * (i % 3)), 2.8)

    @art("gaia_sedgesprout")
    def _(d, t):
        sedge_form(d, 5, 0.36)

    @art("gaia_sedgefen")
    def _(d, t):
        ellipse(d, 0.14, 0.80, 0.86, 0.94, fill=dark(TOWER, 0.55))
        sedge_form(d, 9, 0.48)

    def burr_form(d, r, spines):
        circle(d, 0.5, 0.55, r, fill=mix(HP_GREEN, RUST, 0.30))
        for i in range(spines):
            a = math.radians(i * (360.0 / spines))
            line(d, [(0.5 + math.cos(a) * r, 0.55 + math.sin(a) * r),
                     (0.5 + math.cos(a) * r * 1.55, 0.55 + math.sin(a) * r * 1.55)],
                 mix(BONE, HP_GREEN, 0.40), 2.2)
            circle(d, 0.5 + math.cos(a) * r * 1.62, 0.55 + math.sin(a) * r * 1.62,
                   0.012, fill=mix(BONE, HP_GREEN, 0.40))

    @art("gaia_burrbud")
    def _(d, t):
        burr_form(d, 0.105, 10)

    @art("gaia_burrcrag")
    def _(d, t):
        burr_form(d, 0.145, 14)

    def tuss_form(d, w, h, tufts):
        ellipse(d, 0.5 - w, 0.90 - h * 0.35, 0.5 + w, 0.94,
                fill=mix(RUST, PANEL, 0.55))
        for i in range(tufts):
            x = 0.5 + (i - (tufts - 1) / 2.0) * (w * 1.5 / tufts)
            hh = h * (0.7 + 0.3 * ((i * 3) % 3) / 2.0)
            line(d, [(x, 0.90 - h * 0.30), (x + 0.03, 0.90 - h * 0.30 - hh)],
                 mix(HP_GREEN, BONE, 0.16 + 0.06 * (i % 3)), 2.6)

    @art("gaia_tussling")
    def _(d, t):
        tuss_form(d, 0.20, 0.30, 7)

    @art("gaia_tussbole")
    def _(d, t):
        tuss_form(d, 0.26, 0.40, 10)

    def loam_form(d, w, layers, sprout):
        y = 0.90
        for i in range(layers):
            h = 0.075
            rect(d, 0.5 - w + i * 0.012, y - h, 0.5 + w - i * 0.012, y,
                 fill=mix(RUST, PANEL, 0.50 + i * 0.07), radius=0.014)
            y -= h
        if sprout:
            line(d, [(0.5, y), (0.5, y - 0.13)], dark(HP_GREEN, 0.25), 2.8)
            for sign in (-1, 1):
                poly(d, [(0.5, y - 0.09), (0.5 + sign * 0.08, y - 0.14),
                         (0.5 + sign * 0.04, y - 0.05)],
                     fill=mix(HP_GREEN, BONE, 0.18))

    @art("gaia_loambud")
    def _(d, t):
        loam_form(d, 0.24, 2, True)

    @art("gaia_loamwold")
    def _(d, t):
        loam_form(d, 0.29, 3, True)
        circle(d, 0.5, 0.34, 0.042, fill=mix(HP_GREEN, BONE, 0.30))

    @art("gaia_siltsprout")
    def _(d, t):
        for i in range(3):
            ellipse(d, 0.18 + i * 0.02, 0.74 + i * 0.05, 0.82 - i * 0.02,
                    0.84 + i * 0.05, fill=mix(RUST, PANEL, 0.48 + i * 0.10))

    @art("gaia_siltfen")
    def _(d, t):
        ellipse(d, 0.12, 0.72, 0.88, 0.92, fill=dark(TOWER, 0.55))
        for i in range(3):
            ellipse(d, 0.20 + i * 0.03, 0.76 + i * 0.04, 0.80 - i * 0.03,
                    0.86 + i * 0.04, fill=mix(RUST, PANEL, 0.44 + i * 0.10))
        sedge_form(d, 5, 0.30)

    @art("gaia_bryoshoot")
    def _(d, t):
        circle(d, 0.44, 0.72, 0.095, fill=mix(HP_GREEN, PANEL, 0.26))
        circle(d, 0.58, 0.70, 0.080, fill=mix(HP_GREEN, PANEL, 0.34))

    @art("gaia_bryowold")
    def _(d, t):
        for i, (x, y, r) in enumerate(((0.32, 0.74, 0.105), (0.48, 0.70, 0.125),
                                       (0.64, 0.73, 0.110), (0.76, 0.78, 0.080))):
            circle(d, x, y, r, fill=mix(HP_GREEN, PANEL, 0.20 + i * 0.07))
        for i in range(5):
            x = 0.30 + i * 0.10
            line(d, [(x, 0.64), (x, 0.52)], dark(HP_GREEN, 0.30), 2.0)

    @art("gaia_rootbud")
    def _(d, t):
        line(d, [(0.5, 0.88), (0.5, 0.56)], mix(RUST, HP_GREEN, 0.35), 3.4)
        line(d, [(0.5, 0.70), (0.38, 0.62)], dark(HP_GREEN, 0.30), 2.4)
        circle(d, 0.5, 0.50, 0.048, fill=mix(HP_GREEN, BONE, 0.28))

    @art("gaia_rootbole")
    def _(d, t):
        line(d, [(0.5, 0.92), (0.5, 0.46)], mix(RUST, HP_GREEN, 0.38), 4.0)
        for i, y in enumerate((0.80, 0.68, 0.58)):
            s = 0.16 - i * 0.03
            line(d, [(0.5, y), (0.5 - s, y - 0.07)], dark(HP_GREEN, 0.32), 2.6)
            line(d, [(0.5, y), (0.5 + s, y - 0.07)], dark(HP_GREEN, 0.32), 2.6)
        circle(d, 0.5, 0.40, 0.062, fill=mix(HP_GREEN, BONE, 0.30))

    @art("gaia_verdshoot")
    def _(d, t):
        line(d, [(0.5, 0.88), (0.5, 0.58)], dark(HP_GREEN, 0.28), 2.8)
        for sign in (-1, 1):
            poly(d, [(0.5, 0.66), (0.5 + sign * 0.13, 0.58),
                     (0.5 + sign * 0.06, 0.72)],
                 fill=mix(HP_GREEN, BONE, 0.20))

    @art("gaia_verdbole")
    def _(d, t):
        line(d, [(0.5, 0.90), (0.5, 0.44)], mix(RUST, HP_GREEN, 0.30), 4.2)
        for i, y in enumerate((0.74, 0.62, 0.52)):
            s = 0.19 - i * 0.03
            for sign in (-1, 1):
                poly(d, [(0.5, y), (0.5 + sign * s, y - 0.075),
                         (0.5 + sign * s * 0.5, y + 0.045)],
                     fill=mix(HP_GREEN, BONE, 0.16 + i * 0.06))

    @art("gaia_petribud")
    def _(d, t):
        circle(d, 0.5, 0.58, 0.125, fill=mix(HP_GREEN, PANEL, 0.30))
        poly(d, [(0.5, 0.46), (0.62, 0.54), (0.62, 0.66), (0.5, 0.71)],
             fill=mix(BONE, PANEL, 0.52))

    @art("gaia_petriwold")
    def _(d, t):
        circle(d, 0.5, 0.56, 0.165, fill=mix(HP_GREEN, PANEL, 0.34))
        poly(d, [(0.5, 0.40), (0.67, 0.50), (0.67, 0.66), (0.5, 0.73)],
             fill=mix(BONE, PANEL, 0.48))
        circle(d, 0.43, 0.54, 0.019, fill=light(HP_GREEN, 0.30))

    @art("gaia_lichshoot")
    def _(d, t):
        circle(d, 0.5, 0.56, 0.125, fill=mix(BONE, PANEL, 0.50))
        circle(d, 0.5, 0.56, 0.068, fill=mix(HP_GREEN, PANEL, 0.24))

    @art("gaia_lichfen")
    def _(d, t):
        circle(d, 0.5, 0.54, 0.175, fill=mix(BONE, PANEL, 0.46))
        circle(d, 0.5, 0.54, 0.100, fill=mix(HP_GREEN, PANEL, 0.20))
        for i in range(7):
            a = math.radians(i * 51)
            circle(d, 0.5 + math.cos(a) * 0.195, 0.54 + math.sin(a) * 0.195,
                   0.024, fill=mix(BONE, HP_GREEN, 0.38))

    @art("gaia_thornshoot")
    def _(d, t):
        line(d, [(0.5, 0.88), (0.5, 0.54)], dark(HP_GREEN, 0.30), 2.8)
        for i, y in enumerate((0.78, 0.68)):
            s = 1 if i % 2 else -1
            poly(d, [(0.5, y), (0.5 + s * 0.10, y - 0.06), (0.5, y - 0.02)],
                 fill=mix(BONE, HP_GREEN, 0.42))

    @art("gaia_thornwold")
    def _(d, t):
        for k, x in enumerate((0.34, 0.5, 0.66)):
            line(d, [(x, 0.90), (x + (k - 1) * 0.04, 0.46)],
                 dark(HP_GREEN, 0.32), 2.6)
            for i, y in enumerate((0.80, 0.70, 0.60)):
                s = 1 if (i + k) % 2 else -1
                poly(d, [(x, y), (x + s * 0.085, y - 0.055), (x, y - 0.02)],
                     fill=mix(BONE, HP_GREEN, 0.40))
