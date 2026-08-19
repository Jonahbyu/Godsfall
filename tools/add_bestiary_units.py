"""Add the 58 new creatures from docs/specs/bestiary.md to data/cards.json.

    python tools/add_bestiary_units.py --dry-run
    python tools/add_bestiary_units.py --apply

Every card here is written against the constraints already settled in CLAUDE.md,
and the script checks them rather than trusting the table below:

  * **Cost is derived from damage**, never authored.  cost = round(dmg / RATE),
    clamped into the stage band.  RATE = Basic 7, Stage 1 8, Stage 2 9; bands are
    Basic 1-6, Stage 1 4-10, Stage 2 8-20.  Same rule tools/reprice_attacks.py
    applies to the existing pool, so the new cards land on the same curve.
  * **No new round-1 openers.**  There are exactly six attacks in the game at
    cost 1-2 and that scarcity is deliberate -- a cheap attack is paid once and
    then fires free every turn, so it generates ~3x the activations of an
    expensive one.  New Basic attacks price at 4-6.
  * **Judgment units buy damage at ~8/energy, not 12.**  Judgment is a discount
    on the kill, so the curve takes it back as a rate cut.
  * **The two-line rule.**  At most two lines per unit: one ability + one attack,
    or two attacks.
  * **HP bands.**  Basic 40-90, Stage 1 80-120, Stage 2 110-175.
  * **Judgment caps by stage:** Basic 20, Stage 1 40, Stage 2 50.
  * **Toll is HP/25, retreat is HP/40**, both floored -- derived at design time
    and printed, never recomputed in play.
  * **Only ops the engine actually implements.**  An unknown op parses fine and
    silently does nothing, which is the exact shape of the bug the decision log
    records for dropped unit `effects`.  IMPLEMENTED_OPS is scraped from the
    GDScript so this cannot drift.

Naming follows the per-faction suffix pools in the spec: a chain shares a stem,
the suffix escalates with age, and the pools differ per faction so a name places
its own colour.
"""

import argparse
import json
import pathlib
import re
import subprocess
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
CARDS = ROOT / "data" / "cards.json"

RATE = {"basic": 7.0, "stage1": 8.0, "stage2": 9.0}
JUDGMENT_RATE = {"basic": 8.0, "stage1": 8.0, "stage2": 8.0}
BANDS = {"basic": (1, 6), "stage1": (4, 10), "stage2": (8, 20)}
HP_BANDS = {"basic": (40, 90), "stage1": (80, 120), "stage2": (110, 175)}
JUDGMENT_CAP = {"basic": 20, "stage1": 40, "stage2": 50}
MIN_NEW_COST = 4          # no new round-1 openers
MIN_SANCTUARY = 60        # below this the free overflow makes N do no work


def implemented_ops():
    """Scrape the ops the engine actually handles out of the GDScript."""
    ops = set()
    pat = re.compile(r'(?:has_effect|effect_value)\("([a-z_]+)"')
    for path in list((ROOT / "scripts" / "core").glob("*.gd")) + \
                list((ROOT / "scripts" / "ui").glob("*.gd")):
        ops |= set(pat.findall(path.read_text(encoding="utf-8", errors="ignore")))
    return ops


def A(aid, name, dmg, text, effects=None, ability=False, consume=0):
    """One attack or ability line. Cost is filled in later, from damage."""
    return {"id": aid, "name": name, "damage": dmg, "text": text,
            "effects": effects or [], "_ability": ability, "_consume": consume}


# --------------------------------------------------------------------------
# The roster.  (stem, [(suffix, stage, hp, keywords, lines, flavor)])
# Chains are written as a list so evolves_from can be wired automatically.
# --------------------------------------------------------------------------

HEL = [
    # -- chains ------------------------------------------------------------
    ("Rime", [
        ("lit", "basic", 45, [("toll", 1)],
         [A("frostbite", "Frostbite", 28, "28 damage")],
         "It exhales and the grass goes white. Small mercies freeze first."),
        ("mire", "stage1", 95, [("toll", 3), ("decay", 5)],
         [A("hoarfrost", "Hoarfrost", 48, "48 damage")],
         "Grief that learned to keep. Nothing it touches rots -- it simply stops."),
    ]),
    ("Grist", [
        ("wisp", "basic", 40, [("toll", 1)],
         [A("chaff", "Chaff", 26, "26 damage")],
         "The dust of everything the mill has ever taken. It remembers each one."),
        ("gaunt", "stage1", 90, [("toll", 3)],
         [A("winnow", "Winnow", 44, "44 damage"),
          A("glean", "Glean", 0,
            "Return a Hel unit from your discard to your hand",
            [{"op": "return_from_discard", "n": 1}], ability=True, consume=1)],
         "It separates the living from the dead the way a mill separates chaff."),
    ]),
    ("Hollow", [
        ("grub", "basic", 50, [("toll", 2), ("decay", 5)],
         [A("burrow", "Burrow", 30, "30 damage")],
         "It eats the parts you were not using. You notice much later."),
        ("maw", "stage1", 100, [("toll", 4), ("decay", 5)],
         [A("hollow_out", "Hollow Out", 52, "52 damage")],
         "A hunger with a body built around it, purely as a convenience."),
        ("drung", "stage2", 130, [("toll", 5), ("decay", 10)],
         [A("the_long_hollow", "The Long Hollow", 90, "90 damage"),
          A("interment", "Interment", 0,
            "Deal 15 damage to every enemy unit",
            [{"op": "damage_enemy_board", "n": 15}], ability=True, consume=2)],
         "It has been digging since before there were things to bury."),
    ]),
    # -- standalone Basics -------------------------------------------------
    ("Oss", [
        ("kin", "basic", 55, [("toll", 2), ("rise", 0)],
         [A("splinter", "Splinter", 32, "32 damage")],
         "Bone remembers the shape it held. Given time, it finds it again."),
        ("shroud", "stage1", 105, [("toll", 4), ("rise", 0)],
         [A("ossuary", "Ossuary", 53, "53 damage")],
         "Every bone it ever wore, worn at once."),
        ("rend", "stage2", 150, [("toll", 6)],
         [A("the_last_marrow", "The Last Marrow", 105, "105 damage"),
          A("exhume", "Exhume", 0,
            "Return a Hel unit from your discard to an empty slot",
            [{"op": "reanimate", "n": 1}], ability=True, consume=2)],
         "It is not raising the dead. It is collecting them."),
    ]),
    ("Gnaw", [
        ("ling", "basic", 40, [("toll", 1), ("decay", 5)],
         [A("nibble", "Nibble", 24, "24 damage")],
         "Too small to fear. That is the arrangement it prefers."),
        ("mire", "stage1", 85, [("toll", 3), ("decay", 10)],
         [A("gnash", "Gnash", 42, "42 damage")],
         "It has been chewing on the same root for an age and is not bored."),
    ]),
    ("Mor", [("grub", "basic", 60, [("toll", 2)],
              [A("swarm", "Swarm", 36, "36 damage")],
              "One is nothing. There has never once been one.")]),
    ("Sepul", [("wisp", "basic", 45, [("toll", 1), ("retribution", 10)],
                [A("keening", "Keening", 28, "28 damage")],
                "It mourns whoever strikes it, immediately and at volume.")]),
    ("Cairn", [("ling", "basic", 65, [("toll", 2), ("retribution", 15)],
                [A("stoneward", "Stoneward", 34, "34 damage")],
                "Every stone was set by someone who wanted to be remembered.")]),
]

HEAVEN = [
    ("Vesper", [
        ("mote", "basic", 45, [("judgment", 15)],
         [A("first_light", "First Light", 30, "30 damage")],
         "The last light of the day, which is also the first of the reckoning."),
        ("vigil", "stage1", 95, [("judgment", 35)],
         [A("evensong", "Evensong", 50, "50 damage")],
         "It has kept watch so long that the watching has become the point."),
    ]),
    ("Solem", [
        ("im", "basic", 50, [("sanctuary", 60)],
         [A("intercede", "Intercede", 32, "32 damage")],
         "It steps in front. That is the entire liturgy."),
        ("mant", "stage1", 110, [("sanctuary", 80)],
         [A("bulwark_of_light", "Bulwark of Light", 55, "55 damage")],
         "A wall that apologises to what it stops."),
        ("tribune", "stage2", 145, [("sanctuary", 100)],
         [A("final_shelter", "Final Shelter", 95, "95 damage"),
          A("renew", "Renew", 0, "Restore this unit's Sanctuary at end of turn",
            [{"op": "eot_restore_sanctuary", "n": 1}], ability=True, consume=2)],
         "Behind it, everything is still exactly as it was."),
    ]),
    ("Halo", [
        ("kin", "basic", 40, [("judgment", 20)],
         [A("mark", "Mark", 28, "28 damage")],
         "It draws a circle. Whatever is inside has been decided about."),
        ("sear", "stage1", 90, [("judgment", 40)],
         [A("brand", "Brand", 46, "46 damage"),
          A("absolve", "Absolve", 0, "Restore this unit's Judgment",
            [{"op": "restore_own_judgment", "n": 1}], ability=True, consume=2)],
         "The verdict was written before the trial. The trial is a courtesy."),
    ]),
    ("Clar", [
        ("iel", "basic", 45, [("judgment", 15)],
         [A("clarion", "Clarion", 29, "29 damage")],
         "A note held until every other sound gives up."),
        ("choir", "stage1", 100, [("judgment", 40)],
         [A("chorus", "Chorus", 48, "48 damage")],
         "Many voices, one verdict, no dissent recorded."),
        ("arch", "stage2", 140, [("judgment", 50)],
         [A("the_final_note", "The Final Note", 88, "88 damage"),
          A("reconsecrate", "Reconsecrate", 0,
            "Restore Judgment to every unit you control",
            [{"op": "restore_board_judgment", "n": 1}], ability=True, consume=2)],
         "When it stops, the silence is the sentence."),
    ]),
    ("Aur", [("mote", "basic", 55, [("sanctuary", 60)],
              [A("gild", "Gild", 33, "33 damage")],
              "Gold does not tarnish. It simply waits out whatever is trying.")]),
    ("Lume", [("kin", "basic", 40, [("judgment", 20), ("rise", 0)],
               [A("rekindle", "Rekindle", 27, "27 damage")],
               "Snuff it and it takes the offence personally.")]),
    ("Bell", [("mote", "basic", 50, [("judgment", 15)],
               [A("toll_the_hour", "Toll the Hour", 31, "31 damage")],
               "Each ring is a name. It has not repeated one yet.")]),
    ("Sera", [("kin", "basic", 60, [("sanctuary", 60)],
               [A("shieldwing", "Shieldwing", 35, "35 damage")],
               "Six wings, four of them turned outward, toward you.")]),
]

VOID = [
    ("Fane", [
        ("ith", "basic", 45, [("siphon", 1)],
         [A("unmake", "Unmake", 29, "29 damage")],
         "It was a temple to something. The something is the part that went."),
        ("fray", "stage1", 95, [("siphon", 1), ("rift", 1)],
         [A("erode", "Erode", 48, "48 damage")],
         "Worship without an object, running on habit alone."),
    ]),
    ("Vast", [
        ("sk", "basic", 50, [("rift", 1)],
         [A("widen", "Widen", 31, "31 damage")],
         "The distance between two things, given an appetite."),
        ("ebb", "stage1", 100, [("rift", 1)],
         [A("recede", "Recede", 52, "52 damage")],
         "It does not approach. The space in front of it simply gets longer."),
        ("nought", "stage2", 135, [("rift", 2)],
         [A("the_wide_dark", "The Wide Dark", 64, "64 damage"),
          A("engulf", "Engulf", 0, "Destroy 2 energy attached to an enemy unit",
            [{"op": "void_energy", "n": 2}], ability=True, consume=1)],
         "Everything that is not it is a rounding error."),
    ]),
    ("Scour", [
        ("wane", "basic", 55, [("siphon", 1)],
         [A("abrade", "Abrade", 33, "33 damage")],
         "Patient as weather and about as negotiable."),
        ("gaunt", "stage1", 90, [("siphon", 2)],
         [A("strip", "Strip", 45, "45 damage")],
         "It takes the surface first. There is rarely anything under it."),
    ]),
    ("Hush", [
        ("wane", "basic", 45, [("siphon", 1)],
         [A("muffle", "Muffle", 29, "29 damage"),
          A("quiet", "Quiet", 0, "Destroy 1 energy attached to an enemy unit",
            [{"op": "void_energy", "n": 1}], ability=True, consume=1)],
         "It gets between you and the sound of your own thoughts."),
        ("ebb", "stage1", 95, [("siphon", 2), ("rift", 1)],
         [A("attenuate", "Attenuate", 47, "47 damage")],
         "Everything is still there. None of it reaches you."),
    ]),
    ("Umbr", [
        ("sk", "basic", 40, [("rift", 1)],
         [A("dim", "Dim", 26, "26 damage")],
         "Not darkness. The place light declined to go."),
        ("fray", "stage1", 85, [("rift", 1), ("siphon", 1)],
         [A("penumbra", "Penumbra", 44, "44 damage")],
         "The edge of a shadow, which is the hungriest part of it."),
        ("reave", "stage2", 125, [("rift", 2), ("siphon", 1)],
         [A("total_eclipse", "Total Eclipse", 64, "64 damage"),
          A("consume_light", "Consume Light", 0,
            "Destroy 20% of the enemy's energy pool",
            [{"op": "void_pool_pct", "n": 20}], ability=True, consume=2)],
         "It does not block the light. It keeps it."),
    ]),
    ("Null", [("wane", "basic", 50, [("siphon", 1)],
               [A("subtract", "Subtract", 30, "30 damage")],
               "It performs one operation and has never needed another.")]),
    ("Sev", [("ith", "basic", 60, [("siphon", 1)],
              [A("sunder_bond", "Sunder Bond", 36, "36 damage")],
              "It separates a thing from what made it a thing.")]),
    ("Wane", [("ith", "basic", 55, [("rift", 1)],
               [A("dwindle", "Dwindle", 34, "34 damage")],
               "Every night it is slightly less, and never quite gone.")]),
]

GAIA = [
    ("Mycel", [
        ("spore", "basic", 50, [("earth", 1)],
         [A("bloom", "Bloom", 30, "30 damage")],
         "It is already everywhere. The mushroom is just the part that surfaced."),
        ("bough", "stage1", 105, [("earth", 2), ("essence", 1)],
         [A("mycorrhiza", "Mycorrhiza", 50, "50 damage")],
         "It has been quietly connecting the whole grove for years."),
    ]),
    ("Gran", [
        ("ling", "basic", 65, [("earth", 1), ("resist", 5)],
         [A("shale", "Shale", 34, "34 damage")],
         "Small, dense, and entirely unbothered."),
        ("crag", "stage1", 115, [("earth", 2), ("resist", 5)],
         [A("landslide", "Landslide", 54, "54 damage")],
         "It does not hurry. It has never once needed to."),
        ("thane", "stage2", 165, [("earth", 3), ("resist", 10)],
         [A("orogeny", "Orogeny", 100, "100 damage"),
          A("upthrust", "Upthrust", 0, "This unit gains 1 Earth",
            [{"op": "grow_earth", "n": 1}], ability=True)],
         "Mountains are just this, given enough patience."),
    ]),
    ("Root", [
        ("sprout", "basic", 55, [("earth", 1), ("essence", 1)],
         [A("tendril", "Tendril", 31, "31 damage")],
         "Reaching is the only thing it does, and it does it constantly."),
        ("warden", "stage1", 100, [("earth", 2), ("essence", 2)],
         [A("entangle", "Entangle", 48, "48 damage")],
         "What it holds, it holds on behalf of everything behind it."),
    ]),
    ("Thorn", [
        ("bud", "basic", 45, [("earth", 1), ("retribution", 15)],
         [A("prick", "Prick", 28, "28 damage")],
         "Defended out of all proportion to its size."),
        ("crag", "stage1", 95, [("earth", 2), ("retribution", 20)],
         [A("bramblewall", "Bramblewall", 46, "46 damage")],
         "Walking into it is a decision you get to make exactly once."),
        ("heart", "stage2", 155, [("earth", 3), ("retribution", 25), ("essence", 2)],
         [A("the_deep_thicket", "The Deep Thicket", 95, "95 damage"),
          A("seed_the_grove", "Seed the Grove", 0,
            "Move this unit's Earth to another unit you control",
            [{"op": "move_earth", "n": 1}], ability=True, consume=1)],
         "The grove does not end. You simply stop being inside it."),
    ]),
    ("Bryo", [("spore", "basic", 60, [("earth", 2)],
               [A("creep", "Creep", 35, "35 damage")],
               "Moss wins every argument by outlasting it.")]),
    ("Petri", [("ling", "basic", 70, [("earth", 1), ("resist", 5)],
                [A("harden", "Harden", 37, "37 damage")],
                "It is becoming stone. It is in no rush about it.")]),
    ("Lich", [("bud", "basic", 50, [("earth", 1), ("essence", 1)],
               [A("crust", "Crust", 30, "30 damage")],
               "Two things agreeing to be one thing. It has worked so far.")]),
    ("Verd", [("spore", "basic", 55, [("earth", 2)],
               [A("flourish", "Flourish", 33, "33 damage")],
               "Green comes back. That is the whole of its argument.")]),
]

ROSTERS = {"hel": HEL, "heaven": HEAVEN, "void": VOID, "gaia": GAIA}

## Wave 2 (+30 per faction) lives in its own module -- one literal holding 178
## creatures is not reviewable. Merged rather than replaced so a single run
## still produces the whole roster from scratch.
try:
    import bestiary_wave2
    for _f, _forms in bestiary_wave2.build(A).items():
        ROSTERS[_f] = ROSTERS[_f] + _forms
except ImportError:
    pass
ENERGY_KEY = {"hel": "hel", "heaven": "heaven", "void": "void", "gaia": "gaia"}
# Gaia's existing ids are faction-prefixed; the other three are bare.
ID_PREFIX = {"hel": "", "heaven": "", "void": "", "gaia": "gaia_"}


def price(dmg, stage, has_judgment):
    if dmg <= 0:
        return 0
    rate = (JUDGMENT_RATE if has_judgment else RATE)[stage]
    lo, hi = BANDS[stage]
    cost = round(dmg / rate)
    cost = max(lo, min(hi, cost))
    if stage == "basic":
        cost = max(MIN_NEW_COST, cost)   # no new round-1 openers
    return cost


def build():
    cards, problems = [], []
    for faction, roster in ROSTERS.items():
        for stem, forms in roster:
            ## A card need not touch a mechanic, but a card that touches no
            ## mechanic AND goes nowhere is a dead draw. So a keyword-less Basic
            ## is only legal as the bottom of a line whose next stage carries a
            ## keyword -- the payoff is what the vanilla is *for*.
            for i, form in enumerate(forms):
                kws = form[3]
                if form[1] == "basic" and not kws:
                    if i + 1 >= len(forms):
                        problems.append(
                            f"{stem}{form[0]}: vanilla Basic with no evolution")
                    elif not forms[i + 1][3]:
                        problems.append(
                            f"{stem}{form[0]}: vanilla Basic evolves into "
                            f"{stem}{forms[i + 1][0]}, which has no keyword")
            prev_id = None
            for suffix, stage, hp, kws, lines, flavor in forms:
                name = stem + suffix
                cid = ID_PREFIX[faction] + re.sub(r"[^a-z0-9]+", "_", name.lower())
                kw_list = [{"kw": k, "n": n} for k, n in kws]
                has_j = any(k == "judgment" for k, _ in kws)

                if len(lines) > 2:
                    problems.append(f"{name}: {len(lines)} lines (two-line rule)")
                lo, hi = HP_BANDS[stage]
                if not lo <= hp <= hi:
                    problems.append(f"{name}: hp {hp} outside {stage} band {lo}-{hi}")
                for k, n in kws:
                    if k == "judgment" and n > JUDGMENT_CAP[stage]:
                        problems.append(
                            f"{name}: Judgment {n} over {stage} cap "
                            f"{JUDGMENT_CAP[stage]}")
                    if k == "sanctuary" and n < MIN_SANCTUARY:
                        problems.append(f"{name}: Sanctuary {n} under {MIN_SANCTUARY}")

                # Void prices below the generic curve: Siphon and Rift are paid
                # for out of the attack's base damage, because both scale in
                # play. Mirrors the budget VoidTest enforces -- kept here too so
                # a bad card is caught at authoring time rather than by the
                # harness three steps later.
                rift_n = dict(kws).get("rift", 0)
                attacks = []
                for ln in lines:
                    atk = {"id": ln["id"], "name": ln["name"]}
                    if ln["_ability"]:
                        atk["ability"] = True
                        if ln["_consume"]:
                            atk["consume"] = ln["_consume"]
                        atk["cost"] = {}
                    else:
                        atk["cost"] = {ENERGY_KEY[faction]:
                                       price(ln["damage"], stage, has_j)}
                    atk["damage"] = ln["damage"]
                    atk["text"] = ln["text"]
                    atk["effects"] = ln["effects"]
                    attacks.append(atk)

                    if faction == "void" and ln["damage"] > 0:
                        tc = sum(atk["cost"].values())
                        sn = next((e.get("n", 0) for e in ln["effects"]
                                   if e["op"] == "siphon"), 0)
                        if sn > 0:
                            budget = 10 * tc - 5 * sn
                        elif rift_n > 0:
                            budget = 10 * tc - 8 * rift_n
                        else:
                            budget = 12 * tc
                        if ln["damage"] > budget:
                            problems.append(
                                f"{name}/{ln['name']}: {ln['damage']} damage "
                                f"over Void budget {budget} (cost {tc})")

                cards.append({
                    "id": cid, "name": name, "type": "unit", "faction": faction,
                    "stage": stage, "hp": hp,
                    "retreat": max(1, hp // 40),
                    "evolves_from": prev_id,
                    "keywords": kw_list, "attacks": attacks, "flavor": flavor,
                })
                prev_id = cid
    return cards, problems


def main():
    ap = argparse.ArgumentParser()
    g = ap.add_mutually_exclusive_group(required=True)
    g.add_argument("--dry-run", action="store_true")
    g.add_argument("--apply", action="store_true")
    args = ap.parse_args()

    new, problems = build()
    data = json.loads(CARDS.read_text(encoding="utf-8"))
    existing = data["cards"]
    known = {c["id"] for c in existing}
    names = {c["name"] for c in existing}

    for c in new:
        if c["id"] in known:
            problems.append(f"{c['id']}: id already exists")
        if c["name"] in names:
            problems.append(f"{c['name']}: name already exists")

    ops = implemented_ops()
    for c in new:
        for a in c["attacks"]:
            for e in a["effects"]:
                if e["op"] not in ops:
                    problems.append(f"{c['name']}/{a['name']}: "
                                    f"op '{e['op']}' is not implemented")

    ids = [c["id"] for c in new]
    if len(set(ids)) != len(ids):
        problems.append("duplicate ids within the new roster")

    by_faction = {}
    for c in new:
        by_faction.setdefault(c["faction"], []).append(c)
    for faction in ("hel", "heaven", "void", "gaia"):
        fc = by_faction.get(faction, [])
        stages = {s: sum(1 for c in fc if c["stage"] == s)
                  for s in ("basic", "stage1", "stage2")}
        print(f"{faction:7} {len(fc):2} new   {stages}")
        for c in fc:
            costs = ",".join(
                str(sum(a["cost"].values())) if not a.get("ability") else "abil"
                for a in c["attacks"])
            ev = f" <- {c['evolves_from']}" if c["evolves_from"] else ""
            print(f"    {c['name']:16} {c['stage']:7} {c['hp']:3}hp "
                  f"toll/retreat {c['hp']//25}/{c['retreat']}  cost {costs}{ev}")
        print()

    print(f"{len(new)} new units")
    if problems:
        print("\nPROBLEMS:")
        for p in problems:
            print("  -", p)
        sys.exit(1)
    print("all constraint checks passed")

    if args.apply:
        data["cards"] = existing + new
        CARDS.write_text(json.dumps(data, indent=2, ensure_ascii=False) + "\n",
                         encoding="utf-8")
        print(f"wrote {CARDS.relative_to(ROOT)} -- now {len(data['cards'])} cards")
    else:
        print("(dry run -- nothing written)")


if __name__ == "__main__":
    main()
