# Multi-Faction Costs Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Split most attack costs into colored + colorless halves, teach the engine to parse and render genuinely dual-color costs and dual-faction cards, then author 18 multi-faction evolution lines (3 per faction pair) as bestiary wave 3.

**Architecture:** Three phases in strict order, each independently shippable. Phase A is pure data (a `tools/` script, total cost never moves, no engine change). Phase B is the engine change that makes dual-color costs and dual-faction cards *parse correctly* — it must land before any multi-faction card is authored, because the current parser silently discards the second color. Phase C authors the cards on top of a parser that can read them.

**Tech Stack:** Godot 4.7 / GDScript, `data/cards.json` as the card source of truth, Python 3 for the authoring and repricing tools, the fourteen headless `--script` harnesses for verification.

---

## Why this order (read before starting)

`AttackData.from_dict` currently reads **one** color key and `break`s
(`scripts/core/AttackData.gd:61-64`). A cost block of `{"hel": 2, "void": 2}`
parses as *2 Hel*: the second color is dropped and `total_cost()` returns 2
instead of 4. The card would look right in the JSON, load without error, and be
charged half price forever.

That is the third instance of a shape the decision log already records twice —
`cost.get("hel", 0)` zeroing every Heaven attack, and the `effects` list being
dropped for units. Both were invisible because **absent data reads as "the card
didn't ask for it."** Authoring Phase C before Phase B would reproduce it
across ~54 new cards at once.

`CardData.faction` is likewise a single `String` (`scripts/core/CardData.gd:13`)
with 31 consumers, so a card cannot *be* two factions until Phase B.

---

## File Structure

| File | Responsibility | Phase |
|---|---|---|
| `tools/split_colorless.py` | **Create.** Derives the colored/colorless split from each attack's printed cost and stage. Dry-run by default. | A |
| `data/cards.json` | **Modify.** Cost blocks gain `colorless`; later gains wave-3 cards. | A, C |
| `scripts/core/AttackData.gd` | **Modify.** `cost_colors: Dictionary` replaces the single-color read. Keeps `cost_faction`/`cost_color` as derived compatibility accessors. | B |
| `scripts/core/CardData.gd` | **Modify.** `factions: Array[String]` alongside the existing `faction`, which becomes the primary/first. | B |
| `scripts/ui/CardView.gd` | **Modify.** Cost row draws one icon per color; card tint blends two ramps. | B |
| `scripts/core/CardDBTest.gd` | **Create.** Guards cost parsing: total cost, per-color amounts, dual-faction membership. | B |
| `tools/add_bestiary_units.py` | **Modify.** Accepts dual-color costs and dual factions; enforces the multi-faction rules. | C |
| `docs/specs/2026-08-16-multi-faction-lines.md` | **Create.** The 18 lines' design, written before the cards. | C |
| `CLAUDE.md` | **Modify.** Records the colorless convention and the multi-faction rules. | A, B, C |

---

## PHASE A — Colorless splits

### Task A1: The split script, with its rule under test

**Files:**
- Create: `tools/split_colorless.py`
- Test: run against `data/cards.json` with `--dry-run`

The split rule, decided in conversation 2026-08-16:

| Split | Applies to |
|---|---|
| Keep pure | total cost <= 3 |
| Keep pure | line carries a signature keyword effect (toll/siphon/earth/judgment/rift/sanctuary/decay/essence/void) |
| `N-1` colored + 1 colorless | total cost 4-5 |
| `ceil(N/2)` colored + `floor(N/2)` colorless | total cost >= 6 |

**Total cost never changes.** The colored half is the card's future faction
requirement once enforcement lands, so it is the real design decision; the
colorless half is what a splashing deck may pay with anything.

- [ ] **Step 1: Write the script**

```python
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
"""
import argparse
import json
import math
import pathlib

CARDS = pathlib.Path(__file__).resolve().parent.parent / "data" / "cards.json"

# A line whose effects name one of these keeps a pure colored cost.
SIGNATURE_OPS = (
    "toll", "decay", "siphon", "void", "rift", "earth",
    "essence", "judgment", "sanctuary", "resist", "rise",
)


def is_signature(atk):
    """True when this line's effects or text name a signature keyword."""
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

            if is_signature(atk):
                kept += 1
                continue

            colored, colorless = split(total)
            if colored == int(cost[key]) and colorless == int(cost.get("colorless", 0) or 0):
                kept += 1
                continue

            print("%-22s %-18s %d %s -> %d %s + %d colorless"
                  % (card["id"], atk.get("name", "?"), total, key,
                     colored, key, colorless))
            atk["cost"] = {key: colored, "colorless": colorless}
            changed += 1

    print("\n%d lines split, %d left pure" % (changed, kept))
    if args.apply:
        CARDS.write_text(json.dumps(data, indent=1, ensure_ascii=False) + "\n",
                         encoding="utf-8")
        print("written to %s" % CARDS)


if __name__ == "__main__":
    main()
```

- [ ] **Step 2: Dry-run it and read the output**

Run: `python tools/split_colorless.py --dry-run`

Expected: a list of proposed splits and a summary line. **Confirm total cost is
unchanged on every line** — each row prints `N key -> a key + b colorless`
where `a + b == N`. Do not proceed if any row violates that.

- [ ] **Step 3: Verify the invariant mechanically before applying**

```bash
python - <<'PY'
import json, subprocess, math
before = json.load(open('data/cards.json'))
def totals(d):
    out = {}
    for c in d['cards']:
        for i, a in enumerate(c.get('attacks') or []):
            if a.get('ability'): continue
            out[(c['id'], i)] = sum(int(v or 0) for v in (a.get('cost') or {}).values())
    return out
b = totals(before)
print('attack lines measured:', len(b))
PY
```

Expected: prints the number of attack lines (230 at time of writing).

- [ ] **Step 4: Apply**

Run: `python tools/split_colorless.py --apply`

- [ ] **Step 5: Confirm no total moved**

```bash
python - <<'PY'
import json
d = json.load(open('data/cards.json'))
bad = []
for c in d['cards']:
    for a in c.get('attacks') or []:
        if a.get('ability'): continue
        cost = a.get('cost') or {}
        cols = [k for k in cost if k != 'colorless']
        if len(cols) > 1:
            bad.append((c['id'], a.get('name'), cost))
print('lines printing 2+ colors (should be 0 in phase A):', len(bad))
for x in bad[:5]: print(' ', x)
PY
```

Expected: `lines printing 2+ colors (should be 0 in phase A): 0`

- [ ] **Step 6: Run the full harness suite**

```bash
for t in RulesTest SupportTest DeckStoreTest DragDropTest HeavenTest CardViewTest VoidTest GaiaTest TutorialTest LayoutTest; do
  echo "=== $t ==="
  godot --headless --path . --script res://scripts/core/$t.gd 2>&1 | tail -4
done
```

Expected: every harness reports 0 failed and no MISCOUNT. Total cost did not
move, so no balance assertion should shift.

- [ ] **Step 7: Commit**

```bash
git add tools/split_colorless.py data/cards.json
git commit -m "Split attack costs into colored and colorless halves"
```

### Task A2: Record the convention

**Files:**
- Modify: `CLAUDE.md` (the *Damage Formulas* section, near the existing colorless sentence)

- [ ] **Step 1: Add the rule to CLAUDE.md**

Add under the two existing `colorless` paragraphs:

```markdown
**Most costs are split into a colored half and a colorless half.** The colored
number is the card's faction requirement; the colorless half may be paid with
anything. The split is derived, not authored — `tools/split_colorless.py` holds
the rule, and total cost never moves when it runs:

| Split | Applies to |
|---|---|
| Pure colored | total cost <= 3, or any line carrying a signature keyword |
| `N-1` + 1 colorless | total cost 4-5 |
| Half and half | total cost 6+ |

Signature-keyword lines stay pure on purpose: the colored requirement *is* the
identity, and a splashable `Toll` or `Siphon` at half the colored cost would let
any deck rent a faction's mechanic. The pool is still one untyped int, so none
of this is enforced yet — the data is kept right ahead of the rule, the same way
retreat costs shipped before the retreat action.
```

- [ ] **Step 2: Commit**

```bash
git add CLAUDE.md
git commit -m "Document the colorless split convention"
```

---

## PHASE B — The engine change

This is the gate on Phase C. Nothing here changes a printed number; it changes
what the parser is *able to read*.

### Task B1: Parse every color, not the first one

**Files:**
- Modify: `scripts/core/AttackData.gd:30-66`
- Test: `scripts/core/CardDBTest.gd` (created in Task B2)

- [ ] **Step 1: Replace the single-color read**

In `scripts/core/AttackData.gd`, replace the `cost_faction` / `cost_color`
declarations (lines 30-33) with:

```gdscript
## Every colored requirement this attack prints, as {color: amount}. A card may
## print more than one — a multi-faction line costs e.g. {"hel": 2, "void": 2}.
##
## This replaced a parser that read ONE color key and then broke out of the loop,
## which silently dropped the second color and charged such a card half price.
## Same shape as the `cost.get("hel", 0)` bug that zeroed every Heaven attack.
var cost_colors: Dictionary = {}

## The primary color — the largest requirement, ties broken by the order printed.
## Kept because most call sites want "what colour is this card" and should not
## have to reduce the dictionary themselves.
var cost_color: String = ""

## Total colored energy across every color. Was the single color's amount.
var cost_faction: int = 0

var cost_colorless: int = 0
```

- [ ] **Step 2: Replace the parse loop**

Replace lines 57-65 (`var c: Dictionary = d.get("cost", {})` through the
`break`) with:

```gdscript
	## Read EVERY colour key. The previous version took the first and `break`ed,
	## so a dual-colour cost parsed as half its printed value.
	var c: Dictionary = d.get("cost", {})
	a.cost_colorless = int(c.get("colorless", 0))
	var best: int = 0
	for key in c.keys():
		if key == "colorless":
			continue
		var amount: int = int(c[key])
		if amount <= 0:
			continue
		a.cost_colors[key] = amount
		a.cost_faction += amount
		if amount > best:
			best = amount
			a.cost_color = str(key)
	return a
```

- [ ] **Step 3: Update `cost_string()` to name every color**

Replace the `cost_string()` body (lines 84-93) with:

```gdscript
func cost_string() -> String:
	if is_ability:
		return "Consume %d" % consume if consume > 0 else "Free"
	var parts: Array[String] = []
	for key in cost_colors.keys():
		parts.append("%d %s" % [int(cost_colors[key]), str(key).capitalize()])
	if cost_colorless > 0:
		parts.append("%d colorless" % cost_colorless)
	return ", ".join(parts) if parts.size() > 0 else "Free"
```

`total_cost()` needs no change — `cost_faction + cost_colorless` is still right,
because `cost_faction` is now the sum across colors.

- [ ] **Step 4: Commit**

```bash
git add scripts/core/AttackData.gd
git commit -m "Parse every colour in an attack cost, not just the first"
```

### Task B2: A harness that would have caught the drop

**Files:**
- Create: `scripts/core/CardDBTest.gd`

This is the guard the two earlier cost bugs did not have: an assertion
comparing a card's **printed** cost against what the engine charges.

- [ ] **Step 1: Write the failing test**

```gdscript
extends SceneTree
## Guards that a printed cost block is what the engine actually charges.
##
## Exists because two separate bugs shipped where a cost parsed to the wrong
## number and nothing noticed: `cost.get("hel", 0)` priced every Heaven attack
## at 0, and the single-colour `break` halved every dual-colour cost. Both were
## invisible because no assertion compared printed data against parsed data.

const EXPECTED_ASSERTIONS := 6

var _pass := 0
var _fail := 0


func _check(label: String, got, want) -> void:
	if got == want:
		_pass += 1
	else:
		_fail += 1
		print("FAIL: %s — got %s, want %s" % [label, got, want])


func _initialize() -> void:
	var AttackData := load("res://scripts/core/AttackData.gd")

	## A single-colour cost still parses as it always did.
	var single = AttackData.from_dict({
		"name": "Gnaw", "damage": 12, "cost": {"hel": 4, "colorless": 0},
	})
	_check("single colour total", single.total_cost(), 4)
	_check("single colour primary", single.cost_color, "hel")

	## A split cost sums to its printed total.
	var split = AttackData.from_dict({
		"name": "Cleave", "damage": 30, "cost": {"hel": 3, "colorless": 3},
	})
	_check("split total", split.total_cost(), 6)

	## A DUAL-colour cost charges the full printed amount. This is the assertion
	## that fails against the old parser: it returned 2 instead of 4.
	var dual = AttackData.from_dict({
		"name": "Unmake", "damage": 40, "cost": {"hel": 2, "void": 2, "colorless": 1},
	})
	_check("dual colour total", dual.total_cost(), 5)
	_check("dual colour hel amount", int(dual.cost_colors.get("hel", 0)), 2)
	_check("dual colour void amount", int(dual.cost_colors.get("void", 0)), 2)

	if _pass + _fail != EXPECTED_ASSERTIONS:
		print("MISCOUNT: ran %d assertions, expected %d"
			% [_pass + _fail, EXPECTED_ASSERTIONS])
		_fail += 1

	print("CardDBTest: %d passed, %d failed" % [_pass, _fail])
	quit(1 if _fail > 0 else 0)
```

- [ ] **Step 2: Run it against the NEW parser to verify it passes**

Run: `godot --headless --path . --script res://scripts/core/CardDBTest.gd`
Expected: `CardDBTest: 6 passed, 0 failed`

- [ ] **Step 3: Prove the test catches the bug it was written for**

Temporarily re-add `break` at the end of the colour loop in
`AttackData.gd` (inside the `for key in c.keys():` block, after
`a.cost_color = str(key)`), then run the harness again.

Run: `godot --headless --path . --script res://scripts/core/CardDBTest.gd`
Expected: **FAIL** on `dual colour total` (got 3, want 5) and
`dual colour void amount` (got 0, want 2).

Then remove the `break` again and re-run to confirm it passes.

This step is not optional. A regression test written after the fix is only
worth what it catches when you put the bug back.

- [ ] **Step 4: Commit**

```bash
git add scripts/core/CardDBTest.gd
git commit -m "Add CardDBTest guarding printed cost against parsed cost"
```

### Task B3: Dual-faction cards

**Files:**
- Modify: `scripts/core/CardData.gd:13`, `:59`

- [ ] **Step 1: Add the list alongside the string**

In `scripts/core/CardData.gd`, replace line 13 with:

```gdscript
## The card's primary faction — the first one printed. Kept as a plain String
## because 31 call sites read it for a colour, a filter or a label, and all of
## them want one answer.
var faction: String = "hel"

## Every faction this card belongs to. Single-faction cards hold one entry, so
## `factions[0] == faction` always. A multi-faction card is legal in a deck
## running any of its colours.
var factions: Array[String] = []
```

- [ ] **Step 2: Parse both forms**

Replace line 59 (`c.faction = d.get("faction", "hel")`) with:

```gdscript
	## `faction` accepts a string or a list. A list makes the card multi-faction;
	## the first entry is the primary, which is what every existing colour, filter
	## and label call site reads.
	var raw = d.get("faction", "hel")
	if raw is Array:
		for f in raw:
			c.factions.append(str(f))
	else:
		c.factions.append(str(raw))
	c.faction = c.factions[0] if c.factions.size() > 0 else "hel"
```

- [ ] **Step 3: Verify every existing card still reports one faction**

```bash
godot --headless --path . --script res://scripts/core/DeckStoreTest.gd 2>&1 | tail -3
```

Expected: 74 passed, 0 failed. Every shipped card prints a string, so
`factions` has exactly one entry and `faction` is unchanged.

- [ ] **Step 4: Commit**

```bash
git add scripts/core/CardData.gd
git commit -m "Let a card belong to more than one faction"
```

### Task B4: Draw a dual-color cost

**Files:**
- Modify: `scripts/ui/CardView.gd:904-926`

- [ ] **Step 1: Draw one icon per printed color**

Replace the cost-icon block (from `var fac: String = atk.cost_color ...`
through the `for i in cost:` loop) with:

```gdscript
	## The attack's printed colours, falling back to the card's own faction when
	## the cost block named none (a purely colorless cost).
	var fallback: String = atk.cost_color if atk.cost_color != "" else card.faction

	## One icon per point of each colour it requires, in printed order, then the
	## colorless remainder. A dual-colour cost draws both ramps, so the split is
	## readable on the card rather than only in the inspector.
	##
	## Always solid, always in the required colour — these state what the attack
	## REQUIRES, which does not depend on what the unit holds. (See the long note
	## in the decision log: filling them by attached energy is what rendered every
	## cost in hand as an empty grey socket.)
	for key in atk.cost_colors.keys():
		var col: Color = Palette.faction_color(str(key))
		for _i in int(atk.cost_colors[key]):
			box.add_child(EnergyIcon.new(col, true, false, _m("icon_size"), str(key)))
	var grey: Color = Palette.faction_color(fallback)
	for _c in atk.cost_colorless:
		box.add_child(EnergyIcon.new(grey, true, true, _m("icon_size"), fallback))
	return box
```

- [ ] **Step 2: Run the card frame harness**

Run: `godot --headless --path . --script res://scripts/core/CardViewTest.gd`
Expected: 79 passed, 0 failed.

`CardViewTest.gd:480` asserts every cost icon is solid and in the required
colour. That assertion still holds: colored icons pass `is_colorless=false`,
and the colorless remainder is the grey ramp as before.

- [ ] **Step 3: Check the phone layout did not overflow**

Run: `godot --headless --path . --script res://scripts/core/LayoutTest.gd`
Expected: 37 passed, 0 failed, no layout over 540 units.

A dual-color cost draws the same *number* of icons as before (the total is
unchanged), so the row width should not move. If LayoutTest fails here, the
icon count is wrong, not the layout.

- [ ] **Step 4: Commit**

```bash
git add scripts/ui/CardView.gd
git commit -m "Draw each colour of a multi-colour attack cost"
```

### Task B5: Record the engine change

**Files:**
- Modify: `CLAUDE.md` — the *Decision log*, and the "Not yet implemented" line
  in *Status* that says multi-color cost enforcement is unbuilt

- [ ] **Step 1: Add the decision log entry**

```markdown
- **The cost parser reads every colour, and a card may name more than one
  faction.** `AttackData.from_dict` took the first colour key and `break`ed, so
  a dual-colour cost like `{"hel": 2, "void": 2}` parsed as *2 Hel* and was
  charged half price — the card would have loaded cleanly, looked right in the
  JSON, and been wrong forever. That is the third instance of this exact shape
  (`cost.get("hel", 0)` zeroing Heaven, units dropping their `effects` list),
  and all three were invisible for the same reason: **absent data reads as "the
  card didn't ask for it."** `CardDBTest` now compares printed cost against
  parsed cost, which is the assertion none of the three had, and it was verified
  by putting the `break` back and watching it fail. `CardData.factions` is a
  list with `faction` kept as the primary, so the 31 call sites that want one
  colour for a tint or a filter are untouched.
```

- [ ] **Step 2: Update the Status section**

The *Not yet implemented* paragraph claims `AttackData` "parses and stores which
color a cost was printed in" but that the pool is untyped. Amend to:

```markdown
**Not yet implemented:** targeted attack selection in the UI beyond the friendly
pick that `Consume the Fallen` accepts, and multi-color cost *enforcement*. The
data is now fully right ahead of the rule: `AttackData.cost_colors` holds every
colour an attack requires and `CardData.factions` holds every faction a card
belongs to, but the pool is a single untyped int, so any energy still pays
anything. Enforcement is a `Player` change, not a data change.
```

- [ ] **Step 3: Commit**

```bash
git add CLAUDE.md
git commit -m "Document multi-colour cost parsing"
```

---

## PHASE C — The 18 multi-faction lines

Rules from `CLAUDE.md` that bind every card here:

- Multi-faction units cost **more total energy** and buy **stronger effects,
  never higher raw damage**.
- The two-line rule, the HP bands, the Judgment stage caps (Basic <= 20,
  Stage 1 <= 40, Stage 2 <= 50), and the Sanctuary floor of 60 all still apply.
- No new round-1 openers (cost 1-2 Basic attacks) — there are deliberately six.
- Cost is derived from damage at 7/8/9 per energy by stage, then clamped.

### Task C1: Write the design spec before any card

**Files:**
- Create: `docs/specs/2026-08-16-multi-faction-lines.md`

Rules before code, always — this project's stated practice. The spec is what
the generator is then pointed at.

- [ ] **Step 1: Write the spec**

Document all 18 lines. For each: the pair, the one-sentence idea, three stages
with name / HP / keywords / attack lines, and the cost split. The eighteen
ideas settled in conversation 2026-08-16:

| Pair | Line | Idea |
|---|---|---|
| Hel x Void | 1 | Toll refund taken from the opponent's attached rather than granted |
| | 2 | Siphon feeding a Rise loop — steal, die, return holding it |
| | 3 | Discard recursion that Voids what it cannot return |
| Hel x Heaven | 1 | Judgment charge that recharges on a friendly death |
| | 2 | Decay that executes at the threshold instead of chipping |
| | 3 | Sanctuary that converts to Toll when it breaks |
| Hel x Gaia | 1 | Essence heir that also pays Toll — the death pays twice |
| | 2 | Earth grown from the discard pile's size |
| | 3 | Retribution wall refunding energy on a recoil kill |
| Void x Heaven | 1 | Rift scaling off the Gap, spent as an execute threshold |
| | 2 | Sanctuary pool that Siphons what it absorbs |
| | 3 | Void N that erases a Judgment charge |
| Void x Gaia | 1 | Earth derived from the Gap rather than attached energy |
| | 2 | Siphon converting stolen energy directly into Earth |
| | 3 | Resist body that Voids the attacker's attached on contact |
| Heaven x Gaia | 1 | Earth aura that also raises Sanctuary pools |
| | 2 | Judgment restored by an Essence payment |
| | 3 | Tower-fed line where Earth feeds a Judgment threshold |

Each line's cost split follows Phase A's rule applied across two colors:
roughly half in each color for an even pair, `N-1`/`1` where one faction leads.

**Flag in the spec, do not build yet:** several ideas above need an `op` the
engine does not have (`toll_from_enemy`, `earth_from_discard`,
`sanctuary_to_toll`, `void_judgment`, `earth_from_gap`). The generator scrapes
the implemented `op` list out of the GDScript and rejects unknown ones — that
check is what will catch these. Each such line either gets an engine op added
as its own task, or is re-specified onto an existing op.

- [ ] **Step 2: Commit**

```bash
git add docs/specs/2026-08-16-multi-faction-lines.md
git commit -m "Spec the 18 multi-faction evolution lines"
```

### Task C2: Reconcile the spec against the implemented op list

**Files:**
- Read: `scripts/core/GameState.gd` (the `op` dispatch)
- Modify: `docs/specs/2026-08-16-multi-faction-lines.md`

- [ ] **Step 1: Extract the implemented ops**

```bash
grep -oE '"[a-z_]+"' scripts/core/GameState.gd | sort -u | head -60
```

- [ ] **Step 2: Mark every spec line as BUILDABLE or NEEDS-OP**

Annotate each of the 18 in the spec. A line marked NEEDS-OP gets either an
engine task or a re-spec onto an existing op — decided with Jonah, not
unilaterally, since it is a rules decision.

- [ ] **Step 3: Commit**

```bash
git add docs/specs/2026-08-16-multi-faction-lines.md
git commit -m "Mark which multi-faction lines need new engine ops"
```

### Task C3: Teach the generator dual costs and dual factions

**Files:**
- Modify: `tools/add_bestiary_units.py:340-430`

- [ ] **Step 1: Accept a dual cost and a faction list**

The generator currently writes `{ENERGY_KEY[faction]: cost}` at line ~408.
Extend it to take a pair of factions and emit a two-color block, splitting the
derived cost between them by the Phase A rule.

- [ ] **Step 2: Add the multi-faction guards**

Refuse to write when a multi-faction card's damage exceeds the single-faction
curve for its stage — the rule is *stronger effects, never higher raw damage*.

- [ ] **Step 3: Commit**

```bash
git add tools/add_bestiary_units.py
git commit -m "Generate multi-faction units with dual-colour costs"
```

### Task C4: Author the cards

**Files:**
- Modify: `data/cards.json`

- [ ] **Step 1: Generate the BUILDABLE lines**

Run the generator for each pair. It refuses to write on any rule violation, so
a clean run is the check.

- [ ] **Step 2: Run every harness**

```bash
for t in RulesTest SupportTest DeckStoreTest DragDropTest HeavenTest CardViewTest VoidTest GaiaTest TutorialTest LayoutTest CardDBTest; do
  echo "=== $t ==="
  godot --headless --path . --script res://scripts/core/$t.gd 2>&1 | tail -3
done
```

Expected: 0 failed everywhere. Census assertions in `VoidTest` etc. will need
their counts updated — those exist to catch a card failing to load, not to
freeze the roster, and they are commented as such.

- [ ] **Step 3: Commit**

```bash
git add data/cards.json scripts/core/*Test.gd
git commit -m "Add the multi-faction evolution lines"
```

### Task C5: Art and names

**Files:**
- Modify: `tools/make_card_art.py`
- Create: `assets/art/<new ids>.png`

- [ ] **Step 1: Draw one shape function per family, called at three scales**

A chain shares a silhouette. For a multi-faction chain the shape should read as
*both* colors — the backdrop tint blends the two ramps.

- [ ] **Step 2: Regenerate and import**

```bash
python tools/make_card_art.py
godot --headless --path . --import
```

- [ ] **Step 3: Eyeball at board size, not at 128px**

Every art regression in this project's log failed the same way: a figure
competing with its own props for the silhouette, invisible at 78px. Check the
new emblems at board size before committing.

- [ ] **Step 4: Commit**

```bash
git add tools/make_card_art.py assets/art
git commit -m "Art for the multi-faction lines"
```

---

## Verification

Phase A is done when every harness passes and no attack's total cost moved.
Phase B is done when `CardDBTest` passes **and has been proven to fail** with
the `break` restored. Phase C is done when the generator writes all
BUILDABLE lines with no rule violation and the full suite is green.

None of this is a balance change: Phase A moves no total, Phase B moves no
printed number, and Phase C adds cards without touching existing ones. The
multi-faction lines will need a human playtest before any number is tuned —
the AI has no Judgment or Sanctuary heuristics and dumps its whole pool onto
one body, which flatters Rift decks and wastes Heaven's.
