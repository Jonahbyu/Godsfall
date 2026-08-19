"""Expand Tempest from its 20-card launch set to full parity with the other five
colours (~58 units, ~20 chains, 63 cards total).

The launch set proved the engine: all 11 ops exist and each of its 6 chains owns
one, so this expansion has the problem Forge's did NOT — it is not forced to
reprint one effect. What it adds is **volume**, at the same composition the built
factions measure:

    hel      60 units, 81% carry a signature
    void     60 units, 73%
    gaia     57 units, 87%
    forge    48 units, 100%
    tempest  16 units, 81%   <- ratio already right, count is not

So the target is ~58 units at ~80% signature density, which means roughly a fifth
of the new bodies print no `Charge` at all. That is deliberate and enforced: a
faction where every card carries the keyword is the sameness failure the bestiary
waves documented, and Foehn (the Storm chain) already establishes the pattern.

Three power tiers, following the bestiary's finding that uniform power produces
interchangeable cards once a roster outgrows what a deck can hold:

    vanilla     a clean cheap body, no keyword — must evolve into one that has it
    staple      one signature, standard numbers, the deck filler
    build-around a chain whose Stage 2 ability IS an archetype

Reuses tools/add_tempest_faction.py wholesale for the rules enforcement — the
bands, the discounted rate, the colorless split, the op scrape, and every guard
it added while the launch set was authored (a Charge body must have something
that grows it and something that spends it; `discharge_structures` may not sit on
an ability; no new round-1 openers).

Run:  python tools/add_tempest_expansion.py --dry-run    # then --apply
"""

import argparse
import json
import pathlib
import sys

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))

import add_tempest_faction as base

ROOT = pathlib.Path(__file__).resolve().parent.parent
CARDS = ROOT / "data" / "cards.json"

A = base.A
AB = base.AB
KW = base.KW


# ---------------------------------------------------------------------------
# The expansion roster.
#
# Naming continues the launch set's system: a shared stem per chain, suffixes
# escalating with age, drawn from Tempest's per-faction pools. Suffixes are
# REUSED across chains (Gaia reuses -ling six times); the stem is what places a
# creature, not the suffix.
#
#   Basic:   -sile  -whorl  -skirl  -wisp   -mote
#   Stage 1: -gale  -squall -shear  -rush
#   Stage 2: -tempest -maelstrom -thunderhead -deluge
#
# Tempest's sound stays sibilant and open — moving air, long vowels — and never
# borrows Forge's clipped consonants or Void's hollow trailing endings.

CHAINS = [

    # ---------------------------------------------------------------- vanilla
    #
    # Clean cheap bodies. A vanilla is a legitimate card — the bottom of a line —
    # but a vanilla that goes NOWHERE is a dead draw, so each evolves into a
    # form that carries the signature. The generator enforces this.

    ("Zephyr", [
        ("wisp", "basic", 44, [], [
            A("zeph_brush", "Brush", 22, "22 damage."),
        ], "The first air to move all morning. It moves nothing else."),
        ("rush", "stage1", 88, KW(charge=6), [
            A("zeph_scour", "Scour", 34, "34 damage.",
              [{"op": "charge_on_damage", "n": 6}]),
            AB("zeph_loose", "Loose",
               "Discharge: this unit's next attack deals the counter as bonus "
               "damage and strikes a second unit on that board for the counter.",
               [{"op": "discharge"}]),
        ], "It has picked up enough on the way to be worth standing out of."),
    ]),

    ("Haar", [
        ("mote", "basic", 48, [], [
            A("haar_creep", "Creep", 21, "21 damage."),
        ], "Sea fog. It arrives without having been seen to travel."),
        ("shear", "stage1", 94, KW(charge=6, resist=5), [
            A("haar_blind", "Blind", 33, "33 damage.",
              [{"op": "charge_on_damage", "n": 6}]),
            AB("haar_settle", "Settle",
               "Discharge: heal a unit you control for the counter.",
               [{"op": "discharge_heal"}]),
        ], "Thick enough now that the lane in front of it is a rumour."),
    ]),

    ("Squame", [
        ("wisp", "basic", 52, [], [
            A("squa_flick", "Flick", 23, "23 damage."),
        ], "Scales of cloud, thin enough to read the sun through."),
        ("squall", "stage1", 100, KW(charge=7), [
            A("squa_lash", "Lash", 37, "37 damage.",
              [{"op": "charge_on_damage", "n": 7}]),
            AB("squa_shed", "Shed",
               "Discharge: split the counter as evenly as possible among every "
               "living unit on one enemy board.",
               [{"op": "discharge_sweep"}]),
        ], "Layer on layer, and every one of them moving."),
    ]),

    ("Virga", [
        ("mote", "basic", 46, [], [
            A("virg_trail", "Trail", 22, "22 damage."),
        ], "Rain that never lands. It is falling all the same."),
        ("gale", "stage1", 90, KW(charge=6), [
            A("virg_reach", "Reach", 35, "35 damage.",
              [{"op": "charge_on_damage", "n": 6}]),
            AB("virg_arrive", "Arrive",
               "Discharge: this unit's next attack deals twice the counter to a "
               "single target.",
               [{"op": "discharge_single", "n": 2}]),
        ], "It found the ground eventually. It always does."),
    ]),

    ("Aeol", [
        ("skirl", "basic", 50, [], [
            A("aeol_thrum", "Thrum", 24, "24 damage."),
        ], "A note off a ridge, held far longer than a breath could hold it."),
        ("rush", "stage1", 96, KW(charge=6), [
            A("aeol_keen", "Keen", 36, "36 damage.",
              [{"op": "charge_on_damage", "n": 6}]),
            AB("aeol_swell", "Swell",
               "Discharge: this unit's next attack deals the counter as bonus "
               "damage and strikes a second unit on that board for the counter.",
               [{"op": "discharge"}]),
        ], "The note has become a pressure you can feel in the teeth."),
    ]),

    # ----------------------------------------------------------------- staples
    #
    # One signature, standard numbers, three stages. The deck filler, and where
    # most of a Tempest list's bodies actually come from.

    ("Levin", [
        ("skirl", "basic", 52, KW(charge=4), [
            A("levi_spark", "Spark", 19, "19 damage.",
              [{"op": "charge_on_damage", "n": 4}]),
            AB("levi_snap", "Snap",
               "Discharge: this unit's next attack deals the counter as bonus "
               "damage and strikes a second unit on that board for the counter.",
               [{"op": "discharge"}]),
        ], "Old word for lightning. It has not needed a newer one."),
        ("squall", "stage1", 98, KW(charge=7), [
            A("levi_strike", "Strike", 38, "38 damage.",
              [{"op": "charge_on_damage", "n": 7}]),
            AB("levi_fork", "Fork",
               "Discharge: this unit's next attack deals the counter as bonus "
               "damage and strikes a second unit on that board for the counter.",
               [{"op": "discharge"}]),
        ], "Forked, and both ends land."),
        ("tempest", "stage2", 148, KW(charge=10), [
            A("levi_shatter", "Shatter", 70, "70 damage.",
              [{"op": "charge_on_damage", "n": 10}]),
            AB("levi_split", "Split the Sky",
               "Discharge: this unit's next attack deals the counter as bonus "
               "damage and strikes a second unit on that board for the counter.",
               [{"op": "discharge"}]),
        ], "The sky came apart along a seam nobody knew was there."),
    ]),

    ("Roke", [
        ("whorl", "basic", 58, KW(charge=3), [
            A("roke_muffle", "Muffle", 17, "17 damage.",
              [{"op": "charge_on_damage", "n": 3}]),
            AB("roke_bank", "Bank",
               "Discharge: this unit's next attack deals twice the counter to a "
               "single target.",
               [{"op": "discharge_single", "n": 2}]),
        ], "It says nothing and it is not empty."),
        ("shear", "stage1", 106, KW(charge=6), [
            A("roke_press", "Press", 34, "34 damage.",
              [{"op": "charge_on_damage", "n": 6}]),
            AB("roke_hold", "Hold",
               "Discharge: this unit's next attack deals twice the counter to a "
               "single target.",
               [{"op": "discharge_single", "n": 2}]),
        ], "Still saying nothing. It has grown considerably."),
        ("maelstrom", "stage2", 158, KW(charge=10), [
            A("roke_burst", "Burst", 66, "66 damage.",
              [{"op": "charge_on_damage", "n": 10}]),
            AB("roke_break", "Break",
               "Discharge: this unit's next attack deals twice the counter to a "
               "single target.",
               [{"op": "discharge_single", "n": 2}]),
        ], "Everything it declined to say, at once."),
    ]),

    ("Skirl", [
        ("wisp", "basic", 46, KW(charge=4), [
            A("skir_cut", "Cut", 20, "20 damage.",
              [{"op": "charge_on_damage", "n": 4},
               {"op": "charge_on_kill", "n": 8}]),
            AB("skir_scatter", "Scatter",
               "Discharge: split the counter as evenly as possible among every "
               "living unit on one enemy board.",
               [{"op": "discharge_sweep"}]),
        ], "A thin sound and a thinner edge."),
        ("squall", "stage1", 92, KW(charge=7), [
            A("skir_flense", "Flense", 36, "36 damage.",
              [{"op": "charge_on_damage", "n": 7},
               {"op": "charge_on_kill", "n": 14}]),
            AB("skir_strew", "Strew",
               "Discharge: split the counter as evenly as possible among every "
               "living unit on one enemy board.",
               [{"op": "discharge_sweep"}]),
        ], "It takes the smallest thing first and grows on the taking."),
    ]),

    ("Gale", [
        ("whorl", "basic", 54, KW(charge=4), [
            A("gale_shove", "Shove", 20, "20 damage.",
              [{"op": "charge_on_damage", "n": 4}]),
            AB("gale_pass", "Pass the Charge",
               "Move this unit's counter to another unit you control.",
               [{"op": "charge_transfer"}]),
        ], "It does not stop so much as become somewhere else's problem."),
        ("rush", "stage1", 102, KW(charge=7), [
            A("gale_drive", "Drive", 38, "38 damage.",
              [{"op": "charge_on_damage", "n": 7}]),
            AB("gale_relay", "Relay",
               "Move this unit's counter to another unit you control, then draw "
               "a card.",
               [{"op": "charge_transfer"}, {"op": "draw", "n": 1}]),
        ], "Nothing is lost. It is merely elsewhere, and faster."),
    ]),

    ("Murk", [
        ("mote", "basic", 56, KW(charge=3, resist=5), [
            A("murk_dim", "Dim", 18, "18 damage.",
              [{"op": "charge_on_damage", "n": 3}]),
            AB("murk_shelter", "Shelter",
               "Discharge: heal a unit you control for the counter.",
               [{"op": "discharge_heal"}]),
        ], "Weather thick enough to stand behind."),
        ("shear", "stage1", 110, KW(charge=6, resist=5), [
            A("murk_smother", "Smother", 32, "32 damage.",
              [{"op": "charge_on_damage", "n": 6}]),
            AB("murk_becalm", "Becalm",
               "Discharge: heal a unit you control for the counter.",
               [{"op": "discharge_heal"}]),
        ], "It has not cleared in three days and shows no intention."),
    ]),

    ("Sleet", [
        ("skirl", "basic", 50, KW(charge=4), [
            A("slee_pelt", "Pelt", 21, "21 damage.",
              [{"op": "charge_on_damage", "n": 4}]),
            AB("slee_gather", "Gather",
               "Discharge: split the counter as evenly as possible among every "
               "living unit on one enemy board.",
               [{"op": "discharge_sweep"}]),
        ], "Neither one thing nor the other, and worse than both."),
        ("squall", "stage1", 96, KW(charge=7), [
            A("slee_rake", "Rake", 37, "37 damage.",
              [{"op": "charge_on_damage", "n": 7}]),
            AB("slee_hail", "Hail",
               "Discharge: split the counter as evenly as possible among every "
               "living unit on one enemy board.",
               [{"op": "discharge_sweep"}]),
        ], "It has committed. It is hail now."),
        ("deluge", "stage2", 152, KW(charge=10), [
            A("slee_batter", "Batter", 64, "64 damage.",
              [{"op": "charge_on_damage", "n": 10},
               {"op": "charge_on_kill", "n": 20}]),
            AB("slee_flatten", "Flatten",
               "Discharge: split the counter as evenly as possible among every "
               "living unit on one enemy board.",
               [{"op": "discharge_sweep"}]),
        ], "A field is what is left when everything standing in it is not."),
    ]),

    # ------------------------------------------------------- the Storm chains
    #
    # No Charge at all, matching Foehn. These are what make the faction's own
    # numbers work, since every Charge value is printed assuming Storm exists —
    # and they keep the signature ratio near the 80% the other colours measure.

    ("Baro", [
        ("mote", "basic", 48, [], [
            AB("baro_drop", "Pressure Drop",
               "Raise Storm by 1.",
               [{"op": "storm_raise", "n": 1}]),
            A("baro_lean", "Lean", 22, "22 damage."),
        ], "The needle fell overnight and nobody slept well."),
        ("shear", "stage1", 92, [], [
            AB("baro_trough", "Trough",
               "Raise Storm by 2.",
               [{"op": "storm_raise", "n": 2}]),
            A("baro_press", "Press", 40,
              "40 damage, and 2 more per point of Storm.",
              [{"op": "storm_scale_damage", "n": 2}]),
        ], "Low, and going lower, and the birds have gone quiet."),
        ("thunderhead", "stage2", 144, [], [
            AB("baro_collapse", "Collapse",
               "Raise Storm by 3.",
               [{"op": "storm_raise", "n": 3}]),
            A("baro_bottom", "Bottom Out", 58,
              "58 damage, and 4 more per point of Storm.",
              [{"op": "storm_scale_damage", "n": 4}]),
        ], "There is no lower for it to go. That is the problem."),
    ]),

    ("Squall", [
        ("wisp", "basic", 44, [], [
            AB("sqal_rise", "Rising Air",
               "Raise Storm by 1.",
               [{"op": "storm_raise", "n": 1}]),
            A("sqal_slap", "Slap", 23, "23 damage."),
        ], "Twenty minutes of violence and then blue sky, every time."),
        ("gale", "stage1", 86, [], [
            AB("sqal_line", "Squall Line",
               "Raise Storm by 2.",
               [{"op": "storm_raise", "n": 2}]),
            A("sqal_sweep", "Sweep", 42,
              "42 damage, and 2 more per point of Storm.",
              [{"op": "storm_scale_damage", "n": 2}]),
        ], "Not one storm but a rank of them, arriving in order."),
    ]),

    ("Anvil", [
        ("whorl", "basic", 56, [], [
            AB("anvi_build", "Build",
               "Raise Storm by 1.",
               [{"op": "storm_raise", "n": 1}]),
            A("anvi_weight", "Weight", 24, "24 damage."),
        ], "It is not tall yet. It is getting there in a hurry."),
        ("thunderhead", "stage2", 150, [], [
            AB("anvi_spread", "Spread the Anvil",
               "Raise Storm by 4.",
               [{"op": "storm_raise", "n": 4}]),
            A("anvi_fall", "Fall", 54,
              "54 damage, and 3 more per point of Storm.",
              [{"op": "storm_scale_damage", "n": 3}]),
        ], "Flat-topped, sixty thousand feet, and directly overhead."),
    ]),

    # --------------------------------------------------- build-arounds
    #
    # A chain whose Stage 2 ability IS an archetype. These are the cards a deck
    # is constructed around rather than filled with, and there are deliberately
    # few — the bestiary's finding is that uniform power makes cards
    # interchangeable, so the roster needs a top as well as a middle.

    ("Thrum", [
        ("wisp", "basic", 48, KW(charge=4), [
            A("thru_hum", "Hum", 20, "20 damage.",
              [{"op": "charge_on_damage", "n": 4}]),
            AB("thru_pass", "Pass the Charge",
               "Move this unit's counter to another unit you control.",
               [{"op": "charge_transfer"}]),
        ], "A sound with weather behind it."),
        ("rush", "stage1", 98, KW(charge=7), [
            A("thru_resonate", "Resonate", 36, "36 damage.",
              [{"op": "charge_on_damage", "n": 7}]),
            AB("thru_carry", "Carry",
               "Move this unit's counter to another unit you control, then draw "
               "a card.",
               [{"op": "charge_transfer"}, {"op": "draw", "n": 1}]),
        ], "Everything loose in the lane is moving in sympathy."),
        ("maelstrom", "stage2", 156, KW(charge=11), [
            A("thru_resound", "Resound", 62,
              "62 damage, and 3 more per point of Storm.",
              [{"op": "charge_on_damage", "n": 11},
               {"op": "storm_scale_damage", "n": 3}]),
            AB("thru_amplify", "Amplify",
               "Raise Storm by 2, then move this unit's counter to another unit "
               "you control.",
               [{"op": "storm_raise", "n": 2}, {"op": "charge_transfer"}]),
        ], "It is no longer answering the weather. The weather is answering it."),
    ]),

    ("Keraun", [
        ("skirl", "basic", 54, KW(charge=4), [
            A("kera_jolt", "Jolt", 21, "21 damage.",
              [{"op": "charge_on_damage", "n": 4},
               {"op": "charge_on_kill", "n": 8}]),
            AB("kera_earth", "Earth It",
               "Discharge: this unit's next attack deals twice the counter to a "
               "single target.",
               [{"op": "discharge_single", "n": 2}]),
        ], "It has found the shortest path to the ground and it is through you."),
        ("squall", "stage1", 104, KW(charge=7), [
            A("kera_arc", "Arc", 35, "35 damage.",
              [{"op": "charge_on_damage", "n": 7},
               {"op": "charge_on_kill", "n": 14}]),
            AB("kera_ground", "Ground",
               "Discharge: this unit's next attack deals twice the counter to a "
               "single target.",
               [{"op": "discharge_single", "n": 2}]),
        ], "Twice in the same place, which is supposed to be impossible."),
        ("tempest", "stage2", 165, KW(charge=12), [
            A("kera_smite", "Smite", 60,
              "60 damage. A discharge on this attack may strike a tower or "
              "throne past living units.",
              [{"op": "charge_on_damage", "n": 12},
               {"op": "charge_on_kill", "n": 24},
               {"op": "discharge_structures"}]),
            AB("kera_call", "Call It Down",
               "Discharge: this unit's next attack deals twice the counter to a "
               "single target.",
               [{"op": "discharge_single", "n": 2}]),
        ], "It picks the tallest thing standing. It is very rarely wrong."),
    ]),

    ("Nephel", [
        ("mote", "basic", 50, KW(charge=3), [
            A("neph_wisp", "Wisping", 18, "18 damage.",
              [{"op": "charge_on_damage", "n": 3}]),
            AB("neph_bank", "Bank",
               "Discharge: heal a unit you control for the counter.",
               [{"op": "discharge_heal"}]),
        ], "Cloud in the making, still deciding what kind."),
        ("gale", "stage1", 100, KW(charge=6), [
            A("neph_swell", "Swell", 34, "34 damage.",
              [{"op": "charge_on_damage", "n": 6}]),
            AB("neph_tend", "Tend",
               "Discharge: heal a unit you control for the counter.",
               [{"op": "discharge_heal"}]),
        ], "It decided. It is the kind with a flat black underside."),
        ("deluge", "stage2", 168, KW(charge=9, resist=5), [
            A("neph_open", "Open", 56, "56 damage.",
              [{"op": "charge_on_damage", "n": 9}]),
            AB("neph_shelter", "Shelter the Line",
               "Discharge: heal a unit you control for twice the counter.",
               [{"op": "discharge_heal", "n": 2}]),
        ], "The only thing in the faction that gives more than it takes."),
    ]),

    ("Bluster", [
        ("whorl", "basic", 52, KW(charge=4), [
            A("blus_buffet", "Buffet", 20, "20 damage.",
              [{"op": "charge_on_damage", "n": 4}]),
            AB("blus_spread", "Spread",
               "Discharge: split the counter as evenly as possible among every "
               "living unit on one enemy board.",
               [{"op": "discharge_sweep"}]),
        ], "Loud, and not entirely empty."),
        ("shear", "stage1", 96, KW(charge=6), [
            A("blus_rake", "Rake", 33, "33 damage.",
              [{"op": "charge_on_damage", "n": 6}]),
            AB("blus_scour", "Scour the Rank",
               "Discharge: split the counter as evenly as possible among every "
               "living unit on one enemy board.",
               [{"op": "discharge_sweep"}]),
        ], "It has stopped being loud and started being a problem."),
    ]),
]


# ---------------------------------------------------------------------------
# Supports. Tempest-locked, taking the suite from 3 to 6 — still fewer than
# Forge's 14, because Tempest's identity is on its bodies rather than in its
# support suite.

SUPPORTS = [
    {
        "id": "tempest_bank_the_gale",
        "name": "Bank the Gale",
        "type": "support",
        "faction": "tempest",
        "cost": 2,
        "text": "A unit you control gains 30 Charge.",
        "effects": [{"op": "charge_on_damage", "n": 30}],
        "flavor": "Everything the ridge collected, handed over at once.",
    },
    {
        "id": "tempest_standing_front",
        "name": "Standing Front",
        "type": "support",
        "faction": "tempest",
        "cost": 1,
        "text": "Raise Storm by 3.",
        "effects": [{"op": "storm_raise", "n": 3}],
        "flavor": "It has stopped moving east. It is going to sit here.",
    },
    {
        "id": "tempest_conductor",
        "name": "Conductor",
        "type": "tool",
        "faction": "tempest",
        "text": "This unit grows 4 extra Charge per point of Storm when it "
                "deals damage.",
        "effects": [{"op": "storm_charge_bonus", "n": 4}],
        "flavor": "Everything in the field wants to go through it, so it lets them.",
    },
]


def build():
    """Assemble the expansion, validating with the launch set's own rules."""
    ops = base.implemented_ops() | base.PLANNED_OPS
    out = []
    problems = []

    for stem, forms in CHAINS:
        prev_id = None
        for form in forms:
            suffix, stage, hp, kws, lines, flavor = form
            cid = f"tempest_{stem.lower()}{suffix}"
            name = f"{stem}{suffix}"

            lo, hi = base.HP_BAND[stage]
            if not lo <= hp <= hi:
                problems.append(f"{name}: HP {hp} outside {stage} band {lo}-{hi}")
            if len(lines) > 2:
                problems.append(f"{name}: {len(lines)} lines breaks the two-line rule")

            kwmap = {k["kw"]: k["n"] for k in kws}
            charge_n = kwmap.get("charge", 0)
            if charge_n:
                clo, chi = base.CHARGE_BAND[stage]
                if not clo <= charge_n <= chi:
                    problems.append(
                        f"{name}: Charge {charge_n} outside {stage} band {clo}-{chi}")

            attacks = []
            has_kw = bool(kws)
            has_spender = False
            grows_charge = False

            for ln in lines:
                entry = {"id": ln["id"], "name": ln["name"],
                         "damage": ln["damage"], "text": ln["text"]}
                if ln["effects"]:
                    entry["effects"] = ln["effects"]

                for e in ln["effects"]:
                    op = e.get("op", "")
                    if op not in ops:
                        problems.append(f"{name}/{ln['name']}: op '{op}' is not implemented")
                    if op == "discharge_structures" and ln["_kind"] == "ability":
                        problems.append(
                            f"{name}/{ln['name']}: 'discharge_structures' on an "
                            f"ability — it must ride the attack that resolves")
                    if op in base.SPENDER_OPS:
                        has_spender = True
                        if ln["_kind"] != "ability":
                            problems.append(
                                f"{name}/{ln['name']}: '{op}' on an attack — "
                                f"a Charge spender is a free once-per-turn ability")
                    if op == "charge_on_damage":
                        grows_charge = True
                        if e.get("n") != charge_n:
                            problems.append(
                                f"{name}/{ln['name']}: grows {e.get('n')} Charge "
                                f"but the card prints Charge {charge_n}")
                    ## A Charge payoff on a body that prints no Charge can never
                    ## fire — the same silent-dead-data shape the launch set's
                    ## guards catch, one level up.
                    if charge_n == 0 and op in base.SPENDER_OPS:
                        problems.append(
                            f"{name}/{ln['name']}: '{op}' on a body with no Charge")

                if ln["_kind"] == "ability":
                    entry["ability"] = True
                    if ln["_consume"]:
                        entry["consume"] = ln["_consume"]
                else:
                    discounted = charge_n > 0
                    total = ln["_cost"] or base.cost_for(stage, ln["damage"], discounted)
                    if stage == "basic" and total < base.MAX_NEW_OPENER_COST:
                        problems.append(
                            f"{name}/{ln['name']}: cost {total} is a new round-1 opener")
                    entry["cost"] = base.split_colorless(total)
                attacks.append(entry)

            if charge_n and not has_spender:
                problems.append(
                    f"{name}: prints Charge {charge_n} but nothing spends it")
            if charge_n and not grows_charge:
                problems.append(
                    f"{name}: prints Charge {charge_n} but no line grows it")
            ## A keyword-less Basic must evolve into one that carries something,
            ## or it is a dead draw rather than a clean cheap body.
            if not has_kw and stage == "basic" and len(forms) == 1:
                problems.append(f"{name}: vanilla Basic with nowhere to evolve")

            card = {
                "id": cid, "name": name, "type": "unit", "faction": "tempest",
                "stage": stage, "hp": hp, "retreat": int(hp / 40),
            }
            if prev_id:
                card["evolves_from"] = prev_id
            if kws:
                card["keywords"] = kws
            card["flavor"] = flavor
            card["attacks"] = attacks
            out.append(card)
            prev_id = cid

    for s in SUPPORTS:
        for e in s.get("effects", []):
            if e.get("op") not in ops:
                problems.append(f"{s['name']}: op '{e['op']}' is not implemented")
        if s.get("cost", 0) > 3:
            problems.append(f"{s['name']}: support cost {s['cost']} exceeds the cap of 3")
        out.append(s)

    if problems:
        print("REFUSING TO WRITE -- design rules broken:\n")
        for p in problems:
            print("  *", p)
        sys.exit(1)
    return out


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--apply", action="store_true")
    ap.add_argument("--dry-run", action="store_true")
    args = ap.parse_args()

    cards = build()
    db = json.loads(CARDS.read_text(encoding="utf-8"))
    key = "cards" if isinstance(db, dict) else None
    existing = db[key] if key else db

    units = [c for c in cards if c["type"] == "unit"]
    have_u = len([c for c in existing
                  if c.get("faction") == "tempest" and c["type"] == "unit"])
    have_t = len([c for c in existing if c.get("faction") == "tempest"])

    print(f"Expansion: {len(cards)} cards -- {len(units)} units in "
          f"{len(CHAINS)} chains, {len(SUPPORTS)} supports.")
    print(f"Tempest after apply: {have_u + len(units)} units, "
          f"{have_t + len(cards)} cards total.\n")

    sig = 0
    for c in cards:
        if c["type"] != "unit":
            print(f"  [{c['type']:14}] {c['name']}")
            continue
        kws = {k["kw"] for k in c.get("keywords", [])}
        if "charge" in kws:
            sig += 1
        kw = " ".join(f"{k['kw']} {k['n']}" for k in c.get("keywords", [])) or "-"
        costs = " / ".join(
            "ability" if a.get("ability")
            else "+".join(f"{v}{k[0]}" for k, v in a["cost"].items() if v)
            for a in c["attacks"])
        print(f"  {c['name']:24} {c['stage']:7} {c['hp']:3} HP  [{kw}]  {costs}")

    total_sig = sig + 13   # 13 of the launch set's 16 carry Charge
    total_u = have_u + len(units)
    print(f"\nSignature density after apply: {total_sig}/{total_u} "
          f"({100 * total_sig // total_u}%) — the built colours run 73-100%.")

    if args.apply:
        ids = {c["id"] for c in existing}
        dupes = [c["id"] for c in cards if c["id"] in ids]
        if dupes:
            print(f"\nREFUSING TO APPLY -- these ids already exist: {dupes}")
            sys.exit(1)
        existing.extend(cards)
        CARDS.write_text(json.dumps(db, indent=1, ensure_ascii=False) + "\n",
                         encoding="utf-8")
        print(f"\nWrote {len(cards)} cards to {CARDS}")
    else:
        print("\nDry run -- nothing written.")


if __name__ == "__main__":
    main()
