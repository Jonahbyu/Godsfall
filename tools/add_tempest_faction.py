"""Add the Tempest faction to data/cards.json.

Tempest is the sixth colour: storm, pressure, the break. Its signatures are
`Charge N` (a visible per-unit counter that grows when the unit DEALS damage,
persists across turns AND through evolution, and is spent whole by a Discharge
ability) and `Storm N` (a global board counter both players read, adding one
extra instance of N damage to every attack -- 2N for a Tempest unit).

See docs/specs/2026-08-17-tempest-faction-design.md for the design.

Like tools/add_forge_faction.py this **enforces the design rules rather than
trusting the author**:

  * HP bands, the two-line rule, retreat = HP/40.
  * Charge only on a unit, within the per-stage band, and every Charge body
    must carry a Discharge line -- a counter with no spender is dead data.
  * Discharge only ever on an ability (it is free and once-per-turn).
  * Attack costs derived from damage at Tempest's DISCOUNTED rate, because
    Charge is worth ~2N damage per attack forever.
  * Only ops the engine implements, PLUS the planned Tempest ops -- and
    --apply is refused while any planned op is still missing, so unplayable
    cards can never reach cards.json.

Run:  python tools/add_tempest_faction.py --dry-run    # then --apply
"""

import argparse
import json
import pathlib
import re
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
CARDS = ROOT / "data" / "cards.json"

# ---------------------------------------------------------------------------
# Rates and bands.
#
# The live card pool measures 7.0-8.1 damage per energy by faction and stage,
# overall mean 7.69.  Tempest prints at a 30% DISCOUNT on Charge bodies.
#
# The discount is derived, not chosen.  An attack grows Charge twice (the
# attack, plus its Storm instance), so a unit banks 2N per swing regardless of
# how long it holds -- amortised, Charge is worth +2N damage EVERY attack, and
# Storm adds a further free instance on top.  At Stage 2 that is +20 damage a
# swing, ~2.6 energy of value, the largest keyword benefit in the game.
#
# Compare: Judgment -1/3, Sanctuary -18%, Gaia ~9 against the standard curve.
BASE_RATE = {"basic": 7, "stage1": 8, "stage2": 9}
CHARGE_DISCOUNT = 0.70

BAND = {"basic": (1, 6), "stage1": (4, 10), "stage2": (8, 20)}
HP_BAND = {"basic": (40, 90), "stage1": (80, 120), "stage2": (110, 175)}

# Charge N by stage, tracking the HP curve so the tower clock stays the brake.
CHARGE_BAND = {"basic": (3, 5), "stage1": (6, 8), "stage2": (9, 12)}

# Only six lines in the whole game sit in the round-1 window of cost 1-2.
# Tempest adds none of them.
MAX_NEW_OPENER_COST = 3

# The ops this faction needs. None are built yet -- the engine work is listed
# in the spec's "Engine Cost" table. Declared here so the generator can tell
# "planned but missing" apart from "typo", and so --apply stays refused until
# the engine catches up.
PLANNED_OPS = {
    # Charge
    "charge_on_damage",      # grow the counter when this unit deals an instance
    "discharge",             # spend the whole counter: bonus damage + 2nd target
    "discharge_single",      # spend it all into one target
    "discharge_sweep",       # spend it split across the enemy board
    "discharge_structures",  # the printed rule-break: may reach tower/throne
    "discharge_heal",        # spend it as healing instead of damage
    "charge_transfer",       # move this unit's counter to another you control
    "charge_on_kill",        # grow extra when this unit kills
    # Storm
    "storm_raise",           # raise the global Storm counter by N
    "storm_scale_damage",    # +N damage per point of Storm
    "storm_charge_bonus",    # this unit grows extra Charge per point of Storm
}

# The ops that actually SPEND the counter. `discharge_structures` is deliberately
# absent: it is a RIDER on the attack a discharge rides out, not a spender, and it
# must sit on an attack line rather than an ability (see the check in build()).
DISCHARGE_OPS = {
    "discharge", "discharge_single", "discharge_sweep", "discharge_heal",
}

# A counter needs SOME way off the unit, but Discharge is not the only one:
# `charge_transfer` moves it to another body, which is equally a spender and is
# the whole identity of the relay chain.
SPENDER_OPS = DISCHARGE_OPS | {"charge_transfer"}


def implemented_ops():
    """Scrape the ops the engine actually handles out of the GDScript."""
    ops = set()
    pat = re.compile(r'(?:has_effect|effect_value)\("([a-z_]+)"')
    for path in list((ROOT / "scripts" / "core").glob("*.gd")) + \
                list((ROOT / "scripts" / "ui").glob("*.gd")):
        ops |= set(pat.findall(path.read_text(encoding="utf-8", errors="ignore")))
    return ops


def cost_for(stage, damage, discounted):
    """Derive an attack's cost from its damage, clamped into the stage band.

    A Charge body buys damage at 70% of the standard rate, so the SAME damage
    costs more energy -- the discount is applied as a worse rate, which is how
    Sanctuary's was done (less damage at the same cost is the same trade).
    """
    lo, hi = BAND[stage]
    if damage <= 0:
        return lo
    rate = BASE_RATE[stage] * (CHARGE_DISCOUNT if discounted else 1.0)
    c = max(1, round(damage / rate))
    return max(lo, min(hi, c))


def split_colorless(total, colour="tempest"):
    """The colorless split rule from CLAUDE.md. Total never moves."""
    if total <= 2:
        return {colour: total}
    if total <= 5:
        return {colour: total - 1, "colorless": 1}
    half = total // 2
    return {colour: total - half, "colorless": half}


def A(aid, name, dmg, text, effects=None, cost=None):
    """An attack line. Cost is derived from damage unless pinned."""
    return {"_kind": "attack", "id": aid, "name": name, "damage": dmg,
            "text": text, "effects": effects or [], "_cost": cost}


def AB(aid, name, text, effects=None, consume=0, dmg=0):
    """An ability line. Free unless it prints a non-energy cost."""
    return {"_kind": "ability", "id": aid, "name": name, "damage": dmg,
            "text": text, "effects": effects or [], "_consume": consume}


def KW(**kw):
    return [{"kw": k, "n": v} for k, v in kw.items()]


# ---------------------------------------------------------------------------
# Tempest energy.

ENERGY = {
    "id": "tempest_energy",
    "name": "Stormlight",
    "type": "energy",
    "faction": "tempest",
    "flavor": "The air before it breaks.",
}


# ---------------------------------------------------------------------------
# The roster.
#
# Naming follows the bestiary system: a chain shares a stem, the suffix
# escalates with age, and the suffix pool is PER FACTION so a name places its
# own colour.  Tempest's sound is sibilant and open -- moving air, long vowels,
# nothing struck or clipped (that is Forge) and nothing hollow (that is Void).
#
#   Basic:   -sile  -whorl  -skirl
#   Stage 1: -gale  -squall -shear
#   Stage 2: -tempest -maelstrom -thunderhead
#
# Six chains, one idea each, the same discipline the Hel starter decks used.
# Each chain OWNS one discharge op so the faction reads as six plans rather
# than six piles of the same card.

CHAINS = [
    # ("Stem", [(suffix, stage, hp, keywords, lines, flavor), ...])

    # 1. The baseline. Charge into a two-target discharge -- the keyword's
    #    reference implementation, and the chain a new player learns it from.
    ("Cirr", [
        ("sile", "basic", 50, KW(charge=3), [
            A("cirr_lash", "Lash", 14, "14 damage.",
              [{"op": "charge_on_damage", "n": 3}]),
            AB("cirr_break", "Break",
               "Discharge: this unit's next attack deals the counter as bonus "
               "damage and strikes a second unit on that board for the counter.",
               [{"op": "discharge"}]),
        ], "The first stirring. Nothing in it yet but direction."),
        ("gale", "stage1", 96, KW(charge=6), [
            A("cirr_scour", "Scour", 40, "40 damage.",
              [{"op": "charge_on_damage", "n": 6}]),
            AB("cirr_burst", "Burst",
               "Discharge: this unit's next attack deals the counter as bonus "
               "damage and strikes a second unit on that board for the counter.",
               [{"op": "discharge"}]),
        ], "It has found the shape of the valley and begun to hurry."),
        ("tempest", "stage2", 150, KW(charge=10), [
            A("cirr_rend", "Rend", 72, "72 damage.",
              [{"op": "charge_on_damage", "n": 10}]),
            AB("cirr_landfall", "Landfall",
               "Discharge: this unit's next attack deals the counter as bonus "
               "damage and strikes a second unit on that board for the counter.",
               [{"op": "discharge"}]),
        ], "Everything it gathered on the way, arriving at once."),
    ]),

    # 2. The banker. Slowest growth, biggest single-target dump. The chain that
    #    tests whether the tower clock really is the brake.
    ("Nimb", [
        ("whorl", "basic", 60, KW(charge=3), [
            A("nimb_gather", "Gather", 18, "18 damage.",
              [{"op": "charge_on_damage", "n": 3}]),
            AB("nimb_hold", "Hold",
               "Discharge: this unit's next attack deals twice the counter to a "
               "single target.",
               [{"op": "discharge_single", "n": 2}]),
        ], "Patience is only pressure that has not been asked for yet."),
        ("squall", "stage1", 104, KW(charge=7), [
            A("nimb_press", "Press", 36, "36 damage.",
              [{"op": "charge_on_damage", "n": 7}]),
            AB("nimb_hold_fast", "Hold Fast",
               "Discharge: this unit's next attack deals twice the counter to a "
               "single target.",
               [{"op": "discharge_single", "n": 2}]),
        ], "Still gathering. It has not decided where to put this."),
        ("maelstrom", "stage2", 162, KW(charge=11), [
            A("nimb_bear_down", "Bear Down", 63,
              "63 damage. A discharge on this attack may strike a tower or "
              "throne past living units.",
              [{"op": "charge_on_damage", "n": 11},
               {"op": "discharge_structures"}]),
            AB("nimb_cloudburst", "Cloudburst",
               "Discharge: this unit's next attack deals twice the counter to a "
               "single target.",
               [{"op": "discharge_single", "n": 2}]),
        ], "It decided."),
    ]),

    # 3. The weather-maker. Raises Storm rather than banking hard -- the chain
    #    that turns on everybody else's cards, including the opponent's.
    ("Foehn", [
        ("sile", "basic", 46, [], [
            AB("foehn_rise", "Rising Air",
               "Raise Storm by 1.",
               [{"op": "storm_raise", "n": 1}]),
            A("foehn_gust", "Gust", 21, "21 damage."),
        ], "A warm wind off the ridge. It means something is coming."),
        ("shear", "stage1", 88, [], [
            AB("foehn_front", "Front",
               "Raise Storm by 2.",
               [{"op": "storm_raise", "n": 2}]),
            A("foehn_drive", "Drive", 38, "38 damage."),
        ], "Two air masses that will not agree, and the line between them."),
        ("thunderhead", "stage2", 140, [], [
            AB("foehn_anvil", "Anvil Top",
               "Raise Storm by 3.",
               [{"op": "storm_raise", "n": 3}]),
            A("foehn_downburst", "Downburst", 54,
              "54 damage, and 3 more per point of Storm.",
              [{"op": "storm_scale_damage", "n": 3}]),
        ], "The sky arranged itself into a hammer and then used it."),
    ]),

    # 4. The relay. Moves a counter off a body about to die -- the faction's
    #    only answer to its own failure case, and priced as an ability so it
    #    costs the turn's action rather than energy.
    ("Sirocc", [
        ("skirl", "basic", 44, KW(charge=4), [
            A("sirocc_scud", "Scud", 13, "13 damage.",
              [{"op": "charge_on_damage", "n": 4}]),
            AB("sirocc_pass", "Pass the Charge",
               "Move this unit's counter to another unit you control.",
               [{"op": "charge_transfer"}]),
        ], "It does not stop. It only stops being here."),
        ("squall", "stage1", 92, KW(charge=7), [
            A("sirocc_flense", "Flense", 34, "34 damage.",
              [{"op": "charge_on_damage", "n": 7}]),
            AB("sirocc_hand_off", "Hand Off",
               "Move this unit's counter to another unit you control, then draw "
               "a card.",
               [{"op": "charge_transfer"}, {"op": "draw", "n": 1}]),
        ], "Nothing is lost. It is merely somewhere you did not expect."),
    ]),

    # 5. The executioner. Grows extra on a kill, so it snowballs through a
    #    board rather than off a single target -- the chain that makes
    #    no-overkill work for you.
    ("Bora", [
        ("whorl", "basic", 54, KW(charge=3), [
            A("bora_bite", "Bite", 16, "16 damage.",
              [{"op": "charge_on_damage", "n": 3},
               {"op": "charge_on_kill", "n": 6}]),
            AB("bora_scatter", "Scatter",
               "Discharge: split the counter as evenly as possible among every "
               "living unit on one enemy board.",
               [{"op": "discharge_sweep"}]),
        ], "A cold fall wind. It takes the weakest thing first, then the next."),
        ("shear", "stage1", 100, KW(charge=6), [
            A("bora_harrow", "Harrow", 42, "42 damage.",
              [{"op": "charge_on_damage", "n": 6},
               {"op": "charge_on_kill", "n": 12}]),
            AB("bora_strew", "Strew",
               "Discharge: split the counter as evenly as possible among every "
               "living unit on one enemy board.",
               [{"op": "discharge_sweep"}]),
        ], "It has learned that a cleared field is worth more than a felled tree."),
        ("maelstrom", "stage2", 155, KW(charge=10), [
            A("bora_unroof", "Unroof", 68, "68 damage.",
              [{"op": "charge_on_damage", "n": 10},
               {"op": "charge_on_kill", "n": 20}]),
            AB("bora_winnow", "Winnow",
               "Discharge: split the counter as evenly as possible among every "
               "living unit on one enemy board.",
               [{"op": "discharge_sweep"}]),
        ], "What is left standing was never the point."),
    ]),

    # 6. The doldrum. The support body -- discharges as healing, and reads
    #    Storm for its own growth rather than for damage. Two lines, no attack
    #    on the Stage 1, which is legal: an ability plus an attack.
    ("Calm", [
        ("sile", "basic", 56, KW(charge=3, resist=5), [
            A("calm_still", "Still Air", 17, "17 damage.",
              [{"op": "charge_on_damage", "n": 3}]),
            AB("calm_eye", "The Eye",
               "Discharge: heal a unit you control for the counter.",
               [{"op": "discharge_heal"}]),
        ], "The quiet at the middle is not the storm ending."),
        ("gale", "stage1", 112, KW(charge=6, resist=5), [
            A("calm_press", "Pressure Drop", 32,
              "32 damage, and 2 more per point of Storm.",
              [{"op": "charge_on_damage", "n": 6},
               {"op": "storm_scale_damage", "n": 2}]),
            AB("calm_shelter", "Shelter",
               "Discharge: heal a unit you control for the counter.",
               [{"op": "discharge_heal"}]),
        ], "It holds the middle open a little longer for whoever is inside it."),
    ]),
]


# ---------------------------------------------------------------------------
# Supports.
#
# Tempest-locked, following the precedent forge.md established: a faction
# support is bought with a deckbuilding commitment, which is a cost the 43
# neutral supports never pay. Kept small in number -- the faction's identity is
# on its bodies, unlike Forge whose aggression lives in its support suite.

SUPPORTS = [
    {
        "id": "tempest_front_line",
        "name": "Weather Front",
        "type": "support",
        "faction": "tempest",
        "cost": 0,
        "text": "Raise Storm by 2.",
        "effects": [{"op": "storm_raise", "n": 2}],
        "flavor": "It was always going to happen. This only fixes the hour.",
    },
    {
        "id": "tempest_updraft",
        "name": "Updraft",
        "type": "support",
        "faction": "tempest",
        "cost": 1,
        "text": "A unit you control gains 15 Charge.",
        "effects": [{"op": "charge_on_damage", "n": 15}],
        "flavor": "Everything light enough to be taken is taken.",
    },
    {
        "id": "tempest_earthing",
        "name": "Earthing Rod",
        "type": "tool",
        "faction": "tempest",
        "text": "This unit grows 2 extra Charge per point of Storm when it "
                "deals damage.",
        "effects": [{"op": "storm_charge_bonus", "n": 2}],
        "flavor": "Something has to take the strike. Better it be a thing you chose.",
    },
]


def build():
    """Assemble every Tempest card, validating as we go. Raises on any breach."""
    ops = implemented_ops() | PLANNED_OPS
    out = [ENERGY]
    problems = []

    for stem, forms in CHAINS:
        prev_id = None
        for form in forms:
            suffix, stage, hp, kws, lines, flavor = form
            cid = f"tempest_{stem.lower()}{suffix}"
            name = f"{stem}{suffix}"

            lo, hi = HP_BAND[stage]
            if not lo <= hp <= hi:
                problems.append(f"{name}: HP {hp} outside {stage} band {lo}-{hi}")
            if len(lines) > 2:
                problems.append(f"{name}: {len(lines)} lines breaks the two-line rule")

            kwmap = {k["kw"]: k["n"] for k in kws}
            charge_n = kwmap.get("charge", 0)
            if charge_n:
                clo, chi = CHARGE_BAND[stage]
                if not clo <= charge_n <= chi:
                    problems.append(
                        f"{name}: Charge {charge_n} outside {stage} band {clo}-{chi}")

            attacks = []
            has_kw = bool(kws)
            has_discharge = False
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
                    # `discharge_structures` is read off the ATTACK as it
                    # resolves — _deal_lane_damage never sees the ability that
                    # armed the counter. On an ability it is silent dead data,
                    # the same shape as a `stoked_` payoff on a line that cannot
                    # Stoke, so it is refused here rather than discovered in play.
                    if op == "discharge_structures" and ln["_kind"] == "ability":
                        problems.append(
                            f"{name}/{ln['name']}: 'discharge_structures' on an "
                            f"ability — it must ride the attack that resolves")
                    if op in SPENDER_OPS:
                        has_discharge = True
                        # Discharge is free and once per turn, so it is an
                        # ability by definition. On an attack it would be
                        # paying pool energy for a counter you already earned.
                        if ln["_kind"] != "ability":
                            problems.append(
                                f"{name}/{ln['name']}: '{op}' on an attack -- "
                                f"a Charge spender is a free once-per-turn ability")
                    if op == "charge_on_damage":
                        grows_charge = True
                        if e.get("n") != charge_n:
                            problems.append(
                                f"{name}/{ln['name']}: grows {e.get('n')} Charge "
                                f"but the card prints Charge {charge_n}")

                if ln["_kind"] == "ability":
                    entry["ability"] = True
                    if ln["_consume"]:
                        entry["consume"] = ln["_consume"]
                else:
                    discounted = charge_n > 0
                    total = ln["_cost"] or cost_for(stage, ln["damage"], discounted)
                    if stage == "basic" and total < MAX_NEW_OPENER_COST:
                        problems.append(
                            f"{name}/{ln['name']}: cost {total} is a new round-1 opener")
                    entry["cost"] = split_colorless(total)
                attacks.append(entry)

            # A Charge body with no way to spend the counter is dead data --
            # the same shape as Forge's `stoked_` payoff on a line that cannot
            # Stoke. The counter would grow forever and do nothing.
            if charge_n and not has_discharge:
                problems.append(
                    f"{name}: prints Charge {charge_n} but nothing spends it")
            # ...and a counter nothing feeds is equally dead.
            if charge_n and not grows_charge:
                problems.append(
                    f"{name}: prints Charge {charge_n} but no line grows it")
            # A keyword-less Basic must evolve into one that carries something.
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
    live = implemented_ops()
    missing = sorted(PLANNED_OPS - live)

    units = [c for c in cards if c["type"] == "unit"]
    print(f"Tempest: {len(cards)} cards -- {len(units)} units, "
          f"{len(CHAINS)} chains, {len(SUPPORTS)} supports, 1 energy.\n")
    for c in cards:
        if c["type"] != "unit":
            print(f"  [{c['type']:14}] {c['name']}")
            continue
        kw = " ".join(f"{k['kw']} {k['n']}" for k in c.get("keywords", []))
        costs = " / ".join(
            "ability" if a.get("ability")
            else "+".join(f"{v}{k[0]}" for k, v in a["cost"].items() if v)
            for a in c["attacks"])
        print(f"  {c['name']:22} {c['stage']:7} {c['hp']:3} HP  "
              f"[{kw}]  {costs}")

    if missing:
        print(f"\n{len(missing)} planned op(s) NOT YET IMPLEMENTED in the engine:")
        for m in missing:
            print("  *", m)

    if args.apply:
        if missing:
            print("\nREFUSING TO APPLY -- the engine does not implement these ops yet.")
            print("An unknown op parses fine and silently does nothing, so writing")
            print("these cards now would ship a faction that loads and cannot play.")
            print("Build the ops first (see the spec's Engine Cost table), then rerun.")
            sys.exit(1)
        db = json.loads(CARDS.read_text(encoding="utf-8"))
        key = "cards" if isinstance(db, dict) else None
        existing = db[key] if key else db
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
