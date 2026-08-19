"""Add the Forge faction to data/cards.json.

Forge is the fifth colour: fire, smithing, the primal. Its signatures are
`Stoke N` (a free once-per-turn ability that spends the unit's own HP and sets a
per-turn flag) and `Scrap` (an ability cost that destroys another unit you
control). See forge.md for the design and docs/plans/2026-08-16-forge-faction.md
for the build.

Like tools/add_bestiary_units.py this **enforces the design rules rather than
trusting the author**:

  * HP bands, the two-line rule, retreat = HP/40.
  * `Stoke` only ever on an ability, and never more than the body's own HP.
  * Attack costs derived from damage on the documented per-stage curve.
  * Only ops the engine actually implements -- scraped out of the GDScript,
    because an unknown op parses fine and silently does nothing.
  * No ramp payoffs (`attach N energy`): forge.md names them as the one class
    that breaks pacing, since attached energy is permanent and decay-immune.

Run:  python tools/add_forge_faction.py --dry-run    # then --apply
"""

import argparse
import json
import pathlib
import re
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
CARDS = ROOT / "data" / "cards.json"

# Damage per energy by stage (CLAUDE.md).  Cost is derived from damage and
# clamped into the stage's band -- the band is a clamp, never a target.
RATE = {"basic": 7, "stage1": 8, "stage2": 9}
BAND = {"basic": (1, 6), "stage1": (4, 10), "stage2": (8, 20)}
HP_BAND = {"basic": (40, 90), "stage1": (80, 120), "stage2": (110, 175)}

# Only these six lines in the whole game sit in the round-1 window of cost 1-2.
# Forge adds none of them.
MAX_NEW_OPENER_COST = 3

STOKE_OPS = {
    "stoked_bonus_damage", "stoked_scale_damage", "stoked_threshold",
    "stoked_threshold_damage", "stoked_double", "stoked_free_attack",
    "stoked_heal_back", "stoked_cleave", "stoked_ignore_shield",
}


def implemented_ops():
    """Scrape the ops the engine actually handles out of the GDScript."""
    ops = set()
    pat = re.compile(r'(?:has_effect|effect_value)\("([a-z_]+)"')
    for path in list((ROOT / "scripts" / "core").glob("*.gd")) + \
                list((ROOT / "scripts" / "ui").glob("*.gd")):
        ops |= set(pat.findall(path.read_text(encoding="utf-8", errors="ignore")))
    return ops


def cost_for(stage, damage):
    """Derive an attack's cost from its damage, clamped into the stage band."""
    lo, hi = BAND[stage]
    if damage <= 0:
        return lo
    c = max(1, round(damage / RATE[stage]))
    return max(lo, min(hi, c))


def split_colorless(total, colour="forge"):
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


def AB(aid, name, text, effects=None, stoke=0, scrap=False, consume=0, dmg=0):
    """An ability line. Free unless it prints a non-energy cost."""
    return {"_kind": "ability", "id": aid, "name": name, "damage": dmg,
            "text": text, "effects": effects or [],
            "_stoke": stoke, "_scrap": scrap, "_consume": consume}


def KW(**kw):
    return [{"kw": k, "n": v} for k, v in kw.items()]


# ---------------------------------------------------------------------------
# The roster.
#
# Naming follows the bestiary system: a chain shares a stem, the suffix
# escalates with age, and the suffix pool is PER FACTION so a name places its
# own colour.  Forge's sound is hard and struck -- hot metal, short vowels,
# consonant endings.  Basic -/spark, -ash; Stage 1 -forge, -brand, -kiln;
# Stage 2 -smith, -pyre, -anvil.
#
# Five chains, one idea each -- the same shape Gaia's five chains were built on.
# ---------------------------------------------------------------------------

CHAINS = [
    # 1. THE BIG STOKER -- large Stoke, threshold payoffs, the geometry-breaker.
    ("Cind", [
        ("spark", "basic", 60, KW(),
         [AB("stoke", "Stoke", "Deal 20 damage to this unit. It has stoked this turn.", stoke=20),
          A("ember_strike", "Ember Strike", 28,
            "28 damage. If this unit stoked this turn, +10 damage.",
            [{"op": "stoked_bonus_damage", "n": 10}])],
         "It banks its own heat and waits to be worth spending."),
        ("brand", "stage1", 105, KW(),
         [AB("stoke", "Stoke", "Deal 30 damage to this unit. It has stoked this turn.", stoke=30),
          A("white_heat", "White Heat", 44,
            "44 damage. If this unit stoked this turn, +1 damage per 2 HP stoked.",
            [{"op": "stoked_scale_damage", "n": 2}])],
         "The metal stops glowing red and starts glowing white. So does the smith."),
        ("pyre", "stage2", 160, KW(),
         [AB("stoke", "Stoke", "Deal 50 damage to this unit. It has stoked this turn.", stoke=50),
          A("the_last_heat", "The Last Heat", 70,
            "70 damage. If this unit stoked 40 or more this turn, this attack "
            "burns past living units and strikes the tower behind them.",
            [{"op": "stoked_threshold", "n": 40},
             {"op": "stoked_ignore_shield", "n": 1}])],
         "Everything it was keeping in reserve, spent at once, through the wall."),
    ]),

    # 2. THE CHEAP STOKER -- small Stoke, cheap repeatable payoffs.
    ("Slag", [
        ("ash", "basic", 45, KW(),
         [AB("stoke", "Stoke", "Deal 10 damage to this unit. It has stoked this turn.", stoke=10),
          A("scour", "Scour", 24,
            "24 damage. If this unit stoked this turn, +7 damage.",
            [{"op": "stoked_bonus_damage", "n": 7}])],
         "Cheap to light, cheap to lose. It knows both."),
        ("kiln", "stage1", 88, KW(),
         [AB("stoke", "Stoke", "Deal 20 damage to this unit. It has stoked this turn.", stoke=20),
          A("bellows", "Bellows", 40,
            "40 damage. If this unit stoked this turn, this attack costs no energy.",
            [{"op": "stoked_free_attack", "n": 1}])],
         "Feed it and it asks for nothing else."),
    ]),

    # 3. THE SCRAPPER -- Scrap abilities. The Forge/Hel door.
    ("Grist", [
        # Scrap does NOT set the stoked flag -- only Stoke does -- so this line
        # pairs the two rather than printing a stoked_ payoff that would never
        # fire.  Caught before authoring: an unread effect is silent, not loud.
        ("gnash", "basic", 55, KW(),
         [AB("feed", "Feed the Fire",
             "Destroy another unit you control. Deal 10 damage to this unit. It "
             "has stoked this turn.", [], stoke=10, scrap=True),
          A("cinder_bite", "Cinder Bite", 26,
            "26 damage. If this unit stoked this turn, +7 damage.",
            [{"op": "stoked_bonus_damage", "n": 7}])],
         "It does not distinguish between fuel and family."),
        ("forge", "stage1", 100, KW(),
         [AB("consume_stock", "Consume the Stock",
             "Destroy another unit you control. Deal 30 damage to this unit. It "
             "has stoked this turn.", [], stoke=30, scrap=True),
          A("hammerfall", "Hammerfall", 48,
            "48 damage. If this unit stoked this turn, +1 damage per 2 HP stoked.",
            [{"op": "stoked_scale_damage", "n": 2}])],
         "Everything on the bench is stock. That is what a bench is for."),
        ("smith", "stage2", 140, KW(),
         [AB("reforge", "Reforge",
             "Destroy another unit you control. Deal 40 damage to this unit, then "
             "heal it for that much. It has stoked this turn.",
             [{"op": "stoked_heal_back", "n": 100}], stoke=40, scrap=True),
          A("the_work", "The Work", 62,
            "62 damage. If this unit stoked this turn, this damage is doubled.",
            [{"op": "stoked_double", "n": 1}])],
         "It takes the heat back out of the metal and keeps it."),
    ]),

    # 4. THE CLEAVER -- Stoke damage splashes outward. Stoke as the weapon.
    ("Emb", [
        ("ash", "basic", 50, KW(retribution=10),
         [AB("flare", "Flare",
             "Deal 20 damage to this unit and 20 damage to the enemy unit across "
             "from it. It has stoked this turn.",
             [{"op": "stoked_cleave", "n": 100}], stoke=20),
          A("sear", "Sear", 22, "22 damage")],
         "It burns outward as readily as inward. It does not much notice which."),
        ("kiln", "stage1", 95, KW(retribution=15),
         [AB("backdraft", "Backdraft",
             "Deal 30 damage to this unit and 30 damage to the enemy unit across "
             "from it. It has stoked this turn.",
             [{"op": "stoked_cleave", "n": 100}], stoke=30),
          A("open_flame", "Open Flame", 42,
            "42 damage. If this unit stoked this turn, +10 damage.",
            [{"op": "stoked_bonus_damage", "n": 10}])],
         "Stand too close to the work and the work stands too close to you."),
    ]),

    # 5. THE SUSTAIN BODY -- heal-back. Only good BECAUSE other cards read the
    #    flag; on its own it would just be "stoke for free".
    ("Quench", [
        ("wick", "basic", 65, KW(resist=5),
         [AB("temper", "Temper",
             "Deal 20 damage to this unit, then heal it for that much. It has "
             "stoked this turn.",
             [{"op": "stoked_heal_back", "n": 100}], stoke=20),
          A("anneal", "Anneal", 25,
            "25 damage. If this unit stoked this turn, +7 damage.",
            [{"op": "stoked_bonus_damage", "n": 7}])],
         "Heated, cooled, heated again. That is not damage. That is the process."),
        ("anvil", "stage2", 155, KW(resist=10),
         [AB("the_long_temper", "The Long Temper",
             "Deal 50 damage to this unit, then heal it for that much. It has "
             "stoked this turn.",
             [{"op": "stoked_heal_back", "n": 100}], stoke=50),
          A("finished_work", "Finished Work", 66,
            "66 damage. If this unit stoked 40 or more this turn, +40 damage.",
            [{"op": "stoked_threshold", "n": 40},
             {"op": "stoked_threshold_damage", "n": 40}])],
         "It has been in and out of the fire so many times it no longer counts as leaving."),
    ]),
]

# Stage 1 of the Quench chain, so the line is not Basic -> Stage 2.
QUENCH_MID = ("Quench", "brand", "stage1", 110, KW(resist=5),
    [AB("draw_the_heat", "Draw the Heat",
        "Deal 30 damage to this unit, then heal it for that much. It has stoked "
        "this turn.", [{"op": "stoked_heal_back", "n": 100}], stoke=30),
     A("hardened", "Hardened", 45,
       "45 damage. If this unit stoked this turn, +10 damage.",
       [{"op": "stoked_bonus_damage", "n": 10}])],
    "The shape is decided. Now it is only a question of how hard.")


ENERGY = {
    "id": "forge_energy", "name": "Forge Energy", "type": "energy",
    "faction": "forge",
    "text": "Adds (turn + 1) Forge energy to your pool.",
    "flavor": "Fire is the one god that asks to be fed before it answers.",
}


# Faction-locked supports.  This is where Forge's aggression actually lives:
# above the neutral band, paying in HP and bodies rather than pool energy, and
# bought with a deckbuilding commitment the neutral cards never pay.
#
# The line that does NOT move: a Forge support may not sell damage more
# efficiently than an attack.  These buy reach and tempo, never raw damage.
SUPPORTS = [
    {
        "id": "forge_bank_the_coals", "name": "Bank the Coals", "type": "support",
        "faction": "forge", "cost": 1,
        "effects": [{"op": "heal", "n": 60}],
        "text": "Heal 60 damage from one of your units.",
        "flavor": "You do not put the fire out. You put it away.",
    },
    {
        "id": "forge_quenching_trough", "name": "Quenching Trough", "type": "support",
        "faction": "forge",
        "effects": [{"op": "heal_all", "n": 20}],
        "text": "Heal 20 damage from each of your units.",
        "flavor": "Steam to the rafters, and every blade on the rack still sharp.",
    },
    {
        "id": "forge_stoke_the_works", "name": "Stoke the Works", "type": "support",
        "faction": "forge", "cost": 2,
        "effects": [{"op": "draw", "n": 3}],
        "text": "Draw 3 cards.",
        "flavor": "Every hand in the shop, working at once.",
    },
    {
        "id": "forge_scrap_heap", "name": "Scrap Heap", "type": "support",
        "faction": "forge",
        "effects": [{"op": "random_from_discard", "n": 1}],
        "text": "Return a random unit from your discard pile to your hand.",
        "flavor": "Nothing here is finished. Some of it is only cold.",
    },
    {
        "id": "forge_hearthstone", "name": "Hearthstone", "type": "tool",
        "faction": "forge",
        "effects": [{"op": "heal_eot", "n": 10}],
        "text": "Attach to one of your units. It heals 10 damage at end of turn.",
        "flavor": "A stone that remembers being a fire.",
    },
]


def build():
    """Assemble every Forge card, validating as we go. Raises on any breach."""
    ops = implemented_ops()
    out = [ENERGY]
    problems = []

    # Splice the Quench Stage 1 into its chain.
    chains = []
    for stem, forms in CHAINS:
        if stem == "Quench":
            forms = [forms[0], QUENCH_MID[1:], forms[1]]
        chains.append((stem, forms))

    for stem, forms in chains:
        prev_id = None
        for form in forms:
            suffix, stage, hp, kws, lines, flavor = form
            cid = f"forge_{stem.lower()}{suffix}"
            name = f"{stem}{suffix}"

            lo, hi = HP_BAND[stage]
            if not lo <= hp <= hi:
                problems.append(f"{name}: HP {hp} outside {stage} band {lo}-{hi}")
            if len(lines) > 2:
                problems.append(f"{name}: {len(lines)} lines breaks the two-line rule")

            attacks = []
            has_kw = bool(kws)
            for ln in lines:
                entry = {"id": ln["id"], "name": ln["name"],
                         "damage": ln["damage"], "text": ln["text"]}
                if ln["effects"]:
                    entry["effects"] = ln["effects"]
                for e in ln["effects"]:
                    op = e.get("op", "")
                    if op not in ops:
                        problems.append(f"{name}/{ln['name']}: op '{op}' is not implemented")
                    if op.startswith("stoked_") and op not in STOKE_OPS:
                        problems.append(f"{name}/{ln['name']}: unknown stoke op '{op}'")
                    # forge.md: ramp payoffs are excluded from the core set.
                    if op in ("gain_energy", "pool_to_unit_eot"):
                        problems.append(f"{name}/{ln['name']}: ramp payoff '{op}' is excluded")

                # A stoked_ payoff on an ABILITY that does not itself Stoke can
                # never fire, because the flag is set by Stoke alone -- Scrap and
                # Consume do not set it.  Silent dead data, so it is refused here.
                if ln["_kind"] == "ability" and not ln["_stoke"]:
                    for e in ln["effects"]:
                        op = e.get("op", "")
                        if op.startswith("stoked_") and op != "stoked_heal_back":
                            problems.append(
                                f"{name}/{ln['name']}: '{op}' on an ability that "
                                f"never Stokes -- it can never fire")

                if ln["_kind"] == "ability":
                    entry["ability"] = True
                    if ln["_stoke"]:
                        entry["stoke"] = ln["_stoke"]
                        has_kw = True
                        if ln["_stoke"] > hp:
                            problems.append(
                                f"{name}: stokes {ln['_stoke']} with only {hp} HP")
                    if ln["_scrap"]:
                        entry["scrap"] = True
                        has_kw = True
                    if ln["_consume"]:
                        entry["consume"] = ln["_consume"]
                else:
                    total = ln["_cost"] or cost_for(stage, ln["damage"])
                    if stage == "basic" and total < MAX_NEW_OPENER_COST:
                        problems.append(
                            f"{name}/{ln['name']}: cost {total} is a new round-1 opener")
                    entry["cost"] = split_colorless(total)
                attacks.append(entry)

            # A keyword-less Basic must evolve into one that carries something,
            # or it is a dead draw rather than a clean cheap body.
            if not has_kw and stage == "basic" and len(forms) == 1:
                problems.append(f"{name}: vanilla Basic with nowhere to evolve")

            card = {
                "id": cid, "name": name, "type": "unit", "faction": "forge",
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
    existing = {c["id"] for c in db["cards"]}

    new = [c for c in cards if c["id"] not in existing]
    dupes = [c["id"] for c in cards if c["id"] in existing]

    units = [c for c in cards if c["type"] == "unit"]
    print(f"Forge: {len(cards)} cards -- {len(units)} units, "
          f"{len([c for c in cards if c['type'] != 'unit'])} other")
    for c in units:
        stoke = ""
        for a in c["attacks"]:
            if a.get("stoke"):
                stoke = f"  Stoke {a['stoke']}"
            if a.get("scrap"):
                stoke += "  Scrap"
        costs = [a.get("cost") for a in c["attacks"] if a.get("cost")]
        print(f"  {c['name']:<16} {c['stage']:<7} {c['hp']:>3} HP  "
              f"retreat {c['retreat']}{stoke}   costs {costs}")
    if dupes:
        print(f"\nAlready present, skipping: {dupes}")

    if args.apply:
        db["cards"].extend(new)
        CARDS.write_text(json.dumps(db, indent=1, ensure_ascii=False) + "\n",
                         encoding="utf-8")
        print(f"\nWrote {len(new)} new cards. Total now {len(db['cards'])}.")
    else:
        print("\n(dry run -- pass --apply to write)")


if __name__ == "__main__":
    main()
