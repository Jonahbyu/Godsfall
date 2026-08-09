# Gaia Engine Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Implement Gaia's `Earth` aura and `Essence` death trigger, the shared `Resist` keyword, and Makeshift Tower's auto-fire, so that Gaia cards can be authored against a working engine.

**Architecture:** `Earth` is a board-wide live sum computed on `GameState`, following the exact pattern `gap_for()` / `_attached_total()` already established for Void's Gap — **not** a value stored on `Unit`, because a `Unit` has no reference to its owning `Player` and the aura depends on every other unit that player controls. Every consumer (unit max HP, attack damage, tower max HP, tower damage) reads that sum at the moment it needs it, so the aura is inherently live and no invalidation logic is required. `Essence` hooks `_kill()`, the one place a unit leaves the board. `Resist` is a printed keyword read inside the two existing damage entry points.

**Tech Stack:** Godot 4.7, GDScript. Card data in `data/cards.json`. Tests are headless harness scripts run via `godot --headless --script`.

**Spec:** `docs/specs/2026-08-09-gaia-faction-design.md`
**Rules:** `CLAUDE.md` (Earth/Essence in the signature table, `Resist` in shared keywords), `gaia.md`

---

## Key Design Constraint — read before Task 1

`Unit.max_hp()` currently returns `card.max_hp` and has **no access to its owner**. The aura
must add to it. There are two possible approaches and this plan deliberately picks the second:

1. ~~Give `Unit` a back-reference to its `Player`.~~ Rejected: it makes every `Unit.new()` in
   the codebase and in five test harnesses require an owner, and creates a reference cycle.
2. **Keep `Unit.max_hp()` as the printed value, and add `GameState.effective_max_hp(p, u)`
   for the aura-adjusted value.** Callers that care about the aura call the new function.

This mirrors how Rift already works: `Unit.rift()` returns the printed stat, and `GameState`
combines it with `gap_for()` at damage time.

**Consequence to watch:** `Unit.heal()` caps at `max_hp()`, the printed value. Under the aura
a unit's effective max is higher, so healing would stop short. Task 3 addresses this.

---

## File Structure

| File | Responsibility | Change |
|---|---|---|
| `scripts/core/Unit.gd` | Printed keyword accessors | Modify — add `earth()`, `essence()`, `resist()`, `earth_bonus_hp` field |
| `scripts/core/GameState.gd` | Board-wide sums, damage, deaths, towers | Modify — add `earth_for()`, `effective_max_hp()`, Essence in `_kill()`, aura in damage + towers |
| `scripts/core/Board.gd` | Tower state | Modify — add `earth_max_hp_bonus` for clamping |
| `scripts/core/GaiaTest.gd` | Gaia harness | Create — all assertions for this plan |
| `data/cards.json` | Card data | Modify — three test-fixture Gaia cards |
| `CLAUDE.md` / `gaia.md` | Rules docs | Already updated — do not re-edit |

---

## Task 1: Printed keyword accessors on Unit

**Files:**
- Modify: `scripts/core/Unit.gd` (after `rift()`, around line 129)
- Create: `scripts/core/GaiaTest.gd`

- [ ] **Step 1: Write the failing test**

Create `scripts/core/GaiaTest.gd`. This is the harness for the whole plan; later tasks append to it.

```gdscript
extends SceneTree

## Gaia harness — Earth aura, Essence, Resist, Makeshift Tower.
## Run: godot --headless --path <project> --script res://scripts/core/GaiaTest.gd

var _pass := 0
var _fail := 0

func _check(label: String, got, want) -> void:
	if got == want:
		_pass += 1
	else:
		_fail += 1
		print("FAIL: %s — got %s, want %s" % [label, got, want])

func _ok(label: String, cond: bool) -> void:
	_check(label, cond, true)

## `_initialize()` rather than `_init()`: any test that loads GameState.gd pulls in
## the `CardDB` autoload, which is not registered during `_init()` (object
## construction) but is by `_initialize()` (tree ready). VoidTest.gd defers for the
## same reason. Later tasks add their calls to this list.
func _initialize() -> void:
	_test_printed_keywords()
	print("\nGaiaTest: %d passed, %d failed" % [_pass, _fail])
	quit(1 if _fail > 0 else 0)


func _make_card(id: String, hp: int, kws: Dictionary) -> CardData:
	var kw_list: Array = []
	for k in kws:
		kw_list.append({"kw": k, "n": kws[k]})
	return CardData.from_dict({
		"id": id, "name": id, "type": "unit", "faction": "gaia",
		"hp": hp, "keywords": kw_list,
	})


func _test_printed_keywords() -> void:
	var u := Unit.new(_make_card("t_earth", 60, {"earth": 3, "essence": 2, "resist": 5}))
	_check("earth is printed", u.earth(), 3)
	_check("essence is printed", u.essence(), 2)
	_check("resist is printed", u.resist(), 5)
	_ok("has_essence", u.has_essence())

	var bare := Unit.new(_make_card("t_bare", 50, {}))
	_check("no earth is 0", bare.earth(), 0)
	_check("no resist is 0", bare.resist(), 0)
	_ok("no essence", not bare.has_essence())
```

- [ ] **Step 2: Run it to verify it fails**

Run:
```
godot --headless --path "c:/Users/Jonah/OneDrive/Desktop/Godsfall" --script res://scripts/core/GaiaTest.gd
```
Expected: parse/runtime error — `Invalid call. Nonexistent function 'earth' in base 'Unit'`.

- [ ] **Step 3: Add the accessors**

In `scripts/core/Unit.gd`, immediately after `has_rift()` (line 129):

```gdscript
## --------------------------------------------------------------- Gaia keywords
##
## `Earth N` — this unit's contribution to its owner's board-wide aura. Printed,
## plus anything the card grew in play (see `earth_grown`). The aura itself is
## summed on GameState, because a Unit has no reference to the player whose other
## units it must count — the same reason Rift reads the Gap from there.
func earth() -> int:
	return card.kw("earth") + earth_grown


## `Essence N` — pool energy the owner may pay when this unit dies to move its
## Earth and attached energy to the nearest friendly unit on the same board.
func essence() -> int:
	return card.kw("essence")


func has_essence() -> bool:
	return card.has_kw("essence")


## `Resist X` — flat reduction on each incoming instance of damage. Shared
## keyword; any faction may print it.
func resist() -> int:
	return card.kw("resist")
```

Then add the `earth_grown` field next to the other runtime state, after line 10 (`judgment_spent`):

```gdscript
## Earth this unit has GROWN in play, above its printed value. Reset to 0 on Rise
## and on evolution: Rise restores the card, not the history (CLAUDE.md).
var earth_grown: int = 0
```

- [ ] **Step 4: Run the test to verify it passes**

Run the same command. Expected: `GaiaTest: 7 passed, 0 failed`.

---

## Task 2: The Earth aura sum on GameState

**Files:**
- Modify: `scripts/core/GameState.gd` (after `_attached_total`, around line 101)
- Modify: `scripts/core/GaiaTest.gd`

- [ ] **Step 1: Write the failing test**

Add to `GaiaTest.gd`, and add `_test_earth_sum()` to the `_init()` call list:

```gdscript
## Build a real two-player GameState with empty decks. Deck contents don't matter
## for aura tests — units are placed directly onto boards.
##
## GameState's constructor is `_init(deck_p1: Array, deck_p2: Array)` and it is
## loaded rather than referenced by class_name, matching VoidTest.gd:55.
func _new_game():
	return load("res://scripts/core/GameState.gd").new([], [])


func _place(gs: GameState, side: int, bi: int, si: int, u: Unit) -> void:
	gs.players[side].boards[bi].slots[si] = u


func _test_earth_sum() -> void:
	var gs := _new_game()
	var p: Player = gs.players[0]

	_check("empty board is 0 Earth", gs.earth_for(p), 0)

	var a := Unit.new(_make_card("e_a", 60, {"earth": 3}))
	var b := Unit.new(_make_card("e_b", 60, {"earth": 2}))
	_place(gs, 0, 0, 0, a)
	_place(gs, 0, 1, 0, b)
	_check("Earth sums across both boards", gs.earth_for(p), 5)

	## Grown Earth counts toward the aura.
	a.earth_grown = 4
	_check("grown Earth counts", gs.earth_for(p), 9)
	a.earth_grown = 0

	## Dead-but-not-cleaned units are excluded, exactly like the Gap. Within a
	## volley a corpse still sits on the board for Retribution, but its Earth is
	## already gone or the aura would outlive the body holding it.
	a.hp = 0
	_check("dead units excluded", gs.earth_for(p), 2)
	a.hp = 60

	## The aura is strictly per-player.
	_check("enemy Earth is separate", gs.earth_for(gs.players[1]), 0)
```

- [ ] **Step 2: Run it to verify it fails**

Run the harness. Expected: `Nonexistent function 'earth_for' in base 'GameState'`.

- [ ] **Step 3: Implement the sum**

In `scripts/core/GameState.gd`, immediately after `_attached_total()` (line 101):

```gdscript
## ------------------------------------------------------------------ Gaia Earth
##
## A player's total Earth: the sum across every LIVING unit they control, both
## boards. This is the aura, and it is deliberately computed on demand rather than
## cached — that is what makes it live, so a unit dying shrinks it with no
## invalidation logic anywhere.
##
## Living units only, for the same reason the Gap counts only the living: within a
## volley a unit marked dead stays on the board so it can deal Retribution, but
## counting its Earth would let a corpse hold the aura up for the rest of the
## resolution.
func earth_for(p: Player) -> int:
	var n: int = 0
	for b in p.boards:
		for u in b.units():
			if u != null and u.is_alive():
				n += u.earth()
	return n


## A unit's max HP including its owner's Earth aura. `Unit.max_hp()` stays the
## PRINTED value — a Unit has no owner reference, and giving it one would force an
## owner through every construction site in the game and the harnesses.
func effective_max_hp(p: Player, u: Unit) -> int:
	return u.max_hp() + earth_for(p) * earth_rate(p)


## Stat points each point of Earth grants, to units and towers alike. 1 by default.
## Rate-breaker cards raise it ADDITIVELY and never multiply the total: the aura
## already applies to four units and two towers, so a multiplier on the sum is
## exponential across six things (CLAUDE.md decision log).
func earth_rate(_p: Player) -> int:
	return 1
```

- [ ] **Step 4: Run the test to verify it passes**

Expected: `GaiaTest: 13 passed, 0 failed`.

---

## Task 3: Aura-aware healing and HP clamping

**Files:**
- Modify: `scripts/core/GameState.gd`
- Modify: `scripts/core/GaiaTest.gd`

The aura raises a unit's ceiling. `Unit.heal()` caps at the printed max, so without this a
Gaia unit could never be healed into its aura-granted HP. Conversely, when the aura shrinks,
a unit sitting above the new ceiling must be clamped down.

- [ ] **Step 1: Write the failing test**

Add to `GaiaTest.gd` and to `_init()`:

```gdscript
func _test_aura_healing_and_clamp() -> void:
	var gs := _new_game()
	var p: Player = gs.players[0]

	var big := Unit.new(_make_card("h_big", 60, {"earth": 5}))
	_place(gs, 0, 0, 0, big)

	## 60 printed + 5 Earth = 65 effective.
	_check("effective max includes aura", gs.effective_max_hp(p, big), 65)

	big.hp = 55
	_check("heals into aura HP", gs.heal_unit(p, big, 10), 10)
	_check("hp reached effective max", big.hp, 65)

	## Healing still stops at the effective ceiling, never above it.
	_check("no overheal", gs.heal_unit(p, big, 10), 0)
	_check("hp unchanged", big.hp, 65)

	## Aura shrinks: a second Earth body dies, so the ceiling drops and the unit
	## sitting above it is clamped down.
	var feeder := Unit.new(_make_card("h_feed", 40, {"earth": 3}))
	_place(gs, 0, 0, 1, feeder)
	_check("aura grew", gs.effective_max_hp(p, big), 68)
	gs.heal_unit(p, big, 5)
	_check("healed into the bigger aura", big.hp, 68)

	feeder.hp = 0
	gs.clamp_to_aura(p)
	_check("clamped when aura shrank", big.hp, 65)

	## Clamping never kills. A unit whose whole HP came from the aura floors at 1.
	var frail := Unit.new(_make_card("h_frail", 40, {}))
	frail.hp = 1
	_place(gs, 0, 1, 0, frail)
	gs.clamp_to_aura(p)
	_ok("clamp never kills", frail.is_alive())
```

- [ ] **Step 2: Run it to verify it fails**

Expected: `Nonexistent function 'heal_unit' in base 'GameState'`.

- [ ] **Step 3: Implement both**

In `GameState.gd`, after `earth_rate()`:

```gdscript
## Heal `u`, capped at its AURA-ADJUSTED max rather than the printed one. Callers
## that heal a unit must use this instead of Unit.heal(), or a Gaia unit can never
## be healed into the HP its own aura granted it.
func heal_unit(p: Player, u: Unit, amount: int) -> int:
	if amount <= 0 or not u.is_alive():
		return 0
	var healed: int = min(amount, effective_max_hp(p, u) - u.hp)
	if healed <= 0:
		return 0
	u.hp += healed
	return healed


## Clamp every unit down to its current effective max. Called after anything that
## can shrink the aura — a death, a retreat, an evolution.
##
## It NEVER kills: a unit floors at 1 HP. A body dying because a different unit
## died two boards away is a feel-bad with no counterplay, and it would make Gaia's
## own aura a liability against its own board (gaia.md).
func clamp_to_aura(p: Player) -> void:
	for b in p.boards:
		for u in b.units():
			if u != null and u.is_alive():
				var ceiling: int = effective_max_hp(p, u)
				if u.hp > ceiling:
					u.hp = max(1, ceiling)
```

- [ ] **Step 4: Run the test to verify it passes**

Expected: `GaiaTest: 22 passed, 0 failed`.

---

## Task 3b: Route existing heal sites through `heal_unit`

**Files:**
- Modify: `scripts/core/GameState.gd` — seven `.heal(` call sites

Task 3 added `heal_unit()` but nothing calls it. Every healing card in the game still calls
`Unit.heal()`, which caps at the **printed** max — so a Gaia unit at 60 printed + 5 aura
could only ever be healed to 60, and the aura's HP would be unreachable by any support card.

**The printed-HP cap stays load-bearing** — see the comment at `GameState.gd:785`, where
`Vigil` scales with the round and relies on a cap existing. `heal_unit` still caps; it just
caps at the effective max instead of the printed one, which is a slightly higher ceiling
rather than no ceiling. No heal becomes unbounded.

- [ ] **Step 1: Add a regression test first**

Append to `GaiaTest.gd` and add to `_initialize()`:

```gdscript
## A support heal must reach the aura's HP, not stop at the printed max.
func _test_support_heal_reaches_aura() -> void:
	var gs = _new_game()
	var p: Player = gs.players[0]
	var u := Unit.new(_make_card("sh_u", 60, {"earth": 5}))
	_place(gs, 0, 0, 0, u)
	u.hp = 50
	## 60 printed + 5 Earth = 65 effective. A 20-point heal must reach 65, not 60.
	_check("heal reaches aura ceiling", gs.heal_unit(p, u, 20), 15)
	_check("hp at effective max", u.hp, 65)
```

- [ ] **Step 2: Replace each call site**

All seven are in `scripts/core/GameState.gd`. Each is inside a support-resolution function
that already has the acting player in scope — confirm the variable name before editing
(it is `p` in the support path). Replace:

| Line | From | To |
|---|---|---|
| ~765 | `ht.heal(card.effect_value("heal", 0))` | `heal_unit(p, ht, card.effect_value("heal", 0))` |
| ~772 | `hu.heal(n3)` | `heal_unit(p, hu, n3)` |
| ~781 | `hc.heal(card.effect_value("heal_conditional", 0))` | `heal_unit(p, hc, card.effect_value("heal_conditional", 0))` |
| ~789 | `hr.heal(amount)` | `heal_unit(p, hr, amount)` |
| ~795 | `hd.heal(card.effect_value("heal_undo_decay", 0))` | `heal_unit(p, hd, card.effect_value("heal_undo_decay", 0))` |
| ~796 | `hd.heal(hd.decay_taken_this_turn)` | `heal_unit(p, hd, hd.decay_taken_this_turn)` |
| ~1484 | `u.heal(u.tool.effect_value("heal_eot", 0))` | `heal_unit(owner, u, u.tool.effect_value("heal_eot", 0))` |

The last one is in the end-of-turn Tool loop — **check what the owning player variable is
actually called there** and use it. Do not guess.

Also update the `_log` lines that print `%d/%d` with `ht.max_hp()`: they now under-report the
ceiling. Change `ht.max_hp()` to `effective_max_hp(p, ht)` in those log strings so the
message matches what actually happened.

- [ ] **Step 3: Run the Gaia harness and the full suite**

Expected: the new assertion passes, and `SupportTest.gd` (158) is unchanged — every existing
card has 0 Earth, so `effective_max_hp` equals `max_hp` and every existing heal is identical.

---

## Task 4: Aura damage on attacks

**Files:**
- Modify: `scripts/core/GameState.gd` — the attack damage calculation
- Modify: `scripts/core/GaiaTest.gd`

- [ ] **Step 1: The damage calculation site — already located**

`scripts/core/GameState.gd:1226-1246` is the single place an attack's outgoing damage is
assembled. It currently reads `atk.damage + u.tool_damage_bonus()`, then folds in Rift, then
the `damage_per_voided` rider, then calls `_deal_lane_damage`.

The Earth bonus is added **inline in that same block**, next to the Rift fold — not in a
separate `attack_damage()` helper. Keeping one readable assembly block matters more here than
extracting a function, and it puts Earth beside Rift, the mechanic it most resembles.

- [ ] **Step 2: Write the failing test**

Add to `GaiaTest.gd` and `_init()`. This drives the **real** pipeline via
`_deal_lane_damage` rather than reimplementing the arithmetic — a test that recomputes the
rule it is checking proves nothing about the engine (the pattern `HeavenTest.gd` uses):

```gdscript
func _test_aura_damage() -> void:
	var gs := _new_game()
	var p: Player = gs.players[0]
	var foe: Player = gs.players[1]

	var atk := AttackData.from_dict({
		"id": "a_swing", "name": "Swing", "damage": 10, "cost": {"gaia": 1},
	})
	var attacker := Unit.new(_make_card("d_att", 60, {"earth": 4}))
	_place(gs, 0, 0, 0, attacker)

	var target := Unit.new(_make_card("d_tgt", 100, {}))
	_place(gs, 1, 0, 0, target)

	## 10 printed + 4 Earth = 14.
	gs._deal_lane_damage(p, foe, attacker, 0, 0, gs.attack_damage(p, attacker, atk), atk)
	_check("aura adds to attack damage", target.hp, 86)

	## The aura is the ATTACKER's, never the defender's.
	var shielded := Unit.new(_make_card("d_shield", 100, {"earth": 9}))
	_place(gs, 1, 0, 1, shielded)
	target.hp = 0
	gs._deal_lane_damage(p, foe, attacker, 0, 1, gs.attack_damage(p, attacker, atk), atk)
	_check("defender Earth does not reduce damage", shielded.hp, 86)
```

- [ ] **Step 3: Run it to verify it fails**

Expected: `Nonexistent function 'attack_damage' in base 'GameState'`.

- [ ] **Step 4: Add the helper and wire it in**

In `GameState.gd`, after `clamp_to_aura()`:

```gdscript
## Total outgoing damage for one attack: printed, plus the attacker's Earth aura,
## plus any Tool bonus. Rift is folded in by the caller because it reads the Gap.
##
## The aura is the ATTACKER's — Earth grants damage, it does not reduce incoming
## damage. Resist is the keyword that does that.
func attack_damage(p: Player, u: Unit, atk: AttackData) -> int:
	return atk.damage + earth_for(p) * earth_rate(p) + u.tool_damage_bonus()
```

Then, at the damage-assembly site found in Step 1, add the Earth term alongside the existing
Rift and Tool terms so queued attacks pick it up. Keep the existing Rift arithmetic exactly
as it is; only add `+ earth_for(p) * earth_rate(p)`.

- [ ] **Step 5: Run the test to verify it passes**

Expected: `GaiaTest: 24 passed, 0 failed`.

- [ ] **Step 6: Run the full suite for regressions**

Run each of the nine existing harnesses:
```
godot --headless --path "c:/Users/Jonah/OneDrive/Desktop/Godsfall" --script res://scripts/core/RulesTest.gd
godot --headless --path "c:/Users/Jonah/OneDrive/Desktop/Godsfall" --script res://scripts/core/SupportTest.gd
godot --headless --path "c:/Users/Jonah/OneDrive/Desktop/Godsfall" --script res://scripts/core/HeavenTest.gd
godot --headless --path "c:/Users/Jonah/OneDrive/Desktop/Godsfall" --script res://scripts/core/VoidTest.gd
```
Expected: all pass. Non-Gaia cards have 0 Earth, so `earth_for()` returns 0 and every
existing damage number is unchanged. `RulesTest` and `SupportTest` carry known
AI-mirror flakes (see `CLAUDE.md`) — if one fails, capture the output and re-run before
assuming a regression.

---

## Task 5: Resist

**Files:**
- Modify: `scripts/core/GameState.gd` — `_damage_unit()` (line ~1273) and `_deal_lane_damage()` (line ~1311)
- Modify: `scripts/core/GaiaTest.gd`

- [ ] **Step 1: Write the failing test**

```gdscript
func _test_resist() -> void:
	var gs := _new_game()
	var p: Player = gs.players[0]
	var foe: Player = gs.players[1]

	var atk := AttackData.from_dict({
		"id": "r_swing", "name": "Swing", "damage": 20, "cost": {"gaia": 1},
	})
	var attacker := Unit.new(_make_card("r_att", 60, {}))
	_place(gs, 0, 0, 0, attacker)

	var wall := Unit.new(_make_card("r_wall", 100, {"resist": 5}))
	_place(gs, 1, 0, 0, wall)

	gs._deal_lane_damage(p, foe, attacker, 0, 0, 20, atk)
	_check("resist reduces each instance", wall.hp, 85)

	## The floor: Resist can never fully negate. Decay 5 into Resist 5 still lands 1.
	var tank := Unit.new(_make_card("r_tank", 100, {"resist": 99}))
	_place(gs, 1, 1, 0, tank)
	_check("minimum 1 always lands", gs._damage_unit(tank, 5, "decay"), 1)
	_check("tank took exactly 1", tank.hp, 99)

	## Sanctuary is prevention and comes first; Resist only sees what gets through.
	var both := Unit.new(_make_card("r_both", 100, {"resist": 5, "sanctuary": 60}))
	_place(gs, 1, 1, 1, both)
	_check("sanctuary absorbs before resist", gs._damage_unit(both, 30, "attack"), 0)
	_check("sanctuary pool depleted by full amount", both.sanctuary_pool, 30)
```

- [ ] **Step 2: Run it to verify it fails**

Expected: `resist reduces each instance — got 80, want 85`.

- [ ] **Step 3: Implement Resist**

Add the helper in `GameState.gd` after `attack_damage()`:

```gdscript
## Apply a defender's Resist to one instance of incoming damage.
##
## The minimum of 1 is not optional: without it a Resist 5 body makes Hel's
## Decay 5 do literally nothing, permanently, and no amount of stacking fixes it
## (CLAUDE.md). Resist runs AFTER Sanctuary — Sanctuary is prevention and absorbs
## whole instances, so it must see the full amount.
func _apply_resist(target: Unit, amount: int) -> int:
	if amount <= 0:
		return amount
	var r: int = target.resist()
	if r <= 0:
		return amount
	return max(1, amount - r)
```

In `_damage_unit()`, apply it to the post-Sanctuary value. Replace:

```gdscript
	return target.take_damage(through)
```

with:

```gdscript
	return target.take_damage(_apply_resist(target, through))
```

In `_deal_lane_damage()`, at step 3, replace:

```gdscript
		var dealt := defender.take_damage(through)
```

with:

```gdscript
		## Step 3a: Resist blunts what Sanctuary let through, floored at 1.
		var dealt := defender.take_damage(_apply_resist(defender, through))
```

- [ ] **Step 4: Run the test to verify it passes**

Expected: `GaiaTest: 30 passed, 0 failed`.

---

## Task 5b: Resist applies to Retribution recoil

**Files:**
- Modify: `scripts/core/GameState.gd:~1441`
- Modify: `scripts/core/GaiaTest.gd`

`Resist X` reads *"reduce each incoming instance of damage by X."* Retribution recoil is an
instance of damage, so it must be resisted. The recoil site at `GameState.gd:1441` calls
`u.take_damage(retr)` directly, bypassing `_apply_resist`.

**Scope note — do not widen this.** That same line also bypasses **Sanctuary**, even though
`CLAUDE.md` says Sanctuary "blocks all damage sources — attacks, tower fire, `Decay`, support
damage, `Retribution`." That is a **pre-existing** divergence between the rules and the code,
it predates Gaia, and fixing it would change Heaven's behaviour. **Leave Sanctuary alone** and
record the divergence in Open Questions instead — it is Jonah's call, not this plan's.

- [ ] **Step 1: Add the test**

```gdscript
## Retribution recoil is an instance of damage, so Resist blunts it.
func _test_resist_on_retribution() -> void:
	var gs = _new_game()
	var p: Player = gs.players[0]
	var foe: Player = gs.players[1]

	var atk := AttackData.from_dict({
		"id": "rr_swing", "name": "Swing", "damage": 10, "cost": {"gaia": 1},
	})
	## The attacker has Resist 4 and will eat the recoil.
	var attacker := Unit.new(_make_card("rr_att", 100, {"resist": 4}))
	_place(gs, 0, 0, 0, attacker)
	## The defender punches back for 10.
	var thorns := Unit.new(_make_card("rr_def", 100, {"retribution": 10}))
	_place(gs, 1, 0, 0, thorns)

	gs._resolve_line_effects(p, foe, attacker, atk, null, 0, 0)
	_check("recoil is resisted", attacker.hp, 94)
	_check("defender still took the hit", thorns.hp, 90)
```

- [ ] **Step 2: Wire it**

Replace `var r := u.take_damage(retr)` with `var r := u.take_damage(_apply_resist(u, retr))`.

Leave the surrounding Sanctuary behaviour exactly as it is.

- [ ] **Step 3: Run the Gaia harness and all four existing harnesses**

`RulesTest.gd` covers Retribution and must stay at 84.

---

## Task 6: The Earth aura on towers

**Files:**
- Modify: `scripts/core/Board.gd`
- Modify: `scripts/core/GameState.gd` — `_resolve_towers()` (line ~1459)
- Modify: `scripts/core/GaiaTest.gd`

Towers get `+1 max HP and +1 damage per Earth`. Tower max HP is **stored state** (`tower_max_hp`),
unlike unit max HP which is computed — so the aura's contribution must be tracked separately
and re-applied when it changes, or repeated recalculation would compound it.

- [ ] **Step 1: Write the failing test**

```gdscript
func _test_tower_aura() -> void:
	var gs := _new_game()
	var p: Player = gs.players[0]
	var b: Board = p.boards[0]

	_check("tower starts at printed max", b.tower_max_hp, 50)

	var e := Unit.new(_make_card("t_e", 60, {"earth": 6}))
	_place(gs, 0, 0, 0, e)
	gs.sync_tower_aura(p)
	_check("tower max HP gains the aura", b.tower_max_hp, 56)
	_check("current HP rises with it", b.tower_hp, 56)

	## Idempotent — syncing twice must not compound.
	gs.sync_tower_aura(p)
	_check("sync is idempotent", b.tower_max_hp, 56)

	## Aura shrinks when the Earth body dies.
	e.hp = 0
	gs.sync_tower_aura(p)
	_check("tower max HP falls back", b.tower_max_hp, 50)
	_check("current HP clamped down", b.tower_hp, 50)

	## The aura must never kill a tower.
	e.hp = 60
	gs.sync_tower_aura(p)
	b.tower_hp = 1
	e.hp = 0
	gs.sync_tower_aura(p)
	_ok("aura shrinking never kills a tower", b.tower_alive())
```

- [ ] **Step 2: Run it to verify it fails**

Expected: `Nonexistent function 'sync_tower_aura' in base 'GameState'`.

- [ ] **Step 3: Track the aura's contribution on Board**

In `scripts/core/Board.gd`, after `tower_damage_bonus` (line 26):

```gdscript
## Max HP currently granted by a Gaia Earth aura. Tracked separately from
## tower_max_hp because the aura is LIVE — it rises and falls as Earth units come
## and go — so the engine has to know how much of the current max came from it in
## order to take exactly that much back. Tower support bonuses are permanent and
## are deliberately not tracked this way.
var earth_max_hp_bonus: int = 0
```

- [ ] **Step 4: Implement the sync**

In `GameState.gd`, after `clamp_to_aura()`:

```gdscript
## Re-apply the Earth aura to both of a player's towers. Idempotent: it removes
## the bonus it granted last time before granting the new one, so it can be called
## after any board change without compounding.
##
## Unlike a unit's max HP — which is computed on demand — a tower's max HP is
## stored state, so the aura's share of it has to be tracked explicitly.
##
## Growing the aura raises current HP too: a tower that gains 6 max HP from a new
## Earth body should actually be 6 tougher, not merely have a higher ceiling.
## Shrinking clamps current HP down but NEVER kills — the tower floors at 1.
func sync_tower_aura(p: Player) -> void:
	var bonus: int = earth_for(p) * earth_rate(p)
	for b in p.boards:
		if not b.tower_alive():
			b.earth_max_hp_bonus = 0
			continue
		var delta: int = bonus - b.earth_max_hp_bonus
		if delta == 0:
			continue
		b.tower_max_hp += delta
		b.earth_max_hp_bonus = bonus
		if delta > 0:
			b.tower_hp += delta
		elif b.tower_hp > b.tower_max_hp:
			b.tower_hp = max(1, b.tower_max_hp)
```

- [ ] **Step 5: Add the aura to tower damage**

In `_resolve_towers()`, the strike currently reads:

```gdscript
			_tower_strike(owner, enemy, bi, base + b.tower_damage_bonus, "tower fire")
```

Change to:

```gdscript
			_tower_strike(owner, enemy, bi, base + b.tower_damage_bonus + earth_for(owner) * earth_rate(owner), "tower fire")
```

Leave the crossfire line unchanged — the aura buffs a tower's main shot, not every mod effect.

- [ ] **Step 6: Call the sync wherever the board changes**

Add `sync_tower_aura(p)` and `clamp_to_aura(p)` immediately after each site that can change
a player's living-unit set. Find them with:

```
grep -n "_cleanup_dead\|func play_unit\|func evolve\|func retreat" scripts/core/GameState.gd
```

At minimum: the end of `_cleanup_dead(p)`, and after a successful `play_unit` (line ~122),
`evolve` (line ~162), and `retreat` (line ~198 — the signature is
`retreat(p, u, free := false, from_pool := false)`, there is no `retreat_unit`). Both
functions are cheap and idempotent, so calling them defensively is correct — the aura is
only ever read from live state.

- [ ] **Step 7: Run the test to verify it passes**

Expected: `GaiaTest: 37 passed, 0 failed`.

- [ ] **Step 8: Re-run the full suite**

Same four commands as Task 4 Step 6. Expected: all pass.

---

## Task 7: Essence

**Files:**
- Modify: `scripts/core/GameState.gd` — `_kill()` (line ~1532)
- Modify: `scripts/core/GaiaTest.gd`

`Essence N`: on death, if the owner has N pool energy, they may pay it to move this unit's
Earth and attached energy to the **nearest living friendly unit on the same board**.

- [ ] **Step 1: Write the failing test**

```gdscript
func _test_essence() -> void:
	var gs := _new_game()
	var p: Player = gs.players[0]
	var b: Board = p.boards[0]

	## Dying unit in slot 0, heir in slot 1, same board.
	var dying := Unit.new(_make_card("es_dying", 60, {"essence": 2, "earth": 3}))
	dying.attached = 4
	var heir := Unit.new(_make_card("es_heir", 80, {}))
	_place(gs, 0, 0, 0, dying)
	_place(gs, 0, 0, 1, heir)

	p.pool = 5
	dying.hp = 0
	gs._cleanup_dead(p)

	_check("pool paid the essence cost", p.pool, 3)
	_check("attached energy carried forward", heir.attached, 4)
	_check("earth carried forward", heir.earth_grown, 3)
	_check("board Earth preserved", gs.earth_for(p), 3)

	## Cannot afford: the unit dies normally and everything is lost.
	var gs2 := _new_game()
	var p2: Player = gs2.players[0]
	var poor := Unit.new(_make_card("es_poor", 60, {"essence": 3, "earth": 2}))
	poor.attached = 5
	var heir2 := Unit.new(_make_card("es_h2", 80, {}))
	_place(gs2, 0, 0, 0, poor)
	_place(gs2, 0, 0, 1, heir2)
	p2.pool = 1
	poor.hp = 0
	gs2._cleanup_dead(p2)
	_check("unaffordable essence pays nothing", p2.pool, 1)
	_check("energy lost as normal", heir2.attached, 0)
	_check("earth lost as normal", heir2.earth_grown, 0)

	## Empty board: Essence fizzles rather than crossing to the other board.
	var gs3 := _new_game()
	var p3: Player = gs3.players[0]
	var alone := Unit.new(_make_card("es_alone", 60, {"essence": 1, "earth": 2}))
	alone.attached = 3
	var other_board := Unit.new(_make_card("es_ob", 80, {}))
	_place(gs3, 0, 0, 0, alone)
	_place(gs3, 0, 1, 0, other_board)
	p3.pool = 5
	alone.hp = 0
	gs3._cleanup_dead(p3)
	_check("never crosses boards", other_board.attached, 0)
	_check("fizzle costs nothing", p3.pool, 5)

	## Only transfers to a SURVIVOR: an heir that is also dying is skipped.
	var gs4 := _new_game()
	var p4: Player = gs4.players[0]
	var d4 := Unit.new(_make_card("es_d4", 60, {"essence": 1, "earth": 5}))
	d4.attached = 2
	var dead_heir := Unit.new(_make_card("es_dh", 60, {}))
	var live_heir := Unit.new(_make_card("es_lh", 60, {}))
	_place(gs4, 0, 0, 0, d4)
	_place(gs4, 0, 0, 1, dead_heir)
	_place(gs4, 0, 0, 2, live_heir)
	p4.pool = 5
	d4.hp = 0
	dead_heir.hp = 0
	gs4._cleanup_dead(p4)
	_check("skips a dying heir", dead_heir.attached, 0)
	_check("transfers to the survivor", live_heir.attached, 2)
	_check("earth to the survivor", live_heir.earth_grown, 5)
```

- [ ] **Step 2: Run it to verify it fails**

Expected: `pool paid the essence cost — got 5, want 3`.

- [ ] **Step 3: Implement Essence**

In `GameState.gd`, add before `_kill()`:

```gdscript
## The nearest living friendly unit to slot `si` on board `b`, or null.
##
## Nearest is by slot distance, ties going left — the same leftmost-wins tiebreak
## the targeting chain uses, so there is one rule for "which unit" in the game.
## Strictly per-board: no rule in this game crosses boards, and crossing would make
## Essence best at exactly the moment it should fail — when the board it defended
## has been cleared.
func _nearest_living_on_board(b: Board, si: int) -> Unit:
	var best: Unit = null
	var best_d: int = 99
	for i in Board.SLOT_COUNT:
		if i == si:
			continue
		var u: Unit = b.slots[i]
		## is_alive() is what implements "only to a survivor": in a batched death
		## the other corpses are still sitting in their slots and must be skipped.
		if u == null or not u.is_alive():
			continue
		var d: int = abs(i - si)
		if d < best_d:
			best_d = d
			best = u
	return best


## Essence: pay N from the pool to move a dying unit's Earth and attached energy
## to the nearest living friendly unit on the same board.
##
## This is the deliberate exception to "attached energy is lost when the unit dies"
## (CLAUDE.md). It is priced rather than free: the energy must have been banked
## BEFORE the death, so a board wipe still lands — you can only afford one or two
## funerals. Gaia has no ramp, which is what makes carrying the energy forward
## necessary rather than greedy.
##
## Returns true if the transfer happened.
func _try_essence(p: Player, b: Board, si: int, u: Unit) -> bool:
	if not u.has_essence():
		return false
	var cost: int = u.essence()
	if p.pool < cost:
		return false
	var heir: Unit = _nearest_living_on_board(b, si)
	if heir == null:
		return false

	p.pool -= cost
	heir.attached += u.attached
	heir.earth_grown += u.earth()
	u.attached = 0
	_log("  Essence: %s pays %d to pass %d energy and %d Earth to %s." % [
		u.card.name, cost, heir.attached, u.earth(), heir.card.name
	])
	return true
```

In `_kill()`, insert the call **before** the Toll block, so the energy moves before the
"attached energy lost" log line reads it:

```gdscript
	## Essence moves the investment off the body before it is lost.
	_try_essence(p, b, si, u)
```

- [ ] **Step 4: Run the test to verify it passes**

Expected: `GaiaTest: 50 passed, 0 failed`.

- [ ] **Step 5: Prompt the player instead of auto-paying**

The rule is *"you **may** pay"*. Route the decision through the existing `choice_required`
signal, which already auto-resolves for AI players and headless harnesses so nothing hangs.

Replace the direct `p.pool -= cost` path with a `_choose_from` call offering two options,
following the pattern at `GameState.gd:765`. The headless auto-resolver takes the first
option, so **list "pay" first** to keep the tests above passing unchanged.

- [ ] **Step 6: Re-run the Gaia harness and the full suite**

Expected: `GaiaTest: 50 passed, 0 failed`, and all four existing harnesses pass.

---

## Task 8: Earth resets on Rise and evolution

**Files:**
- Modify: `scripts/core/Unit.gd` — `make_risen()` (line ~285) and `evolve_into()` (line ~300)
- Modify: `scripts/core/GaiaTest.gd`

`CLAUDE.md`: *Rise restores the card, not the history.* Grown Earth is lost, exactly as
attached energy is.

- [ ] **Step 1: Write the failing test**

```gdscript
func _test_earth_resets() -> void:
	var u := Unit.new(_make_card("rz_a", 60, {"earth": 2, "rise": 0}))
	u.earth_grown = 7
	_check("grown earth counts before death", u.earth(), 9)

	var risen := u.make_risen()
	_check("risen keeps printed earth", risen.earth(), 2)
	_check("risen loses grown earth", risen.earth_grown, 0)

	## Evolution is a new printed card, so grown Earth does not carry either.
	var evo := Unit.new(_make_card("rz_b", 60, {"earth": 1}))
	evo.earth_grown = 5
	evo.evolve_into(_make_card("rz_c", 100, {"earth": 3}))
	_check("evolved uses the new printed earth", evo.earth(), 3)
	_check("evolved loses grown earth", evo.earth_grown, 0)
```

- [ ] **Step 2: Run it to verify it fails**

Expected: `risen loses grown earth — got 7, want 0`.

- [ ] **Step 3: Reset in both places**

In `make_risen()`, after `u.attached = 0`:

```gdscript
	## Earth grown in play is lost with the body, exactly as attached energy is.
	## Rise restores the card, not the history (CLAUDE.md).
	u.earth_grown = 0
```

In `evolve_into()`, after `judgment_spent = false`:

```gdscript
	earth_grown = 0                          ## new printed card, new Earth
```

- [ ] **Step 4: Run the test to verify it passes**

Expected: `GaiaTest: 54 passed, 0 failed`.

---

## Task 9: Makeshift Tower auto-fire

**Files:**
- Modify: `scripts/core/GameState.gd` — end-of-turn resolution
- Modify: `data/cards.json`
- Modify: `scripts/core/GaiaTest.gd`

A unit that fires automatically at end of turn — free, no energy, no queueing — and gains
+5 max HP per round like a real tower. It is a unit in every other respect: it shields, it
receives the aura, and **an enemy attack may name it as a target**, which is the entire cost
of the card.

- [ ] **Step 1: Write the failing test**

```gdscript
func _test_makeshift_tower() -> void:
	var gs := _new_game()
	var p: Player = gs.players[0]
	var foe: Player = gs.players[1]

	var mt_card := CardData.from_dict({
		"id": "gaia_makeshift_tower", "name": "Makeshift Tower", "type": "unit",
		"faction": "gaia", "hp": 50, "retreat": 1,
		"keywords": [{"kw": "earth", "n": 1}],
		"effects": [{"op": "auto_fire", "n": 10}, {"op": "tower_growth", "n": 5}],
	})
	var mt := Unit.new(mt_card)
	_place(gs, 0, 0, 0, mt)

	var victim := Unit.new(_make_card("mt_v", 100, {}))
	_place(gs, 1, 0, 0, victim)

	## 10 printed + 1 own Earth = 11.
	gs.resolve_auto_fire(p, foe)
	_check("auto-fires without energy", victim.hp, 89)
	_check("spent no energy", mt.attached, 0)

	## It grows like a tower.
	var before: int = mt.max_hp()
	gs.grow_auto_towers(p)
	_check("gains 5 max HP per round", mt.max_hp(), before + 5)
	_check("current HP grows too", mt.hp, 55)
```

- [ ] **Step 2: Run it to verify it fails**

Expected: `Nonexistent function 'resolve_auto_fire' in base 'GameState'`.

- [ ] **Step 3: Add per-unit HP growth to Unit**

Makeshift Tower's max HP grows, but `Unit.max_hp()` returns the printed value. Add a growth
field, in `Unit.gd` next to `earth_grown`:

```gdscript
## Max HP this unit has grown in play. Makeshift Tower gains +5 a round the way a
## real tower does; nothing else in the game does this. Like earth_grown it is
## history, so Rise and evolution reset it.
var hp_grown: int = 0
```

Change `max_hp()`:

```gdscript
func max_hp() -> int:
	return card.max_hp + hp_grown
```

Reset it alongside `earth_grown` in both `make_risen()` and `evolve_into()`.

- [ ] **Step 4: Implement auto-fire**

In `GameState.gd`:

```gdscript
## Units that fire on their own at end of turn — Makeshift Tower. Free, no energy,
## no queueing: the card is a rule-breaker on "energy only buys attacks", and it
## pays for it by being an ordinary targetable unit that dies the turn it lands.
##
## It resolves through the standard targeting chain like any other damage, so it
## respects shielding and cannot reach past a living board.
func resolve_auto_fire(p: Player, enemy: Player) -> void:
	var bonus: int = earth_for(p) * earth_rate(p)
	for bi in p.boards.size():
		var b: Board = p.boards[bi]
		for si in Board.SLOT_COUNT:
			var u: Unit = b.slots[si]
			if u == null or not u.is_alive():
				continue
			if not u.card.has_effect("auto_fire"):
				continue
			var dmg: int = u.card.effect_value("auto_fire", 0) + bonus
			var atk := AttackData.from_dict({
				"id": "auto_fire", "name": "Auto-fire", "damage": dmg,
			})
			_deal_lane_damage(p, enemy, u, bi, si, dmg, atk)


## +5 max HP a round for auto-fire units, matching a real tower's growth.
func grow_auto_towers(p: Player) -> void:
	for b in p.boards:
		for u in b.units():
			if u == null or not u.is_alive():
				continue
			if u.card.has_effect("tower_growth"):
				var n: int = u.card.effect_value("tower_growth", 5)
				u.hp_grown += n
				u.hp += n
```

- [ ] **Step 5: Wire into end-of-turn resolution**

Find the end-of-turn sequence:
```
grep -n "_resolve_towers\|func end_turn" scripts/core/GameState.gd
```

Per `CLAUDE.md`'s turn structure, auto-fire is an attack, so it resolves with queued attacks
at **step 1** — before end-of-turn effects and before towers fire. Call `resolve_auto_fire`
immediately after the queued-attack volley, and `grow_auto_towers` next to the existing
tower `+5` growth at step 4.

- [ ] **Step 6: Add the card to data/cards.json**

Note the unit `effects` array: `CardData.from_dict` currently returns early for units before
reading `effects` (line 74-78). Move the `c.effects = d.get("effects", [])` line so it runs
for units too, keeping `permanent`/`cost` on the support-only path.

```json
{
  "id": "gaia_makeshift_tower",
  "name": "Makeshift Tower",
  "type": "unit",
  "faction": "gaia",
  "stage": "basic",
  "hp": 50,
  "retreat": 1,
  "keywords": [{ "kw": "earth", "n": 1 }],
  "effects": [
    { "op": "auto_fire", "n": 10 },
    { "op": "tower_growth", "n": 5 }
  ],
  "text": "Fires at the unit across from it at end of turn, free. Gains +5 max HP each round.",
  "flavor": "Stones remember the shape they were stacked in.",
  "attacks": []
}
```

- [ ] **Step 7: Run the test to verify it passes**

Expected: `GaiaTest: 60 passed, 0 failed`.

- [ ] **Step 8: Re-run the full suite**

All four existing harnesses plus `GaiaTest`. Expected: all pass.

---

## Task 10: The attached-energy Earth body and the rate-breaker

**Files:**
- Modify: `scripts/core/Unit.gd` — `earth()`
- Modify: `scripts/core/GameState.gd` — `earth_rate()`
- Modify: `data/cards.json`
- Modify: `scripts/core/GaiaTest.gd`

- [ ] **Step 1: Write the failing test**

```gdscript
func _test_derived_earth_and_rate() -> void:
	var gs := _new_game()
	var p: Player = gs.players[0]

	## Earth = attached energy, live and continuous.
	var card := CardData.from_dict({
		"id": "gaia_living_conduit", "name": "Living Conduit", "type": "unit",
		"faction": "gaia", "hp": 70, "retreat": 1,
		"effects": [{"op": "earth_from_attached", "n": 1}],
	})
	var conduit := Unit.new(card)
	_place(gs, 0, 0, 0, conduit)
	_check("no energy is no Earth", gs.earth_for(p), 0)

	conduit.attached = 4
	_check("Earth tracks attached energy", gs.earth_for(p), 4)
	conduit.attached = 1
	_check("Earth falls with the energy", gs.earth_for(p), 1)

	## The rate-breaker: additive, never multiplicative.
	var breaker := CardData.from_dict({
		"id": "gaia_deep_roots", "name": "Deep Roots", "type": "unit",
		"faction": "gaia", "hp": 90, "retreat": 2,
		"keywords": [{"kw": "earth", "n": 2}],
		"effects": [{"op": "earth_rate", "n": 1}],
	})
	_place(gs, 0, 0, 1, Unit.new(breaker))
	_check("Earth total", gs.earth_for(p), 3)
	_check("rate raised to 2", gs.earth_rate(p), 2)

	## 70 printed + 3 Earth x rate 2 = 76.
	_check("aura uses the raised rate", gs.effective_max_hp(p, conduit), 76)
```

- [ ] **Step 2: Run it to verify it fails**

Expected: `Earth tracks attached energy — got 0, want 4`.

- [ ] **Step 3: Derive Earth from attached energy**

In `Unit.gd`, change `earth()`:

```gdscript
func earth() -> int:
	var n: int = card.kw("earth") + earth_grown
	## Living Conduit: Earth equals attached energy, live and continuous. Read
	## rather than banked — attacking does not spend attached energy, so a version
	## that BANKED Earth per attack would grant the same energy's worth every turn
	## forever (gaia.md).
	if card.has_effect("earth_from_attached"):
		n += attached * card.effect_value("earth_from_attached", 1)
	return n
```

- [ ] **Step 4: Implement the additive rate**

In `GameState.gd`, replace the `earth_rate()` stub:

```gdscript
func earth_rate(p: Player) -> int:
	var rate: int = 1
	for b in p.boards:
		for u in b.units():
			if u != null and u.is_alive() and u.card.has_effect("earth_rate"):
				rate += u.card.effect_value("earth_rate", 1)
	return rate
```

Note the signature changes from `_p` to `p` — update the call in `effective_max_hp()` if the
parameter was left unnamed.

- [ ] **Step 5: Add both cards to data/cards.json**

```json
{
  "id": "gaia_living_conduit",
  "name": "Living Conduit",
  "type": "unit",
  "faction": "gaia",
  "stage": "basic",
  "hp": 70,
  "retreat": 1,
  "keywords": [{ "kw": "essence", "n": 1 }],
  "effects": [{ "op": "earth_from_attached", "n": 1 }],
  "text": "Earth equal to its attached energy.",
  "flavor": "What it drinks, the grove feels.",
  "attacks": [
    {
      "id": "conduit_swell", "name": "Swell",
      "cost": { "gaia": 2 }, "damage": 18
    }
  ]
},
{
  "id": "gaia_deep_roots",
  "name": "Deep Roots",
  "type": "unit",
  "faction": "gaia",
  "stage": "stage1",
  "evolves_from": "gaia_living_conduit",
  "hp": 110,
  "retreat": 2,
  "keywords": [{ "kw": "earth", "n": 2 }, { "kw": "essence", "n": 2 }],
  "effects": [{ "op": "earth_rate", "n": 1 }],
  "text": "Earth grants +2 instead of +1.",
  "flavor": "Down far enough, every stone is one stone.",
  "attacks": [
    {
      "id": "roots_upheaval", "name": "Upheaval",
      "cost": { "gaia": 3 }, "damage": 26
    }
  ]
}
```

- [ ] **Step 6: Run the test to verify it passes**

Expected: `GaiaTest: 67 passed, 0 failed`.

- [ ] **Step 7: Run the complete suite**

All nine existing harnesses plus `GaiaTest`. Expected: all pass, with the two known
AI-mirror flakes (`RulesTest`, `SupportTest`) re-run and captured if they trip.

---

## Task 11: Update the docs

**Files:**
- Modify: `gaia.md`
- Modify: `CLAUDE.md`

- [ ] **Step 1: Update `gaia.md`'s status line**

Replace the status block with what is actually built — number of cards, which keywords are
implemented, and the `GaiaTest.gd` assertion count. **Only claim what was run this session.**

- [ ] **Step 2: Add `GaiaTest.gd` to `CLAUDE.md`'s harness table**

Add a row to the nine-harness table naming what it covers, and update the count in the
sentence above it.

- [ ] **Step 3: Record the aura/quarter-rate interaction in Open Questions**

`CLAUDE.md` already establishes that towers reach structures — enemy towers and the throne —
at a **quarter rate** once the board in front of them is clear, and that the constraint on
towers is about *rate*, not *reach*. That rule is unchanged and correct; Gaia does not alter
it. What is new is that Gaia is the first faction to **scale tower damage off its own board
state**, so the aura feeds that chip. Add to `gaia.md` Open Questions:

> **The Earth aura feeds quarter-rate tower chip.** `CLAUDE.md` lets a tower reach an enemy
> tower or throne at a quarter rate once the board in front of it is clear, and Gaia's aura
> raises the number that quarter is taken from — at 12 Earth that is +3 a turn to a throne
> from a keyword whose text never mentions the throne. The quarter and the "no card may
> raise the rate" rule are both intact, and no Gaia card touches either. What is new is that
> Gaia is the first faction whose *board* scales tower damage, so this is the first time the
> chip grows without a tower support card being played. Watch whether it matters.

- [ ] **Step 4: Do not claim more than was verified**

`CLAUDE.md` requires "harness passes" to mean it was run this session. State plainly what
was and was not run.

---

## Not In This Plan

Deliberately excluded, each needing its own plan:

- **The rest of the Gaia card set** — this plan adds three fixture cards to exercise the
  engine, not a playable faction. A full set is ~15 units, an energy card, supports, and
  evolution lines.
- **AI heuristics.** `AIPlayer` has no notion of Earth, will not protect the aura, and will
  not hold pool for Essence. **AI results are not a balance reading for Gaia** until it does
  — the same caveat Heaven and Void carry.
- **Sample decks.**
- **Card art.** Art-less cards fall back to `CardView`'s initials placeholder by design.
- **UI for Essence.** Task 7 routes the prompt through `choice_required`, which the combat
  screen already renders; a dedicated "decline all" affordance for multi-death turns is
  noted in `gaia.md` Open Questions.
