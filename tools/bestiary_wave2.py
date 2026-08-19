"""Wave 2 of the bestiary: +30 creatures per faction (120 total).

Imported by tools/add_bestiary_units.py, which owns the pricing, the validation
and the writer. This file is only the roster, kept separate because wave 1 plus
wave 2 in one literal is 700 lines of table that nobody can read.

Three decisions from conversation shape every card here:

**Power is deliberately varied, not uniform.** At 234 units a 60-card deck picks
~12 unit slots from ~57 candidates, so most cards are collection content rather
than deck content. Writing 120 more cards all competing at the same power level
produces 120 interchangeable creatures. So each faction gets roughly:

    ~12 vanilla   - no keyword, one attack, cheap. Populates the world.
    ~13 staple    - one keyword, a solid body. The middle of a deck.
    ~5  build-around - keyword plus an ability. A reason to build.

**A vanilla Basic must evolve into something that carries a keyword.** Not every
card needs to touch a mechanic, but a card that touches no mechanic AND goes
nowhere is a dead draw. The vanillas here are all the bottom of a line, and the
generator enforces it: `VANILLA_MUST_EVOLVE`.

**No new keywords.** Wave 2 extends what each faction already does. Everything
below draws from the shipped pool -- Toll, Decay, Rise, Retribution, Judgment,
Sanctuary, Siphon, Rift, Earth, Essence, Resist -- so nothing here needs engine
work, documentation, or a new harness assertion.

Naming follows the wave-2 stem banks in docs/specs/bestiary.md: a second
register per faction (Hel's rot-and-cold against wave 1's bone-and-burial) so a
new creature is recognisably the same colour without sounding like a card that
already exists.
"""


def build(A):
    """Return {faction: [(stem, [forms...])]}, in add_bestiary_units' shape.

    `A` is that module's attack/ability constructor, passed in so this file has
    no import cycle back to it.
    """

    hel = [
        # ---- build-arounds ------------------------------------------------
        ("Blight", [
            ("husk", "basic", 50, [("toll", 2)],
             [A("spore_burst", "Spore Burst", 30, "30 damage")],
             "It is not sick. It is the thing that makes sickness."),
            ("fen", "stage1", 100, [("toll", 4), ("decay", 10)],
             [A("miasma", "Miasma", 50, "50 damage")],
             "The air above it has not moved in a long time."),
            ("knell", "stage2", 140, [("toll", 5), ("decay", 10)],
             [A("the_wasting", "The Wasting", 95, "95 damage"),
              A("pestilence", "Pestilence", 0,
                "Deal 15 damage to every enemy unit",
                [{"op": "damage_enemy_board", "n": 15}], ability=True, consume=2)],
             "Everything downwind of it is already counting down."),
        ]),
        ("Tomb", [
            ("lit", "basic", 45, [], [A("dust", "Dust", 28, "28 damage")],
             "Grave-dust with just enough will to drift toward you."),
            ("shroud", "stage1", 95, [("toll", 3), ("rise", 0)],
             [A("entomb", "Entomb", 47, "47 damage")],
             "It has room for one more. It always has room for one more."),
            ("thane", "stage2", 155, [("toll", 6), ("rise", 0)],
             [A("sealed_in_stone", "Sealed in Stone", 100, "100 damage"),
              A("grave_call", "Grave Call", 0,
                "Return a Hel unit from your discard to an empty slot",
                [{"op": "reanimate", "n": 1}], ability=True, consume=2)],
             "A door that only opens inward."),
        ]),
        # ---- staples --------------------------------------------------------
        ("Murk", [
            ("lit", "basic", 40, [], [A("seep", "Seep", 26, "26 damage")],
             "Standing water that has developed opinions."),
            ("mire", "stage1", 90, [("toll", 3), ("decay", 5)],
             [A("drown", "Drown", 44, "44 damage")],
             "It does not pull you under. It simply rises."),
        ]),
        ("Char", [
            ("grub", "basic", 55, [("toll", 2)],
             [A("ember", "Ember", 33, "33 damage")],
             "Still warm. That is the unsettling part."),
            ("gaunt", "stage1", 105, [("toll", 4)],
             [A("cinderfall", "Cinderfall", 53, "53 damage")],
             "What is left when a pyre finishes its work and keeps going."),
        ]),
        ("Rot", [
            ("wisp", "basic", 45, [("toll", 1), ("decay", 5)],
             [A("fester", "Fester", 29, "29 damage")],
             "Small, patient, and extremely thorough."),
            ("fen", "stage1", 95, [("toll", 3), ("decay", 10)],
             [A("putrefy", "Putrefy", 48, "48 damage")],
             "It has been working on this field for a season."),
        ]),
        ("Grim", [
            ("kin", "basic", 60, [("toll", 2), ("retribution", 15)],
             [A("reproach", "Reproach", 35, "35 damage")],
             "It takes every blow personally and returns the favour."),
            ("shroud", "stage1", 110, [("toll", 4), ("retribution", 20)],
             [A("recompense", "Recompense", 55, "55 damage")],
             "The ledger balances. It always balances."),
        ]),
        ("Ash", [
            ("lit", "basic", 40, [], [A("scatter", "Scatter", 25, "25 damage")],
             "The last thing a fire leaves behind, still moving."),
            ("loam", "stage1", 85, [("toll", 3), ("rise", 0)],
             [A("settle", "Settle", 43, "43 damage")],
             "It sinks into the soil and comes back as something else."),
        ]),
        ("Wither", [
            ("ling", "basic", 50, [], [A("sap", "Sap", 30, "30 damage")],
             "Everything it leans against goes grey."),
            ("husk", "stage1", 100, [("toll", 4), ("decay", 5)],
             [A("desiccate", "Desiccate", 50, "50 damage")],
             "It drinks the moisture and leaves the shape."),
        ]),
        # ---- vanilla Basics, each the bottom of a line above --------------
        ("Sepul", [
            ("grub", "basic", 45, [], [A("scrape", "Scrape", 27, "27 damage")],
             "It digs because digging is what there is."),
            ("knell", "stage1", 90, [("toll", 3), ("retribution", 15)],
             [A("dirgefall", "Dirgefall", 45, "45 damage")],
             "One long note for everything it has put down."),
        ]),
        ("Cairn", [
            ("wisp", "basic", 40, [], [A("totter", "Totter", 25, "25 damage")],
             "A stack of two stones, technically."),
            ("husk", "stage1", 88, [("toll", 3), ("resist", 5)],
             [A("bulwark", "Bulwark", 44, "44 damage")],
             "Now a stack of nine, and disinclined to move."),
        ]),
        ("Mor", [
            ("lit", "basic", 42, [], [A("flit", "Flit", 26, "26 damage")],
             "One of the swarm, separated. It is not coping."),
            ("knell", "stage1", 92, [("toll", 3), ("decay", 5)],
             [A("massing", "Massing", 46, "46 damage")],
             "It found the others."),
        ]),
        ("Gnaw", [
            ("husk", "basic", 48, [], [A("worry", "Worry", 29, "29 damage")],
             "It has been chewing the same thing for weeks."),
            ("loam", "stage1", 96, [("toll", 4), ("decay", 5)],
             [A("hollowing", "Hollowing", 48, "48 damage")],
             "The root finally gave. It has moved on to the tree."),
        ]),
        ("Grist", [
            ("lit", "basic", 44, [], [A("grind", "Grind", 27, "27 damage")],
             "A single stone, turning, with nothing to turn against."),
            ("fen", "stage1", 94, [("toll", 3), ("decay", 5)],
             [A("mill", "Mill", 47, "47 damage")],
             "It found something to turn against."),
        ]),
        ("Oss", [
            ("wisp", "basic", 42, [], [A("rattle", "Rattle", 26, "26 damage")],
             "A handful of finger bones with somewhere to be."),
            ("loam", "stage1", 98, [("toll", 4), ("rise", 0)],
             [A("assemble", "Assemble", 49, "49 damage")],
             "It found the rest of itself."),
        ]),
    ]

    heaven = [
        # ---- build-arounds ------------------------------------------------
        ("Gloria", [
            ("mote", "basic", 45, [("judgment", 15)],
             [A("kindle", "Kindle", 30, "30 damage")],
             "A small light that has already decided about you."),
            ("lumen", "stage1", 100, [("judgment", 40)],
             [A("exalt", "Exalt", 50, "50 damage")],
             "It burns brighter the more there is to judge."),
            ("throne", "stage2", 150, [("judgment", 50), ("sanctuary", 60)],
             [A("in_glory", "In Glory", 92, "92 damage"),
              A("reaffirm", "Reaffirm", 0,
                "Restore Judgment to every unit you control",
                [{"op": "restore_board_judgment", "n": 1}], ability=True, consume=2)],
             "The verdict, and the light to read it by."),
        ]),
        ("Sanct", [
            ("im", "basic", 50, [("sanctuary", 60)],
             [A("ward", "Ward", 32, "32 damage")],
             "It stands where the blow was going to land."),
            ("cant", "stage1", 112, [("sanctuary", 80)],
             [A("consecrate", "Consecrate", 56, "56 damage")],
             "Ground it has stood on stays difficult to cross."),
            ("throne", "stage2", 160, [("sanctuary", 100), ("resist", 5)],
             [A("inviolate", "Inviolate", 98, "98 damage"),
              A("renewal", "Renewal", 0,
                "Restore this unit's Sanctuary at end of turn",
                [{"op": "eot_restore_sanctuary", "n": 1}], ability=True, consume=2)],
             "Nothing has reached it yet. It has been a long yet."),
        ]),
        # ---- staples --------------------------------------------------------
        ("Psalm", [
            ("iel", "basic", 45, [("judgment", 15)],
             [A("verse", "Verse", 29, "29 damage")],
             "It sings one line, over and over, and means it every time."),
            ("cant", "stage1", 95, [("judgment", 35)],
             [A("refrain", "Refrain", 47, "47 damage")],
             "By the ninth repetition it stops sounding like music."),
        ]),
        ("Orat", [
            ("im", "basic", 48, [("judgment", 20)],
             [A("indict", "Indict", 31, "31 damage")],
             "It has read the whole file and has follow-up questions."),
            ("ora", "stage1", 98, [("judgment", 40)],
             [A("prosecute", "Prosecute", 49, "49 damage")],
             "The case was closed before it opened its mouth."),
        ]),
        ("Lucen", [
            ("mote", "basic", 42, [("sanctuary", 60)],
             [A("glimmer", "Glimmer", 28, "28 damage")],
             "Faint, and completely impossible to put out."),
            ("lumen", "stage1", 105, [("sanctuary", 80)],
             [A("radiance", "Radiance", 52, "52 damage")],
             "Standing behind it is the safest place on the field."),
        ]),
        ("Matin", [
            ("kin", "basic", 52, [("judgment", 15), ("rise", 0)],
             [A("dawnstrike", "Dawnstrike", 33, "33 damage")],
             "First light, and it has been waiting up for you."),
            ("ora", "stage1", 102, [("judgment", 35), ("rise", 0)],
             [A("sunrise", "Sunrise", 51, "51 damage")],
             "It comes back every morning. That is rather the point."),
        ]),
        ("Empyr", [
            ("iel", "basic", 55, [("sanctuary", 60)],
             [A("aegis", "Aegis", 34, "34 damage")],
             "A shield with a creature attached, roughly in that order."),
            ("seraph", "stage1", 115, [("sanctuary", 80), ("resist", 5)],
             [A("firmament", "Firmament", 57, "57 damage")],
             "The sky, holding still, on purpose."),
        ]),
        # ---- vanilla Basics -------------------------------------------------
        ("Cant", [
            ("mote", "basic", 42, [], [A("hum", "Hum", 26, "26 damage")],
             "A note looking for a chord."),
            ("lumen", "stage1", 92, [("judgment", 35)],
             [A("harmony", "Harmony", 46, "46 damage")],
             "It found the chord. The chord was a sentence."),
        ]),
        ("Vesper", [
            ("kin", "basic", 44, [], [A("flicker", "Flicker", 27, "27 damage")],
             "Dusk-light, undecided."),
            ("cant", "stage1", 94, [("judgment", 35)],
             [A("nightsong", "Nightsong", 47, "47 damage")],
             "It made up its mind somewhere around midnight."),
        ]),
        ("Aur", [
            ("iel", "basic", 46, [], [A("sheen", "Sheen", 28, "28 damage")],
             "Gilt, and not yet gold."),
            ("ora", "stage1", 96, [("sanctuary", 60)],
             [A("burnish", "Burnish", 48, "48 damage")],
             "Gold, now, and aware of it."),
        ]),
        ("Bell", [
            ("kin", "basic", 43, [], [A("chime", "Chime", 27, "27 damage")],
             "It has not been struck yet."),
            ("throne", "stage1", 90, [("judgment", 40)],
             [A("peal", "Peal", 45, "45 damage")],
             "It has been struck. Everyone heard."),
        ]),
        ("Clar", [
            ("mote", "basic", 41, [], [A("shine", "Shine", 26, "26 damage")],
             "Clear light with nothing yet to clarify."),
            ("seraph", "stage1", 93, [("sanctuary", 60)],
             [A("clarity", "Clarity", 46, "46 damage")],
             "Now everything in front of it is very obvious."),
        ]),
        ("Sera", [
            ("mote", "basic", 47, [], [A("hover", "Hover", 29, "29 damage")],
             "Wings, and no rank to go with them."),
            ("lumen", "stage1", 99, [("judgment", 35)],
             [A("ascend", "Ascend", 49, "49 damage")],
             "It was promoted. The wings multiplied accordingly."),
        ]),
        ("Solem", [
            ("kin", "basic", 44, [], [A("stand_fast", "Stand Fast", 27, "27 damage")],
             "It has taken up a position. Nothing is attacking it yet."),
            ("throne", "stage1", 106, [("sanctuary", 80)],
             [A("hold_the_line", "Hold the Line", 53, "53 damage")],
             "Something is attacking it now. The position has not moved."),
        ]),
    ]

    void = [
        # ---- build-arounds ------------------------------------------------
        ("Lacun", [
            ("ith", "basic", 45, [("siphon", 1)],
             [A("elide", "Elide", 29, "29 damage")],
             "A gap in the record where something used to be recorded."),
            ("lack", "stage1", 95, [("siphon", 2)],
             [A("omit", "Omit", 47, "47 damage")],
             "It removes the word and then the space the word was in."),
            ("abyss", "stage2", 140, [("siphon", 2), ("rift", 1)],
             [A("the_missing_page", "The Missing Page", 78, "78 damage"),
              A("expunge", "Expunge", 0,
                "Destroy 2 energy attached to an enemy unit",
                [{"op": "void_energy", "n": 2}], ability=True, consume=1)],
             "You are certain there was more to this."),
        ]),
        ("Gyre", [
            ("sk", "basic", 48, [("rift", 1)],
             [A("spiral", "Spiral", 30, "30 damage")],
             "It turns, and things near it start turning too."),
            ("rift", "stage1", 98, [("rift", 1)],
             [A("maelstrom", "Maelstrom", 49, "49 damage")],
             "The turning has become the only thing there is."),
            ("shear", "stage2", 130, [("rift", 2)],
             [A("event_horizon", "Event Horizon", 64, "64 damage"),
              A("draw_down", "Draw Down", 0,
                "Destroy 20% of the enemy's energy pool",
                [{"op": "void_pool_pct", "n": 20}], ability=True, consume=2)],
             "Past a certain point the turning is no longer optional."),
        ]),
        # ---- staples --------------------------------------------------------
        ("Ebon", [
            ("ith", "basic", 44, [("siphon", 1)],
             [A("blacken", "Blacken", 28, "28 damage")],
             "Not dark. Dark is an absence of light; this is a presence."),
            ("lack", "stage1", 94, [("siphon", 2)],
             [A("smother", "Smother", 47, "47 damage")],
             "It gets into the corners first."),
        ]),
        ("Dross", [
            ("sk", "basic", 52, [], [A("slag", "Slag", 32, "32 damage")],
             "What is left when something is refined and the good part removed."),
            ("ebb", "stage1", 100, [("siphon", 2)],
             [A("residue", "Residue", 50, "50 damage")],
             "It is made entirely of what other things discarded."),
        ]),
        ("Rive", [
            ("wane", "basic", 46, [("rift", 1)],
             [A("split", "Split", 29, "29 damage")],
             "It finds the seam. There is always a seam."),
            ("shear", "stage1", 96, [("rift", 1)],
             [A("cleave", "Cleave", 48, "48 damage")],
             "Two things that used to be one thing."),
        ]),
        ("Pall", [
            ("ith", "basic", 50, [("siphon", 1)],
             [A("shroud_out", "Shroud Out", 31, "31 damage")],
             "It settles over a thing and the thing stops mattering."),
            ("gaunt", "stage1", 102, [("siphon", 2)],
             [A("obscure", "Obscure", 51, "51 damage")],
             "You know it is still there. You cannot say why you think so."),
        ]),
        ("Stark", [
            ("sk", "basic", 55, [("rift", 1)],
             [A("bare", "Bare", 33, "33 damage")],
             "It takes away everything inessential, which is most things."),
            ("rift", "stage1", 108, [("rift", 1)],
             [A("strip_bare", "Strip Bare", 54, "54 damage")],
             "What is left is true and almost nothing."),
        ]),
        # ---- vanilla Basics -------------------------------------------------
        ("Cess", [
            ("sk", "basic", 42, [], [A("stagnate", "Stagnate", 26, "26 damage")],
             "Still water in a place with no outlet."),
            ("ebb", "stage1", 92, [("siphon", 2)],
             [A("sink", "Sink", 46, "46 damage")],
             "It found the outlet. The outlet goes down."),
        ]),
        ("Null", [
            ("sk", "basic", 40, [], [A("negate", "Negate", 25, "25 damage")],
             "It has not decided what to subtract from yet."),
            ("lack", "stage1", 90, [("siphon", 2)],
             [A("nullify", "Nullify", 45, "45 damage")],
             "It decided."),
        ]),
        ("Umbr", [
            ("wane", "basic", 43, [], [A("shade", "Shade", 27, "27 damage")],
             "A shadow with no object casting it, which nobody has noticed."),
            ("abyss", "stage1", 93, [("rift", 1)],
             [A("deepen", "Deepen", 46, "46 damage")],
             "People have started noticing."),
        ]),
        ("Wane", [
            ("sk2", "basic", 45, [], [A("lessen", "Lessen", 28, "28 damage")],
             "Every day slightly less of it, and it does not seem to mind."),
            ("shear", "stage1", 95, [("rift", 1)],
             [A("diminish", "Diminish", 47, "47 damage")],
             "It has worked out how to do that to other things."),
        ]),
        ("Fane", [
            ("wane", "basic", 47, [], [A("hollow_prayer", "Hollow Prayer", 29, "29 damage")],
             "The rite performed correctly, to nobody."),
            ("rift", "stage1", 97, [("siphon", 2)],
             [A("apostasy", "Apostasy", 48, "48 damage")],
             "It stopped pretending there was anyone listening."),
        ]),
        ("Vast", [
            ("wane", "basic", 49, [], [A("stretch", "Stretch", 30, "30 damage")],
             "The distance is normal. It only feels long."),
            ("abyss", "stage1", 99, [("rift", 1)],
             [A("expanse", "Expanse", 49, "49 damage")],
             "The distance is no longer normal."),
        ]),
        ("Sev", [
            ("sk", "basic", 44, [], [A("nick", "Nick", 27, "27 damage")],
             "A small cut in something that was supposed to be continuous."),
            ("lack", "stage1", 94, [("siphon", 2)],
             [A("excise", "Excise", 47, "47 damage")],
             "The cut goes all the way through now."),
        ]),
    ]

    gaia = [
        # ---- build-arounds ------------------------------------------------
        ("Amber", [
            ("shoot", "basic", 52, [("earth", 1)],
             [A("resin", "Resin", 31, "31 damage")],
             "Sap that has decided to become a mineral about it."),
            ("bole", "stage1", 108, [("earth", 2), ("essence", 1)],
             [A("encase", "Encase", 54, "54 damage")],
             "Everything it has ever caught is still in there, perfectly."),
            ("wold", "stage2", 158, [("earth", 3), ("essence", 2)],
             [A("deep_amber", "Deep Amber", 98, "98 damage"),
              A("preserve", "Preserve", 0,
                "Move this unit's Earth to another unit you control",
                [{"op": "move_earth", "n": 1}], ability=True, consume=1)],
             "Time gets in, but it does not get back out."),
        ]),
        ("Cald", [
            ("ling", "basic", 60, [("earth", 1), ("resist", 5)],
             [A("scoria", "Scoria", 35, "35 damage")],
             "Cooled on the outside. Only on the outside."),
            ("crag", "stage1", 118, [("earth", 2), ("resist", 5)],
             [A("basalt", "Basalt", 58, "58 damage")],
             "It remembers being liquid and is in no hurry to repeat it."),
            ("thane", "stage2", 168, [("earth", 3), ("resist", 10)],
             [A("caldera", "Caldera", 102, "102 damage"),
              A("upwelling", "Upwelling", 0, "This unit gains 1 Earth",
                [{"op": "grow_earth", "n": 1}], ability=True)],
             "The mountain that used to be here is inside it now."),
        ]),
        # ---- staples --------------------------------------------------------
        ("Fern", [
            ("shoot", "basic", 48, [("earth", 1)],
             [A("frond", "Frond", 30, "30 damage")],
             "Older than trees, and quietly smug about it."),
            ("bough", "stage1", 98, [("earth", 2)],
             [A("unfurl", "Unfurl", 49, "49 damage")],
             "It has been doing this since before there was anything to watch."),
        ]),
        ("Sedge", [
            ("sprout", "basic", 50, [("earth", 1), ("essence", 1)],
             [A("cut_grass", "Cut Grass", 31, "31 damage")],
             "Every blade is an edge. There are a great many blades."),
            ("fen", "stage1", 100, [("earth", 2), ("essence", 2)],
             [A("marshhold", "Marshhold", 50, "50 damage")],
             "The water is on its side."),
        ]),
        ("Loam", [
            ("bud", "basic", 58, [("earth", 2)],
             [A("furrow", "Furrow", 34, "34 damage")],
             "Good soil, walking. It has opinions about where to settle."),
            ("wold", "stage1", 112, [("earth", 2), ("essence", 1)],
             [A("deep_till", "Deep Till", 55, "55 damage")],
             "Everything that grows here grows because it allowed it."),
        ]),
        ("Burr", [
            ("bud", "basic", 46, [("earth", 1), ("retribution", 15)],
             [A("catch", "Catch", 29, "29 damage")],
             "It attaches. That is its entire strategy and it works."),
            ("crag", "stage1", 96, [("earth", 2), ("retribution", 20)],
             [A("snare", "Snare", 48, "48 damage")],
             "By the time you notice, you have carried it a long way."),
        ]),
        ("Tuss", [
            ("ling", "basic", 62, [("earth", 1), ("resist", 5)],
             [A("clump", "Clump", 36, "36 damage")],
             "A hummock of grass that stood up."),
            ("bole", "stage1", 114, [("earth", 2), ("resist", 5)],
             [A("root_fast", "Root Fast", 56, "56 damage")],
             "It has been in this exact spot for ninety years."),
        ]),
        # ---- vanilla Basics -------------------------------------------------
        ("Silt", [
            ("sprout", "basic", 44, [], [A("settle_in", "Settle In", 27, "27 damage")],
             "Fine sediment, going where the water goes."),
            ("fen", "stage1", 94, [("earth", 2), ("essence", 1)],
             [A("silt_up", "Silt Up", 47, "47 damage")],
             "The water goes where it goes, now."),
        ]),
        ("Bryo", [
            ("shoot", "basic", 43, [], [A("spread", "Spread", 27, "27 damage")],
             "A patch of moss on the shady side."),
            ("wold", "stage1", 93, [("earth", 2)],
             [A("carpet", "Carpet", 46, "46 damage")],
             "The shady side is now the entire side."),
        ]),
        ("Root", [
            ("bud", "basic", 45, [], [A("probe", "Probe", 28, "28 damage")],
             "One root, searching, with no particular plan."),
            ("bole", "stage1", 95, [("earth", 2), ("essence", 1)],
             [A("taproot", "Taproot", 47, "47 damage")],
             "It found water. It found a great deal of water."),
        ]),
        ("Verd", [
            ("shoot", "basic", 47, [], [A("bud_out", "Bud Out", 29, "29 damage")],
             "New green, with everything still ahead of it."),
            ("bole", "stage1", 97, [("earth", 2)],
             [A("greenwood", "Greenwood", 48, "48 damage")],
             "Everything ahead of it happened."),
        ]),
        ("Petri", [
            ("bud", "basic", 49, [], [A("grit", "Grit", 30, "30 damage")],
             "Soft, but there is something hard under the softness."),
            ("wold", "stage1", 99, [("earth", 2), ("resist", 5)],
             [A("stonewake", "Stonewake", 49, "49 damage")],
             "The softness has finished being relevant."),
        ]),
        ("Lich", [
            ("shoot", "basic", 51, [], [A("encrust", "Encrust", 31, "31 damage")],
             "Two organisms, still negotiating."),
            ("fen", "stage1", 101, [("earth", 2), ("essence", 1)],
             [A("symbiosis", "Symbiosis", 50, "50 damage")],
             "Negotiations concluded. Both parties are pleased."),
        ]),
        ("Thorn", [
            ("shoot", "basic", 46, [], [A("scratch", "Scratch", 28, "28 damage")],
             "One thorn. It is doing its best."),
            ("wold", "stage1", 98, [("earth", 2), ("retribution", 20)],
             [A("thicketfall", "Thicketfall", 49, "49 damage")],
             "A great many thorns, all doing their best."),
        ]),
    ]

    return {"hel": hel, "heaven": heaven, "void": void, "gaia": gaia}
