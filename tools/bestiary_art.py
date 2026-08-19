"""Emblems for the 58 creatures added by the bestiary pass (2026-08-15).

Imported by tools/make_card_art.py, which owns the palette, the 0..1 helpers
and the driver. This file holds only the per-card drawing functions, because
make_card_art.py was already 2029 lines and doubling it in place would have
made both halves harder to read.

The one rule that matters here, from docs/specs/bestiary.md:

    **A chain's creatures share a silhouette.** The Stage 2 is the Basic grown
    up -- same head shape, same posture, more mass. That is the visual half of
    the naming rule, and it is what makes an evolution legible on the board at
    78px without reading the card.

So each family below is written as one shape function taking a scale and a
weight, and the three stages call it with different numbers. Drawing each stage
independently is what lets a chain drift apart, which is exactly what the
Pokemon read cannot survive.
"""

import math


def register(env):
    """Attach every emblem to make_card_art's DRAW table.

    `env` is the module itself, so the helpers and palette resolve to the same
    objects the hand-written emblems use rather than to copies.
    """
    art = env.art
    P, poly, line = env.P, env.poly, env.line
    ellipse, circle, rect = env.ellipse, env.circle, env.rect
    arc, star, skull, bone = env.arc, env.star, env.skull, env.bone
    hexagon, serpent, halo = env.hexagon, env.serpent, env.halo
    rays, wings, bell, scales = env.rays, env.wings, env.bell, env.scales
    void_eye, droplet = env.void_eye, env.droplet
    mix, dark, light = env.mix, env.dark, env.light
    PANEL, BORDER, TEXT = env.PANEL, env.BORDER, env.TEXT
    GOLD, BONE, HP_GREEN = env.GOLD, env.BONE, env.HP_GREEN
    TOWER, DANGER, RUST = env.TOWER, env.DANGER, env.RUST
    ACCENT, TEXT_DIM = env.ACCENT, env.TEXT_DIM

    # ================================================================= HEL
    # Bone on the horizon line. Hel creatures are low, wide and skeletal.

    def grub_body(d, cx, cy, seg, r0, col, legs=True, taper=0.008):
        """Segmented crawler -- the Gnaw/Hollow/Grist family silhouette."""
        for i in range(seg):
            x = cx + (i - (seg - 1) / 2.0) * r0 * 1.55
            r = r0 - i * taper
            circle(d, x, cy + math.sin(i * 0.9) * r0 * 0.13, r,
                   fill=mix(col, PANEL, 0.30 + i * 0.07))
            if legs:
                line(d, [(x, cy + r * 0.85), (x - r * 0.5, cy + r * 1.9)],
                     dark(col, 0.5), 2.2)
        return cx + ((seg - 1) / 2.0) * r0 * 1.55

    def rime_shape(d, scale, spikes):
        """Rime: an ice crystal, NOT a skull.

        This was a frost-rimed skull with radiating needles, which at board size
        was indistinguishable from the Oss family two rows away -- both read as
        "purple skull with marks around it". Hel already spends its skull motif
        on Oss, so Rime has to be a different object entirely: a hard angular
        crystal against Oss's round bone.
        """
        r = 0.20 * scale
        for i in range(spikes):
            a = math.radians(i * (360.0 / spikes) - 90)
            w = math.radians(360.0 / spikes * 0.34)
            poly(d, [(0.5 + math.cos(a - w) * r * 0.42,
                      0.52 + math.sin(a - w) * r * 0.42),
                     (0.5 + math.cos(a) * r, 0.52 + math.sin(a) * r),
                     (0.5 + math.cos(a + w) * r * 0.42,
                      0.52 + math.sin(a + w) * r * 0.42)],
                 fill=mix(TOWER, BONE, 0.30 + 0.10 * (i % 2)))
        circle(d, 0.5, 0.52, r * 0.36, fill=light(TOWER, 0.40))
        circle(d, 0.5, 0.52, r * 0.16, fill=BONE)

    @art("rimelit")
    def _(d, t):
        rime_shape(d, 1.0, 6)

    @art("rimemire")
    def _(d, t):
        rime_shape(d, 1.42, 8)
        # Frozen ground: the mire it has stopped.
        for x in (0.20, 0.35, 0.65, 0.80):
            line(d, [(x, 0.90), (x, 0.78)], mix(TOWER, BONE, 0.35), 2.4)

    @art("gristwisp")
    def _(d, t):
        # A drifting cloud of mill-dust with a suggestion of a face.
        for i, (x, y, r) in enumerate(((0.42, 0.50, 0.10), (0.56, 0.46, 0.085),
                                       (0.50, 0.60, 0.07))):
            circle(d, x, y, r, fill=mix(BONE, PANEL, 0.45 + i * 0.1))
        circle(d, 0.455, 0.485, 0.017, fill=dark(PANEL, -0.3))
        circle(d, 0.545, 0.465, 0.017, fill=dark(PANEL, -0.3))

    @art("gristgaunt")
    def _(d, t):
        # The mill itself: a grinding wheel over the same dust.
        circle(d, 0.5, 0.47, 0.20, fill=dark(BONE, 0.45), outline=BONE, width=3)
        circle(d, 0.5, 0.47, 0.055, fill=dark(PANEL, -0.25))
        for a in range(0, 360, 45):
            r = math.radians(a)
            line(d, [(0.5 + math.cos(r) * 0.07, 0.47 + math.sin(r) * 0.07),
                     (0.5 + math.cos(r) * 0.19, 0.47 + math.sin(r) * 0.19)],
                 dark(BONE, 0.2), 2.4)
        for i, x in enumerate((0.36, 0.5, 0.64)):
            circle(d, x, 0.78, 0.035 - i * 0.004,
                   fill=mix(BONE, PANEL, 0.5))

    @art("hollowgrub")
    def _(d, t):
        head = grub_body(d, 0.48, 0.56, 4, 0.085, mix(ACCENT, BONE, 0.30))
        circle(d, head + 0.055, 0.53, 0.062, fill=mix(BONE, ACCENT, 0.25))
        circle(d, head + 0.085, 0.515, 0.016, fill=DANGER)

    @art("hollowmaw")
    def _(d, t):
        head = grub_body(d, 0.44, 0.55, 5, 0.095, mix(ACCENT, BONE, 0.35))
        circle(d, head + 0.06, 0.52, 0.075, fill=mix(BONE, ACCENT, 0.3))
        # The maw: a dark wedge where a face should be.
        poly(d, [(head + 0.02, 0.47), (head + 0.135, 0.50),
                 (head + 0.02, 0.575)], fill=dark(PANEL, -0.35))
        circle(d, head + 0.075, 0.495, 0.016, fill=DANGER)

    @art("hollowdrung")
    def _(d, t):
        head = grub_body(d, 0.40, 0.55, 6, 0.105, mix(ACCENT, BONE, 0.40))
        circle(d, head + 0.065, 0.51, 0.09, fill=mix(BONE, ACCENT, 0.35))
        poly(d, [(head + 0.005, 0.44), (head + 0.165, 0.495),
                 (head + 0.005, 0.60)], fill=dark(PANEL, -0.4))
        for i in range(4):
            y = 0.455 + i * 0.032
            line(d, [(head + 0.03, y), (head + 0.115, y + 0.012)],
                 BONE, 1.8)
        circle(d, head + 0.085, 0.475, 0.018, fill=DANGER)

    def oss_shape(d, r, ribs, crown):
        """Oss: bone that reassembles. A skull ringed by orbiting fragments."""
        skull(d, 0.5, 0.53, r, col=BONE, eye=dark(PANEL, -0.25))
        for i in range(ribs):
            a = math.radians(-90 + i * (360.0 / ribs))
            rr = r * 2.05
            bx, by = 0.5 + math.cos(a) * rr, 0.53 + math.sin(a) * rr
            circle(d, bx, by, r * 0.16, fill=dark(BONE, 0.2))
        if crown:
            for i in range(5):
                x = 0.5 + (i - 2) * r * 0.42
                h = r * (0.55 if i % 2 == 0 else 0.34)
                poly(d, [(x - r * 0.12, 0.53 - r), (x + r * 0.12, 0.53 - r),
                         (x, 0.53 - r - h)], fill=dark(BONE, 0.15))

    @art("osskin")
    def _(d, t):
        oss_shape(d, 0.125, 5, False)

    @art("ossshroud")
    def _(d, t):
        # Shroud first, skull on top -- drawing the skull twice (once under the
        # shroud) just hides the shroud and makes this read as the Basic.
        poly(d, [(0.26, 0.40), (0.74, 0.40), (0.68, 0.90), (0.32, 0.90)],
             fill=dark(ACCENT, 0.60))
        for x in (0.38, 0.5, 0.62):
            line(d, [(x, 0.44), (x - 0.02, 0.88)], dark(ACCENT, 0.72), 2.0)
        oss_shape(d, 0.15, 7, False)

    @art("ossrend")
    def _(d, t):
        poly(d, [(0.24, 0.38), (0.76, 0.38), (0.68, 0.92), (0.32, 0.92)],
             fill=dark(ACCENT, 0.66))
        oss_shape(d, 0.165, 9, True)

    @art("gnawling")
    def _(d, t):
        head = grub_body(d, 0.46, 0.58, 3, 0.075, mix(HP_GREEN, PANEL, 0.25))
        circle(d, head + 0.05, 0.555, 0.055, fill=mix(HP_GREEN, BONE, 0.30))
        circle(d, head + 0.075, 0.54, 0.014, fill=DANGER)

    @art("gnawmire")
    def _(d, t):
        head = grub_body(d, 0.42, 0.56, 5, 0.088, mix(HP_GREEN, PANEL, 0.32))
        circle(d, head + 0.055, 0.53, 0.068, fill=mix(HP_GREEN, BONE, 0.34))
        # Mandibles.
        line(d, [(head + 0.10, 0.50), (head + 0.16, 0.455)], BONE, 2.6)
        line(d, [(head + 0.10, 0.565), (head + 0.16, 0.61)], BONE, 2.6)
        circle(d, head + 0.08, 0.515, 0.016, fill=DANGER)

    @art("morgrub")
    def _(d, t):
        # Mor is a swarm: many small bodies reading as one mass.
        for i in range(11):
            a = math.radians(i * 32.7)
            rr = 0.075 + (i % 3) * 0.055
            x, y = 0.5 + math.cos(a) * rr, 0.54 + math.sin(a) * rr * 0.8
            circle(d, x, y, 0.036 - (i % 3) * 0.004,
                   fill=mix(ACCENT, BONE, 0.20 + (i % 4) * 0.08))
        circle(d, 0.5, 0.54, 0.045, fill=dark(PANEL, -0.2))

    @art("sepulwisp")
    def _(d, t):
        # A mourner: a hooded shade over a small bell.
        poly(d, [(0.5, 0.30), (0.68, 0.62), (0.32, 0.62)],
             fill=dark(ACCENT, 0.55))
        circle(d, 0.5, 0.40, 0.075, fill=dark(PANEL, -0.15))
        circle(d, 0.47, 0.395, 0.014, fill=light(ACCENT, 0.45))
        circle(d, 0.53, 0.395, 0.014, fill=light(ACCENT, 0.45))
        bell(d, 0.5, 0.74, 0.10, col=mix(BONE, ACCENT, 0.25))

    @art("cairnling")
    def _(d, t):
        # A stacked cairn with eyes in the gaps.
        ws = (0.24, 0.20, 0.155, 0.11)
        y = 0.86
        for i, w in enumerate(ws):
            h = 0.085 - i * 0.008
            rect(d, 0.5 - w / 2, y - h, 0.5 + w / 2, y,
                 fill=mix(BONE, PANEL, 0.42 + i * 0.06), radius=0.018)
            y -= h + 0.012
        circle(d, 0.462, 0.585, 0.016, fill=light(ACCENT, 0.4))
        circle(d, 0.538, 0.585, 0.016, fill=light(ACCENT, 0.4))

    # ============================================================== HEAVEN
    # Gold, radially symmetric, floating above the horizon.

    def lume_form(d, cy, r, ray_count, wing_span=0.0):
        if wing_span:
            wings(d, 0.5, cy, wing_span, r * 0.55, mix(GOLD, BONE, 0.35))
        rays(d, 0.5, cy, r * 1.25, r * 2.05, dark(GOLD, 0.25), ray_count, 2.2)
        circle(d, 0.5, cy, r, fill=GOLD)
        circle(d, 0.5, cy, r * 0.55, fill=light(GOLD, 0.45))

    @art("vespermote")
    def _(d, t):
        lume_form(d, 0.50, 0.10, 8)
        line(d, [(0.5, 0.66), (0.5, 0.86)], dark(GOLD, 0.35), 2.4)

    @art("vespervigil")
    def _(d, t):
        lume_form(d, 0.46, 0.135, 12, wing_span=0.42)
        halo(d, 0.5, 0.46, 0.21, col=light(GOLD, 0.3), width=2.6)

    def solem_form(d, cy, w, h, shield_tone):
        """Solem: an interposing shield. Sanctuary drawn as a body."""
        poly(d, [(0.5, cy - h), (0.5 + w, cy - h * 0.35),
                 (0.5 + w * 0.82, cy + h * 0.72), (0.5, cy + h),
                 (0.5 - w * 0.82, cy + h * 0.72), (0.5 - w, cy - h * 0.35)],
             fill=shield_tone, outline=light(GOLD, 0.35), width=3)

    @art("solemim")
    def _(d, t):
        solem_form(d, 0.53, 0.19, 0.24, dark(GOLD, 0.48))
        circle(d, 0.5, 0.52, 0.055, fill=light(GOLD, 0.4))

    @art("solemmant")
    def _(d, t):
        solem_form(d, 0.52, 0.235, 0.30, dark(GOLD, 0.42))
        halo(d, 0.5, 0.50, 0.145, col=GOLD, width=3.0)
        circle(d, 0.5, 0.50, 0.06, fill=light(GOLD, 0.5))

    @art("solemtribune")
    def _(d, t):
        # Wings behind a shield reads as a saucer at board size -- the wing
        # sweep and the shield's shoulders merge into one horizontal disc. The
        # shield alone, larger, keeps the family silhouette and stays a shield.
        halo(d, 0.5, 0.50, 0.34, col=dark(GOLD, 0.30), width=2.4)
        solem_form(d, 0.52, 0.275, 0.36, dark(GOLD, 0.34))
        halo(d, 0.5, 0.49, 0.155, col=light(GOLD, 0.25), width=3.0)
        circle(d, 0.5, 0.49, 0.065, fill=light(GOLD, 0.45))

    def halo_form(d, r, ring_count):
        """A branded mark: a solid gold core inside its rings.

        The first version drew thin rings around a small dot, which at 78px is
        an empty hexagon -- the ring reads as the card border and the core is
        too small to see. The core has to carry the silhouette.
        """
        for i in range(ring_count):
            halo(d, 0.5, 0.52, r * 1.55 + i * 0.055,
                 col=dark(GOLD, 0.20 + i * 0.12), width=2.6)
        circle(d, 0.5, 0.52, r, fill=GOLD)
        circle(d, 0.5, 0.52, r * 0.46, fill=dark(PANEL, -0.15))

    @art("halokin")
    def _(d, t):
        halo_form(d, 0.115, 1)

    @art("halosear")
    def _(d, t):
        halo_form(d, 0.155, 2)
        rays(d, 0.5, 0.52, 0.27, 0.36, light(GOLD, 0.25), 8, 2.2)

    @art("clariel")
    def _(d, t):
        bell(d, 0.5, 0.50, 0.145, col=GOLD, clapper=dark(GOLD, 0.4))
        arc(d, 0.30, 0.30, 0.70, 0.70, 200, 340, light(GOLD, 0.35), 2.2)

    @art("clarchoir")
    def _(d, t):
        # Two flanking bells behind one larger -- three at equal size crowd the
        # 78px board read into an undifferentiated mound.
        for x in (0.29, 0.71):
            bell(d, x, 0.58, 0.088, col=dark(GOLD, 0.28),
                 clapper=dark(GOLD, 0.5))
        bell(d, 0.5, 0.50, 0.145, col=GOLD, clapper=dark(GOLD, 0.4))

    @art("clararch")
    def _(d, t):
        # One bell, large, haloed and ringing. The wings read as a *table* under
        # the bells at board size, and three bells plus wings is four shapes
        # competing for one silhouette -- the same "figure competing with its own
        # props" failure the Heaven and Void emblems already hit once.
        halo(d, 0.5, 0.50, 0.30, col=dark(GOLD, 0.30), width=2.4)
        bell(d, 0.5, 0.52, 0.215, col=GOLD, clapper=dark(GOLD, 0.42))
        for a in (208, 232, 308, 332):
            r = math.radians(a)
            line(d, [(0.5 + math.cos(r) * 0.30, 0.52 + math.sin(r) * 0.30),
                     (0.5 + math.cos(r) * 0.40, 0.52 + math.sin(r) * 0.40)],
                 light(GOLD, 0.35), 2.4)

    @art("aurmote")
    def _(d, t):
        # A gilded droplet: Sanctuary as a bead of gold.
        droplet(d, 0.5, 0.50, 0.17, GOLD)
        circle(d, 0.463, 0.475, 0.032, fill=light(GOLD, 0.55))
        halo(d, 0.5, 0.54, 0.20, col=dark(GOLD, 0.2), width=2.2)

    @art("lumekin")
    def _(d, t):
        lume_form(d, 0.50, 0.095, 10)
        # Rise: a second, fainter self behind it.
        circle(d, 0.5, 0.50, 0.165, outline=dark(GOLD, 0.45), width=2)

    @art("bellmote")
    def _(d, t):
        bell(d, 0.5, 0.52, 0.135, col=GOLD, clapper=dark(GOLD, 0.4))
        for i, a in enumerate((215, 250, 290, 325)):
            r = math.radians(a)
            line(d, [(0.5 + math.cos(r) * 0.20, 0.52 + math.sin(r) * 0.20),
                     (0.5 + math.cos(r) * 0.27, 0.52 + math.sin(r) * 0.27)],
                 light(GOLD, 0.3), 2.0)

    @art("serakin")
    def _(d, t):
        wings(d, 0.5, 0.50, 0.46, 0.13, mix(GOLD, BONE, 0.38))
        wings(d, 0.5, 0.60, 0.34, 0.10, dark(GOLD, 0.28))
        circle(d, 0.5, 0.50, 0.085, fill=GOLD)
        circle(d, 0.5, 0.50, 0.042, fill=light(GOLD, 0.5))

    # ================================================================ VOID
    # Built out of what is missing: a near-black hole with a bright rim.

    def void_form(d, cx, cy, r, tint, rim=1.30, teeth=0):
        void_eye(d, cx, cy, r, tint, ring=rim)
        if teeth:
            for i in range(teeth):
                a = math.radians(i * (360.0 / teeth))
                r0, r1 = r * rim, r * (rim + 0.30)
                line(d, [(cx + math.cos(a) * r0, cy + math.sin(a) * r0),
                         (cx + math.cos(a) * r1, cy + math.sin(a) * r1)],
                     light(tint, 0.30), 2.0)

    @art("faneith")
    def _(d, t):
        # A ruined shrine arch with nothing inside it.
        arc(d, 0.30, 0.36, 0.70, 0.92, 180, 360, mix(t, BONE, 0.25), 3.2)
        line(d, [(0.30, 0.64), (0.30, 0.88)], mix(t, BONE, 0.25), 3.2)
        line(d, [(0.70, 0.64), (0.70, 0.88)], mix(t, BONE, 0.25), 3.2)
        void_form(d, 0.5, 0.62, 0.105, t)

    @art("fanefray")
    def _(d, t):
        arc(d, 0.24, 0.30, 0.76, 0.94, 180, 360, mix(t, BONE, 0.30), 3.4)
        line(d, [(0.24, 0.62), (0.26, 0.90)], mix(t, BONE, 0.30), 3.4)
        line(d, [(0.76, 0.62), (0.74, 0.90)], mix(t, BONE, 0.30), 3.4)
        void_form(d, 0.5, 0.58, 0.135, t, teeth=8)

    def vast_form(d, r, rings, teeth):
        for i in range(rings):
            rr = r + 0.055 * (i + 1)
            circle(d, 0.5, 0.52, rr, outline=dark(TOWER, 0.35 + i * 0.12),
                   width=2)
        void_form(d, 0.5, 0.52, r, TOWER, teeth=teeth)

    @art("vastsk")
    def _(d, t):
        vast_form(d, 0.105, 1, 0)

    @art("vastebb")
    def _(d, t):
        vast_form(d, 0.135, 2, 6)

    @art("vastnought")
    def _(d, t):
        vast_form(d, 0.165, 3, 10)

    def scour_form(d, cy, n, w):
        """Scour: parallel abrasion streaks stripping a surface."""
        for i in range(n):
            y = cy - (n - 1) * 0.028 / 2 + i * 0.028
            x0 = 0.22 + (i % 2) * 0.05
            line(d, [(x0, y), (0.80, y - 0.02)],
                 mix(TOWER, BONE, 0.18 + i * 0.06), w)

    @art("scourwane")
    def _(d, t):
        scour_form(d, 0.52, 4, 2.4)
        void_form(d, 0.72, 0.48, 0.075, t)

    @art("scourgaunt")
    def _(d, t):
        scour_form(d, 0.53, 6, 2.8)
        void_form(d, 0.75, 0.47, 0.10, t, teeth=6)

    @art("hushwane")
    def _(d, t):
        # Sound cut off: concentric arcs that stop short.
        for i, r in enumerate((0.13, 0.19, 0.25)):
            arc(d, 0.5 - r, 0.52 - r, 0.5 + r, 0.52 + r,
                200 + i * 12, 340 - i * 12, mix(TOWER, BONE, 0.3 - i * 0.08), 2.4)
        void_form(d, 0.5, 0.56, 0.085, t)

    @art("hushebb")
    def _(d, t):
        for i, r in enumerate((0.15, 0.22, 0.29, 0.36)):
            arc(d, 0.5 - r, 0.52 - r, 0.5 + r, 0.52 + r,
                205 + i * 14, 335 - i * 14, mix(TOWER, BONE, 0.34 - i * 0.07), 2.6)
        void_form(d, 0.5, 0.55, 0.11, t, teeth=6)

    def umbr_form(d, r, spread, teeth):
        # A shadow that keeps the light: dark core, bright crescent.
        circle(d, 0.5, 0.52, r * 1.5, fill=dark(PANEL, -0.30))
        arc(d, 0.5 - r * 1.5, 0.52 - r * 1.5, 0.5 + r * 1.5, 0.52 + r * 1.5,
            300 - spread, 300 + spread, light(GOLD, 0.20), 3.0)
        void_form(d, 0.5, 0.52, r, TOWER, teeth=teeth)

    @art("umbrsk")
    def _(d, t):
        umbr_form(d, 0.095, 40, 0)

    @art("umbrfray")
    def _(d, t):
        umbr_form(d, 0.12, 55, 6)

    @art("umbrreave")
    def _(d, t):
        umbr_form(d, 0.145, 70, 10)
        halo(d, 0.5, 0.52, 0.30, col=dark(GOLD, 0.55), width=2.0)

    @art("nullwane")
    def _(d, t):
        # Subtraction: a minus bitten out of a disc.
        circle(d, 0.5, 0.52, 0.165, fill=dark(TOWER, 0.55),
               outline=mix(TOWER, BONE, 0.25), width=3)
        rect(d, 0.40, 0.495, 0.60, 0.545, fill=dark(PANEL, -0.35), radius=0.012)

    @art("sevith")
    def _(d, t):
        # A severed link: two half-rings pulled apart.
        arc(d, 0.20, 0.34, 0.56, 0.70, 300, 240, mix(TOWER, BONE, 0.28), 3.4)
        arc(d, 0.44, 0.42, 0.80, 0.78, 120, 60, mix(TOWER, BONE, 0.28), 3.4)
        void_form(d, 0.5, 0.56, 0.07, t)

    @art("waneith")
    def _(d, t):
        # A crescent, dwindling. The bite is cut with the backdrop tone rather
        # than a transparent hole -- the emblem is composited onto an already
        # painted backdrop, so an alpha punch would show the card frame through.
        circle(d, 0.5, 0.52, 0.175, fill=mix(TOWER, BONE, 0.30))
        circle(d, 0.575, 0.485, 0.165, fill=dark(t, 0.42))
        halo(d, 0.5, 0.52, 0.245, col=dark(TOWER, 0.30), width=2.0)

    # ================================================================ GAIA
    # On the ground line, growing upward. Soft and rounded.

    def mycel_form(d, cap_r, stalks):
        for i in range(stalks):
            x = 0.5 + (i - (stalks - 1) / 2.0) * cap_r * 1.35
            h = 0.86 - (0.10 if i % 2 else 0.16)
            line(d, [(x, 0.88), (x, h)], mix(BONE, HP_GREEN, 0.35), 3.0)
            r = cap_r * (0.72 if i % 2 else 1.0)
            ellipse(d, x - r, h - r * 0.78, x + r, h + r * 0.42,
                    fill=mix(HP_GREEN, BONE, 0.22 + 0.1 * (i % 3)))

    @art("gaia_mycelspore")
    def _(d, t):
        mycel_form(d, 0.085, 3)

    @art("gaia_mycelbough")
    def _(d, t):
        mycel_form(d, 0.105, 5)
        # Mycelial threads under the ground line.
        for i in range(5):
            x0 = 0.22 + i * 0.14
            line(d, [(x0, 0.90), (x0 + 0.09, 0.955)],
                 dark(HP_GREEN, 0.45), 1.8)

    def gran_form(d, w, h, facets):
        base = 0.90
        poly(d, [(0.5 - w, base), (0.5 - w * 0.72, base - h),
                 (0.5 + w * 0.62, base - h * 1.05), (0.5 + w, base)],
             fill=mix(BONE, PANEL, 0.52), outline=mix(BONE, HP_GREEN, 0.30),
             width=3)
        for i in range(facets):
            x = 0.5 - w * 0.5 + i * (w / max(1, facets - 1))
            line(d, [(x, base), (x + w * 0.12, base - h * 0.85)],
                 dark(BONE, 0.42), 1.8)

    @art("gaia_granling")
    def _(d, t):
        gran_form(d, 0.17, 0.30, 3)
        circle(d, 0.455, 0.70, 0.017, fill=light(HP_GREEN, 0.35))
        circle(d, 0.545, 0.70, 0.017, fill=light(HP_GREEN, 0.35))

    @art("gaia_grancrag")
    def _(d, t):
        gran_form(d, 0.225, 0.40, 4)
        circle(d, 0.44, 0.64, 0.019, fill=light(HP_GREEN, 0.4))
        circle(d, 0.56, 0.64, 0.019, fill=light(HP_GREEN, 0.4))

    @art("gaia_granthane")
    def _(d, t):
        gran_form(d, 0.275, 0.52, 5)
        circle(d, 0.43, 0.58, 0.022, fill=light(HP_GREEN, 0.45))
        circle(d, 0.57, 0.58, 0.022, fill=light(HP_GREEN, 0.45))
        for i in (-1, 1):
            poly(d, [(0.5 + i * 0.20, 0.50), (0.5 + i * 0.30, 0.34),
                     (0.5 + i * 0.26, 0.52)], fill=mix(BONE, PANEL, 0.45))

    def root_form(d, spread, depth, coils):
        line(d, [(0.5, 0.86), (0.5, 0.86 - depth)],
             mix(RUST, HP_GREEN, 0.35), 4.0)
        for i in range(coils):
            s = spread * (1.0 - i * 0.16)
            y = 0.86 - depth * (i + 1) / (coils + 1)
            line(d, [(0.5, y), (0.5 - s, y - 0.06)], dark(HP_GREEN, 0.30), 2.6)
            line(d, [(0.5, y), (0.5 + s, y - 0.06)], dark(HP_GREEN, 0.30), 2.6)

    @art("gaia_rootsprout")
    def _(d, t):
        root_form(d, 0.16, 0.32, 3)
        circle(d, 0.5, 0.50, 0.055, fill=mix(HP_GREEN, BONE, 0.30))

    @art("gaia_rootwarden")
    def _(d, t):
        root_form(d, 0.22, 0.44, 4)
        circle(d, 0.5, 0.40, 0.075, fill=mix(HP_GREEN, BONE, 0.35))
        circle(d, 0.478, 0.385, 0.014, fill=dark(PANEL, -0.2))
        circle(d, 0.522, 0.385, 0.014, fill=dark(PANEL, -0.2))

    def thorn_form(d, r, spikes, eye):
        circle(d, 0.5, 0.55, r, fill=mix(HP_GREEN, PANEL, 0.30))
        for i in range(spikes):
            a = math.radians(i * (360.0 / spikes) - 90)
            r0, r1 = r * 0.95, r * 1.75
            poly(d, [(0.5 + math.cos(a - 0.14) * r0, 0.55 + math.sin(a - 0.14) * r0),
                     (0.5 + math.cos(a) * r1, 0.55 + math.sin(a) * r1),
                     (0.5 + math.cos(a + 0.14) * r0, 0.55 + math.sin(a + 0.14) * r0)],
                 fill=mix(BONE, HP_GREEN, 0.45))
        if eye:
            circle(d, 0.5, 0.55, r * 0.32, fill=dark(PANEL, -0.25))
            circle(d, 0.5, 0.55, r * 0.15, fill=DANGER)

    @art("gaia_thornbud")
    def _(d, t):
        thorn_form(d, 0.105, 7, False)

    @art("gaia_thorncrag")
    def _(d, t):
        thorn_form(d, 0.135, 9, True)

    @art("gaia_thornheart")
    def _(d, t):
        thorn_form(d, 0.165, 12, True)
        halo(d, 0.5, 0.55, 0.31, col=dark(HP_GREEN, 0.40), width=2.2)

    @art("gaia_bryospore")
    def _(d, t):
        # A moss cushion: overlapping soft lobes on the ground line.
        for i, (x, y, r) in enumerate(((0.38, 0.70, 0.115), (0.54, 0.66, 0.135),
                                       (0.66, 0.72, 0.10))):
            circle(d, x, y, r, fill=mix(HP_GREEN, PANEL, 0.22 + i * 0.09))
        for i in range(6):
            x = 0.32 + i * 0.075
            line(d, [(x, 0.62 - (i % 2) * 0.03), (x, 0.50 - (i % 2) * 0.04)],
                 dark(HP_GREEN, 0.32), 2.0)

    @art("gaia_petriling")
    def _(d, t):
        # Half flesh, half stone -- the chain's whole arc in one body.
        circle(d, 0.5, 0.56, 0.155, fill=mix(HP_GREEN, PANEL, 0.30))
        poly(d, [(0.5, 0.405), (0.655, 0.50), (0.655, 0.63), (0.5, 0.715)],
             fill=mix(BONE, PANEL, 0.50))
        circle(d, 0.44, 0.53, 0.019, fill=light(HP_GREEN, 0.35))

    @art("gaia_lichbud")
    def _(d, t):
        # Two organisms as one: a ring of crust around a green core.
        circle(d, 0.5, 0.55, 0.165, fill=mix(BONE, PANEL, 0.48))
        circle(d, 0.5, 0.55, 0.095, fill=mix(HP_GREEN, PANEL, 0.20))
        for i in range(9):
            a = math.radians(i * 40)
            circle(d, 0.5 + math.cos(a) * 0.185, 0.55 + math.sin(a) * 0.185,
                   0.026, fill=mix(BONE, HP_GREEN, 0.35))

    @art("gaia_verdspore")
    def _(d, t):
        # New growth: a curled frond unrolling.
        pts = []
        for i in range(26):
            th = i * 0.30
            rr = 0.035 + th * 0.028
            pts.append((0.46 + math.cos(th - 1.4) * rr,
                        0.60 - math.sin(th - 1.4) * rr))
        line(d, pts, mix(HP_GREEN, BONE, 0.28), 3.4)
        circle(d, pts[-1][0], pts[-1][1], 0.030, fill=light(HP_GREEN, 0.30))
