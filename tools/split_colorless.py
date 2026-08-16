"""Split printed attack costs into a colored half and a colorless half.

    python tools/split_colorless.py --dry-run
    python tools/split_colorless.py --apply

Total cost NEVER changes -- this moves no balance number. What it decides is how
much of each cost stays *gated to the faction* when multi-color enforcement is
built. A cost of {"hel": 4} becoming {"hel": 2, "colorless": 2} means "any deck
splashing 2 Hel can run this", which is a real deckbuilding statement.

Lines that carry a faction's signature keyword stay pure: the colored
requirement is the identity, and diluting it would make Toll/Siphon/Earth
splashable at half price.

The split rule (decided in conversation 2026-08-16):

    total <= 3          pure colored
    signature keyword   pure colored
    total 4-5           N-1 colored + 1 colorless
    total 6+            ceil(N/2) colored + floor(N/2) colorless
"""
import argparse
import json
import math
import pathlib

CARDS = pathlib.Path(__file__).resolve().parent.parent / "data" / "cards.json"

# A line whose effects or text name one of these keeps a pure colored cost.
SIGNATURE_OPS = (
    "toll", "decay", "siphon", "void", "rift", "earth",
    "essence", "judgment", "sanctuary", "resist", "rise",
)


def is_signature(card, atk):
    """True when this CARD carries a signature keyword, or the line names one.

    Read at the CARD level, not the attack level. A signature keyword lives in
    the card's `keywords` array -- `grave_whelp` carries Toll and its attack
    "Gnaw" says nothing about Toll -- so inspecting only the attack's own
    effects and text found 7 lines where the rule means 188. That version would
    have diluted the colored requirement on nearly every Toll, Decay, Rise,
    Earth and Judgment body in the game, and no harness could have caught it
    because total cost never moves.
    """
    kws = {str(k.get("kw", "")).lower() for k in (card.get("keywords") or [])}
    if kws & set(SIGNATURE_OPS):
        return True
    for e in atk.get("effects") or []:
        op = str(e.get("op", "")).lower()
        if any(sig in op for sig in SIGNATURE_OPS):
            return True
    text = str(atk.get("text", "")).lower()
    return any(sig in text for sig in SIGNATURE_OPS)


def split(total):
    """(colored, colorless) for a given total cost."""
    if total <= 3:
        return total, 0
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

            if is_signature(card, atk):
                kept += 1
                continue

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
