"""Apply the bestiary rename table from docs/specs/bestiary.md to data/cards.json.

    python tools/apply_bestiary.py --dry-run
    python tools/apply_bestiary.py --apply

The rename table in the spec is the source of truth; this script parses it
rather than carrying its own copy, so the doc and the data cannot drift. That
matters more here than usual: the spec is the reviewable artifact and the JSON
is generated from it, which is the same relationship CLAUDE.md has with the
rules engine.

**Only the `name` field changes.** Card ids are referenced 130+ times across 15
GDScript files (TutorialData alone names 40), and they are internal -- so
`grave_whelp` displays as "Osslit" without a line of engine code changing.
Renaming ids would mean touching the tutorial, every sample deck, and GaiaTest's
assertions to buy nothing a player can see.
"""

import argparse
import json
import pathlib
import re
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
SPEC = ROOT / "docs" / "specs" / "bestiary.md"
CARDS = ROOT / "data" / "cards.json"

# | `card_id` | Old Name | **New Name** |
ROW = re.compile(r"^\|\s*`([a-z0-9_]+)`\s*\|\s*(.+?)\s*\|\s*(.+?)\s*\|\s*$", re.M)


def parse_renames():
    """Pull {card_id: new_name} out of the spec's rename tables.

    Rows whose third cell is not bolded are the deliberate no-ops -- the named
    legendaries, marked "*(unchanged -- named)*" -- and are skipped.
    """
    text = SPEC.read_text(encoding="utf-8")
    renames, skipped = {}, []
    for card_id, _old, new in ROW.findall(text):
        m = re.fullmatch(r"\*\*(.+?)\*\*", new.strip())
        if m:
            renames[card_id] = m.group(1)
        else:
            skipped.append(card_id)
    return renames, skipped


def main():
    ap = argparse.ArgumentParser()
    g = ap.add_mutually_exclusive_group(required=True)
    g.add_argument("--dry-run", action="store_true")
    g.add_argument("--apply", action="store_true")
    args = ap.parse_args()

    renames, skipped = parse_renames()
    data = json.loads(CARDS.read_text(encoding="utf-8"))
    cards = data["cards"]
    by_id = {c["id"]: c for c in cards}

    # Every rename must hit a real unit, and every unit must be accounted for.
    unknown = sorted(set(renames) - set(by_id))
    if unknown:
        sys.exit(f"ERROR: spec names cards that do not exist: {unknown}")

    units = {c["id"] for c in cards if c.get("type") == "unit"}
    uncovered = sorted(units - set(renames) - set(skipped))
    if uncovered:
        sys.exit(f"ERROR: units missing from the spec's rename table: {uncovered}")

    # New names must be unique across the whole card pool, including against
    # the non-unit cards this script never touches.
    other = {c["name"] for c in cards if c["id"] not in renames}
    collide = sorted(set(renames.values()) & other)
    if collide:
        sys.exit(f"ERROR: new names collide with existing card names: {collide}")
    if len(set(renames.values())) != len(renames):
        seen, dupes = set(), set()
        for n in renames.values():
            if n in seen:
                dupes.add(n)
            seen.add(n)
        sys.exit(f"ERROR: duplicate new names in the spec: {sorted(dupes)}")

    changes = []
    for card_id, new_name in renames.items():
        card = by_id[card_id]
        if card["name"] != new_name:
            changes.append((card["faction"], card["stage"], card_id,
                            card["name"], new_name))

    order = {"basic": 0, "stage1": 1, "stage2": 2}
    changes.sort(key=lambda r: (r[0], order.get(r[1], 9), r[3]))
    for faction, stage, card_id, old, new in changes:
        print(f"  {faction:7} {stage:7} {old:32} -> {new}")

    print(f"\n{len(changes)} renamed, {len(skipped)} kept as named legendaries"
          f" ({', '.join(skipped)})")

    if args.apply:
        for _f, _s, card_id, _o, new in changes:
            by_id[card_id]["name"] = new
        CARDS.write_text(
            json.dumps(data, indent=2, ensure_ascii=False) + "\n",
            encoding="utf-8")
        print(f"\nwrote {CARDS.relative_to(ROOT)}")
    else:
        print("\n(dry run -- nothing written)")


if __name__ == "__main__":
    main()
