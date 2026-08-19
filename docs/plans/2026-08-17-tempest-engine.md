# Tempest Engine + Cards Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the `Charge` and `Storm` keywords, their 11 effect ops, and the 20 Tempest cards, so the sixth faction is playable.

**Architecture:** `Charge` is a per-unit integer on `Unit` (the same shape as `sanctuary_pool`) that grows when the unit deals a damage instance and is spent whole by a free once-per-turn Discharge ability. `Storm` is a single global int on `GameState` (the same category as the Gap) that appends one extra damage instance to every attack. Both hook into paths that already exist: `_after_defender_damaged` for Charge growth (it exists precisely so two damage paths cannot drift), `_deliver_attack_damage` for the Storm instance, and `use_ability` for Discharge.

**Tech Stack:** Godot 4.7, GDScript. Headless harnesses run via `godot --headless --path . --script res://scripts/core/<Name>Test.gd`.

---

## Reference

Spec: `docs/specs/2026-08-17-tempest-faction-design.md`. Read it before Task 1 — the interaction rules are decided there and this plan implements them without re-litigating.

**The Godot binary** is pinned in `tools/godot-path.txt`. In bash:

```bash
GODOT=$(cat tools/godot-path.txt | tr -d '\r')
"$GODOT" --headless --path . --script res://scripts/core/RulesTest.gd 2>&1 | grep -E "passed|failed"
```

**Baseline before starting:** `RulesTest` reports `146 passed, 0 failed`. Every task must leave it there or higher.

**The eleven ops**, all currently unimplemented:

| Op | Meaning |
|---|---|
| `charge_on_damage` | Grow the counter by N per damage instance dealt |
| `charge_on_kill` | Grow by an extra N when this unit's damage kills |
| `discharge` | Spend all: bonus damage on the attack + a second unit for the counter |
| `discharge_single` | Spend all into one target, multiplied by N |
| `discharge_sweep` | Spend all split evenly across the enemy board |
| `discharge_heal` | Spend all as healing on a unit you control |
| `discharge_structures` | Rider: the discharge attack may reach tower/throne past units |
| `charge_transfer` | Move this unit's counter to another unit you control |
| `storm_raise` | Raise the global Storm counter by N |
| `storm_scale_damage` | +N damage per point of Storm |
| `storm_charge_bonus` | This unit grows N extra Charge per point of Storm |

---

## File Structure

| File | Responsibility | Change |
|---|---|---|
| `scripts/core/Unit.gd` | `charge` counter, growth, spend, evolution carry-through | Modify |
| `scripts/core/GameState.gd` | `storm` global, the extra instance, discharge resolution, `storm_is_relevant()` | Modify |
| `scripts/core/CardData.gd` | Parse `charge` keyword (verify — may already be generic) | Verify/modify |
| `scripts/ui/CardView.gd` | Render the live counter on the card | Modify |
| `scripts/ui/Palette.gd` | `charge`/`storm` keyword colours + help text | Modify |
| `scripts/core/TempestTest.gd` | The harness | Create |
| `tools/add_tempest_faction.py` | The 20 cards (already written) | Run |
| `data/cards.json` | The cards | Generated |
| `CLAUDE.md` | Keyword table, status | Modify |

---

## Task 1: The Charge counter on Unit

**Files:**
- Modify: `scripts/core/Unit.gd`
- Test: `scripts/core/TempestTest.gd` (create)

- [ ] **Step 1: Create the harness skeleton with the first failing test**

Create `scripts/core/TempestTest.gd`:

```gdscript
extends SceneTree

## Tempest harness — `Charge` (a per-unit banked counter) and `Storm` (a global
## damage ramp). See docs/specs/2026-08-17-tempest-faction-design.md.
##
## Loaded by PATH, not by class name: under `--script` this compiles before
## autoloads register, so naming a class that touches `Palette` or `CardDB`
## fails to compile with "Identifier not found". Same rule CardViewTest follows.

const CardDataS = preload("res://scripts/core/CardData.gd")
const UnitS = preload("res://scripts/core/Unit.gd")

## A green suite is only evidence if you know how many assertions it should run:
## a harness that crashes mid-file reports "0 failed" and exits 0.
const EXPECTED_ASSERTIONS := 4

var _pass := 0
var _fail := 0


func ok(cond: bool, label: String) -> void:
	if cond:
		_pass += 1
	else:
		_fail += 1
		print("  FAIL: %s" % label)


func eq(got, want, label: String) -> void:
	ok(got == want, "%s — got %s, want %s" % [label, got, want])


## A bare unit from an inline card dict, so the harness does not depend on
## data/cards.json having been regenerated yet.
func unit(d: Dictionary) -> Unit:
	return UnitS.new(CardDataS.from_dict(d))


func _init() -> void:
	print("=== TempestTest ===")
	_test_charge_counter()

	print("%d passed, %d failed" % [_pass, _fail])
	if _pass + _fail != EXPECTED_ASSERTIONS:
		print("FAIL: expected %d assertions, ran %d" % [EXPECTED_ASSERTIONS, _pass + _fail])
		_fail += 1
	quit(1 if _fail > 0 else 0)


func _test_charge_counter() -> void:
	var u := unit({
		"id": "t_a", "name": "A", "type": "unit", "faction": "tempest",
		"stage": "basic", "hp": 50, "keywords": [{"kw": "charge", "n": 3}],
		"attacks": [],
	})
	eq(u.charge, 0, "charge starts at 0")
	u.add_charge(3)
	eq(u.charge, 3, "add_charge raises it")
	u.add_charge(3)
	eq(u.charge, 6, "charge accumulates")
	eq(u.spend_charge(), 6, "spend_charge returns the whole counter")
```

- [ ] **Step 2: Run it to verify it fails**

```bash
GODOT=$(cat tools/godot-path.txt | tr -d '\r')
"$GODOT" --headless --path . --script res://scripts/core/TempestTest.gd 2>&1 | grep -E "FAIL|passed|error|Invalid"
```

Expected: a compile or runtime error naming `charge` / `add_charge` as unknown.

- [ ] **Step 3: Add the counter to Unit**

In `scripts/core/Unit.gd`, immediately after the `hp_grown` declaration (around line 20), add:

```gdscript
## Tempest `Charge`: a banked counter that grows when this unit DEALS damage and
## is spent whole by a Discharge ability.
##
## Unlike every other accumulated value on a unit, this SURVIVES evolution — see
## evolve_into(). Attached energy and Tools are the only other things that do, and
## the reason is identical: without it, evolving would destroy the investment, so
## the correct play for the one faction whose resource is time would be never to
## evolve. It is still lost on death, on Rise, and on retreat.
var charge: int = 0
```

Then add these methods next to the Sanctuary helpers:

```gdscript
## Grow the banked counter. Never negative — every keyword reads as "N of
## something" and the floor is applied here because charge has no printed value
## to fall back to the way kw_mods does.
func add_charge(n: int) -> void:
	charge = maxi(0, charge + n)


## Spend the whole counter and return what it held. A spend is a spend: the
## caller must not credit any of it back, or a large discharge partially refunds
## itself (see the spec).
func spend_charge() -> int:
	var held: int = charge
	charge = 0
	return held


## The printed Charge rate — how much this unit banks per damage instance.
## Reads through kw_value so a card that raises Charge is honoured, exactly as
## every other keyword works.
func charge_rate() -> int:
	return kw_value("charge")
```

- [ ] **Step 4: Run to verify it passes**

```bash
"$GODOT" --headless --path . --script res://scripts/core/TempestTest.gd 2>&1 | grep -E "passed|failed"
```

Expected: `4 passed, 0 failed`

- [ ] **Step 5: Commit**

```bash
git add scripts/core/Unit.gd scripts/core/TempestTest.gd
git commit -m "feat(tempest): add the Charge counter to Unit"
```

---

## Task 2: Charge survives evolution, dies with the body

**Files:**
- Modify: `scripts/core/Unit.gd` (`evolve_into`, `make_risen`)
- Test: `scripts/core/TempestTest.gd`

- [ ] **Step 1: Write the failing tests**

Add to `TempestTest.gd`, and change `EXPECTED_ASSERTIONS` to `9`:

```gdscript
func _test_charge_persistence() -> void:
	var basic := {
		"id": "t_b", "name": "B", "type": "unit", "faction": "tempest",
		"stage": "basic", "hp": 50, "keywords": [{"kw": "charge", "n": 3}],
		"attacks": [],
	}
	var evolved := CardDataS.from_dict({
		"id": "t_b2", "name": "B2", "type": "unit", "faction": "tempest",
		"stage": "stage1", "hp": 96, "keywords": [{"kw": "charge", "n": 8}],
		"attacks": [],
	})

	## Evolution CARRIES the value and CHANGES the rate. This is the exception to
	## "new printed card, new everything" and the whole reason Tempest can evolve.
	var u := unit(basic)
	u.add_charge(21)
	eq(u.charge_rate(), 3, "basic banks at its printed rate")
	u.evolve_into(evolved)
	eq(u.charge, 21, "charge SURVIVES evolution")
	eq(u.charge_rate(), 8, "but the rate is the new card's")

	## Rise restores the card, not the history — same rule grown Earth follows.
	var r := unit(basic)
	r.add_charge(30)
	var risen := r.make_risen()
	eq(risen.charge, 0, "Rise returns the unit with no charge")

	## kw_mods clear on evolution, so a raised Charge does not ride along.
	var m := unit(basic)
	m.add_kw_mod("charge", 5)
	eq(m.charge_rate(), 8, "a raised Charge rate reads modified")
	m.evolve_into(evolved)
	eq(m.charge_rate(), 8, "but the modifier cleared — this is the new print")
```

Call it from `_init` after `_test_charge_counter()`.

- [ ] **Step 2: Run to verify it fails**

```bash
"$GODOT" --headless --path . --script res://scripts/core/TempestTest.gd 2>&1 | grep -E "FAIL|passed"
```

Expected: `charge SURVIVES evolution` passes only by accident (evolve_into does not touch it yet) but `Rise returns the unit with no charge` FAILS if `make_risen` copies it, and the assertion count is wrong. Read the output rather than assuming — the point of this step is to see which of the two rules is already true.

- [ ] **Step 3: Make both rules explicit**

In `scripts/core/Unit.gd`, inside `evolve_into()`, add this comment beside the existing resets so the omission is deliberate rather than accidental (do NOT add a reset):

```gdscript
	judgment_spent = false                   ## new printed card, new charge
	## `charge` is deliberately NOT reset. It is the third thing to survive
	## evolution, after attached energy and the Tool, and for the same reason:
	## without it, evolving destroys the investment and the correct play for the
	## one faction whose resource is time is never to evolve. The VALUE carries;
	## the RATE comes from the new card via kw_value, so evolving is a rate rise.
```

Then find `make_risen()` and ensure the returned unit has `charge = 0`. If it builds a fresh `Unit` from `CardData` it already does — add an explicit assertion comment:

```gdscript
	## `charge` starts at 0 on the new instance: Rise restores the card, not the
	## history, exactly as grown Earth and grown HP are dropped.
```

If `make_risen()` copies fields onto an existing unit instead, add `u.charge = 0` there.

- [ ] **Step 4: Run to verify it passes**

Expected: `9 passed, 0 failed`

- [ ] **Step 5: Verify by putting the bug back**

Temporarily add `charge = 0` inside `evolve_into()`, rerun, and confirm `charge SURVIVES evolution` FAILS. Then remove it. A regression test written after the fact is only worth what it catches when you reintroduce the bug.

- [ ] **Step 6: Commit**

```bash
git add scripts/core/Unit.gd scripts/core/TempestTest.gd
git commit -m "feat(tempest): Charge survives evolution, resets on Rise"
```

---

## Task 3: The Storm global counter

**Files:**
- Modify: `scripts/core/GameState.gd`
- Test: `scripts/core/TempestTest.gd`

- [ ] **Step 1: Write the failing test**

Add to `TempestTest.gd` and set `EXPECTED_ASSERTIONS` to `13`:

```gdscript
func _test_storm_counter() -> void:
	var gs = _new_game()
	eq(gs.storm, 0, "Storm starts at 0")
	gs.raise_storm(2)
	eq(gs.storm, 2, "raise_storm raises it")
	gs.raise_storm(3)
	eq(gs.storm, 5, "Storm accumulates and never falls")
	## Symmetric: one number, not one per player. Unlike the Gap.
	ok(gs.storm_damage_for(null) == 5, "a non-Tempest attacker gets N")
```

You will need a `_new_game()` helper. Add it near `unit()`, modelled on how `ForgeTest.gd` builds a `GameState` — read that file's setup and copy the pattern exactly rather than inventing one.

- [ ] **Step 2: Run to verify it fails**

Expected: error naming `storm` / `raise_storm` as unknown.

- [ ] **Step 3: Add Storm to GameState**

Near the Gap declarations in `scripts/core/GameState.gd`, add:

```gdscript
## Tempest `Storm`: a GLOBAL board counter both players read, the same category
## as the Gap — a property of the board, not of a card. It is 0 until a Tempest
## card raises it, it never falls, and it is SYMMETRIC: one number shared by both
## players, where each player has their own Gap.
##
## Every attack deals one ADDITIONAL instance of `storm` damage. One instance of
## N, never N instances of 1 — the multi-instance reading is accidentally a
## Resist-piercing mechanic, because Resist floors each instance at 1 damage, so
## armour would stop working as Storm climbed.
var storm: int = 0


## Raise the global Storm counter. Never negative: cards only ever add.
func raise_storm(n: int) -> void:
	if n <= 0:
		return
	storm += n
	_log("The storm builds — Storm is now %d." % storm)
	emit_signal("state_changed")


## The extra damage instance an attack from `u` carries. A Tempest unit's Storm
## instance deals 2N — the asymmetry that makes Storm a Tempest mechanic rather
## than a house rule, and the intended balance dial if Storm proves too strong.
func storm_damage_for(u: Unit) -> int:
	if storm <= 0:
		return 0
	if u != null and u.card != null and u.card.faction == "tempest":
		return storm * 2
	return storm


## Is Storm worth showing? Same rule and same reason as gap_is_relevant(): the
## number is real at all times but nothing reads it without Tempest in the game,
## so a permanent meter would be clutter in most matchups.
func storm_is_relevant() -> bool:
	if storm > 0:
		return true
	for p in players:
		if p == null:
			continue
		for pile in [p.deck, p.hand, p.discard]:
			for id in pile:
				if _is_tempest_card(str(id)):
					return true
		for u in p.all_units():
			if u != null and _is_tempest_card(u.card.id):
				return true
	return false


## Guards against a null lookup, so an id removed from the data cannot take the
## readout down with it. Mirrors _is_void_card.
func _is_tempest_card(id: String) -> bool:
	var db = _card_db()
	if db == null:
		return false
	var c = db.get_card(id)
	return c != null and c.faction == "tempest"
```

Check `_is_void_card`'s body and match its exact accessor calls — `get_card` may be named differently.

- [ ] **Step 4: Run to verify it passes**

Expected: `13 passed, 0 failed`

- [ ] **Step 5: Commit**

```bash
git add scripts/core/GameState.gd scripts/core/TempestTest.gd
git commit -m "feat(tempest): add the global Storm counter"
```

---

## Task 4: Storm adds one extra damage instance

**Files:**
- Modify: `scripts/core/GameState.gd` (`_deliver_attack_damage`, around line 2043)
- Test: `scripts/core/TempestTest.gd`

- [ ] **Step 1: Write the failing tests**

Set `EXPECTED_ASSERTIONS` to `18` and add:

```gdscript
func _test_storm_instance() -> void:
	## A 20-damage attack at Storm 3 from a NON-Tempest unit deals 20 + 3.
	var gs = _new_game()
	gs.raise_storm(3)
	var d := _attack_for(gs, "hel", 20)
	eq(d, 23, "Storm adds one instance of N")

	## A Tempest attacker's Storm instance is doubled.
	var gs2 = _new_game()
	gs2.raise_storm(3)
	eq(_attack_for(gs2, "tempest", 20), 26, "a Tempest unit's Storm instance is 2N")

	## ONE instance, not N. Against Resist 10, Storm 3 is fully absorbed rather
	## than becoming three 1-damage hits that pierce armour.
	var gs3 = _new_game()
	gs3.raise_storm(3)
	eq(_attack_for(gs3, "hel", 20, 10), 10, "Resist blunts the Storm instance normally")

	## Storm 0 changes nothing at all.
	var gs4 = _new_game()
	eq(_attack_for(gs4, "hel", 20), 20, "no Storm, no extra instance")
	eq(gs4.storm, 0, "and the counter stays 0")
```

`_attack_for(gs, faction, damage, resist := 0)` is a helper you write: it places an attacker of `faction` and a defender carrying `resist`, drives one attack through `gs._deal_lane_damage(...)`, and returns total HP lost by the defender. Drive the REAL pipeline — a test that reimplements the rule proves nothing about the engine, which is why the Heaven and Gaia harnesses call `_deal_lane_damage` directly.

- [ ] **Step 2: Run to verify it fails**

Expected: the Storm assertions FAIL, reporting 20 where 23 was wanted.

- [ ] **Step 3: Append the Storm instance**

In `_deliver_attack_damage`, at the very END of the function (after the existing `_deal_lane_damage(p, enemy, u, bi, si, dmg, atk)` call and the tower-splash block), add:

```gdscript
	## Tempest `Storm`: every attack carries ONE additional instance of the global
	## counter — 2N from a Tempest body. It resolves as its own instance through
	## the ordinary chain, so if the main attack killed the defender this retargets
	## to the next living unit and falls through to the tower once the board is
	## clear. Storm therefore quietly rewards clearing a board.
	##
	## Appended AFTER the geometry breaks return, so a sweeping or both-boards
	## attack does not also multiply its Storm instance across every target.
	var storm_dmg: int = storm_damage_for(u)
	if storm_dmg > 0 and not finished:
		_deal_lane_damage(p, enemy, u, bi, si, storm_dmg, atk)
```

Note the early `return`s in the sweep and both-boards branches already prevent double-application; verify by reading the function top to bottom before editing.

- [ ] **Step 4: Run to verify it passes**

Expected: `18 passed, 0 failed`

- [ ] **Step 5: Confirm nothing else regressed**

```bash
for T in RulesTest SupportTest HeavenTest VoidTest GaiaTest ForgeTest; do
  echo -n "$T: "
  "$GODOT" --headless --path . --script res://scripts/core/$T.gd 2>&1 | grep -oE "[0-9]+ passed, [0-9]+ failed"
done
```

Expected: every suite at its documented count, 0 failed. Storm is 0 in all of them, so the new branch must be inert.

- [ ] **Step 6: Commit**

```bash
git add scripts/core/GameState.gd scripts/core/TempestTest.gd
git commit -m "feat(tempest): Storm adds one extra damage instance per attack"
```

---

## Task 5: Charge grows on damage dealt

**Files:**
- Modify: `scripts/core/GameState.gd` (`_after_defender_damaged`)
- Test: `scripts/core/TempestTest.gd`

- [ ] **Step 1: Write the failing tests**

Set `EXPECTED_ASSERTIONS` to `23` and add:

```gdscript
func _test_charge_growth() -> void:
	## Grows on damage DEALT. Two instances per attack once Storm is up: the
	## attack itself, then its Storm instance.
	var gs = _new_game()
	var a := _place_charger(gs, 5)          ## a Tempest unit with charge_on_damage 5
	_swing(gs, a)
	eq(a.charge, 5, "one instance dealt grows the counter once")

	gs.raise_storm(2)
	_swing(gs, a)
	eq(a.charge, 15, "with Storm up, an attack is two instances")

	## NEVER on damage taken. The counterplay must not be "stop attacking".
	var gs2 = _new_game()
	var b := _place_charger(gs2, 5)
	_swing_at(gs2, b)                       ## b is the DEFENDER here
	eq(b.charge, 0, "taking damage never grows the counter")

	## A unit with no charge_on_damage line banks nothing.
	var gs3 = _new_game()
	var c := _place_plain(gs3)
	_swing(gs3, c)
	eq(c.charge, 0, "a unit with no Charge line banks nothing")

	## charge_on_kill pays an extra bonus when the damage kills.
	var gs4 = _new_game()
	var k := _place_killer(gs4, 3, 6)       ## charge_on_damage 3, charge_on_kill 6
	_swing_lethal(gs4, k)
	eq(k.charge, 9, "a kill pays the on-damage AND the on-kill bonus")
```

Write `_place_charger`, `_place_plain`, `_place_killer`, `_swing`, `_swing_at`, `_swing_lethal` as small helpers in the harness.

- [ ] **Step 2: Run to verify it fails**

Expected: the counter reads 0 where 5 was wanted.

- [ ] **Step 3: Grow the counter where both damage paths already converge**

In `_after_defender_damaged`, at the very TOP (before the defensive Judgment block), add:

```gdscript
	## Tempest `Charge`: the attacker banks its counter for this instance.
	##
	## Placed here rather than at either call site because this function exists
	## precisely so the ordinary path and Forge's `stoked_unpreventable` path
	## cannot drift — Charge has to grow identically down both, and two code paths
	## for one question is one path too many.
	##
	## `_dealt` is the damage that actually landed, so a fully absorbed hit still
	## counts as an instance dealt: Charge reads "deals an instance", not "deals
	## damage above zero", which keeps it legible against Sanctuary walls.
	if u != null and _atk.has_effect("charge_on_damage"):
		var per: int = _atk.effect_value("charge_on_damage", 0)
		if per > 0:
			## A Tool or card may pay extra per point of Storm.
			if _atk.has_effect("storm_charge_bonus"):
				per += _atk.effect_value("storm_charge_bonus", 0) * storm
			u.add_charge(per)
	## A kill pays an additional bonus — the executioner chain snowballs through
	## a board rather than off one target.
	if u != null and defender.hp <= 0 and _atk.has_effect("charge_on_kill"):
		u.add_charge(_atk.effect_value("charge_on_kill", 0))
```

Rename the leading-underscore parameters `_atk` and `_dealt` to `atk` and `dealt` in the signature if you use them, and update both call sites. The underscore prefix only marks them unused.

- [ ] **Step 4: Run to verify it passes**

Expected: `23 passed, 0 failed`

- [ ] **Step 5: Verify by putting the bug back**

Temporarily change `u.add_charge(per)` to `pass`, rerun, confirm the growth assertions FAIL, then restore.

- [ ] **Step 6: Commit**

```bash
git add scripts/core/GameState.gd scripts/core/TempestTest.gd
git commit -m "feat(tempest): Charge grows on damage dealt, extra on a kill"
```

---

## Task 6: Discharge — the four spend modes

**Files:**
- Modify: `scripts/core/GameState.gd` (`use_ability`, plus a `_resolve_discharge` helper)
- Test: `scripts/core/TempestTest.gd`

- [ ] **Step 1: Write the failing tests**

Set `EXPECTED_ASSERTIONS` to `32` and add:

```gdscript
func _test_discharge() -> void:
	## The baseline: the next attack carries the counter as bonus damage AND
	## strikes a second unit on that board for the counter.
	var gs = _new_game()
	var a := _place_charger(gs, 5)
	a.add_charge(20)
	_use_discharge(gs, a, "discharge")
	eq(a.charge, 0, "discharge spends the whole counter")
	ok(a.pending_discharge == 20, "and arms the next attack with it")

	## Discharge damage NEVER grows Charge — a spend is a spend.
	_swing(gs, a)
	eq(a.charge, 5, "the swing banks its own instance only, not the discharge")

	## discharge_single multiplies into one target.
	var gs2 = _new_game()
	var b := _place_charger(gs2, 5)
	b.add_charge(15)
	var before := _defender_hp(gs2)
	_use_discharge(gs2, b, "discharge_single", 2)
	_swing(gs2, b)
	ok(_defender_hp(gs2) <= before - 30, "discharge_single deals 2x the counter")

	## discharge_heal spends it as healing instead.
	var gs3 = _new_game()
	var h := _place_charger(gs3, 5)
	h.add_charge(25)
	var ally := _place_hurt_ally(gs3, 40)   ## at 40 of 96 HP
	_use_discharge(gs3, h, "discharge_heal", 0, ally)
	eq(ally.hp, 65, "discharge_heal restores the counter as HP")
	eq(h.charge, 0, "and still spends it")

	## charge_transfer moves the counter rather than spending it.
	var gs4 = _new_game()
	var s := _place_charger(gs4, 4)
	s.add_charge(18)
	var heir := _place_charger(gs4, 4)
	_use_discharge(gs4, s, "charge_transfer", 0, heir)
	eq(s.charge, 0, "transfer empties the source")
	eq(heir.charge, 18, "and fills the destination")

	## Discharge is once per turn — the ordinary ability limit, not a new rule.
	ok(not gs4.use_ability(gs4.active, s, _ability_of(s, "charge_transfer")),
	   "a second discharge in one turn is refused")
```

- [ ] **Step 2: Run to verify it fails**

Expected: `pending_discharge` unknown.

- [ ] **Step 3: Add the pending-discharge slot to Unit**

In `scripts/core/Unit.gd`, beside `charge`:

```gdscript
## A discharge that has been paid for and is waiting on this unit's next attack.
## Cleared when that attack resolves. Separate from `charge` because the counter
## is already spent — this is the amount in flight, and it must never feed back
## into the counter (a spend is a spend).
var pending_discharge: int = 0
var pending_discharge_mult: int = 1
```

- [ ] **Step 4: Resolve the discharge ops in use_ability**

In `use_ability`, after the Stoke block, add:

```gdscript
	## Tempest Discharge: spend the whole counter. Free and once per turn, so it
	## is an ability by definition — on an attack it would charge pool energy for
	## a counter the unit already earned.
	for op in ["discharge", "discharge_single", "discharge_sweep"]:
		if ab.has_effect(op):
			var held: int = u.spend_charge()
			if held > 0:
				u.pending_discharge = held
				u.pending_discharge_mult = maxi(1, ab.effect_value(op, 1))
				u.pending_discharge_mode = op
				_log("%s discharges %d." % [u.card.name, held])
			break

	if ab.has_effect("discharge_heal"):
		var healed: int = u.spend_charge()
		var tgt: Unit = target if target is Unit else u
		if healed > 0 and tgt != null:
			tgt.hp = mini(effective_max_hp(p, tgt), tgt.hp + healed)
			_log("%s discharges %d as healing onto %s." % [u.card.name, healed, tgt.card.name])

	if ab.has_effect("charge_transfer"):
		var moved: int = u.spend_charge()
		var heir: Unit = target if target is Unit else _nearest_living_ally(p, u)
		if moved > 0 and heir != null and heir != u:
			heir.add_charge(moved)
			_log("%s passes %d charge to %s." % [u.card.name, moved, heir.card.name])
		elif moved > 0:
			u.add_charge(moved)   ## no legal heir: the transfer fizzles, nothing is lost
```

Add `var pending_discharge_mode: String = ""` to `Unit`. Write `_nearest_living_ally(p, u)` modelled on Gaia's `Essence` heir search — read that code and reuse its nearest-living, ties-go-left rule rather than writing a second one.

- [ ] **Step 5: Apply the pending discharge when the attack resolves**

In `_deliver_attack_damage`, before the geometry-break branches:

```gdscript
	## A discharge armed this turn rides the next attack out.
	var disc: int = 0
	if u != null and u.pending_discharge > 0:
		disc = u.pending_discharge * maxi(1, u.pending_discharge_mult)
		dmg += disc
```

And after the main `_deal_lane_damage` call, before the Storm instance:

```gdscript
	## The baseline discharge also strikes a SECOND unit on that board.
	if disc > 0 and u.pending_discharge_mode == "discharge" and not finished:
		var eb2: Board = enemy.boards[bi]
		for s2 in Board.SLOT_COUNT:
			var v: Unit = eb2.slots[s2]
			if v != null and v.is_alive() and s2 != si:
				_deal_lane_damage(p, enemy, u, bi, s2, u.pending_discharge, atk)
				break

	if u != null and u.pending_discharge > 0:
		u.pending_discharge = 0
		u.pending_discharge_mult = 1
		u.pending_discharge_mode = ""
```

For `discharge_sweep`, split the counter evenly across living units on the board — follow `stoked_sweep`'s loop shape exactly.

- [ ] **Step 6: Run to verify it passes**

Expected: `32 passed, 0 failed`

- [ ] **Step 7: Commit**

```bash
git add scripts/core/Unit.gd scripts/core/GameState.gd scripts/core/TempestTest.gd
git commit -m "feat(tempest): implement the four Discharge modes and charge_transfer"
```

---

## Task 7: storm_raise, storm_scale_damage, discharge_structures

**Files:**
- Modify: `scripts/core/GameState.gd`
- Test: `scripts/core/TempestTest.gd`

- [ ] **Step 1: Write the failing tests**

Set `EXPECTED_ASSERTIONS` to `37`:

```gdscript
func _test_storm_ops() -> void:
	## storm_raise on an ability raises the global counter.
	var gs = _new_game()
	var f := _place_stormcaller(gs, 2)
	_use_ability_named(gs, f, "storm_raise")
	eq(gs.storm, 2, "storm_raise raises the global counter")

	## storm_scale_damage adds N per point of Storm to the attack itself.
	var gs2 = _new_game()
	gs2.raise_storm(4)
	## base 20, +3 per Storm = +12, plus the Storm instance itself
	ok(_attack_for(gs2, "hel", 20, 0, 3) >= 32, "storm_scale_damage scales the attack")

	## discharge_structures lets the discharge attack reach past living units.
	var gs3 = _new_game()
	var d := _place_charger(gs3, 5)
	d.add_charge(30)
	_place_enemy_blocker(gs3)
	var tower_before := _enemy_tower_hp(gs3)
	_use_discharge(gs3, d, "discharge_single", 2)
	_swing(gs3, d)
	ok(_enemy_tower_hp(gs3) < tower_before, "discharge_structures reaches the tower past a wall")

	## ...and the base keyword does NOT.
	var gs4 = _new_game()
	var e := _place_charger(gs4, 5)
	e.add_charge(30)
	_place_enemy_blocker(gs4)
	var t4 := _enemy_tower_hp(gs4)
	_use_discharge(gs4, e, "discharge")
	_swing(gs4, e)
	eq(_enemy_tower_hp(gs4), t4, "a plain discharge never reaches a shielded tower")
```

- [ ] **Step 2: Run to verify it fails**

- [ ] **Step 3: Implement the three ops**

`storm_raise` — in `use_ability`, alongside the discharge block:

```gdscript
	if ab.has_effect("storm_raise"):
		raise_storm(ab.effect_value("storm_raise", 1))
```

Also handle it for supports wherever support effect ops are dispatched (find the support `op` switch and add the same case).

`storm_scale_damage` — wherever an attack's final damage is computed, before delivery:

```gdscript
	## Tempest: this attack scales with the global Storm counter.
	if atk.has_effect("storm_scale_damage") and storm > 0:
		dmg += atk.effect_value("storm_scale_damage", 0) * storm
```

`discharge_structures` — in `_deal_lane_damage`, beside the `stoked_ignore_shield` block:

```gdscript
	## Tempest: a discharge that prints the break may reach this board's
	## structures past living units. The base keyword is units-only, matching
	## Forge's sweep; this is the printed exception, per design principle #1.
	if u != null and u.pending_discharge > 0 and atk.has_effect("discharge_structures"):
		if eb.tower_alive():
			eb.tower_take_damage(dmg)
			_log("*** %s discharges %d past the wall into the TOWER." % [atk.name, dmg])
		else:
			enemy.throne_take_damage(dmg)
			_check_throne(enemy)
		return
```

- [ ] **Step 4: Run to verify it passes**

Expected: `37 passed, 0 failed`

- [ ] **Step 5: Commit**

```bash
git add scripts/core/GameState.gd scripts/core/TempestTest.gd
git commit -m "feat(tempest): storm_raise, storm_scale_damage, discharge_structures"
```

---

## Task 8: Retribution fires once per attack

**Files:**
- Modify: `scripts/core/GameState.gd`
- Test: `scripts/core/TempestTest.gd`

The Storm instance is a second damage instance, so a `Retribution` wall would recoil twice per attack — at Storm 3 a `Retribution 25` body deals 50 back. The spec rules this out: the printed wording is *"when this unit takes damage from an attack"*, singular.

- [ ] **Step 1: Write the failing test**

Set `EXPECTED_ASSERTIONS` to `39`:

```gdscript
func _test_retribution_once() -> void:
	var gs = _new_game()
	gs.raise_storm(3)
	var a := _place_plain(gs)
	var hp_before := a.hp
	_swing_into_retributor(gs, a, 25)     ## defender has Retribution 25
	eq(hp_before - a.hp, 25, "Retribution fires once per attack, not per instance")

	var gs2 = _new_game()
	var b := _place_plain(gs2)
	var h2 := b.hp
	_swing_into_retributor(gs2, b, 25)
	eq(h2 - b.hp, 25, "and identically with no Storm at all")
```

- [ ] **Step 2: Run to verify it fails**

Expected: 50 where 25 was wanted.

- [ ] **Step 3: Gate recoil to the first instance of an attack**

Add a per-attack flag. In `_deliver_attack_damage`, before delivering:

```gdscript
	## Retribution is per ATTACK, not per instance — the Storm instance must not
	## double a wall's recoil. Reset here so each queued attack recoils once.
	_retribution_fired = false
```

Declare `var _retribution_fired: bool = false` on `GameState`, and in `_after_defender_damaged` wrap the recoil block:

```gdscript
	var retr: int = defender.total_retribution()
	if retr > 0 and not _retribution_fired:
		_retribution_fired = true
		var r := u.take_damage(_apply_resist(u, retr))
		_log("  Retribution: %s takes %d back (%d HP left)." % [u.card.name, r, max(0, u.hp)])
```

- [ ] **Step 4: Run the FULL suite**

```bash
for T in RulesTest SupportTest HeavenTest VoidTest GaiaTest ForgeTest TempestTest; do
  echo -n "$T: "
  "$GODOT" --headless --path . --script res://scripts/core/$T.gd 2>&1 | grep -oE "[0-9]+ passed, [0-9]+ failed"
done
```

This change touches EVERY faction's combat, so all seven must stay green. `GaiaTest` covers Retribution recoil with Resist explicitly — if it fails, the flag is being reset in the wrong place.

- [ ] **Step 5: Commit**

```bash
git add scripts/core/GameState.gd scripts/core/TempestTest.gd
git commit -m "fix(combat): Retribution fires once per attack, not per damage instance"
```

---

## Task 9: Render Charge and Storm

**Files:**
- Modify: `scripts/ui/Palette.gd`, `scripts/ui/CardView.gd`, `scripts/ui/Combat.gd`

Per `CLAUDE.md`: *state the engine tracks per-unit has to be visible per-unit*. A correct-but-invisible counter is indistinguishable from broken — the spent-`Judgment` bug is exactly this shape.

- [ ] **Step 1: Add the keyword colours and help**

In `scripts/ui/Palette.gd`, add to `KEYWORD_COLORS` a `charge` and a `storm` entry in Tempest's colour, and to `KEYWORD_HELP`:

```gdscript
"charge": "Charge N — this unit banks N each time it deals damage. Spend the whole counter with its Discharge ability. Kept through evolution; lost if the unit dies.",
"storm": "Storm N — a global counter both players read. Every attack deals one extra instance of N damage; a Tempest unit's is doubled.",
```

`CardViewTest` asserts every keyword in `KEYWORD_COLORS` has help, so omitting either fails that suite.

- [ ] **Step 2: Show the live counter**

In `CardView._live_keyword_line()`, render `Charge` as the **banked value**, not the printed rate — the same rule that makes `Sanctuary N` show its remaining pool:

```gdscript
	## Charge shows what is BANKED, with the rate in parentheses. The printed
	## number is the rate; the interesting number is the counter.
	if unit != null and unit.card.has_kw("charge"):
		parts.append("Charge %d (+%d)" % [unit.charge, unit.charge_rate()])
```

- [ ] **Step 3: Add the Storm readout to Combat**

Beside the Gap row, gated on `gs.storm_is_relevant()`, in Tempest's colour.

- [ ] **Step 4: Run the UI suites**

```bash
for T in CardViewTest LayoutTest SceneSmokeTest SupportUITest; do
  echo -n "$T: "
  "$GODOT" --headless --path . --script res://scripts/core/$T.gd 2>&1 | grep -oE "[0-9]+ passed, [0-9]+ failed|OK|FAIL"
done
```

`LayoutTest` asserts no phone layout exceeds 540 units — the Storm row is new width in the top bar, so this is the assertion most likely to catch a mistake.

- [ ] **Step 5: Commit**

```bash
git add scripts/ui/Palette.gd scripts/ui/CardView.gd scripts/ui/Combat.gd
git commit -m "feat(tempest): render the Charge counter and the Storm readout"
```

---

## Task 10: Generate the cards

**Files:**
- Modify: `data/cards.json` (generated)
- Run: `tools/add_tempest_faction.py`

- [ ] **Step 1: Confirm every op is now implemented**

```bash
python tools/add_tempest_faction.py --dry-run | tail -20
```

Expected: NO "planned op(s) NOT YET IMPLEMENTED" section. If any op is still listed, its name in the GDScript does not match `PLANNED_OPS` — fix the mismatch rather than editing the op list.

- [ ] **Step 2: Apply**

```bash
python tools/add_tempest_faction.py --apply
```

Expected: `Wrote 20 cards to .../data/cards.json`

- [ ] **Step 3: Verify the data loads**

```bash
python -c "
import json
d=json.load(open('data/cards.json'))
c=d['cards'] if isinstance(d,dict) else d
t=[x for x in c if x.get('faction')=='tempest']
print(len(t),'tempest cards;',len([x for x in t if x['type']=='unit']),'units')
ids=[x['id'] for x in c]
assert len(ids)==len(set(ids)), 'duplicate ids'
print('ids unique OK')
"
```

- [ ] **Step 4: Run every suite**

All fourteen must pass. `SupportTest` asserts card-data integrity across the whole file, so it is the one that catches a malformed Tempest card.

- [ ] **Step 5: Commit**

```bash
git add data/cards.json
git commit -m "feat(tempest): add the 20 Tempest cards"
```

---

## Task 11: Card art and a sample deck

**Files:**
- Modify: `tools/make_card_art.py`, `scripts/core/DeckStore.gd`

- [ ] **Step 1: Draw the emblems**

Add one shape function per chain in `tools/make_card_art.py`. Tempest's grammar must be distinct from all five existing colours: **one closed figure, never linework** — the bestiary log records that thin linework reads as nothing at 78px, and that a figure competing with its own props loses its silhouette. Cirr/Nimb/Foehn/Sirocc/Bora/Calm each get one object drawn at three scales so a chain shares a silhouette.

- [ ] **Step 2: Regenerate and import**

```bash
python tools/make_card_art.py
"$GODOT" --headless --path . --import
```

- [ ] **Step 3: Look at them at board size**

Rasterise each at 78px and actually view them. Every previous art wave needed 2–3 redraws caught only this way; structural checks confirm an emblem exists, never that it reads as its subject.

- [ ] **Step 4: Add a sample deck**

Add one 60-card Tempest deck to `DeckStore.sample_decks()`, built on one idea. Check for stranded evolutions by hand — `errors_at()` does not catch a Stage 1 whose Basic is absent.

- [ ] **Step 5: Run DeckStoreTest and commit**

---

## Task 12: AI heuristics

**Files:**
- Modify: `scripts/core/AIPlayer.gd`

Forge's log records the trap directly: *"a cost the engine does not charge in pool energy is invisible to a heuristic that measures pool energy."* Discharge is free, so the AI's "free abilities are always taken" default will discharge a counter of 5 on turn one, every time.

- [ ] **Step 1: Add `_discharge_worth_it()`**

Refuse unless the counter is worth spending — a floor proportional to the unit's stage, and a preference for discharging when a kill is available. Model it on `_stoke_worth_it()`.

- [ ] **Step 2: Make the AI raise Storm**

`storm_raise` is a free ability with no downside for a Tempest deck, so it should almost always fire — but note it helps the opponent too.

- [ ] **Step 3: Run an AI-vs-AI sample**

Five games, Tempest against an established deck. Confirm no stalls and that Storm and Charge actually move. **This is not a balance reading** — it is a check that the faction functions.

- [ ] **Step 4: Commit**

---

## Task 13: Documentation

**Files:**
- Modify: `CLAUDE.md`
- Create: `tempest.md`

- [ ] **Step 1: Write `tempest.md`** following `forge.md`'s structure, promoting the spec's content into the permanent faction file.

- [ ] **Step 2: Update `CLAUDE.md`** — move Tempest from Future Factions into the main faction table, update the card count, add `TempestTest` to the harness table with its assertion count, and add a decision-log entry recording anything learned during the build that the spec did not predict.

- [ ] **Step 3: Final full-suite run.** Record the real numbers and report them plainly.

- [ ] **Step 4: Commit**

---

## Risks

**The Storm/tower-clock bet (spec bet #1) is untested and this plan does not test it.** Task 12's five games check that the faction *functions*. Whether Storm outruns the clock needs a real sample against the field, and the dial if it does is the `* 2` in `storm_damage_for`.

**Task 8 changes every faction's combat.** Retribution firing once per attack is a fix the spec calls for, but it alters behaviour for Gaia's `Thicket` and Forge's `Standing Heat` even at Storm 0 if the current engine fires per instance. Read the existing behaviour before changing it — if it already fires once, Task 8 is a test-only task and should be recorded as such.

**Op-reachability is a third question**, distinct from "the op works" and "the AI finds it". Forge's log records several ops that pass their harness and never fire in a real game. Task 12 step 3 is the check.
