"""Raise the healing/board-swing support band to match the current HP curve.

The band was set when Basics were ~50 HP and a 4-energy attack dealt 50. The
2026-08-08 curve raise took Basics to 40-90, Stage 1 to 80-120 and Stage 2 to
110-175 and the anchors deliberately did NOT move -- but the SUPPORT band never
moved either, and nothing re-derived it. A 20-point heal against a 160 HP body is
12% of it; against the 50 HP body it was written for it was 40%.

Measured consequence: over 4M games, supports-per-deck correlates NEGATIVELY with
win rate (-0.19). Every deck in the bottom third runs 15-22 supports and every
deck in the top third runs 7-10, because a support is a card that is not a body,
and bodies are what shield the tower.

Scales flat heal numbers by 1.6 (keeping the documented "base 20, +30 per energy"
SHAPE, just re-anchored), and leaves draw, search and utility alone -- those are
card-economy effects whose value did not change when HP did.

  python tools/reprice_supports.py --dry-run   # then --apply
"""
import json, sys, os

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SCALE = 1.6
## No card may fully heal a unit (CLAUDE.md), and the largest printed HP is 175.
## A single-target heal is therefore capped below that so the biggest bodies still
## overflow it -- which is what keeps a big heal a choice rather than a strict
## upgrade. Board-wide and per-turn heals are capped harder, since they pay out
## across up to four bodies or across many turns.
CAP = {"heal": 120, "heal_conditional": 120, "heal_undo_decay": 60,
       "heal_all": 40, "heal_per_round": 30, "heal_eot": 20, "tower_heal": 45}
HEAL_OPS = set(CAP)

def main():
    apply = "--apply" in sys.argv
    path = os.path.join(ROOT, "data/cards.json")
    doc = json.load(open(path, encoding="utf-8"))
    changed = []
    for c in doc["cards"]:
        if c.get("type") not in ("support", "tool", "tower_support"):
            continue
        for e in c.get("effects", []):
            op = e.get("op")
            if op not in HEAL_OPS:
                continue
            n = e.get("n", 0)
            if n <= 0:
                continue
            nn = min(CAP[op], int(round(n * SCALE)))
            if nn == n:
                continue
            e["n"] = nn
            changed.append((c["id"], op, n, nn))
            for fld in ("text", "flavor"):
                if fld in c and f"{n}" in c[fld]:
                    c[fld] = c[fld].replace(f"{n}", f"{nn}", 1)
    print(f"{len(changed)} healing effects rescaled x{SCALE}")
    for cid, op, n, nn in changed:
        print(f"  {cid:<26} {op:<18} {n:>4} -> {nn}")
    if apply:
        json.dump(doc, open(path, "w", encoding="utf-8"), indent=1, ensure_ascii=False)
        print("APPLIED")
    else:
        print("(dry run -- pass --apply to write)")

main()
