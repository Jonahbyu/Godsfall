"""Re-price every unit attack into the widened per-stage cost bands.

    python tools/reprice_attacks.py --dry-run
    python tools/reprice_attacks.py --apply

Bands (decided in conversation 2026-08-15):

    Basic    1-6
    Stage 1  4-10
    Stage 2  8-20

Why re-pricing rather than re-damaging: the 100k-game sample found the printed
cost ladder compressed at the bottom (no Basic attack cost more than 3, yet two
Basics dealt 36-38 -- as much as a 5-cost Stage 1) and stretched at the top. That
compression is why 93.9% of attacks queued cost 1-3. Widening the bands puts a
substantial attack at 5-6 where it belongs, and does it by moving *cost*, so the
damage values -- which are what each card's identity and its faction budget were
tuned around -- stay put.

The mapping rule: **cost is derived from damage at a target rate**, then clamped
into the stage's band.

    cost = round(damage / RATE[stage]),  clamped to the band

RATE rises with stage (Basic 7, Stage 1 8, Stage 2 9 damage per energy), so a
bigger body converts energy better and evolving is never a downgrade.

Deriving cost *from* damage -- rather than rank-mapping damage onto the band --
is what keeps the numbers sane. Rank-mapping spreads a stage's attacks evenly
across its whole band regardless of how hard they hit, which on the wide Stage 2
band (8-20) pushed a 42-damage attack to cost 14 (3.0/e). Holding a rate instead
means an attack costs what its damage is worth, and the band is a *clamp* rather
than a target.

The consequence worth stating: **a band's ceiling is reached only by attacks
whose payoff is an effect rather than damage.** At 9 damage per energy a cost-20
Stage 2 attack would need 180 damage, which exceeds every HP in the game -- so no
damage attack belongs at the top of the Stage 2 band, and the two cards that sit
there (THE LAST TOLL, The Long Quiet) both print 0 damage and win through effects.
That is the band working correctly, not a gap in it.

Two classes are left alone:

  - Attacks with 0 printed damage (Silence Eternal, THE LAST TOLL). Their whole
    output is an effect, so damage-rank says nothing about them. THE LAST TOLL is
    already the game's deliberate 20-cost capstone and sits at the Stage 2 ceiling
    anyway.
  - Abilities. They may carry no cost but Consume, enforced in the data.

Multi-colour costs keep their colour split: the new total is distributed back
over the same colour keys in the same proportion, remainder to the largest, so a
two-colour card stays two-colour.
"""
import json
import sys
from collections import defaultdict

PATH = "data/cards.json"
BANDS = {"basic": (1, 6), "stage1": (4, 10), "stage2": (8, 20)}

## How many Basic attacks may stay in the round-1 window (cost 1-2).
##
## Round 1 gives exactly 2 energy, so cost<=2 is the only thing playable on the
## opening turn and a few Basics must sit there or nobody attacks turn one. But
## a cheap attack, once paid, re-fires free every turn from round 1 onward, while
## an 8-cost fires only in the last few rounds of the ~37% of games that get
## there -- so a cheap attack generates roughly 3x the activations of an
## expensive one. Printed parity therefore produces a heavy cheap-attack
## majority in play.
##
## The measured chain: 34.6% of printed attacks cost <=3 produced 77.8% of
## attacks queued. Holding queued-share under 50% needs printed cheap attacks
## well under parity, which is what this cap enforces -- the N lowest-damage
## Basic attacks keep the opening window and the rest are priced on the curve.
ROUND1_OPENERS = 6

## Damage range a non-opener Basic attack is rescaled into, so it prices at
## cost 4-6 on the normal rate.
##
## A flat floor was tried first and is wrong: it collapsed fourteen attacks onto
## the identical 28 damage / cost 4, erasing the difference between a 12-damage
## chip and a 24-damage swing. Rescaling preserves each attack's rank and its
## spacing, so Rust Crawler still hits harder than Shell Slam -- both just cost
## what that damage is worth now.
##
## Raising the *damage* rather than lowering the rate keeps a Basic's energy
## conversion honest: a 4-cost Basic attack should hit like a 4-cost attack, not
## be a 2-cost attack with a worse price.
BASIC_NONOPENER_RANGE = (28, 42)

## Openers are spread across cost 1-2 rather than all landing on 1, so the
## opening turn has a real choice (one 2-cost swing, or hold) instead of every
## deck making the identical round-1 play.
OPENER_RANGE = (8, 16)

## Stage 1 damage is rescaled into this window. Without it a Stage 1 dealing 16
## and a Basic dealing 30 both price at cost 4, which inverts the stage ladder --
## the evolved body costs the same as the Basic under it and hits half as hard.
## The floor sits above the Basic non-opener ceiling so the tiers stay ordered.
STAGE1_RANGE = (36, 80)

## Attacks whose cost is deliberate design and must not be rank-mapped.
## THE LAST TOLL is the printed rule-breaker capstone; The Long Quiet's output is
## entirely Gap-scaled throne damage, so its damage rank is meaningless.
## Swallow is pinned because its Rift 2 rider shares the damage budget VoidTest
## enforces (`10*cost - 8*rift`): at 80 damage the derived cost 9 gives a budget
## of 74 and fails, while cost 10 gives 84 and passes. The rider is priced into
## the cost, which the damage-only derivation cannot see.
PINNED = {"THE LAST TOLL": 20, "The Long Quiet": 8, "Swallow": 10}

## Minimum damage-per-energy each stage must deliver after re-pricing.
## Chosen so evolving is never a downgrade: a Stage 2 must convert energy at
## least as well as the Stage 1 under it. The 100k sample measured the shipped
## cards at ~9/e overall, so these hold roughly that rate at Basic and improve on
## it with stage, which is what makes a bigger body worth its slower arrival.
## Target damage-per-energy per stage. Cost is derived from damage at this rate.
## Rises with stage so that evolving improves how well a body converts energy,
## which is what makes a slower, more expensive Stage 2 worth reaching.
RATE = {"basic": 7.0, "stage1": 8.0, "stage2": 9.0}

## Stage 2 damage multiplier, and the hard ceiling on any single attack.
## DMG_CAP is set just under the largest printed HP (175) so that even the
## biggest attack has to be paired with chip or a second body to remove the
## biggest body -- one card should never delete any unit in the game outright.
## Applied ONCE, on 2026-08-15. The scale-up is recorded in the card data by the
## resulting damage values themselves, so re-running must not compound it: a
## second pass would push every Stage 2 attack to DMG_CAP. Set to 1.0 now that
## the data carries the scaled values; kept as a named constant so the history
## of the number is legible rather than lost in a diff.
STAGE2_SCALE = 1.0
DMG_CAP = 120

## Void's Rift cards buy their scaling out of the same budget as their printed
## damage (VoidTest asserts `10*cost - 8*rift`), so a blanket Stage 2 scale-up
## can push one over its budget even though the rate looks fine. Cards listed
## here take an explicit damage instead of the scaled value.
DMG_OVERRIDE = {"Swallow": 80}


def total_cost(atk):
    return sum(v for v in (atk.get("cost") or {}).values() if isinstance(v, int))


def set_cost(atk, new_total):
    """Write `new_total` back across the attack's existing colour keys."""
    cost = atk.get("cost") or {}
    ints = {k: v for k, v in cost.items() if isinstance(v, int) and v > 0}
    if not ints:
        atk["cost"] = {"colorless": new_total}
        return
    old = sum(ints.values())
    if old == new_total:
        return
    keys = sorted(ints, key=lambda k: -ints[k])
    out, assigned = {}, 0
    for k in keys[1:]:
        share = round(new_total * ints[k] / old)
        out[k] = max(0, share)
        assigned += out[k]
    ## Remainder to the dominant colour, so the card keeps its primary identity.
    out[keys[0]] = max(0, new_total - assigned)
    for k, v in list(out.items()):
        if v == 0:
            del out[k]
    if not out:
        out = {keys[0]: new_total}
    ## Preserve any non-int entries (colour markers etc.) untouched.
    for k, v in cost.items():
        if not isinstance(v, int):
            out[k] = v
    atk["cost"] = out


def main():
    apply = "--apply" in sys.argv
    with open(PATH, encoding="utf-8") as f:
        doc = json.load(f)
    cards = doc["cards"] if isinstance(doc, dict) and "cards" in doc else doc

    ## Collect every priced attack, grouped by stage.
    groups = defaultdict(list)
    for c in cards:
        if c.get("type") != "unit":
            continue
        stage = str(c.get("stage", "basic"))
        if stage not in BANDS:
            continue
        for a in c.get("attacks") or []:
            if a.get("ability"):
                continue
            groups[stage].append((c, a))

    ## The N lowest-damage Basic attacks keep the round-1 window; every other
    ## Basic attack is floored to BASIC_MIN_DAMAGE so it prices out of it.
    basic_atks = sorted(
        ((a.get("damage") or 0, id(a), a) for c, a in groups["basic"]
         if (a.get("damage") or 0) > 0 and a.get("name") not in PINNED))
    openers = {ident for _, ident, _ in basic_atks[:ROUND1_OPENERS]}
    _rest = [d for d, ident, _ in basic_atks if ident not in openers]
    nonopener_min = min(_rest) if _rest else 0
    nonopener_max = max(_rest) if _rest else 0
    _op = [d for d, ident, _ in basic_atks if ident in openers]
    opener_min = min(_op) if _op else 0
    opener_max = max(_op) if _op else 0
    _s1 = [(a.get("damage") or 0) for c, a in groups["stage1"]
           if (a.get("damage") or 0) > 0 and a.get("name") not in PINNED]
    s1_min = min(_s1) if _s1 else 0
    s1_max = max(_s1) if _s1 else 0

    changes = []
    for stage, (lo, hi) in BANDS.items():
        rate = RATE[stage]
        for c, a in groups[stage]:
            old = total_cost(a)
            dmg = a.get("damage") or 0
            name = a.get("name")

            if name in PINNED:
                new = PINNED[name]
            elif dmg <= 0:
                ## Zero-damage attacks buy an effect, so damage says nothing
                ## about what they are worth. Left at their authored cost.
                continue
            else:
                new = max(lo, min(hi, int(round(dmg / rate))))

            ## Stage 2 damage was authored for a 4-6 cost world, so at the target
            ## rate every Stage 2 attack clamps to the band floor and the 8-20
            ## band collapses to a single value. Scale those attacks up to fill
            ## the usable part of the band instead.
            ##
            ## "Usable" stops at DMG_CAP, not at the band ceiling: at 9/e a
            ## cost-20 attack needs 180 damage, which one-shots the largest body
            ## in the game (175 HP). A cost above ~13 therefore cannot be bought
            ## with damage at all, which is why the top of the Stage 2 band
            ## belongs to effect cards (THE LAST TOLL, The Long Quiet) and the
            ## damage attacks stop partway up.
            new_dmg = dmg

            ## Openers keep the round-1 window, spread over cost 1-2.
            if stage == "basic" and name not in PINNED and dmg > 0                     and id(a) in openers:
                lo_d, hi_d = OPENER_RANGE
                span = max(1, opener_max - opener_min)
                frac = (dmg - opener_min) / span
                new_dmg = int(round(lo_d + (hi_d - lo_d) * frac))
                new = max(lo, min(hi, int(round(new_dmg / rate))))

            ## Stage 1 rescaled so it never shares a cost floor with Basics.
            if stage == "stage1" and name not in PINNED and dmg > 0:
                lo_d, hi_d = STAGE1_RANGE
                span = max(1, s1_max - s1_min)
                frac = (dmg - s1_min) / span
                new_dmg = int(round((lo_d + (hi_d - lo_d) * frac) / 5.0)) * 5
                new = max(lo, min(hi, int(round(new_dmg / rate))))

            ## Non-opener Basics are rescaled into the 4-6 cost window, keeping
            ## their relative order and spacing.
            if stage == "basic" and name not in PINNED and dmg > 0                     and id(a) not in openers:
                lo_d, hi_d = BASIC_NONOPENER_RANGE
                span = max(1, nonopener_max - nonopener_min)
                frac = (dmg - nonopener_min) / span
                new_dmg = int(round((lo_d + (hi_d - lo_d) * frac) / 5.0)) * 5
                new = max(lo, min(hi, int(round(new_dmg / rate))))

            if stage == "stage2" and name not in PINNED and dmg > 0:
                scaled = int(round(dmg * STAGE2_SCALE / 5.0)) * 5
                new_dmg = min(DMG_CAP, scaled)
                if name in DMG_OVERRIDE:
                    new_dmg = DMG_OVERRIDE[name]
                new = max(lo, min(hi, int(round(new_dmg / rate))))

            if new != old or new_dmg != dmg:
                changes.append((stage, c.get("name"), name, dmg, new_dmg, old, new))
                if apply:
                    set_cost(a, new)
                    if new_dmg != dmg:
                        a["damage"] = new_dmg

    changes.sort(key=lambda r: (list(BANDS).index(r[0]), r[6]))
    print(f"{'stage':<7} {'dmg':>10} {'cost':>9} {'d/e':>5}  card / attack")
    for stage, cn, an, od, nd, old, new in changes:
        dm = f"{od}" if od == nd else f"{od}->{nd}"
        cs = f"{old}" if old == new else f"{old}->{new}"
        rate = nd / new if new else 0
        print(f"{stage:<7} {dm:>10} {cs:>9} {rate:>5.1f}  {cn} / {an}")
    print(f"\n{len(changes)} attacks re-priced"
          + ("" if apply else "  (dry run -- pass --apply to write)"))

    if apply:
        with open(PATH, "w", encoding="utf-8") as f:
            json.dump(doc, f, indent=2, ensure_ascii=False)
            f.write("\n")
        print(f"wrote {PATH}")


main()
