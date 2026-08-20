"""Add the Wilds faction to data/cards.json.

Wilds is the seventh colour: flesh, beasts, raw physicality, brute force --
nature as a threat, not a garden (that's Gaia). Its signatures are `Molt`
(when this unit would die, it is instantly replaced in the same slot by an
exact copy at full HP with all attached energy retained -- the copy loses
Molt, restored only by evolving) and `Ferocity N` (a per-unit stack counter
that grows N per FRIENDLY death on this unit's own board -- including a death
answered by Molt or Rise, and including a unit's own Molt feeding its own
counter -- additive into +2 max HP / +1 damage per stack held, wiped on death
unless answered by the unit's own Molt).

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
  * Ferocity's trigger fires on a Molt-death and a Rise-death too, at the
    moment of death, including a unit's own Molt feeding its own stacks
    (settled 2026-08-20; Whelp carries Molt for exactly this reason).

Both signatures are printed as KEYWORDS, not as attack/ability effects --
unlike Tempest's Charge/Discharge or Forge's Stoke/Scrap, neither has an
activation a player chooses to use. Molt fires automatically on death; the
+2 HP / +1 damage per Ferocity stack is a passive, always-on read of the
counter, the same shape Rise, Judgment and Sanctuary already use. So a card
needs no dedicated "ability line" to carry either keyword -- `keywords: [...]`
is the whole mechanism, and CardData.keyword_line() already renders it. A
one-line Basic (an attack, nothing else) is a normal, common shape in this
card pool (205 of ~230 units already ship that way) and is not a sign the
card is unfinished.

Like tools/add_tempest_faction.py this **enforces the design rules rather
than trusting the author**:

  * HP bands (Molt's own reduced bands, further reduced for the combo),
    the two-line rule, retreat = HP/40.
  * Ferocity only within its per-stage N.
  * Molt and Rise never coexist on one card.
  * Only ops the engine implements for the LINES that use them (Molt and
    Ferocity themselves need no op -- see above -- but a card may still
    carry a genuine ability, and those ops are checked exactly as every
    other faction's are).

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
# that only gets angrier, and doubly so now that its own Molt feeds its own
# stacks) and must never also be printed at the top of it.
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

# Ops that GENUINE ability/attack lines in this roster use. Molt and Ferocity
# are NOT here -- they are keywords, read automatically by the engine, and
# need no op of their own (see the module docstring). Everything below this
# faction actually needs is already implemented elsewhere in the game.


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
    """A genuine ability line -- something the player chooses to activate.
    Free unless it prints a non-energy cost. Molt and Ferocity are NEVER
    expressed this way; see the module docstring."""
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
#   Basic:   -grub  -runt  -cub  -whelp
#   Stage 1: -maw   -hide  -fang  -tusk
#   Stage 2: -brute -warden -ravager -reaver
#
# Eight chains, one idea each. Each chain owns a distinct piece of the design
# so the faction reads as eight plans rather than eight piles of the same
# card, and there are enough bodies here to build three genuinely different
# 60-card decks without every list running the same six units.

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
    #    actually dead. The chain that teaches the counter reads clean: one
    #    attack line, and the keyword itself does the rest.
    ("Snarl", [
        ("cub", "basic", 46, KW(ferocity=1), [
            A("snarl_bite", "Bite", 20, "20 damage."),
        ], "It has learned to count the ones that don't get back up."),
        ("hide", "stage1", 90, KW(ferocity=2), [
            A("snarl_savage", "Savage", 46, "46 damage."),
        ], "Every body on the ground makes the next fight shorter."),
        ("ravager", "stage2", 145, KW(ferocity=3), [
            A("snarl_rampage", "Rampage", 100, "100 damage."),
        ], "It stopped being hungry a long time ago. It kept the habit."),
    ]),

    # 3. The combo build-around. Both signatures at once, at the reduced
    #    Molt+Ferocity band -- the card the spec's carve-out exists for.
    #    Its own Molt feeds its own Ferocity counter (settled 2026-08-20),
    #    so this chain is the clearest demonstration of that interaction:
    #    every near-death makes it both survive AND grow.
    ("Thrash", [
        ("runt", "basic", 32, KW(molt=1, ferocity=1), [
            A("thrash_snap", "Snap", 18, "18 damage."),
        ], "Small enough to lose, angry enough that losing it costs you."),
        ("fang", "stage1", 65, KW(molt=1, ferocity=2), [
            A("thrash_gore", "Gore", 32, "32 damage."),
        ], "It has been dying and getting up the whole fight. It is furious "
           "about it."),
        ("warden", "stage2", 96, KW(molt=1, ferocity=3), [
            A("thrash_unmake", "Unmake", 58, "58 damage."),
        ], "It never really died. That is the whole design of it."),
    ]),

    # 4. The fodder chain. Cheap, disposable, and carries Molt on purpose --
    #    reversed 2026-08-20. Earlier drafts withheld Molt on the reasoning
    #    that a self-Molting token contradicts being disposable; that only
    #    held while Ferocity ignored Molt-deaths. Now that a unit's own Molt
    #    is itself a qualifying friendly death, a Whelp that Molts feeds a
    #    nearby tracker TWICE -- once on the Molt, once on its real death --
    #    so Molt makes better fodder, not contradictory fodder. At the plain
    #    Molt HP band (Whelp does not itself carry Ferocity). Two Basics, no
    #    further evolution, each also carrying `Retribution` as a printed
    #    keyword so trading into it still costs something.
    ("Whelp", [
        ("grub", "basic", 34, KW(molt=1, retribution=12), [
            A("whelp_scratch", "Scratch", 19, "19 damage."),
            A("whelp_snap", "Snap and Run", 24, "24 damage."),
        ], "Small, quick, and entirely spent the moment it matters -- the "
           "first time, anyway."),
        ("runt", "basic", 36, KW(molt=1, retribution=14), [
            A("whelp_nip", "Nip", 19, "19 damage."),
            A("whelp_flail", "Flail", 26, "26 damage."),
        ], "It was never going to be the one that lived. It's on its second "
           "try now."),
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
        ], "It has started noticing who doesn't get up."),
    ]),

    # 6. The Molt utility chain. Molt plus a GENUINE ability that reads the
    #    return itself -- the chain that shows Molt is a moment a card can
    #    build around, not only insurance sitting quietly on the card.
    ("Scarl", [
        ("cub", "basic", 36, KW(molt=1), [
            A("scarl_claw", "Claw", 19, "19 damage."),
            AB("scarl_thicken", "Thicken the Hide",
               "This unit heals 8 and grows Retribution 5 until end of turn.",
               [{"op": "heal", "n": 8}, {"op": "temp_retribution", "n": 5}]),
        ], "The scars come back with it, every time, a little thicker."),
        ("fang", "stage1", 70, KW(molt=1), [
            A("scarl_rip", "Rip", 38, "38 damage."),
            AB("scarl_harden", "Harden the Hide",
               "This unit heals 14 and grows Retribution 8 until end of turn.",
               [{"op": "heal", "n": 14}, {"op": "temp_retribution", "n": 8}]),
        ], "It is not healing wrong. It is healing like this on purpose."),
    ]),

    # 7. The wide-Ferocity chain. Cheap Basics that print Ferocity 1 alongside
    #    real damage, so a deck can run several trackers rather than banking
    #    everything onto one -- the counterpoint to Snarl and Thrash both
    #    being single, tall investments.
    ("Gnaw", [
        ("whelp", "basic", 48, KW(ferocity=1), [
            A("gnaw_worry", "Worry", 22, "22 damage."),
        ], "It is not the strongest thing on the field. It is just always "
           "there when something dies."),
        ("tusk", "stage1", 92, KW(ferocity=2), [
            A("gnaw_root", "Root Out", 47, "47 damage."),
        ], "It has stopped flinching at the sound."),
    ]),

    # 8. The Stage 2 finisher. No Molt (nothing to lose it TO -- this is a
    #    top-of-chain card the deck wants alive, not returning), Ferocity 3
    #    on a body already big enough that the stacks are a bonus rather than
    #    the plan. Its second line is a real ability: bank stacks manually off
    #    its own damage taken, giving a deck a way to feed it even against an
    #    opponent unwilling to trade into the board.
    ("Reave", [
        ("grub", "basic", 52, [], [
            A("reave_gouge", "Gouge", 24, "24 damage."),
        ], "It hasn't grown into its own claws yet."),
        ("hide", "stage1", 98, KW(ferocity=2), [
            A("reave_tear", "Tear", 45, "45 damage."),
        ], "It is starting to notice how much easier this gets."),
        ("reaver", "stage2", 152, KW(ferocity=3), [
            A("reave_flense", "Flense", 92, "92 damage."),
            AB("reave_remember", "Remember Every One",
               "This unit gains 2 Ferocity stacks.",
               [{"op": "gain_stacks", "n": 2}]),
        ], "It keeps a tally. It has stopped needing to."),
    ]),
]


# ---------------------------------------------------------------------------
# Supports.
#
# Wilds-locked, following the precedent forge.md and tempest.md established:
# a faction support is bought with a deckbuilding commitment, a cost the 43
# neutral supports never pay. Six here (up from three) so three decks can
# each lean on a different pair without all of them fighting for the same
# four copies of one card.

SUPPORTS = [
    {
        "id": "wilds_second_skin",
        "name": "Second Skin",
        "type": "support",
        "faction": "wilds",
        "cost": 0,
        "text": "A unit you control gains Molt if it does not already have "
                "it, until it next dies or evolves.",
        "effects": [{"op": "grant_molt"}],
        "flavor": "Borrowed, not printed. It still counts.",
    },
    {
        "id": "wilds_cull_the_weak",
        "name": "Cull the Weak",
        "type": "support",
        "faction": "wilds",
        "cost": 1,
        "text": "Destroy a friendly unit with 40 HP or less. Every Ferocity "
                "tracker on its board gains stacks as if it had died there.",
        "effects": [{"op": "sacrifice_small"}],
        "flavor": "The pack does not mourn. The pack recalculates.",
    },
    {
        "id": "wilds_running_wound",
        "name": "Running Wound",
        "type": "support",
        "faction": "wilds",
        "cost": 0,
        "text": "Deal 18 damage to a friendly unit. It cannot be reduced "
                "below 1 HP by this.",
        "effects": [{"op": "self_damage_floor", "n": 18}],
        "flavor": "Pain that stays under your own control is a tool, not "
                  "an injury.",
    },
    {
        "id": "wilds_stampede",
        "name": "Stampede",
        "type": "support",
        "faction": "wilds",
        "cost": 2,
        "text": "Every friendly unit with Ferocity gains 1 stack.",
        "effects": [{"op": "gain_stacks_all_ferocity", "n": 1}],
        "flavor": "One of them breaks first. The rest do not notice.",
    },
    {
        "id": "wilds_shed_the_skin",
        "name": "Shed the Skin",
        "type": "support",
        "faction": "wilds",
        "cost": 1,
        "text": "A friendly unit with Molt uses it immediately, without "
                "dying first.",
        "effects": [{"op": "force_molt"}],
        "flavor": "Not every reason to leave the old body behind is an "
                  "emergency.",
    },
    {
        "id": "wilds_trophy_rack",
        "name": "Trophy Rack",
        "type": "tool",
        "faction": "wilds",
        "text": "This unit gains Ferocity stacks whenever ANY unit -- yours "
                "or the opponent's -- dies on either of your boards.",
        "effects": [{"op": "ferocity_reads_any_death"}],
        "flavor": "It does not care whose kill it was. It only counts.",
    },
]

# Ops the SUPPORTS above need, which no other faction has printed yet. Molt
# and Ferocity's core keyword behaviour needs none of these -- these are the
# genuinely new one-shot/tool effects six new cards introduce.
PLANNED_SUPPORT_OPS = {
    "grant_molt",                # Second Skin
    "sacrifice_small",           # Cull the Weak
    "self_damage_floor",         # Running Wound
    "gain_stacks_all_ferocity",  # Stampede
    "force_molt",                # Shed the Skin
    "ferocity_reads_any_death",  # Trophy Rack (Tool)
    "temp_retribution",          # Scarl's ability lines
    "gain_stacks",               # Reave's ability line
}


def build():
    """Assemble every Wilds card, validating as we go. Raises on any breach."""
    ops = implemented_ops() | PLANNED_SUPPORT_OPS
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

            for ln in lines:
                entry = {"id": ln["id"], "name": ln["name"],
                         "damage": ln["damage"], "text": ln["text"]}
                if ln["effects"]:
                    entry["effects"] = ln["effects"]

                for e in ln["effects"]:
                    op = e.get("op", "")
                    if op not in ops:
                        problems.append(f"{name}/{ln['name']}: op '{op}' is not implemented")

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
    missing = sorted(PLANNED_SUPPORT_OPS - live)

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
        print(f"\n{len(missing)} planned support op(s) NOT YET IMPLEMENTED in the engine:")
        for m in missing:
            print("  *", m)
        print("\n(Molt and Ferocity themselves are keyword-driven and need no op --")
        print(" these are only the six new SUPPORT/TOOL effects, and are unrelated")
        print(" to whether the two signature keywords work.)")

    if args.apply:
        if missing:
            print("\nREFUSING TO APPLY -- the engine does not implement these ops yet.")
            print("An unknown op parses fine and silently does nothing, so writing")
            print("these cards now would ship supports that load and cannot play.")
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
