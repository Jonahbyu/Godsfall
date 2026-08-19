"""Re-price Sanctuary units' attack damage down to the rate the keyword is worth.

Sanctuary buys effective HP: measured across the pool a Sanctuary body carries
1.5-1.9x the effective HP of a plain one at the same stage, and pays for it in
NOTHING -- it hits 2-22% harder than plain units, not softer. `Judgment` takes a
documented one-third rate cut for a comparable (smaller) benefit; Sanctuary takes
none, which is why the Sanctuary ladder deck measured 89-91% over 2M games.

This applies a flat -18% to the damage of attacks on units printing Sanctuary and
LEAVES THE COST ALONE. Re-deriving cost from the reduced damage was the first
attempt and it is self-defeating: it lowers the price in step with the damage, so
the rate is unchanged and the card is merely smaller. The keyword has to make the
body pay a WORSE rate, exactly as Judgment does -- same cost, less damage.

  python tools/reprice_sanctuary.py --dry-run   # then --apply
"""
import json, sys, os

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
CUT = 0.82                        # -18% damage on Sanctuary bodies
STAGES = ("basic", "stage1", "stage2")
OPENER_MAX = 2                    # do not create/destroy round-1 openers

def kws(c):
    return {k["kw"]: k.get("n", 0) for k in c.get("keywords", [])}

def main():
    apply = "--apply" in sys.argv
    path = os.path.join(ROOT, "data/cards.json")
    doc = json.load(open(path, encoding="utf-8"))
    changed = []
    for c in doc["cards"]:
        if c.get("type") != "unit" or "sanctuary" not in kws(c):
            continue
        stage = c.get("stage")
        if stage not in STAGES:
            continue
        for a in c.get("attacks", []):
            if a.get("ability"):
                continue
            d = a.get("damage", 0)
            if d <= 0:
                continue
            cost = a.get("cost", {})
            total = sum(cost.values())
            if total <= OPENER_MAX:
                continue          # round-1 openers are a fixed scarce set
            nd = max(1, int(round(d * CUT)))
            if nd == d:
                continue
            ## COST IS DELIBERATELY UNCHANGED. Re-deriving cost from the reduced
            ## damage was the first attempt and it is self-defeating: it lowers
            ## the price in step with the damage, leaving the RATE identical and
            ## the card merely smaller. The keyword has to make the body pay a
            ## worse rate, exactly as Judgment does -- same cost, less damage.
            changed.append((c["name"], a["name"], d, nd, total, total))
            a["damage"] = nd
            if a.get("text", "").startswith(f"{d} damage"):
                a["text"] = a["text"].replace(f"{d} damage", f"{nd} damage", 1)
    print(f"{len(changed)} Sanctuary attack lines re-priced (-18% damage)")
    for n, an, d, nd, t, nc in changed:
        print(f"  {n:<20} {an:<24} dmg {d:>3}->{nd:<3}  cost {t}->{nc}")
    if apply:
        json.dump(doc, open(path, "w", encoding="utf-8"), indent=1, ensure_ascii=False)
        print("APPLIED")
    else:
        print("(dry run -- pass --apply to write)")

main()
