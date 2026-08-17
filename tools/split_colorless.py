"""Split printed attack costs into a colored half and a colorless half.

    python tools/split_colorless.py --dry-run
    python tools/split_colorless.py --apply

Total cost NEVER changes -- this moves no balance number. What it decides is how
much of each cost stays *gated to the faction* when multi-color enforcement is
built. A cost of {"hel": 4} becoming {"hel": 2, "colorless": 2} means "any deck
splashing 2 Hel can run this", which is a real deckbuilding statement.

The split rule (decided in conversation 2026-08-16):

    total <= 2          pure colored -- the round-1 openers
    total 3-5           N-1 colored + 1 colorless
    total 6+            ceil(N/2) colored + floor(N/2) colorless

Cost is the only input. Keyword-based protection was tried first and abandoned;
see split() for why.
"""
import argparse
import json
import math
import pathlib

CARDS = pathlib.Path(__file__).resolve().parent.parent / "data" / "cards.json"

# Keeping a keyword pure was tried and abandoned -- see the note in split().
# Kept only as the list of what "signature" would have meant.
SIGNATURE_OPS = (
    "toll", "decay", "siphon", "void", "rift", "earth",
    "essence", "judgment", "sanctuary", "resist", "rise",
)


def split(total):
    """(colored, colorless) for a given total cost.

    Cost is the ONLY input. An earlier version kept any line on a card carrying a
    signature keyword at a pure colored cost, on the theory that the colored
    requirement is the faction's identity and a splashable Toll or Siphon would
    let any deck rent a mechanic.

    That was wrong, and the data says why: those keywords are the BASELINE, not a
    scarce identity. Toll is on 47 attack lines, Earth on 46, Judgment on 30 --
    so "protect the signature" protected 194 of 230 lines and left Heaven with 7
    mixed costs out of 57. Every Judgment Basic in the game printed a pure
    `{"heaven": 4}`, which is the opposite of a card pool built for splashing.

    A keyword that appears on most of a faction's cards is not what distinguishes
    a deck; the faction's ENERGY is. Gating identity therefore belongs in the
    colored half's SIZE -- a 6-cost line still demands 3 of its own colour, which
    is a real requirement -- rather than in refusing to print colorless at all.
    """
    if total <= 2:
        return total, 0          # round-1 openers stay pure; 1 colorless of 2 is noise
    if total <= 5:
        return total - 1, 1
    return math.ceil(total / 2), total // 2


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--apply", action="store_true")
    ap.add_argument("--dry-run", action="store_true")
    args = ap.parse_args()
    if not args.apply and not args.dry_run:
        ap.error("pass --dry-run or --apply")

    data = json.loads(CARDS.read_text(encoding="utf-8"))
    changed = kept = 0
    violations = []

    for card in data["cards"]:
        if card.get("type") != "unit":
            continue
        for atk in card.get("attacks") or []:
            if atk.get("ability"):
                continue
            cost = atk.get("cost") or {}
            colors = [k for k in cost if k != "colorless" and int(cost[k] or 0) > 0]
            if len(colors) != 1:
                continue
            key = colors[0]
            total = int(cost[key]) + int(cost.get("colorless", 0) or 0)

            ## A cost that ALREADY prints colorless was authored deliberately;
            ## leave it exactly as it is. Re-deriving it collapsed
            ## carrion_crawler's {hel:1, colorless:1} back into a pure 2 Hel,
            ## which is the script undoing an author's decision rather than
            ## making one.
            if int(cost.get("colorless", 0) or 0) > 0:
                kept += 1
                continue

            colored, colorless = split(total)

            # The invariant this whole script rests on.
            if colored + colorless != total:
                violations.append((card["id"], atk.get("name"), total,
                                   colored, colorless))
                continue

            if (colored == int(cost[key])
                    and colorless == int(cost.get("colorless", 0) or 0)):
                kept += 1
                continue

            print("%-24s %-20s %2d %-9s -> %d %s + %d colorless"
                  % (card["id"], atk.get("name", "?"), total, key,
                     colored, key, colorless))
            atk["cost"] = {key: colored, "colorless": colorless}
            changed += 1

    print("\n%d lines split, %d left pure" % (changed, kept))

    if violations:
        print("\nABORT -- %d lines would change total cost:" % len(violations))
        for v in violations:
            print("  ", v)
        raise SystemExit(1)

    if args.apply:
        CARDS.write_text(json.dumps(data, indent=1, ensure_ascii=False) + "\n",
                         encoding="utf-8")
        print("written to %s" % CARDS)


if __name__ == "__main__":
    main()
