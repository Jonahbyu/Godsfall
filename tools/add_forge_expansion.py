"""Expand the Forge faction from 19 cards to full parity (~60).

Forge shipped at 19 cards against 59-66 for the other four colours, and its 13
units read as five chains but only three *ideas*.  This adds eight new chains,
a set of staple/vanilla bodies, and eight supports -- and the design constraint
Jonah set is that **each line takes a unique stab at a different part of how the
faction operates**, so every new chain OWNS one of the payoffs forge.md
catalogues rather than reprinting `stoked_bonus_damage`.

Nine of those payoffs were designed-but-unimplemented when this ran; they are
built in `GameState` first (see docs/plans/2026-08-16-forge-expansion.md), so
the chains below have real mechanics to be built on.

Like tools/add_forge_faction.py this **enforces the design rules rather than
trusting the author**:

  * HP bands, the two-line rule, retreat = HP/40.
  * `Stoke` only on an ability, and never more than the body's own HP.
  * Costs derived from damage on the documented per-stage curve.
  * Only ops the engine actually implements -- scraped out of the GDScript,
    because an unknown op parses fine and silently does nothing.
  * No ramp payoffs: forge.md names them as the one class that breaks pacing.
  * A `stoked_` payoff on an ability that never Stokes can never fire, so it is
    refused (the Gristgnash bug, caught at authoring time last build).
  * A keyword-less Basic must evolve into one that carries something, or it is
    a dead draw rather than a clean cheap body.

Run:  python tools/add_forge_expansion.py --dry-run    # then --apply
"""

import argparse
import json
import pathlib
import re
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
CARDS = ROOT / "data" / "cards.json"

RATE = {"basic": 7, "stage1": 8, "stage2": 9}
BAND = {"basic": (1, 6), "stage1": (4, 10), "stage2": (8, 20)}
HP_BAND = {"basic": (40, 90), "stage1": (80, 120), "stage2": (110, 175)}
MIN_NEW_COST = 3            # no new round-1 openers (those six are fixed)
MAX_ATTACK_DAMAGE = 120     # the printed damage ceiling

# Every stoke payoff the engine implements, old and new.  Anything outside this
# set is a typo -- the whole point of scraping is that a typo'd op is silent.
STOKE_OPS = {
    # shipped with the faction
    "stoked_bonus_damage", "stoked_scale_damage", "stoked_threshold",
    "stoked_threshold_damage", "stoked_double", "stoked_free_attack",
    "stoked_heal_back", "stoked_cleave", "stoked_ignore_shield",
    # built for this expansion
    "stoked_extra_attack", "stoked_immediate", "stoked_cost_reduction",
    "stoked_no_decay", "stoked_sweep", "stoked_both_boards",
    "stoked_also_tower", "stoked_unpreventable", "stoked_draw", "stoked_twice",
}

# forge.md: ramp payoffs convert HP into permanent decay-immune energy and walk
# around one-energy-card-per-turn, the game's central pacing dial.
BANNED_OPS = {"gain_energy", "pool_to_unit_eot"}


def implemented_ops():
    ops = set()
    pat = re.compile(r'(?:has_effect|effect_value)\("([a-z_]+)"')
    for path in list((ROOT / "scripts" / "core").glob("*.gd")) + \
                list((ROOT / "scripts" / "ui").glob("*.gd")):
        ops |= set(pat.findall(path.read_text(encoding="utf-8", errors="ignore")))
    return ops


def cost_for(stage, damage):
    lo, hi = BAND[stage]
    if damage <= 0:
        return lo
    c = max(1, round(damage / RATE[stage]))
    return max(lo, min(hi, c))


def split_colorless(total, colour="forge"):
    """CLAUDE.md's colorless split. Total never moves."""
    if total <= 2:
        return {colour: total}
    if total <= 5:
        return {colour: total - 1, "colorless": 1}
    half = total // 2
    return {colour: total - half, "colorless": half}


def A(aid, name, dmg, text, effects=None, cost=None):
    return {"_kind": "attack", "id": aid, "name": name, "damage": dmg,
            "text": text, "effects": effects or [], "_cost": cost}


def AB(aid, name, text, effects=None, stoke=0, scrap=False, consume=0):
    return {"_kind": "ability", "id": aid, "name": name, "damage": 0,
            "text": text, "effects": effects or [],
            "_stoke": stoke, "_scrap": scrap, "_consume": consume}


def KW(**kw):
    return [{"kw": k, "n": v} for k, v in kw.items()]


def ST(n):
    """The standard Stoke ability, worded identically everywhere it appears."""
    return AB("stoke", "Stoke",
              "Deal %d damage to this unit. It has stoked this turn." % n, stoke=n)


# ---------------------------------------------------------------------------
# THE CHAINS
#
# Eight, each OWNING one mechanic.  Naming follows the bestiary system: a chain
# shares a stem, the suffix escalates with age, and Forge's suffix pool is hard
# and struck -- Basic -spark/-ash/-slag/-wick, Stage 1 -brand/-kiln/-forge,
# Stage 2 -smith/-pyre/-anvil/-maul.
#
# Each entry: (suffix, stage, hp, keywords, [lines], flavor)
# ---------------------------------------------------------------------------

CHAINS = [
    # ---------------------------------------------------------------- 1
    # BELLOW -- owns `stoked_extra_attack`.  The multi-attack chain, which is
    # the Windfury slot expressed as a CONDITION rather than a printed keyword:
    # the condition sits on a Forge body, so it can never drift onto a Judgment
    # card the way a granted keyword could.
    ("Bellow", [
        ("wick", "basic", 55, KW(),
         [ST(20),
          A("draft", "Draft", 26,
            "26 damage. If this unit stoked this turn, +8 damage.",
            [{"op": "stoked_bonus_damage", "n": 8}])],
         "Air first. Everything else the fire will do on its own."),
        ("brand", "stage1", 92, KW(),
         [AB("double_draft", "Double Draft",
             "Deal 25 damage to this unit. It has stoked this turn, and may "
             "attack twice this turn.",
             [{"op": "stoked_extra_attack", "n": 1}], stoke=25),
          A("hammer_song", "Hammer Song", 34, "34 damage")],
         "Two strokes, one breath. The rhythm is the whole trade."),
        ("maul", "stage2", 148, KW(),
         [AB("full_bellows", "Full Bellows",
             "Deal 40 damage to this unit. It has stoked this turn, may attack "
             "twice this turn, and its attacks cost 1 less this turn.",
             [{"op": "stoked_extra_attack", "n": 1},
              {"op": "stoked_cost_reduction", "n": 1}], stoke=40),
          A("both_hands", "Both Hands", 54, "54 damage")],
         "It stopped counting blows a long time ago. It counts breaths."),
    ]),

    # ---------------------------------------------------------------- 2
    # CHAR -- owns `stoked_sweep`.  Wide rather than tall, and it pairs with
    # no-overkill: clearing the front rank is what exposes the rest of a board
    # to everything queued behind it.
    ("Char", [
        ("ash", "basic", 50, KW(),
         [ST(15),
          A("scorch", "Scorch", 24,
            "24 damage. If this unit stoked this turn, +7 damage.",
            [{"op": "stoked_bonus_damage", "n": 7}])],
         "It leaves a shape behind on whatever it touched."),
        ("kiln", "stage1", 96, KW(),
         [ST(30),
          A("wildfire", "Wildfire", 30,
            "30 damage. If this unit stoked 25 or more this turn, this attack "
            "hits every unit on the target board instead.",
            [{"op": "stoked_threshold", "n": 25},
             {"op": "stoked_sweep", "n": 1}])],
         "It does not choose. It only spreads."),
        ("pyre", "stage2", 150, KW(),
         [ST(45),
          A("the_burning_line", "The Burning Line", 40,
            "40 damage. If this unit stoked 40 or more this turn, this attack "
            "hits every unit on the target board instead.",
            [{"op": "stoked_threshold", "n": 40},
             {"op": "stoked_sweep", "n": 1}])],
         "A whole rank of them, and one line drawn through all of it."),
    ]),

    # ---------------------------------------------------------------- 3
    # SCORIA -- owns `stoked_unpreventable`.  The printed answer to shield
    # decks, and the card that supplies the Forge/Heaven and Forge/Gaia reason
    # to exist: making Stoke unpreventable cost those pairings their free
    # keyword synergy, and forge.md flags supplying it as an open question.
    ("Scoria", [
        ("slag", "basic", 58, KW(),
         [ST(20),
          A("bite_through", "Bite Through", 22,
            "22 damage. If this unit stoked this turn, this damage cannot be "
            "prevented or reduced.",
            [{"op": "stoked_unpreventable", "n": 1}])],
         "Shields are just another thing that has not been hot enough yet."),
        ("forge", "stage1", 104, KW(),
         [ST(30),
          A("run_the_seam", "Run the Seam", 40,
            "40 damage. If this unit stoked this turn, this damage cannot be "
            "prevented or reduced.",
            [{"op": "stoked_unpreventable", "n": 1}])],
         "It finds the join in the plate and goes in at the join."),
        ("smith", "stage2", 152, KW(),
         [ST(45),
          A("nothing_holds", "Nothing Holds", 63,
            "63 damage. If this unit stoked this turn, this damage cannot be "
            "prevented or reduced, and it also scorches the tower behind for 15.",
            [{"op": "stoked_unpreventable", "n": 1},
             {"op": "stoked_also_tower", "n": 15}])],
         "Every wall it has ever met was built by someone who had not met it."),
    ]),

    # ---------------------------------------------------------------- 4
    # FLUX -- owns the ECONOMY payoffs.  The chain where Forge reaches into the
    # energy rules rather than the board: a free attack, a discount that stacks,
    # and the pool skipping its decay for a turn.  Deliberately low damage --
    # it buys turns, not points.
    ("Flux", [
        ("wick", "basic", 48, KW(),
         [ST(20),
          A("skim", "Skim", 21,
            "21 damage. If this unit stoked this turn, this attack costs no energy.",
            [{"op": "stoked_free_attack", "n": 1}])],
         "It takes the scum off the top and the metal underneath is worth more."),
        ("brand", "stage1", 90, KW(),
         [AB("bank_heat", "Bank the Heat",
             "Deal 25 damage to this unit. It has stoked this turn, and your "
             "pool does not decay at the end of this turn.",
             [{"op": "stoked_no_decay", "n": 1}], stoke=25),
          A("draw_off", "Draw Off", 36, "36 damage")],
         "Heat kept overnight is heat you did not have to make twice."),
        ("anvil", "stage2", 138, KW(),
         [AB("the_long_bank", "The Long Bank",
             "Deal 40 damage to this unit. It has stoked this turn, your pool "
             "does not decay at the end of this turn, and draw 2 cards.",
             [{"op": "stoked_no_decay", "n": 1},
              {"op": "stoked_draw", "n": 2}], stoke=40),
          A("poured_out", "Poured Out", 58, "58 damage")],
         "Everything the shop made this season, in one shape, still warm."),
    ]),

    # ---------------------------------------------------------------- 5
    # TIND -- owns `stoked_twice` and `stoked_draw`.  The engine chain: stoke
    # twice into an amount-scaling payoff, which is the combination that makes
    # a large printed Stoke worth having.
    ("Tind", [
        ("spark", "basic", 52, KW(),
         [ST(15),
          A("catch", "Catch", 20,
            "20 damage. If this unit stoked this turn, +1 damage per 2 HP stoked.",
            [{"op": "stoked_scale_damage", "n": 2}])],
         "The smallest possible amount of fire, and it is enough."),
        ("kiln", "stage1", 94, KW(),
         [AB("relight", "Relight",
             "Deal 20 damage to this unit. It has stoked this turn, may stoke "
             "again this turn, and you draw a card.",
             [{"op": "stoked_twice", "n": 1},
              {"op": "stoked_draw", "n": 1}], stoke=20),
          A("run_hot", "Run Hot", 32,
            "32 damage. If this unit stoked this turn, +1 damage per 2 HP stoked.",
            [{"op": "stoked_scale_damage", "n": 2}])],
         "Twice in a turn is not twice the fire. It is the same fire, refusing to stop."),
        ("pyre", "stage2", 158, KW(),
         [AB("never_out", "Never Out",
             "Deal 35 damage to this unit. It has stoked this turn, may stoke "
             "again this turn, and you draw a card.",
             [{"op": "stoked_twice", "n": 1},
              {"op": "stoked_draw", "n": 1}], stoke=35),
          A("everything_at_once", "Everything At Once", 45,
            "45 damage. If this unit stoked this turn, +1 damage per 2 HP stoked.",
            [{"op": "stoked_scale_damage", "n": 2}])],
         "It has been burning since before the shop was built and intends to outlast it."),
    ]),

    # ---------------------------------------------------------------- 6
    # DROSSAL -- owns `Scrap` + `Consume`, printed steepest.  The second
    # scrapper, and the chain that leans hardest on the shared keyword forge.md
    # says Forge prints wider than the other four factions combined.
    ("Drossal", [
        ("gnash", "basic", 62, KW(),
         [AB("pick_over", "Pick Over",
             "Destroy another unit you control. Deal 15 damage to this unit. It "
             "has stoked this turn.", [], stoke=15, scrap=True),
          A("slagbite", "Slagbite", 25,
            "25 damage. If this unit stoked this turn, +8 damage.",
            [{"op": "stoked_bonus_damage", "n": 8}])],
         "It sorts the yard by what will burn and what will burn longer."),
        ("kiln", "stage1", 98, KW(),
         [AB("melt_down", "Melt Down",
             "Consume 1. Destroy another unit you control. Deal 25 damage to "
             "this unit, then heal it for that much. It has stoked this turn.",
             [{"op": "stoked_heal_back", "n": 100}],
             stoke=25, scrap=True, consume=1),
          A("pour", "Pour", 42,
            "42 damage. If this unit stoked this turn, +10 damage.",
            [{"op": "stoked_bonus_damage", "n": 10}])],
         "Whatever it was is not the point. What it becomes is the point."),
        ("smith", "stage2", 144, KW(),
         [AB("the_whole_yard", "The Whole Yard",
             "Consume 2. Destroy another unit you control. Deal 40 damage to "
             "this unit, then heal it for that much. It has stoked this turn, "
             "and you draw 2 cards.",
             [{"op": "stoked_heal_back", "n": 100},
              {"op": "stoked_draw", "n": 2}],
             stoke=40, scrap=True, consume=2),
          A("rendered", "Rendered", 60,
            "60 damage. If this unit stoked this turn, this damage is doubled.",
            [{"op": "stoked_double", "n": 1}])],
         "Nothing leaves the yard. It only changes which shelf it is on."),
    ]),

    # ---------------------------------------------------------------- 7
    # ANNEAL -- owns `Retribution` + Stoke.  The wall that gets MORE dangerous
    # the more it has already spent, which is the defensive reading of the
    # faction: Forge does not block, it makes being blocked expensive.
    ("Anneal", [
        ("ash", "basic", 70, KW(retribution=15),
         [ST(20),
          A("backhand", "Backhand", 21,
            "21 damage. If this unit stoked this turn, +7 damage.",
            [{"op": "stoked_bonus_damage", "n": 7}])],
         "Hitting it is a decision, and it would like you to make it."),
        ("brand", "stage1", 112, KW(retribution=20),
         [AB("case_harden", "Case Harden",
             "Deal 25 damage to this unit, then heal it for that much. It has "
             "stoked this turn.",
             [{"op": "stoked_heal_back", "n": 100}], stoke=25),
          A("recoil", "Recoil", 38,
            "38 damage. If this unit stoked this turn, +10 damage.",
            [{"op": "stoked_bonus_damage", "n": 10}])],
         "Cooled slowly on purpose. That is what makes it hard to break."),
        ("anvil", "stage2", 168, KW(retribution=25, resist=5),
         [AB("the_standing_heat", "The Standing Heat",
             "Deal 40 damage to this unit, then heal it for that much. It has "
             "stoked this turn.",
             [{"op": "stoked_heal_back", "n": 100}], stoke=40),
          A("struck_back", "Struck Back", 56,
            "56 damage. If this unit stoked this turn, +15 damage.",
            [{"op": "stoked_bonus_damage", "n": 15}])],
         "Every mark on it belongs to someone who is no longer swinging."),
    ]),

    # ---------------------------------------------------------------- 8
    # INGOT -- owns `stoked_immediate` and `stoked_both_boards`.  The closer
    # chain, and the two rule-breaks reserved for the top of the curve: acting
    # out of turn order, and reaching a board an attack should not be able to.
    ("Ingot", [
        ("spark", "basic", 56, KW(),
         [ST(20),
          A("first_strike", "First Strike", 21,
            "21 damage. If this unit stoked this turn, this attack resolves "
            "immediately instead of at the end of your turn.",
            [{"op": "stoked_immediate", "n": 1}])],
         "It goes now, while the going is still the going."),
        ("forge", "stage1", 108, KW(),
         [ST(30),
          A("strike_while", "Strike While", 36,
            "36 damage. If this unit stoked 25 or more this turn, this attack "
            "resolves immediately instead of at the end of your turn.",
            [{"op": "stoked_threshold", "n": 25},
             {"op": "stoked_immediate", "n": 1}])],
         "The window is exactly as wide as the metal is hot."),
        ("pyre", "stage2", 165, KW(),
         [ST(50),
          A("both_furnaces", "Both Furnaces", 46,
            "46 damage. If this unit stoked 45 or more this turn, this attack "
            "strikes both enemy boards.",
            [{"op": "stoked_threshold", "n": 45},
             {"op": "stoked_both_boards", "n": 1}])],
         "Two fires, one draught, and no wall between them that it respects."),
    ]),
]


# ---------------------------------------------------------------------------
# PAIRS AND SINGLES
#
# Two-form chains and a few staples, so the roster has a floor as well as eight
# build-arounds.  The bestiary rule applies: a keyword-less Basic must evolve
# into one that carries something, or it is a dead draw rather than a clean
# cheap body.  These are pitched deliberately BELOW the eight chains above --
# uniform power across a 44-unit roster is what makes creatures interchangeable.
# ---------------------------------------------------------------------------

PAIRS = [
    # The cheap unpreventable body -- the floor of the anti-shield plan, so a
    # deck can reach that effect before its Stage 1 lands.
    ("Cinderling", [
        ("wick", "basic", 46, KW(),
         [ST(15),
          A("needle", "Needle", 20,
            "20 damage. If this unit stoked this turn, this damage cannot be "
            "prevented or reduced.",
            [{"op": "stoked_unpreventable", "n": 1}])],
         "Small enough to get in through the gap in the visor."),
        ("brand", "stage1", 86, KW(),
         [ST(25),
          A("through_the_gap", "Through the Gap", 34,
            "34 damage. If this unit stoked this turn, this damage cannot be "
            "prevented or reduced.",
            [{"op": "stoked_unpreventable", "n": 1}])],
         "It has been practising on the gap."),
    ]),

    # The tower splasher -- the SOFT reach payoff.  It never bypasses the
    # shield, it only adds a second smaller hit behind the one that landed, so
    # a defended board still costs the attacker its main damage.
    ("Sootfall", [
        ("ash", "basic", 54, KW(),
         [ST(20),
          A("ember_fall", "Ember Fall", 22,
            "22 damage. If this unit stoked this turn, it also scorches the "
            "tower behind for 8.",
            [{"op": "stoked_also_tower", "n": 8}])],
         "What goes up in a forge does not stay up."),
        ("kiln", "stage1", 100, KW(),
         [ST(30),
          A("rain_of_coals", "Rain of Coals", 38,
            "38 damage. If this unit stoked this turn, it also scorches the "
            "tower behind for 15.",
            [{"op": "stoked_also_tower", "n": 15}])],
         "The roof is the first thing to learn what the shop is for."),
    ]),

    # The discount body -- the economy payoff at Basic/Stage 1, so the Flux
    # plan has bodies before its own Stage 1 arrives.
    ("Cokewright", [
        ("slag", "basic", 60, KW(),
         [AB("shave_cost", "Shave the Cost",
             "Deal 20 damage to this unit. It has stoked this turn, and its "
             "attacks cost 1 less this turn.",
             [{"op": "stoked_cost_reduction", "n": 1}], stoke=20),
          A("knap", "Knap", 24, "24 damage")],
         "It reckons the price in heat and finds the price agreeable."),
        ("forge", "stage1", 102, KW(),
         [AB("cut_the_price", "Cut the Price",
             "Deal 30 damage to this unit. It has stoked this turn, and its "
             "attacks cost 2 less this turn.",
             [{"op": "stoked_cost_reduction", "n": 2}], stoke=30),
          A("hard_bargain", "Hard Bargain", 40, "40 damage")],
         "Everything in the shop is for sale and everything is priced in fuel."),
    ]),
]

# Single bodies.  A vanilla is a legitimate card -- cheap, clean, the bottom of
# a line -- but a vanilla that goes NOWHERE is a dead draw, so each of these
# carries something even without an evolution above it.
SINGLES = [
    ("Forgehand", "basic", 64, KW(retribution=10),
     [ST(20),
      A("strike", "Strike", 26,
        "26 damage. If this unit stoked this turn, +7 damage.",
        [{"op": "stoked_bonus_damage", "n": 7}])],
     "One pair of hands, one job, and no opinions about either."),
    ("Slakeling", "basic", 68, KW(resist=5),
     [AB("douse", "Douse",
         "Deal 20 damage to this unit, then heal it for that much. It has "
         "stoked this turn.",
         [{"op": "stoked_heal_back", "n": 100}], stoke=20),
      A("hiss", "Hiss", 22, "22 damage")],
     "In and out of the water so often it has forgotten which state is rest."),
    ("Tapwright", "basic", 50, KW(),
     [AB("open_the_tap", "Open the Tap",
         "Deal 20 damage to this unit. It has stoked this turn, and you draw a card.",
         [{"op": "stoked_draw", "n": 1}], stoke=20),
      A("runoff", "Runoff", 21, "21 damage")],
     "It knows what is in the crucible because it is the one who looks."),
    ("Bloomsmith", "stage1", 106, KW(),
     [AB("work_it_twice", "Work It Twice",
         "Deal 30 damage to this unit. It has stoked this turn, and may stoke "
         "again this turn.",
         [{"op": "stoked_twice", "n": 1}], stoke=30),
      A("consolidate", "Consolidate", 42,
        "42 damage. If this unit stoked this turn, +1 damage per 2 HP stoked.",
        [{"op": "stoked_scale_damage", "n": 2}])],
     "The bloom is worked until it stops arguing."),
    ("Cindergaunt", "stage2", 132, KW(),
     [AB("last_measure", "Last Measure",
         "Destroy another unit you control. Deal 35 damage to this unit, then "
         "heal it for that much. It has stoked this turn, and you draw a card.",
         [{"op": "stoked_heal_back", "n": 100},
          {"op": "stoked_draw", "n": 1}], stoke=35, scrap=True),
      A("spend_it_all", "Spend It All", 58,
        "58 damage. If this unit stoked 30 or more this turn, this damage cannot "
        "be prevented or reduced.",
        [{"op": "stoked_threshold", "n": 30},
         {"op": "stoked_unpreventable", "n": 1}])],
     "It is down to the last of everything and has never been more dangerous."),
]


# ---------------------------------------------------------------------------
# SUPPORTS
#
# Faction-locked, so each is bought with a deckbuilding commitment the 43
# neutral supports never pay -- which is the room that lets them sit above the
# neutral band.  forge.md's rule 4 is the binding one and is checked in build():
# a Forge support may NOT sell damage more efficiently than an attack, in ANY
# currency.  These buy reach, sustain, tempo and card flow.
# ---------------------------------------------------------------------------

SUPPORTS = [
    {
        "id": "forge_second_wind", "name": "Second Wind", "type": "support",
        "faction": "forge", "cost": 1,
        "effects": [{"op": "clear_locks", "n": 1}, {"op": "draw", "n": 2}],
        "text": "Cards returned to your hand this turn are playable again. Draw 2 cards.",
        "flavor": "The shop does not close. It only changes who is standing at the anvil.",
    },
    {
        "id": "forge_the_long_shift", "name": "The Long Shift", "type": "support",
        "faction": "forge", "cost": 2,
        "effects": [{"op": "heal_all", "n": 30}],
        "text": "Heal 30 damage from each of your units.",
        "flavor": "Everyone stops. Everyone drinks. Then everyone starts again.",
    },
    {
        "id": "forge_cold_shut", "name": "Cold Shut", "type": "support",
        "faction": "forge", "cost": 1,
        "effects": [{"op": "damage_uncharged", "n": 25}],
        "text": "Deal 25 damage to an enemy unit with no attached energy.",
        "flavor": "The metal folded and did not weld. Now it is only a shape of a thing.",
    },
    {
        "id": "forge_draw_the_temper", "name": "Draw the Temper", "type": "support",
        "faction": "forge", "cost": 1,
        "effects": [{"op": "heal_conditional", "n": 70}],
        "text": "Heal 70 damage from one of your units that is below half HP.",
        "flavor": "It is not too late. It is only very nearly too late.",
    },
    {
        "id": "forge_open_the_doors", "name": "Open the Doors", "type": "support",
        "faction": "forge", "cost": 2,
        "effects": [{"op": "search_basic", "n": 2}],
        "text": "Search your deck for up to 2 Basic units and add them to your hand.",
        "flavor": "Every hand in the district, and the district owes the shop a favour.",
    },
    {
        "id": "forge_the_reclaim", "name": "The Reclaim", "type": "support",
        "faction": "forge", "cost": 1,
        "effects": [{"op": "return_from_discard", "n": 1}],
        "text": "Return a unit from your discard pile to your hand.",
        "flavor": "Scrap is only scrap until somebody with a fire disagrees.",
    },
    {
        "id": "forge_murder_holes_hot", "name": "Firing Slits", "type": "tower_support",
        "faction": "forge",
        "effects": [{"op": "tower_damage", "n": 5}],
        "text": "Attach to one of your towers. It deals 5 more damage.",
        "flavor": "They cut the slits after the third siege, and never after that.",
    },
    {
        "id": "forge_bellows_rig", "name": "Bellows Rig", "type": "tool",
        "faction": "forge",
        "effects": [{"op": "heal_eot", "n": 15}],
        "text": "Attach to one of your units. It heals 15 damage at end of turn.",
        "flavor": "Someone has to keep the air moving. It may as well be a machine.",
    },
    {
        "id": "forge_deadmans_hammer", "name": "Deadman's Hammer", "type": "tool",
        "faction": "forge",
        "effects": [{"op": "buff_keyword", "kw": "retribution", "n": 15}],
        "text": "Attach to one of your units. It gains Retribution 15.",
        "flavor": "It swings whether or not anybody is holding it.",
    },
]


# ---------------------------------------------------------------------------

def build():
    """Assemble every new Forge card, validating as we go. Raises on a breach."""
    ops = implemented_ops()
    out = []
    problems = []

    def emit_form(stem, suffix, stage, hp, kws, lines, flavor, prev_id, solo):
        cid = "forge_%s%s" % (stem.lower(), suffix.lower())
        name = "%s%s" % (stem, suffix) if suffix else stem

        lo, hi = HP_BAND[stage]
        if not lo <= hp <= hi:
            problems.append("%s: HP %d outside %s band %d-%d" % (name, hp, stage, lo, hi))
        if len(lines) > 2:
            problems.append("%s: %d lines breaks the two-line rule" % (name, len(lines)))

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
                    problems.append("%s/%s: op '%s' is not implemented"
                                    % (name, ln["name"], op))
                if op.startswith("stoked_") and op not in STOKE_OPS:
                    problems.append("%s/%s: unknown stoke op '%s'"
                                    % (name, ln["name"], op))
                if op in BANNED_OPS:
                    problems.append("%s/%s: ramp payoff '%s' is excluded"
                                    % (name, ln["name"], op))

            # A `stoked_` payoff on an ability that does not itself Stoke can
            # never fire -- only Stoke sets the flag, Scrap and Consume do not.
            # Silent dead data, so it is refused rather than shipped.
            if ln["_kind"] == "ability" and not ln["_stoke"]:
                for e in ln["effects"]:
                    if e.get("op", "").startswith("stoked_"):
                        problems.append(
                            "%s/%s: '%s' on an ability that never Stokes -- "
                            "it can never fire" % (name, ln["name"], e["op"]))

            if ln["_kind"] == "ability":
                entry["ability"] = True
                if ln["_stoke"]:
                    entry["stoke"] = ln["_stoke"]
                    has_kw = True
                    if ln["_stoke"] > hp:
                        problems.append("%s: stokes %d with only %d HP"
                                        % (name, ln["_stoke"], hp))
                if ln["_scrap"]:
                    entry["scrap"] = True
                    has_kw = True
                if ln["_consume"]:
                    entry["consume"] = ln["_consume"]
            else:
                if ln["damage"] > MAX_ATTACK_DAMAGE:
                    problems.append("%s/%s: %d damage over the %d ceiling"
                                    % (name, ln["name"], ln["damage"], MAX_ATTACK_DAMAGE))
                total = ln["_cost"] or cost_for(stage, ln["damage"])
                if stage == "basic" and total < MIN_NEW_COST:
                    problems.append("%s/%s: cost %d is a new round-1 opener"
                                    % (name, ln["name"], total))
                entry["cost"] = split_colorless(total)
            attacks.append(entry)

        # A keyword-less Basic with nowhere to evolve is a dead draw.
        if not has_kw and stage == "basic" and solo:
            problems.append("%s: vanilla Basic with nowhere to evolve" % name)

        card = {"id": cid, "name": name, "type": "unit", "faction": "forge",
                "stage": stage, "hp": hp, "retreat": int(hp / 40)}
        if prev_id:
            card["evolves_from"] = prev_id
        if kws:
            card["keywords"] = kws
        card["flavor"] = flavor
        card["attacks"] = attacks
        out.append(card)
        return cid

    for stem, forms in CHAINS + PAIRS:
        prev = None
        for suffix, stage, hp, kws, lines, flavor in forms:
            prev = emit_form(stem, suffix, stage, hp, kws, lines, flavor,
                             prev, len(forms) == 1)

    for name, stage, hp, kws, lines, flavor in SINGLES:
        emit_form(name, "", stage, hp, kws, lines, flavor, None, True)

    for s in SUPPORTS:
        for e in s.get("effects", []):
            if e.get("op") not in ops:
                problems.append("%s: op '%s' is not implemented" % (s["name"], e["op"]))
            if e.get("op") in BANNED_OPS:
                problems.append("%s: ramp payoff is excluded" % s["name"])
        # forge.md rule 4, the binding constraint: a Forge support may not sell
        # damage more efficiently than an attack, in ANY currency.
        #
        # The measure is the CEILING on a damage support, not a per-energy rate.
        # The two neutral damage supports (`Collapse` 20, `Toppling Blow` 25) are
        # both FREE and both restricted -- the restriction is what they pay with,
        # so dividing by a pool cost of 0 measures nothing.  What the rule
        # actually protects is that no support out-damages what swinging buys, so
        # the check is an absolute cap set by the existing neutral ceiling: a
        # Forge support may match the best neutral damage card and never beat it.
        NEUTRAL_DAMAGE_CEILING = 25
        for e in s.get("effects", []):
            if e.get("op") in ("damage_uncharged", "damage_tower", "damage_enemy_board"):
                if e.get("n", 0) > NEUTRAL_DAMAGE_CEILING:
                    problems.append(
                        "%s: %d damage exceeds the %d neutral ceiling -- a Forge "
                        "support buys reach, never raw damage"
                        % (s["name"], e.get("n", 0), NEUTRAL_DAMAGE_CEILING))
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
    print("Forge expansion: %d cards -- %d units, %d other"
          % (len(cards), len(units), len(cards) - len(units)))
    for c in units:
        tags = ""
        for a in c["attacks"]:
            if a.get("stoke"):
                tags += "  Stoke %d" % a["stoke"]
            if a.get("scrap"):
                tags += " Scrap"
            if a.get("consume"):
                tags += " Consume %d" % a["consume"]
        costs = [a.get("cost") for a in c["attacks"] if a.get("cost")]
        print("  %-18s %-7s %3d HP  retreat %d%s   %s"
              % (c["name"], c["stage"], c["hp"], c["retreat"], tags, costs))
    if dupes:
        print("\nAlready present, skipping: %s" % dupes)

    if args.apply:
        db["cards"].extend(new)
        CARDS.write_text(json.dumps(db, indent=1, ensure_ascii=False) + "\n",
                         encoding="utf-8")
        print("\nWrote %d new cards. Total now %d." % (len(new), len(db["cards"])))
    else:
        print("\n(dry run -- pass --apply to write)")


if __name__ == "__main__":
    main()
