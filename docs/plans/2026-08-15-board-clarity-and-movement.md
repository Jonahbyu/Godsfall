# Board Clarity and Free Movement Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the board direct to manipulate and self-explanatory — units drag freely between slots and boards, supports drag onto their target, keywords explain themselves on hover, and the Void Gap becomes visible when it matters.

**Architecture:** Six independent changes. One is an engine rule (`GameState.move_unit`) with a card repurpose behind it; the rest are UI-only and touch `CardView.gd` and `Combat.gd`. Every new rule is asserted in a headless harness before the UI is wired to it, and every harness's `EXPECTED_ASSERTIONS` guard is updated deliberately in the same commit as the assertions it counts.

**Tech Stack:** Godot 4.7, GDScript. Headless harnesses run via `godot --headless --path . --script res://scripts/core/<Name>.gd`.

---

## Design decisions locked in before coding

These were settled in conversation and the docs must end up agreeing with them.

| Decision | Value | Why |
|---|---|---|
| Movement cost | **Free, unlimited** | Jonah's call. Chosen over once-per-turn for maximum directness. |
| Movement reach | Either of **your own** boards, into any empty usable slot | Crossing boards is the point — lanes are independent fights, so moving between them is the interesting decision. |
| `Reposition` | **Repurposed**, not left dead | Free movement makes "swap two of your units" almost worthless. See Task 3. |
| Gap readout | Shown **only when Void is present** in either deck | Jonah's constraint. A permanent Gap meter is clutter in the ~3/4 of matchups with no Void card. |
| Attached badge | Bottom-left of the card frame: **faction symbol + number** | The footer's bottom-left currently holds the reserved `wk —` / `res —` slots; the badge goes left of them. |

### The rule change this makes to CLAUDE.md

`CLAUDE.md` currently forbids free repositioning in two places, and both must be rewritten
rather than left contradicting the code:

1. The *Deckbuilding → Cards can be clicked or dragged* paragraph ("There is deliberately
   **no free drag-to-rearrange**…").
2. The decision-log entry beginning "**Drag-and-drop is an input method, never a new rule.**"

`Combat.gd:15-16` carries the same claim as a header comment and must be rewritten too.

---

## File Structure

| File | Responsibility | Change |
|---|---|---|
| `scripts/core/GameState.gd` | The move primitive and the repurposed `Reposition` op | Modify |
| `scripts/core/RulesTest.gd` | Asserts the move rule | Modify |
| `scripts/core/SupportTest.gd` | Asserts the repurposed card | Modify |
| `data/cards.json` | `Reposition`'s new text and effect | Modify |
| `scripts/ui/CardView.gd` | Keyword tooltips, attached-energy badge, board drag payload | Modify |
| `scripts/ui/Combat.gd` | Unit drag source, unit/slot drop targets, support drop targets, "in use" banner, Gap readout | Modify |
| `scripts/ui/Theme.gd` | `KEYWORD_HELP` table backing the tooltips | Modify |
| `scripts/core/CardViewTest.gd` | Asserts tooltips and the badge | Modify |
| `scripts/core/LayoutTest.gd` | Glyph scan already covers these files; count moves | Modify |
| `CLAUDE.md` | Rule change + decision-log entries | Modify |

---

## Task 1: The `move_unit` engine primitive

**Files:**
- Modify: `scripts/core/GameState.gd` (add `move_unit`, near `_do_swap_slots` at line 1206)
- Test: `scripts/core/RulesTest.gd`

- [ ] **Step 1: Write the failing test**

Add this function to `scripts/core/RulesTest.gd`, and call it from `_run()` alongside the
other `_test_*` calls:

```gdscript
## Free repositioning. Adopted 2026-08-15: a unit may move to any empty usable slot on
## either of the player's own boards, free and unlimited. The engine primitive is what
## the UI's drag-to-move calls; `Reposition` was repurposed because free movement made
## its printed effect near-worthless.
func _test_move_unit(GS, CardDataC) -> void:
	var gs = _game(GS)
	var p = gs.players[GS.P1]
	var u = _basic_unit(CardDataC, "mover", 60)
	p.boards[0].slots[0] = u

	## Same board, into an empty slot.
	_check("move to empty slot", gs.move_unit(p, u, 0, 1), true)
	_check("vacated the old slot", p.boards[0].slots[0], null)
	_check("occupies the new slot", p.boards[0].slots[1], u)

	## Across to the other board — lanes are independent, so this is legal and is
	## the whole reason movement is interesting.
	_check("move across boards", gs.move_unit(p, u, 1, 0), true)
	_check("left board 0 entirely", p.boards[0].unit_at(1), null)
	_check("arrived on board 1", p.boards[1].slots[0], u)

	## Attached energy rides along. A move is not a retreat and not a death.
	u.attached = 4
	gs.move_unit(p, u, 1, 1)
	_check("attached energy moves with the unit", u.attached, 4)

	## Illegal destinations are refused rather than silently doing nothing weird.
	var other = _basic_unit(CardDataC, "blocker", 60)
	p.boards[1].slots[0] = other
	_check("occupied slot refused", gs.move_unit(p, u, 1, 0), false)
	_check("unit did not move", p.boards[1].slots[1], u)
	_check("tower slot refused while tower lives",
		gs.move_unit(p, u, 1, Board.TOWER_SLOT), false)
	_check("moving to its own slot is a no-op", gs.move_unit(p, u, 1, 1), false)

	## A dead unit is not on the board in any meaningful sense.
	u.hp = 0
	_check("dead unit cannot move", gs.move_unit(p, u, 1, 0), false)
```

If `RulesTest.gd` has no `_basic_unit` helper, add this one next to `_game`:

```gdscript
## A minimal living Basic, for tests that only need a body in a slot.
func _basic_unit(CardDataC, id: String, hp: int):
	var c = CardDataC.new()
	c.id = id
	c.name = id
	c.type = CardDataC.Type.UNIT
	c.stage = CardDataC.Stage.BASIC
	c.hp = hp
	var u = load("res://scripts/core/Unit.gd").new(c)
	u.hp = hp
	return u
```

- [ ] **Step 2: Run the test and verify it fails**

```
godot --headless --path . --script res://scripts/core/RulesTest.gd
```

Expected: FAIL. `move_unit` does not exist, so the run aborts with
`Invalid call. Nonexistent function 'move_unit' in base 'GameState'`.

- [ ] **Step 3: Write the implementation**

Add to `scripts/core/GameState.gd`, immediately after `_do_swap_slots` (line 1206):

```gdscript
## Move one of your own units to an empty slot, on either of your boards.
##
## Free and unlimited, adopted 2026-08-15. This was forbidden until now on the
## reasoning that placement *is* targeting and that repositioning is the printed
## effect of `Reposition` — but chosen targeting had already retired the first half
## of that argument (an attack may name any living unit, so placement is the default
## rather than the only lever), and the card was repurposed rather than left dead.
##
## What movement still decides, and why it is not free of consequence: which of your
## units eats the tower shot, which one shields the structures behind it, and which
## slot an unnamed enemy attack faces. So it is a real decision, just no longer one
## that costs a card.
##
## Deliberately NOT a retreat: no cost is paid, no death effect fires, attached energy
## rides along untouched, and the unit is not locked. It never leaves the board.
func move_unit(p: Player, u: Unit, to_board: int, to_slot: int) -> bool:
	if finished or in_setup_for(p) == false and active != _index_of(p):
		pass   ## phase/turn gating is applied below; see the guard block
	if u == null or not u.is_alive():
		return false
	if to_board < 0 or to_board >= p.boards.size():
		return false
	var dest: Board = p.boards[to_board]
	if not dest.is_slot_playable(to_slot):
		return false

	var loc: Array = p.find_unit(u)
	if loc[0] < 0:
		return false
	if loc[0] == to_board and loc[1] == to_slot:
		return false

	p.boards[loc[0]].slots[loc[1]] = null
	dest.slots[to_slot] = u
	_log("  %s moves to board %d, slot %d." % [u.card.name, to_board + 1, to_slot + 1])
	state_changed.emit()
	return true
```

Remove the stray first `if` block from the snippet above — it is a placeholder for gating
that this function deliberately does **not** apply. Movement is a board manipulation the UI
gates via `_my_turn()`, exactly as charging does; the engine primitive stays callable by the
harnesses without a phase dance. The final function body starts at `if u == null`.

`_index_of` is not needed. Delete that line.

- [ ] **Step 4: Run the test and verify it passes**

```
godot --headless --path . --script res://scripts/core/RulesTest.gd
```

Expected: PASS on all 12 new assertions, and the MISCOUNT guard will now fire because
`EXPECTED_ASSERTIONS` is stale.

- [ ] **Step 5: Update the assertion guard**

`scripts/core/RulesTest.gd:5` — change `126` to `138`, with a reason comment:

```gdscript
const EXPECTED_ASSERTIONS := 138   ## +12: free unit movement (2026-08-15)
```

Re-run; expect `0 failed` and no MISCOUNT line.

- [ ] **Step 6: Commit**

```bash
git add scripts/core/GameState.gd scripts/core/RulesTest.gd
git commit -m "Add move_unit: free repositioning between slots and boards"
```

---

## Task 2: Drag a board unit to a new slot

**Files:**
- Modify: `scripts/ui/CardView.gd:1086-1091` (`_get_drag_data`)
- Modify: `scripts/ui/Combat.gd:980-1060` (`_slot_widget`), and the payload helpers at 1899-1990

- [ ] **Step 1: Give board cards a drag payload**

`CardView.drag_payload` already exists and is mode-agnostic — `_get_drag_data` returns
whatever Combat put there. No change to `CardView.gd` is needed for the source side.
Verify by reading `scripts/ui/CardView.gd:1086`:

```gdscript
func _get_drag_data(_at: Vector2) -> Variant:
	if drag_payload.is_empty():
		return null
	set_drag_preview(_make_drag_preview())
	return drag_payload
```

Confirmed: setting `drag_payload` on a board-mode card is sufficient.

- [ ] **Step 2: Add the board-unit payload helpers**

Add to `scripts/ui/Combat.gd`, next to `_payload_card` (around line 1916):

```gdscript
## A board unit in flight. Distinct `kind` from "hand_card" so a drop target can
## tell "a card being played" from "a unit being moved" without inspecting further.
## Shape: { "kind": "board_unit", "board": int, "slot": int }
func _payload_unit(data: Variant) -> Unit:
	if typeof(data) != TYPE_DICTIONARY:
		return null
	var d: Dictionary = data
	if d.get("kind", "") != "board_unit":
		return null
	var bi := int(d.get("board", -1))
	var si := int(d.get("slot", -1))
	if bi < 0 or bi >= gs.players[GameState.P1].boards.size():
		return null
	return gs.players[GameState.P1].boards[bi].unit_at(si)


## True when a unit is being dragged and this empty slot is a legal destination.
func _can_move_to(data: Variant, bi: int, si: int) -> bool:
	if not _my_turn():
		return false
	var u := _payload_unit(data)
	if u == null or not u.is_alive():
		return false
	return gs.players[GameState.P1].boards[bi].is_slot_playable(si)


func _move_from_drag(data: Variant, bi: int, si: int) -> void:
	var u := _payload_unit(data)
	_end_drag()
	if u == null or not _my_turn():
		return
	_selected_hand = -1
	gs.move_unit(gs.players[GameState.P1], u, bi, si)
	_refresh()
```

- [ ] **Step 3: Set the payload on your own living board cards**

In `scripts/ui/Combat.gd`, inside `_slot_widget`, in the occupied-slot branch after
`view.enemy = is_enemy` (around line 1021), add:

```gdscript
	## Your own units are draggable to any empty slot on either of your boards.
	## Free movement replaced the old no-drag-to-rearrange rule on 2026-08-15.
	if not is_enemy and u.is_alive() and _my_turn() and _pending_support == null:
		view.drag_payload = {"kind": "board_unit", "board": bi, "slot": si}
		view.drag_started.connect(func(): _on_unit_drag_started(u))
```

And add the drag-start handler next to `_on_drag_started` (around line 1885):

```gdscript
## A unit being moved is its own gesture: clear any card selection so the two
## input styles don't fight, and record what is in flight so empty slots light up.
func _on_unit_drag_started(u: Unit) -> void:
	_drag_unit = u
	_drag_card = null
	_dragging_basic = false
	_selected_hand = -1
	_selected_unit = null
```

Declare `_drag_unit` near `_drag_card` in the variable block (around line 41):

```gdscript
## The board unit currently being dragged, so empty slots can pre-light as
## destinations the same way they pre-light for a dragged Basic.
var _drag_unit: Unit = null
```

And clear it in `_end_drag` (line 1893):

```gdscript
func _end_drag() -> void:
	_drag_card = null
	_drag_unit = null
	_dragging_basic = false
```

- [ ] **Step 4: Make empty slots accept a dragged unit**

In `_slot_widget`'s empty-slot branch, replace the existing drop wiring (line 1015-1017):

```gdscript
		## A Basic dropped on an empty, legal slot deploys there.
		if droppable:
			e.set("can_drop", func(data): return _is_basic_payload(data))
			e.set("on_drop", func(data): _deploy_from_drag(data, bi, si))
```

with:

```gdscript
		## An empty legal slot accepts either a Basic from hand (deploy) or one of
		## your own units from the board (move). One zone, two payload kinds.
		if droppable:
			e.set("can_drop", func(data):
				return _is_basic_payload(data) or _can_move_to(data, bi, si))
			e.set("on_drop", func(data):
				if _payload_unit(data) != null:
					_move_from_drag(data, bi, si)
				else:
					_deploy_from_drag(data, bi, si))
```

And extend the pre-light so a dragged unit lights destinations, replacing line 1006:

```gdscript
		elif droppable and _dragging_basic:
			e.state = SlotSocket.State.DROP
```

with:

```gdscript
		elif droppable and (_dragging_basic or _drag_unit != null):
			e.state = SlotSocket.State.DROP
```

Also update the caption on the same widget (line 1010) so the word matches the gesture:

```gdscript
		e.text = "" if _compact else (
			"move" if (droppable and _drag_unit != null)
			else ("deploy" if playable
			else ("drop" if (droppable and _dragging_basic) else "")))
```

- [ ] **Step 5: Verify the drag harness still passes**

```
godot --headless --path . --script res://scripts/core/DragDropTest.gd
```

Expected: `0 failed`, 27 assertions, no MISCOUNT. This harness drives hand-card drops; the
new payload kind must not have disturbed them.

- [ ] **Step 6: Add a harness assertion for the move drop**

Append to `scripts/core/DragDropTest.gd`, in the same style as its existing deploy test:

```gdscript
## Free movement by drop. The UI path, not just the engine primitive: a board unit
## payload dropped on an empty slot must relocate the unit.
func _test_drag_move(combat) -> void:
	var gs = combat.gs
	var p = gs.players[0]
	var u = p.boards[0].unit_at(0)
	if u == null:
		_check("fixture has a unit on board 0 slot 0", false, true)
		return
	var payload := {"kind": "board_unit", "board": 0, "slot": 0}
	_check("empty slot accepts a dragged unit", combat._can_move_to(payload, 0, 1), true)
	combat._move_from_drag(payload, 0, 1)
	_check("unit relocated by drop", p.boards[0].unit_at(1), u)
	_check("old slot vacated by drop", p.boards[0].unit_at(0), null)
	_check("enemy board rejects your unit",
		combat._can_move_to({"kind": "board_unit", "board": 9, "slot": 0}, 0, 2), false)
```

Call it from the harness's run sequence at a point where P1 has a unit on board 0 slot 0
and slot 1 is empty. Bump `EXPECTED_ASSERTIONS` at `scripts/core/DragDropTest.gd:5` from
`27` to `31`, with a comment:

```gdscript
const EXPECTED_ASSERTIONS := 31   ## +4: drag-to-move (2026-08-15)
```

- [ ] **Step 7: Run and commit**

```
godot --headless --path . --script res://scripts/core/DragDropTest.gd
```

Expected: `0 failed`, 31 assertions.

```bash
git add scripts/ui/Combat.gd scripts/core/DragDropTest.gd
git commit -m "Drag your own units between slots and boards"
```

---

## Task 3: Repurpose `Reposition`

Free movement makes "swap the slots of two of your units" nearly worthless — the only thing
it still does that movement cannot is exchange two *occupied* slots with no empty slot
available, which is a corner case, not a card.

The replacement keeps the card's identity (a positioning trick) and points it at the enemy,
where the player has no free lever at all:

> **Reposition** — *Move an enemy unit to another slot on its own board.*

That is a genuinely useful effect under the current rules: it changes which enemy unit is
across from which of yours, so it redirects the *default* target of every unnamed attack,
and it can pull a body out from in front of a tower. It stays within the shielding rules —
the unit remains on its own board, so nothing is exposed that clearing the board would not
already expose.

**Files:**
- Modify: `data/cards.json` (the `reposition` entry)
- Modify: `scripts/core/GameState.gd` (add `move_enemy` op; `UNIT_TARGET_OPS` at line 635)
- Test: `scripts/core/SupportTest.gd`

- [ ] **Step 1: Write the failing test**

Add to `scripts/core/SupportTest.gd` and call it from the run sequence:

```gdscript
## Reposition, repurposed 2026-08-15. Free unit movement made its old "swap two of
## your own units" effect near-worthless, so it now moves an ENEMY unit within its
## own board — a lever the player otherwise has none of, and one that redirects the
## default target of every unnamed attack.
func _test_reposition(GS, CardDataC) -> void:
	var gs = _game(GS)
	var me = gs.players[GS.P1]
	var them = gs.players[GS.P2]

	var target = _unit(CardDataC, "victim", 60)
	them.boards[0].slots[0] = target

	var card = CardDB.get_card("reposition")
	_check("reposition still exists", card != null, true)
	_check("reposition targets an enemy unit", card.has_effect("move_enemy"), true)
	_check("reposition no longer swaps your own units",
		card.has_effect("swap_slots"), false)

	me.hand.append("reposition")
	_check("resolves against an enemy unit",
		gs.play_support(me, me.hand.size() - 1, target), true)
	## The engine picks the destination (leftmost empty usable slot on that board),
	## so the card needs one pick rather than two.
	_check("enemy unit left its slot", them.boards[0].unit_at(0), null)
	_check("enemy unit is still on its own board",
		them.boards[0].units().has(target), true)
```

If `SupportTest.gd` has no `_unit` helper, reuse the same `_basic_unit` body given in
Task 1 Step 1, named to match the file's existing convention.

- [ ] **Step 2: Run and verify it fails**

```
godot --headless --path . --script res://scripts/core/SupportTest.gd
```

Expected: FAIL — `reposition targets an enemy unit` is false, since the card still prints
`swap_slots`.

- [ ] **Step 3: Rewrite the card data**

In `data/cards.json`, replace the `reposition` entry with:

```json
{
 "id": "reposition",
 "name": "Reposition",
 "type": "support",
 "faction": "neutral",
 "text": "Move an enemy unit to another slot on its own board. It keeps all attached energy.",
 "effects": [
  {
   "op": "move_enemy",
   "n": 0
  }
 ],
 "flavor": "Shove them out of the line they were holding. Facing is the default target, so moving a body changes what everything aims at."
}
```

The `id` deliberately does not change — ids are referenced across `TutorialData.gd`, the
sample decks and the harnesses, and the project's established rule is that when an
identifier is load-bearing and a label is not, you change the label.

- [ ] **Step 4: Implement the op**

In `scripts/core/GameState.gd`, add `"move_enemy"` to `UNIT_TARGET_OPS` (line 635 block),
in the neutral group rather than the Void group:

```gdscript
	"damage_uncharged", "destroy_energy", "retreat_unit", "retreat_free",
	"retreat_from_pool", "return_to_hand", "move_enemy",
```

Then add the resolver next to `_do_swap_slots`:

```gdscript
## Reposition. Moves an enemy unit within its OWN board — never across boards and
## never onto your side, so shielding and the two-independent-fights rule are both
## untouched. What it buys is a change of facing: an unnamed attack hits the slot
## across, so shoving a body one slot over redirects every default target on that
## board.
##
## The destination is the leftmost empty usable slot rather than a second pick. One
## pick keeps the card a single click, and on a 3-slot board with a tower there is
## rarely more than one empty slot to choose between anyway.
func _do_move_enemy(enemy: Player, u: Unit) -> void:
	if u == null or not u.is_alive():
		_log("  No enemy unit to move.")
		return
	var loc: Array = enemy.find_unit(u)
	if loc[0] < 0:
		return
	var b: Board = enemy.boards[loc[0]]
	var dest: int = -1
	for i in b.usable_slots():
		if b.slots[i] == null:
			dest = i
			break
	if dest < 0:
		_log("  %s has nowhere to be moved to." % u.card.name)
		return
	b.slots[loc[1]] = null
	b.slots[dest] = u
	_log("  %s is shoved to slot %d." % [u.card.name, dest + 1])
```

And dispatch it where the other unit-target ops are handled — alongside the
`swap_slots` branch at line 887:

```gdscript
	if card.has_effect("move_enemy"):
		_do_move_enemy(_opponent_of(p), target)
```

Use whatever the file's existing accessor for the opposing player is; grep for how
`siphon_support` resolves its enemy, since that op has the same shape, and reuse it.

- [ ] **Step 5: Remove `swap_slots` if now unused**

Check whether any other card still prints it:

```bash
grep -c swap_slots data/cards.json
```

If the count is 0, leave the `_do_swap_slots` function and its `TWO_UNIT_OPS` entry in
place — it is harmless, still tested, and a future card may want it. Do **not** delete
working engine code as part of a UI task.

- [ ] **Step 6: Run and verify it passes**

```
godot --headless --path . --script res://scripts/core/SupportTest.gd
```

Expected: PASS. Then update the guard at `scripts/core/SupportTest.gd:5` from `158` to
`165` (+7 new assertions), with a reason comment, and re-run for `0 failed` and no
MISCOUNT.

- [ ] **Step 7: Check nothing else referenced the old effect**

```bash
grep -rn "reposition\|swap_slots" scripts/ data/ docs/ CLAUDE.md support.md
```

`Reposition` is named in `support.md` and possibly in `TutorialData.gd`. Update every
prose description of its effect to the new text. The card *id* must appear unchanged
everywhere it already appears.

- [ ] **Step 8: Commit**

```bash
git add data/cards.json scripts/core/GameState.gd scripts/core/SupportTest.gd support.md
git commit -m "Repurpose Reposition: move an enemy unit within its board"
```

---

## Task 4: Drag supports onto their target, with a clear "in use" state

Supports are click-targeted today: click the card, the board enters pick mode, click a
target. Tools already drop. This task makes every single-target support droppable too, and
makes the pending state unmistakable.

**Files:**
- Modify: `scripts/ui/Combat.gd:1934-1956` (`_can_drop_on_unit`), 1958-1975 (`_drop_on_unit`)
- Modify: `scripts/ui/Combat.gd:900-915` (the hint label) and `_slot_widget`

- [ ] **Step 1: Let a single-target support drop on a unit**

In `scripts/ui/Combat.gd`, replace the support branch of `_can_drop_on_unit` (lines
1946-1950):

```gdscript
	## A Tool dropped on a legal unit attaches to it.
	if c.is_tool():
		return gs.can_play_support(gs.players[GameState.P1], c, u)
	## Other supports are click-targeted, not dragged — they can need two picks
	## or a tower, which a single drop can't express.
	if c.is_support_like():
		return false
```

with:

```gdscript
	## A Tool dropped on a legal unit attaches to it.
	if c.is_tool():
		return gs.can_play_support(gs.players[GameState.P1], c, u)
	## Any support whose whole target is ONE unit can be dropped on that unit —
	## dragging a card onto what it affects is the most direct statement of intent
	## the interface can offer, and it removes the two-click detour entirely.
	##
	## Still click-only: tower support (the target is a structure, not a unit) and
	## two-unit supports (one drop cannot express two picks). Those keep pick mode.
	if c.is_support_like():
		if c.is_tower_support() or c.has_effect("damage_tower"):
			return false
		if _is_two_unit_support(c):
			return false
		if not gs._support_needs_target(c):
			return false
		return gs._support_unit_candidates(gs.players[GameState.P1], c).has(u) \
			or _enemy_target_candidates(c).has(u)
```

Add the enemy-candidate helper next to `_is_legal_support_target` (around line 1817):

```gdscript
## Supports that point at an ENEMY unit (Void's siphon/void/gap ops, Reposition,
## the damage supports). `_support_unit_candidates` covers your own side, so this
## is the other half of the legal set for a dragged support.
func _enemy_target_candidates(card: CardData) -> Array:
	var out: Array = []
	if not card.is_support_like():
		return out
	var enemy: Player = gs.players[GameState.P2]
	for op in ["siphon_support", "void_all", "gap_damage", "move_enemy",
			"damage_unit", "damage_uncharged", "destroy_energy"]:
		if card.has_effect(op):
			for u in enemy.all_units():
				if u.is_alive():
					out.append(u)
			return out
	return out
```

- [ ] **Step 2: Resolve the drop**

In `_drop_on_unit` (line 1958), replace the Tool-only branch:

```gdscript
	_selected_hand = -1
	if c.is_tool():
		gs.play_support(gs.players[GameState.P1], i, u)
```

with:

```gdscript
	_selected_hand = -1
	if c.is_tool() or c.is_support_like():
		## One code path for Tools and single-target supports: both resolve as
		## `play_support` against the dropped-on unit. Sampled either side, because
		## a heal leaves no standing record in GameState for the tutorial to read.
		var hp_before := u.hp
		gs.play_support(gs.players[GameState.P1], i, u)
		if u.hp > hp_before:
			Tutorial.note("healed")
```

- [ ] **Step 3: Make the card being used unmistakable**

Three cues, because the current one (a hint line at the top) is far from the board where
the eye is.

**3a. The pending card lifts and glows in hand.** In `_slot_widget`'s hand-building
counterpart, find where hand cards are built (grep `_pending_support` near the hand row) and
give the pending card a gold highlight. In the hand loop, where `view.selected` is set:

```gdscript
		## The card driving pick mode is not merely "selected" — it is mid-action.
		## Gold matches the gold ring on its legal targets, so the eye connects the
		## card in hand to the things it may be played on.
		if _pending_support != null and i == _selected_hand:
			view.highlight = Palette.GOLD
			view.selected = true
```

**3b. A banner naming the card.** Replace the hint text at lines 905-909:

```gdscript
	elif _pending_support != null:
		if _pending_two != null:
			_hint_lbl.text = "%s — now pick the second unit.  (Esc cancels)" % _pending_support.name
		else:
			_hint_lbl.text = "%s — pick a target.  (Esc cancels)" % _pending_support.name
```

with a version that states the card is in use, in the imperative, and says what it does:

```gdscript
	elif _pending_support != null:
		var what: String = _pending_support.text.strip_edges()
		if _pending_two != null:
			_hint_lbl.text = "USING %s  ·  now pick the second unit  ·  Esc cancels" \
				% _pending_support.name.to_upper()
		else:
			_hint_lbl.text = "USING %s  ·  %s  ·  Esc cancels" \
				% [_pending_support.name.to_upper(), what]
		_hint_lbl.add_theme_color_override("font_color", Palette.GOLD)
```

Reset that colour override on the other branches of the same `if` chain, otherwise the hint
stays gold after the pick resolves. At the top of the function that sets `_hint_lbl.text`,
add:

```gdscript
	## The USING banner turns the hint gold; every other state must put it back,
	## or the label stays gold for the rest of the game.
	_hint_lbl.add_theme_color_override("font_color", Palette.TEXT_DIM)
```

**3c. Illegal targets already dim** (`view.dimmed = true` at line 1039) and legal ones
already ring gold. Verify both still fire after the drag changes.

- [ ] **Step 4: Verify against the real combat UI**

```
godot --headless --path . --script res://scripts/core/SupportUITest.gd
```

Expected: `0 failed`, 43 assertions, no MISCOUNT. This harness drives support targeting
mode, the two-unit pick and Tool attach by both click and drop — the exact paths this task
touched.

- [ ] **Step 5: Add an assertion for the new drop path**

Append to `scripts/core/SupportUITest.gd`:

```gdscript
## Single-target supports are now droppable, not only click-targeted. Tower support
## and two-unit supports deliberately stay click-only — a tower is not a unit, and
## one drop cannot express two picks.
func _test_support_drop(combat) -> void:
	var gs = combat.gs
	var me = gs.players[0]
	var u = me.boards[0].unit_at(0)
	u.hp = max(1, u.hp - 30)
	me.hand.append("shore_up")
	var payload := {"kind": "hand_card",
		"hand_index": me.hand.size() - 1, "card_id": "shore_up"}
	_check("heal support can drop on your damaged unit",
		combat._can_drop_on_unit(payload, u), true)
	var before := u.hp
	combat._drop_on_unit(payload, u)
	_check("dropped support healed the unit", u.hp > before, true)

	me.hand.append("reinforced_base")
	var tower_payload := {"kind": "hand_card",
		"hand_index": me.hand.size() - 1, "card_id": "reinforced_base"}
	_check("tower support does not drop on a unit",
		combat._can_drop_on_unit(tower_payload, u), false)
```

Confirm `shore_up` and `reinforced_base` are the real card ids before relying on them:

```bash
grep -n '"id": "shore_up"\|"id": "reinforced_base"' data/cards.json
```

Bump `EXPECTED_ASSERTIONS` at `scripts/core/SupportUITest.gd:5` from `43` to `47`.

- [ ] **Step 6: Run and commit**

```
godot --headless --path . --script res://scripts/core/SupportUITest.gd
```

Expected: `0 failed`, 47 assertions.

```bash
git add scripts/ui/Combat.gd scripts/core/SupportUITest.gd
git commit -m "Drag single-target supports onto their target; show which card is in use"
```

---

## Task 5: Keyword tooltips

Keyword chips currently carry no tooltip at all — `_keyword_chip` sets `mouse_filter =
MOUSE_FILTER_IGNORE` on both the chip and its label, so they cannot even receive a hover.
`Void N`, `Rift N` and `Siphon N` are the worst cases named by Jonah, but every keyword has
the same gap.

**Files:**
- Modify: `scripts/ui/Theme.gd` (add `KEYWORD_HELP` after `KEYWORD_COLORS`, line 133)
- Modify: `scripts/ui/CardView.gd:623-648` (`_keyword_chip`)
- Test: `scripts/core/CardViewTest.gd`

- [ ] **Step 1: Write the failing test**

Add to `scripts/core/CardViewTest.gd`:

```gdscript
## Every keyword chip explains itself on hover. The chips are the game's densest
## information and carried no tooltip at all — Void's three in particular (Void N,
## Rift N, Siphon N) are unguessable from a two-word chip.
func _test_keyword_tooltips() -> void:
	## A Void unit with Rift, so the chip under test is one of the unguessable ones.
	var card := CardDB.get_card("riftmote")
	if card == null:
		_check("a rift card exists to test", false, true)
		return
	var view := make_view(card)
	var chips := _find_node(view, "KeywordChips")
	_check("keyword chips are present", chips != null, true)
	if chips == null:
		return
	var found := false
	for c in chips.get_children():
		if c.tooltip_text.strip_edges() != "":
			found = true
			_check("chip tooltip names the keyword",
				c.tooltip_text.to_lower().contains("rift")
				or c.tooltip_text.to_lower().contains("gap"), true)
			break
	_check("at least one chip carries a tooltip", found, true)
	view.queue_free()


## Every keyword the game colours must also have help text, or a chip explains
## nothing on the card where it matters most.
func _test_keyword_help_coverage() -> void:
	var missing: Array = []
	for kw in Palette.KEYWORD_COLORS.keys():
		if str(Palette.keyword_help(kw)).strip_edges() == "":
			missing.append(kw)
	_check("every coloured keyword has help text", missing, [])
```

`riftmote` is a guess at a card id. Confirm a real Rift-carrying card id first:

```bash
python -c "
import json
cards = json.load(open('data/cards.json'))['cards']
for c in cards:
    kw = c.get('keywords', {})
    if isinstance(kw, dict) and 'rift' in kw: print(c['id'], c['name'], kw); break
"
```

Use whatever id that prints. If `CardViewTest.gd` has no `_find_node` helper, grep for how
its existing tests locate `"AttackRows"` and reuse that.

- [ ] **Step 2: Run and verify it fails**

```
godot --headless --path . --script res://scripts/core/CardViewTest.gd
```

Expected: FAIL — `Palette.keyword_help` does not exist, and no chip has a tooltip.

- [ ] **Step 3: Add the help table**

In `scripts/ui/Theme.gd`, after `KEYWORD_COLORS` (line 133), add:

```gdscript
## One-paragraph help for every keyword, shown as the tooltip on a keyword chip.
##
## A chip is two words on a 7px frame — enough to *recognise* a keyword you already
## know and nothing at all if you don't. Void's three are the clearest case: "Void 2"
## and "Rift 2" are unguessable without the rules, and Rift additionally reads a
## board-wide number (the Gap) that the chip cannot show.
##
## Kept deliberately short. This is a reminder at the point of decision, not a rules
## page — the Compendium (Learn to Play) holds the full text, and `TutorialData`'s
## keyword pages are the source of truth these are condensed from.
const KEYWORD_HELP := {
	"toll":
		"Toll N — when this unit dies, you gain N energy to your pool.\nThe refund is printed on the card (HP / 25) and never recalculates.",
	"decay":
		"Decay N — deals N damage at end of turn to the unit across from it.\nFollows the normal targeting chain, so it cannot chip past a wall.",
	"judgment":
		"Judgment N — ONE charge, spent by either half.\nDefensive: when this would die, it survives at N HP instead.\nOffensive: when it attacks and leaves the defender at N or below, that defender dies.\nUsing it either way spends it.",
	"sanctuary":
		"Sanctuary N — a pool of N that incoming damage depletes.\nWhen the pool cannot cover a hit, it absorbs that hit ENTIRELY and is spent.\nBlocks every damage source. Weak to many small hits, strong against one big one.",
	"siphon":
		"Siphon N — MOVES up to N attached energy from an enemy unit onto this one.\nNot destruction: you gain what they lose, so it swings the Gap by 2N.\nOn a support it goes to your pool instead, which does NOT feed the Gap.",
	"void":
		"Void N — DESTROYS up to N attached energy on an enemy unit.\nGone, not taken — nobody gets it. Hits attached energy only, never the pool.\nObeys the normal targeting chain: slot across, then leftmost.",
	"rift":
		"Rift N — this attack deals +N damage for every point of your Gap.\nGap = your total attached energy minus theirs, floored at 0.\nUncapped: a large Gap means you have staked that much on bodies that can all die at once.",
	"earth":
		"Earth N — a board-wide aura. Every point of Earth on your LIVING units gives\n+1 damage and +1 max HP to each of your units and both of your towers.\nKill an Earth body and the aura shrinks immediately.",
	"essence":
		"Essence N — when this unit dies, spend N POOL energy to move its Earth and\nattached energy to the nearest living friendly unit on the same board.\nNever crosses boards. Fizzles if you cannot pay.",
	"rise":
		"Rise — when this dies, it returns to an empty slot on your side at the start of\nyour next turn, at HALF HP and WITHOUT Rise.\nAttached energy is not restored, and grown stats reset to printed values.",
	"retribution":
		"Retribution N — when this unit takes damage from an attack, it deals N damage\nback to the attacker.\nIt still fires from a unit killed by that attack — nothing leaves the board mid-attack.",
	"consume":
		"Consume N — this line DESTROYS N attached energy each time it is used.\nThe only cost an ability may carry, and it charges every single use — which is what\nstops a free once-per-turn ability from being a permanent engine.",
	"windfury":
		"Windfury — this unit may attack twice per turn.\nDocumented but not yet implemented; no card currently uses it.",
	"resist":
		"Resist X — reduces each incoming instance of damage by X, to a minimum of 1.\nPer-instance, so it is strong against many small hits and weak to one big one —\nthe deliberate inverse of Sanctuary.",
}


## Help text for a keyword chip's tooltip. Empty for an unrecognised keyword, so a
## chip without help renders as a plain chip rather than showing "null".
func keyword_help(kw: String) -> String:
	return KEYWORD_HELP.get(kw.to_lower(), "")
```

- [ ] **Step 4: Put the tooltip on the chip**

In `scripts/ui/CardView.gd`, in `_keyword_chip` (line 623), the chip and its label are both
`MOUSE_FILTER_IGNORE`, so neither can receive a hover. Change the chip to `PASS` and set the
tooltip. Replace:

```gdscript
	var chip := PanelContainer.new()
	chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
```

with:

```gdscript
	var chip := PanelContainer.new()
	## PASS rather than IGNORE: the chip must receive hover to show its tooltip,
	## while still letting the click through to the card's own button underneath.
	## The label stays IGNORE so the tooltip belongs to one node, not two.
	chip.mouse_filter = Control.MOUSE_FILTER_PASS
	var help: String = Palette.keyword_help(kw_name)
	if help != "":
		chip.tooltip_text = help
```

The row holding the chips is also `MOUSE_FILTER_IGNORE` (line 611). An `IGNORE` parent
does not block a `PASS` child from receiving events in Godot 4, but the containing
`VBoxContainer` root is `IGNORE` too — verify the tooltip actually appears in the running
game (Task 7), and if it does not, change the `KeywordChips` row at line 611 to `PASS`.

- [ ] **Step 5: Run and verify it passes**

```
godot --headless --path . --script res://scripts/core/CardViewTest.gd
```

Expected: PASS. Bump `EXPECTED_ASSERTIONS` at `scripts/core/CardViewTest.gd:5` from `63`
to `67` (+4), then re-run for `0 failed` and no MISCOUNT.

- [ ] **Step 6: Run the glyph scan**

`Theme.gd` and `CardView.gd` are both in `LayoutTest`'s scanned file list, and the new help
strings are long. The em-dashes in them are Latin-1 and safe; verify mechanically rather
than by eye:

```
godot --headless --path . --script res://scripts/core/LayoutTest.gd
```

Expected: `0 failed`, 37 assertions. If a glyph fails, replace the offending character with
an ASCII equivalent — do not add it to `GLYPH`, since these are prose strings, not symbols.

- [ ] **Step 7: Commit**

```bash
git add scripts/ui/Theme.gd scripts/ui/CardView.gd scripts/core/CardViewTest.gd
git commit -m "Keyword chips explain themselves on hover"
```

---

## Task 6: Separate "required" from "held" — the cost row bug, the badge, and the Gap

### The bug this task exists to fix

`CardView._cost_icons()` at line 901 decides fill like this:

```gdscript
var is_filled: bool = unit != null and i < attached
```

**In hand there is no `Unit`, so `unit` is null and EVERY cost icon renders unfilled.** The
unfilled branch of `EnergyIcon._draw` returns early after painting a black well and a dim
outline — so the faction colour is passed in and never drawn. A card in hand shows its
energy requirement as a row of **empty grey sockets in no colour at all**, which is the
reported symptom: "it currently shows as empty on what's required."

The root cause is that one widget was made to do two jobs. The cost row states the
requirement *and* doubles as an attached-energy progress bar, and the progress-bar reading
is what forces the "unfilled" state that erases the colour.

**These are two different questions and they get two different widgets:**

| Question | Widget | Rule |
|---|---|---|
| What does this attack *require*? | Cost icons beside the attack | **Always solid, always in the required colour** — in hand, on the board, everywhere |
| What does this unit *hold*? | Badge in the bottom-left | Faction symbol + number |

Once "held" has its own home in the bottom-left, the cost row no longer needs to encode it,
so it can simply state the requirement in full colour. Colorless requirements stay visually
distinct (grey), because *which* colour an attack demands is part of the requirement.

The one thing worth preserving from the progress-bar read is "can this fire yet", and the
badge answers it better: the requirement is `3` in Hel purple beside the attack, and the
badge says `#5`, so 5 ≥ 3 is a comparison of two stated numbers rather than a count of
filled sockets.

**Files:**
- Modify: `scripts/ui/CardView.gd:868-905` (`_cost_icons` — the colour fix)
- Modify: `scripts/ui/CardView.gd:905-975` (`_add_footer` — the badge)
- Modify: `scripts/ui/Combat.gd` (pool bar area, around line 619 and 830-895)
- Test: `scripts/core/CardViewTest.gd`, `scripts/core/VoidTest.gd`

- [ ] **Step 0a: Write the failing test for the cost row**

Add to `scripts/core/CardViewTest.gd`:

```gdscript
## An attack's cost states what it REQUIRES, in the colour it requires, whether the
## card is in hand or on the board.
##
## This is a regression test for a real bug: `is_filled` was `unit != null and i <
## attached`, so in hand (where `unit` is always null) every icon rendered unfilled —
## and `EnergyIcon`'s unfilled branch paints a black well and returns before the
## faction colour is ever used. A card in hand showed its requirement as a row of
## empty grey sockets. The progress-bar reading moved to the bottom-left badge, so the
## cost row is now free to just state the requirement.
func _test_cost_icons_show_required_color() -> void:
	var card := CardDB.get_card("grave_whelp")
	if card == null:
		_check("a unit exists to test costs", false, true)
		return
	var atk = card.attack_lines()[0] if card.attack_lines().size() > 0 else null
	if atk == null or atk.total_cost() <= 0:
		_check("test card has a priced attack", false, true)
		return

	## In hand: no unit, so nothing is attached — and the icons must STILL be solid
	## and coloured, because the requirement does not depend on what is attached.
	var view := make_view(card)
	var icons := _energy_icons_in(view)
	_check("hand card draws its cost icons", icons.size() > 0, true)
	var all_filled := true
	var any_faction_colored := false
	for ic in icons:
		if not ic.filled:
			all_filled = false
		if not ic.colorless:
			any_faction_colored = true
	_check("hand cost icons are solid, not empty sockets", all_filled, true)
	_check("hand cost icons carry the required faction colour",
		any_faction_colored, true)
	view.queue_free()

	## On the board with ZERO attached: still solid. The old code drew these empty.
	var u := load("res://scripts/core/Unit.gd").new(card)
	u.hp = card.hp
	var bv := make_view(card, u, MODE_BOARD)
	var bicons := _energy_icons_in(bv)
	var board_all_filled := true
	for ic in bicons:
		if not ic.filled:
			board_all_filled = false
	_check("uncharged board card still shows a solid requirement",
		board_all_filled, true)
	bv.queue_free()


## Every EnergyIcon under a node, depth-first. The cost row and the retreat footer
## both use them, so callers filter by what they are checking.
func _energy_icons_in(n: Node) -> Array:
	var out: Array = []
	if n is EnergyIcon:
		out.append(n)
	for c in n.get_children():
		out.append_array(_energy_icons_in(c))
	return out
```

`_energy_icons_in` walks the whole card, so it picks up the retreat footer's grey icons too.
For the "any faction coloured" assertion that is harmless. For the "all filled" assertions
it is also harmless — retreat icons are constructed with `filled = true` already
(`CardView.gd:975`). If a future change breaks that assumption, scope the search to the
`AttackRows` node instead.

- [ ] **Step 0b: Run and verify it fails**

```
godot --headless --path . --script res://scripts/core/CardViewTest.gd
```

Expected: FAIL on `hand cost icons are solid, not empty sockets` — this is the reported bug
reproduced as an assertion.

- [ ] **Step 0c: Fix the cost row**

In `scripts/ui/CardView.gd`, in `_cost_icons`, replace the icon loop (lines 899-903):

```gdscript
	for i in cost:
		var is_colorless: bool = i >= atk.cost_faction
		var is_filled: bool = unit != null and i < attached
		box.add_child(EnergyIcon.new(col, is_filled, is_colorless, _m("icon_size"), fac))
	return box
```

with:

```gdscript
	## Always solid, always in the required colour.
	##
	## These icons state what the attack REQUIRES, which does not depend on what the
	## unit happens to hold — so they are drawn the same in hand, on an uncharged
	## body, and on a fully charged one. They used to be filled left-to-right by
	## attached energy, which meant a card in hand (where `unit` is null) drew every
	## icon unfilled, and `EnergyIcon`'s unfilled branch paints a black well and
	## never reaches the faction colour: the requirement rendered as empty grey
	## sockets on every card in your hand.
	##
	## "How close am I to affording this" is now answered by the attached-energy
	## badge in the footer, which states the total as a number — a comparison of two
	## stated numbers rather than a count of filled sockets.
	for i in cost:
		var is_colorless: bool = i >= atk.cost_faction
		box.add_child(EnergyIcon.new(col, true, is_colorless, _m("icon_size"), fac))
	return box
```

The `attached` parameter is now unused by the icon loop but is still read by the `cost > 8`
numeric chip above it, so leave the signature alone.

- [ ] **Step 0d: Run and verify it passes**

```
godot --headless --path . --script res://scripts/core/CardViewTest.gd
```

Expected: PASS on all five new assertions. The guard will MISCOUNT until Step 4 sets it.

- [ ] **Step 0e: Commit the fix on its own**

```bash
git add scripts/ui/CardView.gd scripts/core/CardViewTest.gd
git commit -m "Fix: attack costs rendered as empty sockets in hand, with no colour"
```

Committed separately from the badge because it is a **bug fix**, not a feature — it should
be revertable on its own.

- [ ] **Step 1: Write the failing test for the badge**

Add to `scripts/core/CardViewTest.gd`:

```gdscript
## Attached energy reads as a faction symbol and a number in the footer's bottom-left.
## The attack rows already fill their cost icons left-to-right as energy accumulates,
## but that only answers "can this attack fire" — it never states the plain total,
## and a unit saving toward a 14-cost attack shows eight filled icons and no number.
func _test_attached_badge() -> void:
	var card := CardDB.get_card("grave_whelp")
	if card == null:
		_check("a basic unit exists to test", false, true)
		return

	## In hand there is no unit, so there is nothing attached and no badge.
	var hand_view := make_view(card)
	_check("no attached badge in hand", _find_node(hand_view, "AttachedBadge"), null)
	hand_view.queue_free()

	## On the board with energy attached, the badge states the total.
	var u := load("res://scripts/core/Unit.gd").new(card)
	u.hp = card.hp
	u.attached = 5
	var board_view := make_view(card, u, MODE_BOARD)
	var badge = _find_node(board_view, "AttachedBadge")
	_check("attached badge present on a charged unit", badge != null, true)
	if badge != null:
		_check("badge states the attached total",
			_text_of(badge).contains("5"), true)
	board_view.queue_free()

	## An uncharged unit shows no badge — zero is the common case and a "0" on
	## every empty body is noise.
	var u0 := load("res://scripts/core/Unit.gd").new(card)
	u0.hp = card.hp
	var v0 := make_view(card, u0, MODE_BOARD)
	_check("no badge on an uncharged unit", _find_node(v0, "AttachedBadge"), null)
	v0.queue_free()
```

`_text_of` may not exist; if not, write it as a small recursive helper that concatenates
every descendant `Label`'s text, and reuse the file's existing traversal style. Confirm
`grave_whelp` is still a real id (`grep '"id": "grave_whelp"' data/cards.json`).

- [ ] **Step 2: Run and verify it fails**

```
godot --headless --path . --script res://scripts/core/CardViewTest.gd
```

Expected: FAIL — no node named `AttachedBadge` exists.

- [ ] **Step 3: Add the badge to the footer**

In `scripts/ui/CardView.gd`, in `_add_footer`, insert the badge as the row's first child —
before the `wk` label (line 928). Replace the opening of the weakness block:

```gdscript
	## Weakness / resistance — reserved, not implemented.
	var wk := Label.new()
```

with:

```gdscript
	## Attached energy, bottom-left: the faction's energy symbol and a plain total.
	##
	## The attack rows already fill their cost icons as energy accumulates, but that
	## answers "can this attack fire yet" and never states the total — a unit saving
	## toward a 14-cost attack shows a full row of eight and no number. And attached
	## energy is the half of the economy that DIES WITH THE UNIT, so its total is the
	## number a trade is judged on.
	##
	## Only drawn when there is something attached. A "0" on every uncharged body is
	## noise on a frame this size.
	if unit != null and unit.attached > 0:
		var badge := HBoxContainer.new()
		badge.name = "AttachedBadge"
		badge.add_theme_constant_override("separation", 1)
		badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(badge)

		## The card's own faction colour, so the symbol says which energy this is.
		badge.add_child(EnergyIcon.new(
			Palette.faction_color(card.faction), true, false,
			_m("footer_size") + 1, card.faction))

		var n := Label.new()
		n.text = str(unit.attached)
		n.add_theme_font_size_override("font_size", _m("footer_size") + 1)
		n.add_theme_color_override("font_color", Palette.GOLD)
		n.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		n.mouse_filter = Control.MOUSE_FILTER_IGNORE
		badge.add_child(n)

	## Weakness / resistance — reserved, not implemented.
	var wk := Label.new()
```

Note the footer is inside the `else` branch of `_is_micro()` in `_build`, so the phone board
card does not get a footer. The phone card's `_add_micro_status` already reports attached
energy (`CardView.gd:1149`) — leave that alone.

- [ ] **Step 4: Run and verify the badge passes**

```
godot --headless --path . --script res://scripts/core/CardViewTest.gd
```

Expected: PASS. Bump `EXPECTED_ASSERTIONS` at `scripts/core/CardViewTest.gd:5` from `67`
to `77`, with a reason comment covering both this task's groups:

```gdscript
const EXPECTED_ASSERTIONS := 77   ## +4 keyword tooltips, +5 cost colour fix, +5 attached badge (2026-08-15)
```

Re-run for `0 failed` and no MISCOUNT.

- [ ] **Step 5: Write the failing test for Void detection**

Add to `scripts/core/VoidTest.gd`:

```gdscript
## The Gap readout is conditional: it only means something when a Void card can read
## it, and a permanent Gap meter would be clutter in the ~3/4 of matchups with none.
## The detection is on the DECKS, not the board, so the readout does not blink in and
## out as Void units are drawn and die.
func _test_gap_relevance(GS, CardDataC) -> void:
	var gs = _game(GS)
	_check("no Void anywhere means no Gap readout", gs.gap_is_relevant(), false)

	## A Void card in your own deck makes it relevant.
	gs.players[GS.P1].deck.append(_a_void_card_id())
	_check("Void in your deck makes the Gap relevant", gs.gap_is_relevant(), true)

	## And so does one in theirs, since their Rift reads their Gap against you.
	var gs2 = _game(GS)
	gs2.players[GS.P2].deck.append(_a_void_card_id())
	_check("Void in their deck makes the Gap relevant", gs2.gap_is_relevant(), true)

	## A Void card in HAND or on the BOARD counts too — a deck list is the usual
	## signal but a card can arrive by other means.
	var gs3 = _game(GS)
	gs3.players[GS.P1].hand.append(_a_void_card_id())
	_check("Void in hand makes the Gap relevant", gs3.gap_is_relevant(), true)


## Any real Void card id, read from the database rather than hardcoded — a census
## value like this is exactly what breaks on a roster change while proving nothing.
func _a_void_card_id() -> String:
	for id in CardDB.all_ids():
		var c = CardDB.get_card(id)
		if c != null and c.faction == "void":
			return id
	return ""
```

Confirm `CardDB.all_ids()` exists; if the accessor has another name, grep `CardDB.gd` for
how `VoidTest` already enumerates cards and reuse it.

- [ ] **Step 6: Run and verify it fails**

```
godot --headless --path . --script res://scripts/core/VoidTest.gd
```

Expected: FAIL — `gap_is_relevant` does not exist.

- [ ] **Step 7: Implement the relevance check**

Add to `scripts/core/GameState.gd`, directly after `gap_for` (line 120):

```gdscript
## Whether the Gap is worth showing the player.
##
## The Gap is a real board number at all times, but NOTHING READS IT unless a Void
## card is in the game — so a permanent Gap meter would be clutter in the roughly
## three-quarters of matchups that contain no Void at all.
##
## Measured over decks, hands and boards rather than over the board alone, so the
## readout does not blink in and out as Void units are drawn, played and killed. A
## deck list is the usual signal; hand and board are checked because a card can
## arrive without ever having been in a deck (the tutorial hands fixed lists to
## GameState directly).
func gap_is_relevant() -> bool:
	for p in players:
		for src in [p.deck, p.hand, p.discard]:
			for id in src:
				var c: CardData = CardDB.get_card(str(id))
				if c != null and c.faction == "void":
					return true
		for u in p.all_units():
			if u != null and u.card != null and u.card.faction == "void":
				return true
	return false
```

- [ ] **Step 8: Run and verify it passes**

```
godot --headless --path . --script res://scripts/core/VoidTest.gd
```

Expected: PASS. Bump `EXPECTED_ASSERTIONS` at `scripts/core/VoidTest.gd:5` from `64` to
`68` (+4).

- [ ] **Step 9: Add the readout to Combat's pool bar**

In `scripts/ui/Combat.gd`, add a label next to `_pool_lbl` (built around line 619):

```gdscript
	## The Gap, shown only when a Void card is in the game — see
	## GameState.gap_is_relevant. Void's Rift scales its damage off this number and
	## it is otherwise completely invisible, so the one faction that reads it had no
	## way to see it.
	_gap_lbl = Palette.label("", Palette.TYPE_SMALL, Palette.keyword_color("rift"))
	_gap_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_gap_lbl.visible = false
	_gap_lbl.tooltip_text = "Gap = your attached energy minus theirs, floored at 0.\nVoid's Rift attacks deal +N damage per point of Gap.\nCounts LIVING units only, and ignores pool energy entirely."
	poolbar.add_child(_gap_lbl)
```

Declare it next to `_pool_lbl` (line 52):

```gdscript
var _gap_lbl: Label
```

And refresh it wherever `_pool_lbl.text` is set (line 894):

```gdscript
	## Both Gaps, because they are not symmetric — if you hold 10 attached and they
	## hold 4, yours is 6 and theirs is 0. Showing only your own would make an enemy
	## Rift unit's damage unexplainable.
	if _gap_lbl != null:
		var relevant: bool = gs != null and gs.gap_is_relevant()
		_gap_lbl.visible = relevant
		if relevant:
			var mine: int = gs.gap_for(gs.players[GameState.P1])
			var theirs: int = gs.gap_for(gs.players[GameState.P2])
			_gap_lbl.text = "   ·   Gap %d  (theirs %d)" % [mine, theirs]
```

- [ ] **Step 10: Verify the layout still fits the phone viewport**

The pool bar gained a label, and `LayoutTest`'s binding assertion is that no phone layout
exceeds 540 units.

```
godot --headless --path . --script res://scripts/core/LayoutTest.gd
```

Expected: `0 failed`, 37 assertions. If the pool row now overflows on the phone layout,
shorten the text to `"Gap %d/%d"` rather than widening the viewport.

- [ ] **Step 11: Commit**

```bash
git add scripts/ui/CardView.gd scripts/ui/Combat.gd scripts/core/GameState.gd \
        scripts/core/CardViewTest.gd scripts/core/VoidTest.gd
git commit -m "Attached-energy badge on the card; Gap readout when Void is in play"
```

---

## Task 7: Full harness sweep, then verify in the running game

- [ ] **Step 1: Run all fourteen harnesses**

```bash
for t in RulesTest SupportTest DeckStoreTest DragDropTest SceneSmokeTest \
         PlaythroughTest SupportUITest HeavenTest CardViewTest VoidTest \
         GaiaTest TutorialTest TutorialWalkTest LayoutTest; do
  echo "=== $t ==="
  godot --headless --path . --script "res://scripts/core/$t.gd" 2>&1 | tail -5
done
```

Expected: every harness reports `0 failed` and no `MISCOUNT` line. `SceneSmokeTest`,
`PlaythroughTest` and `TutorialWalkTest` report pass/fail without a count.

Two harnesses are known-flaky **by design** and their failures are real signals rather than
noise: `RulesTest`'s unit-only mirror (~1 in 14) and `SupportTest`'s support-heavy mirror
(~1 in 10) can stall. If one fails on the stall assertion, re-run once and capture the
output if it repeats — do not simply re-run until green.

- [ ] **Step 2: Check the error log is clean, then play the game**

The harnesses check structure, not legibility. Four things only a human can confirm, and
they are exactly the four this plan changed:

1. **Dragging a unit** to another slot and to the other board — does the destination
   pre-light, and does the card land where the pointer was?
2. **Dropping a support** on a unit — is it obvious which card is being used, from the
   board rather than from the top bar?
3. **Hovering a keyword chip** — does the tooltip actually appear? Task 5 Step 4 flagged
   the `MOUSE_FILTER` chain as the risk here.
4. **The badge and the Gap** — is the bottom-left badge readable at 132×196, and does the
   Gap row appear only in a Void matchup? (Pin a Void deck as the opponent from deck
   select to test both states.)

Launch from the `Godsfall` desktop shortcut, then:

```bash
cat logs/errors.log
```

Empty means nothing went wrong. If it has content, fix the causes and archive:

```bash
powershell -ExecutionPolicy Bypass -File tools/archive-errors.ps1 -Note "what was fixed"
```

- [ ] **Step 3: Update the docs**

This is the step that must not be skipped — `CLAUDE.md` currently states the opposite of
what the code now does, in three places.

**3a.** In `CLAUDE.md`, the *Deckbuilding* paragraph beginning "**Cards can be clicked or
dragged.**" — replace the "There is deliberately **no free drag-to-rearrange**" sentence
with the new rule and its reasoning:

```markdown
**Units drag freely between slots and boards.** Moving one of your own units to any empty
usable slot, on either of your boards, is free and unlimited — adopted 2026-08-15.

This reverses a rule that stood from the first prototype, and the reason it could go is
that its own justification had already expired: it rested on *placement is targeting*, and
chosen targeting retired that in favour of placement being the **default and the fallback**.
What movement still decides is real but narrower — which of your units eats the tower shot,
which one shields the structures behind it, and which slot an unnamed attack faces — so it
stays a decision without needing to cost a card.

`Reposition` was **repurposed rather than left dead**: it now moves an *enemy* unit within
its own board, which is a lever the player otherwise has none of, and it changes the default
target of every unnamed attack on that board. Free movement of your own units is what made
its old effect (swap two of yours) redundant.
```

**3b.** In the decision log, rewrite the entry beginning "**Drag-and-drop is an input
method, never a new rule.**" That claim is now false — this change *is* a rule change made
through the drag system. Replace it with:

```markdown
- **Drag-and-drop was an input method until 2026-08-15, when free unit movement made it a
  rule change.** The old entry said dragging never adds a rule, and the ban on
  drag-to-rearrange was its main evidence: repositioning was `Reposition`'s printed effect
  and giving it away free would make the card worthless. Both halves changed. The rule's
  stated reasoning — *placement is targeting* — had already been retired by chosen
  targeting, which made placement the default and the fallback rather than the only lever;
  and the card was **repurposed** (it now moves an *enemy* unit within its board) instead
  of being left as a dead draw. What movement still costs the player is unchanged and is
  why it is not free of consequence: it decides which unit eats the tower shot, which one
  shields, and what an unnamed attack faces.
```

**3c.** In `scripts/ui/Combat.gd:15-16`, rewrite the header comment that still claims
placement is targeting and that repositioning is a card effect.

**3d.** Add decision-log entries for the other four changes:

```markdown
- **Single-target supports drop onto their target; the card in use says so on the board.**
  Supports were click-then-click, with the only feedback a hint line at the top of the
  screen — furthest from the board, which is where the eye is during a pick. Dragging a
  card onto the thing it affects is the most direct statement of intent available, and the
  pending card now lifts and rings gold to match the gold on its legal targets. Tower
  support and two-unit supports deliberately stay click-only: a tower is not a unit, and
  one drop cannot express two picks.
- **Keyword chips carry their rules text as a tooltip.** The chips are the densest
  information on the board and had no tooltip at all — `mouse_filter = IGNORE` meant they
  could not even receive a hover. A chip is enough to *recognise* a keyword you know and
  nothing at all if you don't, which is worst exactly where the rules are least guessable:
  `Void 2` and `Rift 2` are unreadable without the rules, and Rift additionally scales off
  a board-wide number the chip cannot show. `Palette.KEYWORD_HELP` is one table condensed
  from the Compendium pages, and `CardViewTest` asserts every coloured keyword has an
  entry — so a new keyword fails the suite until someone writes its help.
- **An attack's cost states what it REQUIRES; what a unit HOLDS moved to the bottom-left.**
  One widget had been doing both jobs — the cost icons were filled left-to-right by attached
  energy, so they doubled as a progress bar. That overload is what broke the requirement
  read: encoding "held" as fill state forces an "unfilled" state, and `EnergyIcon`'s unfilled
  branch paints a black well and returns **before the faction colour is ever used**. Since
  `unit` is null for a card in hand, every cost icon on every card in your hand rendered as
  an empty colourless socket — the requirement was invisible on the screen where you decide
  what to play. Costs are now always solid and always in the colour they demand (colorless
  stays grey, because *which* colour is part of the requirement), and attached energy is a
  faction symbol plus a number in the footer's bottom-left. "Can this fire yet" is better
  served by the split anyway: comparing a stated `3` against a stated `5` beats counting
  filled sockets, and a unit saving toward a 14-cost attack now shows a number instead of a
  maxed-out row of eight. The badge is drawn only when something is attached — a "0" on every
  uncharged body is noise at 132×196.
  **The general shape: when one widget encodes two different questions, the second question's
  states will eventually corrupt the first one's.**
- **The Gap readout appears only when a Void card is in the game.** The Gap is a real board
  number at all times but *nothing reads it* without Void, so a permanent meter would be
  clutter in roughly three-quarters of matchups. `gap_is_relevant()` measures decks, hands,
  discards and boards rather than the board alone, so the readout does not blink in and out
  as Void units are drawn and die. Both Gaps are shown, because they are **not symmetric** —
  if you hold 10 attached and they hold 4, yours is 6 and theirs is 0, and showing only your
  own would make an enemy Rift unit's damage unexplainable.
```

**3e.** Update the harness table's assertion counts in `CLAUDE.md` (the "Verified by
fourteen headless harnesses" section) to the new totals, and update the stated grand total.

**3f.** Update `support.md`'s `Reposition` entry to the new effect.

- [ ] **Step 4: Commit the docs**

```bash
git add CLAUDE.md support.md scripts/ui/Combat.gd
git commit -m "Document free movement, support drops, keyword tooltips and the Gap readout"
```

---

## Self-review notes

**Spec coverage.** Every item Jonah asked for maps to a task: move between slots and boards
(1, 2), drag supports onto a card (4), make clear which card is in use (4), tooltips for
things like Void damage (5), the energy difference made clear (6, as the Gap per his
follow-up), required energy next to the attack in its required colours (6 Step 0 — this was
**wrongly reported as already working** in the first draft of this plan; the icons exist but
render as empty colourless sockets on every card in hand, which is the bug Jonah reported),
and the energy type and number in the bottom-left (6 Steps 1-4).

**The correction that reshaped Task 6.** The first draft treated "required energy beside the
attack" and "energy the unit holds" as one already-solved problem, because one widget was
doing both jobs. It is precisely that overload that breaks the requirement read: encoding
"held" as fill state forces an "unfilled" state, and unfilled discards the colour. Splitting
the two is what fixes the bug, and it is why the badge is not merely an addition — it is
what lets the cost row stop pretending to be a progress bar.

**"Find anything else like that."** Three further legibility gaps were found while reading
and are folded in above rather than left implicit: the hint label's colour override leaks
gold if not reset (Task 4 Step 3b), the reserved `wk —`/`res —` slots claim two thirds of
the footer's width for unimplemented systems (left alone deliberately — the plan adds the
badge left of them rather than re-laying-out the footer, since that is documented as a
deliberate reservation), and `Windfury`'s help text has to say it is unimplemented so a
tooltip never promises what the engine cannot do.

**Known risk.** Task 5 Step 4's `MOUSE_FILTER` change is the one place a headless harness
can pass while the feature does not work — a tooltip needs a real hover. It is called out
in Task 7 Step 2 item 3 for exactly that reason.
