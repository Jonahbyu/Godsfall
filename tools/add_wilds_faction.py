"""Add the Wilds faction to data/cards.json.

Wilds is the seventh colour: flesh, beasts, raw physicality, brute force --
nature as a threat, not a garden (that's Gaia). Its signatures are `Molt`
(when this unit would die, it is instantly replaced in the same slot by an
exact copy at full HP with all attached energy retained -- the copy loses
Molt, restored only by evolving) and `Ferocity N` (a per-unit stack counter
that grows N per FRIENDLY death on this unit's own board, additive into
+2 max HP / +1 damage per stack held, wiped on death unless answered by the
unit's own Molt).

See docs/specs/2026-08-19-wilds-faction-design.md for the design, including
the resolved Open Questions this generator builds against:
  * No separate damage-rate discount for either keyword -- HP-band (Molt)
    and death-scarcity (Ferocity) already pay for them once each.
  * Ferocity N by stage: 1 (Basic) / 2 (Stage 1) / 3 (one Stage 2).
  * A card printing BOTH keywords sits at the bottom of its (already
    reduced) Molt HP band.
  * No card ever prints both `Molt` and the shared `Rise` -- both claim
    "when this unit would die" and adjudicating a precedence rule is not
    worth it when nothing about either keyword's identity needs the other.

Like tools/add_tempest_faction.py this **enforces the design rules rather
than trusting the author**:

  * HP bands (Molt's own reduced bands, further reduced for the combo),
    the two-line rule, retreat = HP/40.
  * Ferocity only within its per-stage N, and every Ferocity body must
    carry something that reads its own stacks (the +HP/+damage grant is
    passive and implicit -- but a card claiming the keyword with nothing
    else going on is still checked for the vanilla-must-evolve rule).
  * Molt and Rise never coexist on one card.
  * Only ops the engine implements, PLUS the planned Wilds ops -- and
    --apply is refused while any planned op is still missing, so
    unplayable cards can never reach cards.json.

Run:  python tools/add_wilds_faction.py --dry-run    # then --apply
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

# No discount, and no premium -- Wilds pays for its keywords in HP-band and
# death-scarcity, not in the attack curve. See the spec's Open Questions.
BASE_RATE = {"basic": 7, "stage1": 8, "stage2": 9}

BAND = {"basic": (1, 6), "stage1": (4, 10), "stage2": (8, 20)}
HP_BAND = {"basic": (40, 90), "stage1": (80, 120), "stage2": (110, 175)}

# Molt trades a smaller printed body for a guaranteed second life, the same
# house style as Judgment (-1/3 rate) and Sanctuary (-18% rate) paying for
# their keyword in the stat line instead of as a free addition.
MOLT_HP_BAND = {"basic": (30, 60), "stage1": (60, 95), "stage2": (90, 140)}

# A card printing BOTH signatures sits at the very bottom of its Molt band --
# it is strictly stronger than either keyword alone (immortal-feeling body
# that only gets angrier) and must never also be printed at the top of it.
MOLT_FEROCITY_HP_BAND = {
    "basic": (30, 35), "stage1": (60, 68), "stage2": (90, 100),
}

# Ferocity N by stage -- not a band, a pinned value. See Open Questions:
# bounded by board size (2-3 slots) and mean game length (~9.5 rounds), so a
# real game plausibly feeds single digits to low teens of stacks. N above 3
# would make the keyword swingy rather than steady, and nothing needs it.
FEROCITY_N = {"basic": 1, "stage1": 2, "stage2": 3}

# Only six lines in the whole game sit in the round-1 window of cost 1-2.
# Wilds adds none of them.
MAX_NEW_OPENER_COST = 3

# The ops this faction needs. None are built yet -- the engine work is
# listed in the spec's "Engine Cost" table. Declared here so the generator
# can tell "planned but missing" apart from "typo", and so --apply stays
# refused until the engine catches up.
PLANNED_OPS = {
    "molt",              # the death-interception + full-HP/energy replacement
    "ferocity_gain",     # grow this unit's stack counter by N per friendly
                          # death on its own board (the passive trigger)
    "ferocity_bonus",    # the +2 HP / +1 damage per stack the counter grants
                          # while held -- declared even though it is meant to
                          # be implicit/always-on, so the keyword's payoff is
                          # a real op the engine can point to rather than a
                          # bonus with no name
}

# `molt` and `ferocity_gain`/`ferocity_bonus` are declared on the KEYWORD,
# not as attack/ability effects the way Charge or Stoke are -- Molt has no
# activation (it fires on death) and Ferocity's growth is passive (it fires
# on ANY friendly death on the board, not on something this card does). So
# neither needs a "spender" op the way Charge needs Discharge: the keyword
# IS the mechanic. This is a deliberate difference from Tempest/Forge's
# ability-based signatures, not an oversight -- see the design spec's
# Engine Cost table, which routes both through GameState's death-resolution
# path and Unit's keyword-value accessors rather than through use_ability()
# or queue_attack().


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
    rate = BASE_RATE[stage]
    c = max(1, round(damage / rate))
    return max(lo, min(hi, c))


def split_colorless(total, colour="wilds"):
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
# Wilds energy.

ENERGY = {
    "id": "wilds_energy",
    "name": "Rawhide",
    "type": "energy",
    "faction": "wilds",
    "flavor": "Something out there is still breathing.",
}


# ---------------------------------------------------------------------------
# The roster.
#
# Naming follows the bestiary system: a chain shares a stem, the suffix
# escalates with age, and the suffix pool is PER FACTION so a name places
# its own colour. Wilds' sound is guttural and physical -- short, hard
# vowels, nothing ringing (that's Heaven) and nothing sibilant (that's
# Tempest).
#
#   Basic:   -grub  -runt  -cub
#   Stage 1: -maw   -hide  -fang
#   Stage 2: -brute -warden -ravager
#
# Six chains, one idea each, the same discipline the Tempest/Hel starter
# decks used. Each chain owns a distinct piece of the design so the faction
# reads as six plans rather than six piles of the same card.

CHAINS = [
    # ("Stem", [(suffix, stage, hp, keywords, lines, flavor), ...])

    # 1. The reference chain. Molt alone -- the keyword's clean teach, no
    #    Ferocity muddying the read. Ordinary damage on a reduced body.
    ("Grum", [
        ("grub", "basic", 40, KW(molt=1), [
            A("grum_gnash", "Gnash", 19, "19 damage."),
            AB("grum_shrug", "Shrug It Off",
               "This unit heals 10.",
               [{"op": "heal", "n": 10}]),
        ], "It has died before. It did not think it was worth mentioning."),
        ("maw", "stage1", 78, KW(molt=1), [
            A("grum_rend", "Rend", 44, "44 damage."),
            AB("grum_shake", "Shake It Off",
               "This unit heals 18.",
               [{"op": "heal", "n": 18}]),
        ], "Whatever took the last one off didn't take enough."),
        ("brute", "stage2", 118, KW(molt=1), [
            A("grum_maul", "Maul", 88, "88 damage."),
            AB("grum_stand", "Stand Back Up",
               "This unit heals 30.",
               [{"op": "heal", "n": 30}]),
        ], "It has stopped counting. There is no longer a number to keep."),
    ]),

    # 2. The reference chain for Ferocity alone -- no Molt, so a dead one is
    #    actually dead. The chain that teaches the counter reads clean.
    ("Snarl", [
        ("cub", "basic", 46, KW(ferocity=1), [
            A("snarl_bite", "Bite", 20, "20 damage."),
            AB("snarl_watch", "Watch the Pack",
               "Passive: gains Ferocity stacks when a friendly unit on this "
               "board dies.",
               [{"op": "ferocity_gain", "n": 1},
                {"op": "ferocity_bonus", "n": 1}]),
        ], "It has learned to count the ones that don't get back up."),
        ("hide", "stage1", 90, KW(ferocity=2), [
            A("snarl_savage", "Savage", 46, "46 damage."),
            AB("snarl_circle", "Circle the Kill",
               "Passive: gains Ferocity stacks when a friendly unit on this "
               "board dies.",
               [{"op": "ferocity_gain", "n": 2},
                {"op": "ferocity_bonus", "n": 2}]),
        ], "Every body on the ground makes the next fight shorter."),
        ("ravager", "stage2", 145, KW(ferocity=3), [
            A("snarl_rampage", "Rampage", 100, "100 damage."),
            AB("snarl_gorge", "Gorge",
               "Passive: gains Ferocity stacks when a friendly unit on this "
               "board dies.",
               [{"op": "ferocity_gain", "n": 3},
                {"op": "ferocity_bonus", "n": 3}]),
        ], "It stopped being hungry a long time ago. It kept the habit."),
    ]),

    # 3. The combo build-around. Both signatures at once, at the reduced
    #    Molt+Ferocity band -- the card the spec's carve-out exists for.
    ("Thrash", [
        ("runt", "basic", 32, KW(molt=1, ferocity=1), [
            A("thrash_snap", "Snap", 18, "18 damage."),
            AB("thrash_bristle", "Bristle",
               "Passive: gains Ferocity stacks when a friendly unit on this "
               "board dies.",
               [{"op": "ferocity_gain", "n": 1},
                {"op": "ferocity_bonus", "n": 1}]),
        ], "Small enough to lose, angry enough that losing it costs you."),
        ("fang", "stage1", 65, KW(molt=1, ferocity=2), [
            A("thrash_gore", "Gore", 32, "32 damage."),
            AB("thrash_rally", "Rally the Wound",
               "Passive: gains Ferocity stacks when a friendly unit on this "
               "board dies.",
               [{"op": "ferocity_gain", "n": 2},
                {"op": "ferocity_bonus", "n": 2}]),
        ], "It has been dying and getting up the whole fight. It is furious "
           "about it."),
        ("warden", "stage2", 96, KW(molt=1, ferocity=3), [
            A("thrash_unmake", "Unmake", 58,
              "58 damage, plus 1 per Ferocity stack held.",
              [{"op": "ferocity_bonus", "n": 3}]),
            AB("thrash_endure", "Endure the Field",
               "Passive: gains Ferocity stacks when a friendly unit on this "
               "board dies.",
               [{"op": "ferocity_gain", "n": 3},
                {"op": "ferocity_bonus", "n": 3}]),
        ], "It never really died. That is the whole design of it."),
    ]),

    # 4. The fodder chain. Cheap, disposable, no Molt (a self-Molting token
    #    would contradict its own job) -- exists to die in front of chain 2
    #    and chain 3's Ferocity trackers. Two Basics, nowhere further to go,
    #    each carrying `Retribution` as a printed keyword rather than an
    #    attack rider -- it bites back once before it goes down, which is
    #    what makes trading into it a real cost rather than a free kill.
    ("Whelp", [
        ("grub", "basic", 42, KW(retribution=12), [
            A("whelp_scratch", "Scratch", 19, "19 damage."),
            A("whelp_snap", "Snap and Run", 24, "24 damage."),
        ], "Small, quick, and entirely spent the moment it matters."),
        ("runt", "basic", 44, KW(retribution=14), [
            A("whelp_nip", "Nip", 19, "19 damage."),
            A("whelp_flail", "Flail", 26, "26 damage."),
        ], "It was never going to be the one that lived."),
    ]),

    # 5. The vanilla-into-keyword chain, satisfying the standing rule that a
    #    keyword-less Basic must evolve into a body that carries one. Plain
    #    stats up front, Ferocity on arrival at Stage 1.
    ("Boar", [
        ("grub", "basic", 58, [], [
            A("boar_headbutt", "Headbutt", 26, "26 damage."),
            A("boar_trample", "Trample", 34, "34 damage."),
        ], "Nothing clever. It has not needed to be, yet."),
        ("hide", "stage1", 104, KW(ferocity=2), [
            A("boar_gore", "Gore", 42, "42 damage."),
            AB("boar_low", "Lower the Head",
               "Passive: gains Ferocity stacks when a friendly unit on this "
               "board dies.",
               [{"op": "ferocity_gain", "n": 2},
                {"op": "ferocity_bonus", "n": 2}]),
        ], "It has started noticing who doesn't get up."),
    ]),

    # 6. The Molt utility chain. Molt plus a rider that reads the return
    #    itself rather than just banking HP back -- the chain that shows
    #    Molt is a moment a card can build around, not only a safety net.
    ("Scarl", [
        ("cub", "basic", 36, KW(molt=1), [
            A("scarl_claw", "Claw", 19, "19 damage."),
            AB("scarl_thicken", "Thicken the Hide",
               "The next time this unit would die and Molt, the copy gains "
               "Resist 5 until end of turn.",
               [{"op": "molt"}]),
        ], "The scars come back with it, every time, a little thicker."),
        ("fang", "stage1", 70, KW(molt=1), [
            A("scarl_rip", "Rip", 38, "38 damage."),
            AB("scarl_harden", "Harden the Hide",
               "The next time this unit would die and Molt, the copy gains "
               "Resist 8 until end of turn.",
               [{"op": "molt"}]),
        ], "It is not healing wrong. It is healing like this on purpose."),
    ]),
]


# ---------------------------------------------------------------------------
# Supports.
#
# Wilds-locked, following the precedent forge.md and tempest.md established:
# a faction support is bought with a deckbuilding commitment, a cost the 43
# neutral supports never pay. Kept small -- the faction's identity lives on
# its bodies.

SUPPORTS = [
    {
        "id": "wilds_second_skin",
        "name": "Second Skin",
        "type": "support",
        "faction": "wilds",
        "cost": 0,
        "text": "A unit you control gains Molt if it does not already have it, "
                "until it next dies or evolves.",
        "effects": [{"op": "molt"}],
        "flavor": "Borrowed, not printed. It still counts.",
    },
    {
        "id": "wilds_cull_the_weak",
        "name": "Cull the Weak",
        "type": "support",
        "faction": "wilds",
        "cost": 1,
        "text": "Destroy a friendly unit with 40 HP or less. A unit you "
                "control with Ferocity gains stacks as if it had died there.",
        "effects": [{"op": "ferocity_gain", "n": 1}],
        "flavor": "The pack does not mourn. The pack recalculates.",
    },
    {
        "id": "wilds_trophy_rack",
        "name": "Trophy Rack",
        "type": "tool",
        "faction": "wilds",
        "text": "This unit gains Ferocity stacks whenever ANY unit -- yours "
                "or the opponent's -- dies on either of your boards.",
        "effects": [{"op": "ferocity_gain", "n": 1}],
        "flavor": "It does not care whose kill it was. It only counts.",
    },
]


def build():
    """Assemble every Wilds card, validating as we go. Raises on any breach."""
    ops = implemented_ops() | PLANNED_OPS
    out = [ENERGY]
    problems = []

    for stem, forms in CHAINS:
        prev_id = None
        for form in forms:
            suffix, stage, hp, kws, lines, flavor = form
            cid = f"wilds_{stem.lower()}{suffix}"
            name = f"{stem}{suffix}"

            kwmap = {k["kw"]: k["n"] for k in kws}
            has_molt = "molt" in kwmap
            has_ferocity = "ferocity" in kwmap

            if has_molt and has_ferocity:
                lo, hi = MOLT_FEROCITY_HP_BAND[stage]
            elif has_molt:
                lo, hi = MOLT_HP_BAND[stage]
            else:
                lo, hi = HP_BAND[stage]
            if not lo <= hp <= hi:
                problems.append(f"{name}: HP {hp} outside band {lo}-{hi}")

            if len(lines) > 2:
                problems.append(f"{name}: {len(lines)} lines breaks the two-line rule")

            if has_molt and "rise" in kwmap:
                problems.append(f"{name}: Molt and Rise never coexist on one card")

            if has_ferocity:
                expected = FEROCITY_N[stage]
                if kwmap["ferocity"] != expected:
                    problems.append(
                        f"{name}: Ferocity {kwmap['ferocity']} does not match the "
                        f"pinned {stage} value of {expected}")

            attacks = []
            has_kw = bool(kws)
            grants_ferocity_bonus = False

            for ln in lines:
                entry = {"id": ln["id"], "name": ln["name"],
                         "damage": ln["damage"], "text": ln["text"]}
                if ln["effects"]:
                    entry["effects"] = ln["effects"]

                for e in ln["effects"]:
                    op = e.get("op", "")
                    if op not in ops:
                        problems.append(f"{name}/{ln['name']}: op '{op}' is not implemented")
                    if op == "ferocity_bonus":
                        grants_ferocity_bonus = True

                if ln["_kind"] == "ability":
                    entry["ability"] = True
                    if ln["_consume"]:
                        entry["consume"] = ln["_consume"]
                else:
                    total = ln["_cost"] or cost_for(stage, ln["damage"])
                    if stage == "basic" and total < MAX_NEW_OPENER_COST:
                        problems.append(
                            f"{name}/{ln['name']}: cost {total} is a new round-1 opener")
                    entry["cost"] = split_colorless(total)
                attacks.append(entry)

            # A Ferocity body with no line granting its own bonus is dead
            # data -- the counter would grow and never pay out. (The bonus
            # is meant to be an always-on read of the stack count once the
            # engine ships it; requiring the op on a line keeps the card
            # data honest about which bodies actually claim the payout.)
            if has_ferocity and not grants_ferocity_bonus:
                problems.append(
                    f"{name}: prints Ferocity {kwmap['ferocity']} but no line "
                    f"grants ferocity_bonus")
            # A keyword-less Basic must evolve into one that carries something.
            if not has_kw and stage == "basic" and len(forms) == 1:
                problems.append(f"{name}: vanilla Basic with nowhere to evolve")

            card = {
                "id": cid, "name": name, "type": "unit", "faction": "wilds",
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
    print(f"Wilds: {len(cards)} cards -- {len(units)} units, "
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
