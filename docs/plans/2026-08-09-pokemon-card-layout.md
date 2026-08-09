# Pokémon-Style Card Layout Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Restructure `CardView` into a Pokémon-TCG-style frame — HP in the top-right, an explicit "evolves from" strip, a banner-styled ability block, energy cost icons beside each attack name, retreat cost in the bottom-right, a dedicated keyword chip row, and reserved weakness/resistance slots — rendered identically in hand and on the board.

**Architecture:** One layout, one `_build()` path, both sizes. `CardView` keeps its current role as the single card renderer (the hand, the board, the inspector's big card, and the inspector's evolution chain all build the same node). Sizes stay at `HAND_SIZE 168×262` and `BOARD_SIZE 132×196`; a `_scaled()` font/metric helper derives every dimension from the mode so the board card packs the full structure into small type. Because small type is genuinely hard to read mid-combat, board cards gain a hover-to-enlarge overlay — a scaled `CardView` in a floating panel, reusing the existing hover-panel pattern.

**Tech Stack:** Godot 4.7, GDScript, code-built Controls (no `.tscn` for cards). Headless harnesses run via `godot --headless --path <project> --script res://scripts/core/<Test>.gd`.

---

## Context an engineer needs before starting

**Read `CLAUDE.md` first.** It is the source of truth for the game's rules; this plan implements a *presentation* change and must not alter any rule. Three of its standing constraints bear directly on this work:

1. **"State the rules engine tracks per-unit has to be visible per-unit."** `CardView._live_keyword_line()` exists because `CardData.keyword_line()` prints the *card*, which never changes, while `Judgment`, `Sanctuary` and `Rise` are charges that get spent. The new keyword chip row must preserve that behaviour exactly — a spent charge disappears, and `Sanctuary N` shows its **remaining** pool. Assertions in `HeavenTest.gd` guard it.

2. **"Ship the printed value early, and say plainly in the UI that it does nothing yet."** Weakness and resistance are not designed. This plan reserves their footer slots and prints `—`. `CardInspector` states they are not implemented. This mirrors how retreat costs shipped ahead of the retreat action.

3. **A board card must never grow past its slot.** `Combat._wrap_with_status()` reserves a fixed-height status strip under every slot for exactly this reason — a board row that changes height pushes the throne, the pool bar and the hand down the screen. `BOARD_SIZE` does not change in this plan, and `clip_contents` stays on for board cards.

**Where cards are rendered.** Every one of these builds a `CardView` and is affected:

| Caller | File | Mode | Notes |
|---|---|---|---|
| Hand | `scripts/ui/Combat.gd:685` | `HAND` | Wrapped in a holder sized `HAND_SIZE + HOVER_LIFT`; hover lifts the card |
| Board slot | `scripts/ui/Combat.gd:467` | `BOARD` | Wrapped by `_wrap_with_status()` |
| Drag preview | `scripts/ui/CardView.gd:629` | inherits | A second `CardView` following the cursor |
| Inspector big card | `scripts/ui/CardInspector.gd:171` | `HAND` | `scale = 1.55` |
| Inspector chain | `scripts/ui/CardInspector.gd:407` | `BOARD` | `scale = 0.62`, overlay button for hit box |
| Deck builder grid | `scripts/ui/DeckBuilder.gd` | `BOARD` | Shrunk card frames |

**The card data already carries everything this layout needs**, with one exception. `CardData` has `max_hp`, `evolves_from`, `retreat`, `keywords`, `stage`, `faction`. `AttackData` has `cost_faction`, `cost_color`, `cost_colorless`, `is_ability`, `consume`, `damage`, `name`, `text`. Nothing new needs parsing. The exception is weakness/resistance, which does not exist and is deliberately not being added as data — the footer prints a literal `—`.

**Energy colors** come from `Palette.FACTION_COLORS` (`scripts/ui/Theme.gd:25`), keyed by faction name, with `Palette.faction_color()` falling back to `GOLD`. Cost icons use this, so a new faction gets correct icons with no drawing-code change.

**Run the harnesses like this** (the path is the project root, which is this folder):

```
godot --headless --path "c:/Users/Jonah/OneDrive/Desktop/Godsfall" --script res://scripts/core/SceneSmokeTest.gd
```

If `godot` is not on PATH, the pinned build is named in `tools/godot-path.txt`.

**This project is not a git repository.** CLAUDE.md says so explicitly, and `using-git-worktrees` / `finishing-a-development-branch` do not apply. **Skip every commit step** — where a task would normally end in a commit, instead run the harnesses named in that task and confirm they pass. Do not run `git init`.

---

## Target layout

Both modes build this identical tree. Only font sizes and box heights differ.

```
┌────────────────────────────────────┐
│ STAGE 2            330 HP  ⬢hel    │  header: stage left, HP + faction dot right
│ ↑ Evolves from Charmeleon          │  evolve strip (units with evolves_from only)
├────────────────────────────────────┤
│ ▐                                ▌ │
│ ▐            art                 ▌ │  art box (unchanged sizing)
│ ▐                                ▌ │
├────────────────────────────────────┤
│  (Toll 3)  (Sanctuary 60)          │  keyword chip row — LIVE, not printed
├────────────────────────────────────┤
│ ╔ABILITY  Infernal Reign══════════╗│  ability banner (colored, per CLAUDE.md
│ ║ text of the ability            ║ │  abilities are free / Consume only)
│ ╚════════════════════════════════╝ │
│ ⬢⬢⬢  Burning Darkness       180    │  attack row: cost icons, name, damage
│ ⬡⬡    Crush                  38    │
├────────────────────────────────────┤
│ wk —     res —          Retreat ⬢⬢ │  footer: weakness/resist reserved, retreat
└────────────────────────────────────┘
```

Non-unit cards (energy, support, tool, tower support) keep a simpler tree: header with the type label, art, rules text body, and a footer showing the play cost. They have no HP, no evolve strip, no keyword chips, no attack rows, and no retreat.

### Metric table

Every number below is derived by `_m()` (a metric helper added in Task 1) from the mode. Board values are deliberately small; the hover-enlarge overlay from Task 9 is what makes them readable in play.

| Metric key | HAND | BOARD |
|---|---|---|
| `title_size` | 12 | 9 |
| `stage_size` | 8 | 7 |
| `hp_size` | 15 | 11 |
| `evolve_size` | 8 | 7 |
| `art_h` | 74 | 40 |
| `chip_size` | 8 | 7 |
| `chip_h` | 15 | 13 |
| `ability_title_size` | 9 | 7 |
| `ability_text_size` | 8 | 7 |
| `attack_name_size` | 10 | 8 |
| `attack_dmg_size` | 11 | 9 |
| `icon_size` | 10 | 7 |
| `footer_size` | 8 | 7 |

---

## File Structure

| File | Change | Responsibility |
|---|---|---|
| `scripts/ui/CardView.gd` | **Rewrite the build path** | The card frame. Gains `_m()`, `_add_header()`, `_add_evolve_strip()`, `_add_keyword_chips()`, `_add_ability_banner()`, `_add_attack_rows()`, `_add_footer()`. Loses `_add_stage_badge()`, `_add_stat_row()`, `_add_abilities()`, `_add_attacks()`, `_add_energy_row()`. Keeps `_live_keyword_line()`, `_frame_style()`, `_add_art()`, all drag/drop, and `status_line()`. |
| `scripts/ui/EnergyIcon.gd` | **Create** | Draws one energy cost icon — a faction-colored hexagon, or a hollow grey one for colorless. Used by attack rows, the footer's retreat cost, and (later) anything else that shows energy. |
| `scripts/ui/Theme.gd` | **Modify** | Add `KEYWORD_COLORS` so a chip's tint is looked up rather than hardcoded in `CardView`. |
| `scripts/ui/Combat.gd` | **Modify** | Add the board hover-enlarge overlay. |
| `scripts/ui/CardInspector.gd` | **Modify** | Add a weakness/resistance line to the not-yet-implemented notes. |
| `scripts/core/CardViewTest.gd` | **Create** | New headless harness asserting the frame's structure and live-keyword behaviour. |
| `CLAUDE.md` | **Modify** | Document the card layout as a settled decision, and weakness/resistance as an open question. |

---

## Task 1: Metric helper and the energy icon

**Files:**
- Create: `scripts/ui/EnergyIcon.gd`
- Modify: `scripts/ui/Theme.gd`
- Modify: `scripts/ui/CardView.gd`

- [ ] **Step 1: Add keyword colors to the palette**

In `scripts/ui/Theme.gd`, after the `FACTION_COLORS` const block (which ends at line 34), add:

```gdscript
## Keyword chip tints. A keyword's chip is colored by what it *does*, not by
## which faction prints it — `Rise` reads the same on a Hel body and on a Heaven
## one. Keywords absent from here fall back to BORDER, which is legible but
## deliberately plain, so a new keyword renders correctly before it gets a color.
const KEYWORD_COLORS := {
	## Hel signatures — death as a resource
	"toll":        Color("d9b45b"),
	"decay":       Color("8fbf6a"),
	## Heaven — reprieves
	"judgment":    Color("e8d98a"),
	"sanctuary":   Color("9ec9e8"),
	## Void signatures — denial
	"siphon":      Color("9a7ac9"),
	"void":        Color("6a6a80"),
	"rift":        Color("b866c9"),
	## Gaia signatures — growth
	"earth":       Color("5fbf6a"),
	"essence":     Color("7ad9a0"),
	## Shared
	"rise":        Color("bf6b9e"),
	"retribution": Color("d94f4f"),
	"consume":     Color("e07a3c"),
	"windfury":    Color("58b8d9"),
	"resist":      Color("8f8fbf"),
}


## The chip tint for a keyword, falling back to a plain border grey so an
## unrecognised keyword still renders as a chip rather than vanishing.
func keyword_color(kw: String) -> Color:
	return KEYWORD_COLORS.get(kw.to_lower(), BORDER)
```

- [ ] **Step 2: Create the energy icon**

Create `scripts/ui/EnergyIcon.gd`:

```gdscript
class_name EnergyIcon
extends Control

## One energy cost icon: a filled hexagon in the faction's color, or a hollow
## grey one for colorless.
##
## Drawn rather than built from a texture because the icon appears at four
## different sizes across the game (board attack rows at 7px, hand rows at 10px,
## the inspector's 1.55x scale, the deck builder grid) and a bitmap would be
## either soft when scaled up or heavy when scaled down. A polygon is crisp at
## every size and costs one draw call.
##
## `filled` has a second meaning on the board: an attack's cost icons are filled
## left-to-right by the unit's *attached* energy, so a player can see how close a
## unit is to affording each attack. That is the same information the old pip row
## carried, kept because it is the core read of the energy economy.

var color: Color = Color.WHITE
var filled: bool = true
var colorless: bool = false


func _init(c: Color, is_filled: bool = true, is_colorless: bool = false, px: float = 10.0) -> void:
	color = c
	filled = is_filled
	colorless = is_colorless
	custom_minimum_size = Vector2(px, px)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	var r: float = min(size.x, size.y) * 0.5
	var c: Vector2 = size * 0.5
	var pts := PackedVector2Array()
	## Flat-top hexagon: six points at 60-degree steps, offset 30 degrees so the
	## silhouette reads as a hex rather than as a circle at small sizes.
	for i in 6:
		var a: float = deg_to_rad(30.0 + 60.0 * i)
		pts.append(c + Vector2(cos(a), sin(a)) * r)

	var body: Color = color if filled else Color(0, 0, 0, 0.45)
	var edge: Color = color.lightened(0.3) if filled else color.darkened(0.2)
	if colorless and filled:
		body = Palette.TEXT_DIM
		edge = Palette.TEXT_DIM.lightened(0.3)
	elif colorless:
		edge = Palette.TEXT_DIM

	draw_colored_polygon(pts, body)
	## Close the outline by repeating the first point.
	var outline := PackedVector2Array(pts)
	outline.append(pts[0])
	draw_polyline(outline, edge, max(1.0, r * 0.16), true)
```

- [ ] **Step 3: Add the metric helper to CardView**

In `scripts/ui/CardView.gd`, add after the `BOARD_SIZE` const (line 21):

```gdscript
## Every font size and box height on the card, keyed by metric name, for each
## mode. One layout is built at both sizes (CLAUDE.md decision log), so the only
## thing that varies between hand and board is what comes out of this table.
##
## The board numbers are deliberately small — the full Pokémon-style structure
## does not get to drop rows just because the frame is 132px wide, because a card
## that reads differently in two places is the drift this renderer exists to
## prevent. Board legibility is answered by hover-to-enlarge (Combat.gd), not by
## a second layout.
const METRICS := {
	"title_size":         { "hand": 12, "board": 9 },
	"stage_size":         { "hand": 8,  "board": 7 },
	"hp_size":            { "hand": 15, "board": 11 },
	"evolve_size":        { "hand": 8,  "board": 7 },
	"art_h":              { "hand": 74, "board": 40 },
	"chip_size":          { "hand": 8,  "board": 7 },
	"chip_h":             { "hand": 15, "board": 13 },
	"ability_title_size": { "hand": 9,  "board": 7 },
	"ability_text_size":  { "hand": 8,  "board": 7 },
	"attack_name_size":   { "hand": 10, "board": 8 },
	"attack_dmg_size":    { "hand": 11, "board": 9 },
	"icon_size":          { "hand": 10, "board": 7 },
	"footer_size":        { "hand": 8,  "board": 7 },
}


## Look up a metric for this card's mode. Unknown keys return 0 rather than
## erroring, so a typo shows as a collapsed row instead of crashing the board.
func _m(key: String) -> int:
	var entry: Dictionary = METRICS.get(key, {})
	return int(entry.get("hand" if mode == Mode.HAND else "board", 0))
```

- [ ] **Step 4: Verify the scenes still load**

The build path has not changed yet, so this is a check that the new file and const parse cleanly.

Run:
```
godot --headless --path "c:/Users/Jonah/OneDrive/Desktop/Godsfall" --script res://scripts/core/SceneSmokeTest.gd
```
Expected: `all scenes loaded`, exit 0. Any `SCRIPT ERROR` or parse error in the output is a failure — fix before moving on.

---

## Task 2: The header — HP top-right, stage top-left

**Files:**
- Modify: `scripts/ui/CardView.gd`

The current `_add_title()` (line 165) centers the name, `_add_stage_badge()` (line 197) draws a full-width badge row, and `_add_stat_row()` (line 234) puts HP on the left. All three are replaced by one header that matches the Pokémon reading order: stage marker top-left, name center, HP top-right.

- [ ] **Step 1: Write the failing test**

Create `scripts/core/CardViewTest.gd`:

```gdscript
extends SceneTree

## Structural assertions on the card frame.
##
## These check the *shape* of what CardView builds — that the header exists, that
## HP is in the right-hand cell, that a keyword chip disappears when its charge is
## spent. They deliberately do not check pixel positions, which would break on
## every metric tweak; they check that the nodes a player needs to read are
## present and carry the right text.
##
##   godot --headless --path <project> --script res://scripts/core/CardViewTest.gd

var _pass := 0
var _fail := 0


func check(ok: bool, label: String) -> void:
	if ok:
		_pass += 1
	else:
		_fail += 1
		print("  FAIL %s" % label)


## Depth-first search for a Label whose text contains `needle`.
func find_label(n: Node, needle: String) -> Label:
	if n is Label and (n as Label).text.contains(needle):
		return n
	for c in n.get_children():
		var got := find_label(c, needle)
		if got != null:
			return got
	return null


## Every Label under a node, in tree order.
func all_labels(n: Node, out: Array = []) -> Array:
	if n is Label:
		out.append(n)
	for c in n.get_children():
		all_labels(c, out)
	return out


func find_node_named(n: Node, want: String) -> Node:
	if n.name == want:
		return n
	for c in n.get_children():
		var got := find_node_named(c, want)
		if got != null:
			return got
	return null


func _initialize() -> void:
	var db = root.get_node_or_null("CardDB")
	if db != null and db._cards.is_empty():
		db._load()

	print("\n=== CardView layout test ===\n")

	await _test_header()

	print("\n%d passed, %d failed\n" % [_pass, _fail])
	quit(1 if _fail > 0 else 0)


func _test_header() -> void:
	var card: CardData = CardDB.get_card("charnel_colossus")
	check(card != null, "fixture card charnel_colossus exists")
	if card == null:
		return

	var view := CardView.new(card, null, CardView.Mode.HAND)
	root.add_child(view)
	await process_frame

	## HP lives in its own named node so the layout can move without the test
	## chasing it, and so Combat/DeckBuilder could address it if they ever need to.
	var hp := find_node_named(view, "HPLabel") as Label
	check(hp != null, "header has an HPLabel")
	if hp != null:
		check(hp.text.contains("90"), "HP label shows printed HP (90), got '%s'" % hp.text)

	var stage := find_node_named(view, "StageLabel") as Label
	check(stage != null, "header has a StageLabel")
	if stage != null:
		check(stage.text.to_upper().contains("BASIC"), "stage reads BASIC, got '%s'" % stage.text)

	check(find_label(view, "Charnel Colossus") != null, "name is present")

	view.queue_free()
	await process_frame
```

- [ ] **Step 2: Run it to make sure it fails**

Run:
```
godot --headless --path "c:/Users/Jonah/OneDrive/Desktop/Godsfall" --script res://scripts/core/CardViewTest.gd
```
Expected: FAIL lines for `header has an HPLabel` and `header has a StageLabel` (the nodes do not exist yet), and a non-zero exit. The name assertion should already pass.

- [ ] **Step 3: Replace the three header builders**

In `scripts/ui/CardView.gd`, delete `_add_title()` (lines 165–191), `_add_stage_badge()` (lines 194–230), and `_add_stat_row()` (lines 233–272). Keep `_typing_text()` and `_stage_color()` — the header uses both.

Add in their place:

```gdscript
## The header row, in Pokémon's reading order:
##
##   [STAGE]        Card Name        330 HP ⬢
##
## HP is top-right because that is the number a player checks most often and the
## one they check *fastest* — it is the read that decides whether an attack kills.
## Putting it in a fixed corner means it is found without scanning, on both sides
## of the board, at either size.
func _add_header(root: VBoxContainer) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(row)

	## Left cell — stage for units, type label for everything else.
	var stage := Label.new()
	stage.name = "StageLabel"
	stage.text = card.stage_name().to_upper() if card.is_unit() else card.type_label().to_upper()
	stage.add_theme_font_size_override("font_size", _m("stage_size"))
	stage.add_theme_color_override("font_color", _stage_color() if card.is_unit() else _type_color())
	stage.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	## A fixed left cell keeps the name centred whatever the stage text is, so the
	## title does not shift between a Basic and a Stage 2.
	stage.custom_minimum_size = Vector2(_m("stage_size") * 4.2, 0)
	stage.clip_text = true
	row.add_child(stage)

	## Centre cell — the name, expanding to take the slack.
	var nm := Label.new()
	nm.name = "NameLabel"
	nm.text = card.name
	nm.add_theme_font_size_override("font_size", _m("title_size"))
	nm.add_theme_color_override("font_color", Palette.TEXT)
	nm.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	nm.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	nm.mouse_filter = Control.MOUSE_FILTER_IGNORE
	## Trim from the right with an ellipsis rather than clip_text, which is centred
	## and eats the *start* of the name too — "Hel, Queen of the Unclaimed" came out
	## as "el, Queen of the Unclaime". The opening words identify the card.
	nm.autowrap_mode = TextServer.AUTOWRAP_OFF
	nm.max_lines_visible = 1
	nm.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	if card.name.length() > 20:
		nm.add_theme_font_size_override("font_size", max(6, _m("title_size") - 2))
	row.add_child(nm)

	## Right cell — HP and the faction dot.
	var right := HBoxContainer.new()
	right.add_theme_constant_override("separation", 3)
	right.alignment = BoxContainer.ALIGNMENT_END
	right.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(right)

	if card.is_unit():
		var hp := Label.new()
		hp.name = "HPLabel"
		var hp_col: Color = Palette.HP_GREEN
		if unit != null:
			## In play, HP is current/max and colored by how hurt the unit is.
			hp.text = "%d/%d" % [max(0, unit.hp), unit.max_hp()]
			hp_col = Palette.hp_color(unit.hp, unit.max_hp())
		else:
			hp.text = "%d HP" % card.max_hp
		hp.add_theme_font_size_override("font_size", _m("hp_size"))
		hp.add_theme_color_override("font_color", hp_col)
		hp.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		hp.mouse_filter = Control.MOUSE_FILTER_IGNORE
		right.add_child(hp)

	## The faction dot. A card's color is its energy color (CLAUDE.md: a faction
	## *is* an energy color), so one dot in a fixed corner identifies the color
	## without spending a row on the word.
	var dot := EnergyIcon.new(Palette.faction_color(card.faction), true, false, _m("hp_size") * 0.72)
	right.add_child(dot)


## The accent color for a non-unit card's type label, matching the frame border
## each type already gets in _frame_style().
func _type_color() -> Color:
	if card.is_energy():
		return Palette.GOLD
	return Palette.TOWER
```

- [ ] **Step 4: Wire the header into the build path**

In `_build()` (line 105–111), replace these three lines:

```gdscript
	_add_title(root)
	_add_stage_badge(root)
	_add_stat_row(root)
```

with:

```gdscript
	_add_header(root)
```

Leave `_add_art(root)`, `_add_abilities(root)`, `_add_attacks(root)` and `_add_energy_row(root)` alone for now — later tasks replace them.

- [ ] **Step 5: Run the test to verify it passes**

Run:
```
godot --headless --path "c:/Users/Jonah/OneDrive/Desktop/Godsfall" --script res://scripts/core/CardViewTest.gd
```
Expected: `4 passed, 0 failed` (fixture, HPLabel present, HP text, StageLabel present, stage text, name — count may differ slightly; what matters is `0 failed` and exit 0).

- [ ] **Step 6: Verify nothing else broke**

Run:
```
godot --headless --path "c:/Users/Jonah/OneDrive/Desktop/Godsfall" --script res://scripts/core/SceneSmokeTest.gd
godot --headless --path "c:/Users/Jonah/OneDrive/Desktop/Godsfall" --script res://scripts/core/HeavenTest.gd
```
Expected: `all scenes loaded`; `HeavenTest` passes all 61 assertions. `HeavenTest` matters here because it asserts on live keyword rendering, which this task did not touch but the next one does.

---

## Task 3: The evolves-from strip

**Files:**
- Modify: `scripts/ui/CardView.gd`
- Modify: `scripts/core/CardViewTest.gd`

The old stage badge appended `"  ↑ Charmeleon"` to the badge text. The request is for evolution to be *clear*, so it gets its own strip directly under the header — the position Pokémon uses.

- [ ] **Step 1: Write the failing test**

In `scripts/core/CardViewTest.gd`, add this function, and add `await _test_evolve_strip()` to `_initialize()` after `await _test_header()`:

```gdscript
func _test_evolve_strip() -> void:
	## A Stage 1 or Stage 2 that names a base form shows the strip.
	var evolved: CardData = null
	for cid in CardDB.all_ids():
		var c: CardData = CardDB.get_card(cid)
		if c == null:
			continue
		if c.is_unit() and c.evolves_from != "" and CardDB.get_card(c.evolves_from) != null:
			evolved = c
			break
	check(evolved != null, "found an evolving unit to test with")
	if evolved == null:
		return

	var base: CardData = CardDB.get_card(evolved.evolves_from)

	var view := CardView.new(evolved, null, CardView.Mode.HAND)
	root.add_child(view)
	await process_frame

	var strip := find_node_named(view, "EvolveStrip") as Label
	check(strip != null, "evolving unit has an EvolveStrip")
	if strip != null:
		check(strip.text.contains(base.name),
			"strip names the base form '%s', got '%s'" % [base.name, strip.text])
	view.queue_free()
	await process_frame

	## A Basic has no base form, so it must NOT reserve a strip — an empty row
	## would waste the scarcest thing on the board card, vertical space.
	var basic: CardData = CardDB.get_card("charnel_colossus")
	var bview := CardView.new(basic, null, CardView.Mode.HAND)
	root.add_child(bview)
	await process_frame
	check(find_node_named(bview, "EvolveStrip") == null, "a Basic has no EvolveStrip")
	bview.queue_free()
	await process_frame
```

**Verified signatures** (checked against the code before this plan was executed — use these exactly):

- `CardDB` has **no** `all_cards()`. Enumerate with `CardDB.all_ids() -> Array[String]` and resolve each id through `CardDB.get_card(id)`, as the test above does.
- `Unit._init(c: CardData)`, so `Unit.new(card)` is correct. `Unit.attached`, `Unit.hp`, `Unit.lost_rise`, `Unit.judgment_spent`, `Unit.sanctuary_active`, `Unit.sanctuary_pool` and `Unit.queued_attack` are all plain settable members; `Unit.max_hp()` and `Unit.has_used_ability(ab)` are methods.

- [ ] **Step 2: Run it to verify it fails**

Run:
```
godot --headless --path "c:/Users/Jonah/OneDrive/Desktop/Godsfall" --script res://scripts/core/CardViewTest.gd
```
Expected: FAIL on `evolving unit has an EvolveStrip`, exit non-zero.

- [ ] **Step 3: Implement the strip**

In `scripts/ui/CardView.gd`, add:

```gdscript
## "↑ Evolves from Charmeleon" — its own strip under the header.
##
## This used to be tacked onto the end of the stage badge's text, where it was
## the least prominent thing on the card despite being the one piece of
## information that decides whether a card in hand is playable *at all*: a Stage 1
## with no base form on the board is a dead card. It gets its own row for the same
## reason Pokémon gives it one.
##
## Only drawn when the card actually evolves from something. A Basic gets no
## empty strip — vertical space is the scarcest thing on a 196px board card, and
## reserving a row to say "nothing" is the worst possible use of it.
func _add_evolve_strip(root: VBoxContainer) -> void:
	if not card.is_unit() or card.evolves_from == "":
		return
	var base: CardData = CardDB.get_card(card.evolves_from)
	if base == null:
		return

	var panel := PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var col: Color = _stage_color()
	var s := StyleBoxFlat.new()
	s.bg_color = col.darkened(0.72)
	s.border_color = col.darkened(0.35)
	s.set_border_width_all(1)
	s.set_corner_radius_all(3)
	s.content_margin_top = 0
	s.content_margin_bottom = 0
	s.content_margin_left = 4
	s.content_margin_right = 4
	panel.add_theme_stylebox_override("panel", s)
	root.add_child(panel)

	var l := Label.new()
	l.name = "EvolveStrip"
	l.text = "↑ Evolves from %s" % base.name
	l.add_theme_font_size_override("font_size", _m("evolve_size"))
	l.add_theme_color_override("font_color", col.lightened(0.5))
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.clip_text = true
	l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(l)
```

- [ ] **Step 4: Wire it in**

In `_build()`, add the call immediately after `_add_header(root)`:

```gdscript
	_add_header(root)
	_add_evolve_strip(root)
	_add_art(root)
```

- [ ] **Step 5: Run the tests to verify they pass**

Run:
```
godot --headless --path "c:/Users/Jonah/OneDrive/Desktop/Godsfall" --script res://scripts/core/CardViewTest.gd
godot --headless --path "c:/Users/Jonah/OneDrive/Desktop/Godsfall" --script res://scripts/core/SceneSmokeTest.gd
```
Expected: both pass with exit 0.

---

## Task 4: The keyword chip row

**Files:**
- Modify: `scripts/ui/CardView.gd`
- Modify: `scripts/core/CardViewTest.gd`

This replaces `_add_abilities()` (line 361), which rendered the keyword line as one centered comma-joined string. **`_live_keyword_line()` is kept and still does the filtering** — this task changes only how the result is drawn, from a string into one chip per keyword.

The reason to keep the existing function rather than rewrite the filtering: it encodes the "spent charges must visibly disappear" rule that `HeavenTest.gd` guards, and it is correct. Re-deriving it risks silently losing the `Sanctuary N` remaining-pool behaviour.

- [ ] **Step 1: Write the failing test**

Add to `scripts/core/CardViewTest.gd`, and add `await _test_keyword_chips()` to `_initialize()`:

```gdscript
func _test_keyword_chips() -> void:
	var card: CardData = CardDB.get_card("charnel_colossus")   ## Toll 3
	check(card.has_kw("toll"), "fixture has Toll")

	var view := CardView.new(card, null, CardView.Mode.HAND)
	root.add_child(view)
	await process_frame

	var chips := find_node_named(view, "KeywordChips")
	check(chips != null, "card with keywords has a KeywordChips row")
	if chips != null:
		var texts: Array = []
		for l in all_labels(chips):
			texts.append((l as Label).text)
		check(texts.size() == 1, "one chip per keyword, got %d" % texts.size())
		check(str(texts).contains("Toll 3"), "chip reads 'Toll 3', got %s" % str(texts))
	view.queue_free()
	await process_frame

	## A spent charge must disappear from the board. This is the rule CLAUDE.md
	## records as "state the rules engine tracks per-unit has to be visible
	## per-unit" — a Judgment unit that has cashed its charge still printed
	## "Judgment 30" before _live_keyword_line() existed, which made the decision
	## the keyword is built around impossible to make.
	var judged: CardData = null
	for cid in CardDB.all_ids():
		var c: CardData = CardDB.get_card(cid)
		if c == null:
			continue
		if c.is_unit() and c.has_kw("judgment"):
			judged = c
			break
	check(judged != null, "found a Judgment unit to test with")
	if judged == null:
		return

	var u := Unit.new(judged)
	var live := CardView.new(judged, u, CardView.Mode.BOARD)
	root.add_child(live)
	await process_frame
	var before := find_node_named(live, "KeywordChips")
	var n_before: int = 0 if before == null else all_labels(before).size()
	check(n_before >= 1, "unspent Judgment shows a chip")
	live.queue_free()
	await process_frame

	u.judgment_spent = true
	var after_view := CardView.new(judged, u, CardView.Mode.BOARD)
	root.add_child(after_view)
	await process_frame
	var after := find_node_named(after_view, "KeywordChips")
	var n_after: int = 0 if after == null else all_labels(after).size()
	check(n_after < n_before, "spent Judgment drops its chip (%d -> %d)" % [n_before, n_after])
	after_view.queue_free()
	await process_frame
```

`Unit.new(judged)` must match `Unit`'s actual constructor. Check it first:

```
grep -n "func _init" scripts/core/Unit.gd
```

If the signature differs, construct the unit the way `GameState` does — search for `Unit.new(` in `scripts/core/GameState.gd` and copy that call.

- [ ] **Step 2: Run it to verify it fails**

Run:
```
godot --headless --path "c:/Users/Jonah/OneDrive/Desktop/Godsfall" --script res://scripts/core/CardViewTest.gd
```
Expected: FAIL on `card with keywords has a KeywordChips row`.

- [ ] **Step 3: Implement the chip row**

In `scripts/ui/CardView.gd`, delete `_add_abilities()` (lines 361–376). **Keep `_live_keyword_line()` exactly as it is.** Add:

```gdscript
## Keywords as a row of tinted chips, under the art.
##
## The values come from _live_keyword_line(), NOT from CardData.keyword_line() —
## a spent Judgment or Rise must vanish from the board, and Sanctuary must show
## its remaining pool rather than its printed one. See that function's comment;
## HeavenTest.gd asserts the behaviour.
##
## Chips rather than one comma-joined line because a keyword is a discrete thing
## a player checks for ("does that body still hold its charge?"), and a row of
## separated pills answers that with a glance where a sentence has to be read.
## Each chip is colored by keyword via Palette.keyword_color(), so Toll and
## Judgment are told apart before either word is read.
##
## The row is omitted entirely when the card has no live keywords — the old
## renderer printed a placeholder em-dash, which spent a row saying nothing.
func _add_keyword_chips(root: VBoxContainer) -> void:
	if not card.is_unit():
		return

	var text := _live_keyword_line()
	if text.strip_edges() == "":
		return

	var row := HBoxContainer.new()
	row.name = "KeywordChips"
	row.add_theme_constant_override("separation", 3)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.custom_minimum_size = Vector2(0, _m("chip_h"))
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(row)

	for part in text.split(",", false):
		var p := str(part).strip_edges()
		if p == "":
			continue
		row.add_child(_keyword_chip(p))


## One chip. `text` is a live keyword phrase like "Toll 3" or "Sanctuary 40";
## the first word is what selects the color.
func _keyword_chip(text: String) -> Control:
	var kw_name := text.split(" ")[0].to_lower()
	var col: Color = Palette.keyword_color(kw_name)

	var chip := PanelContainer.new()
	chip.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var s := StyleBoxFlat.new()
	s.bg_color = col.darkened(0.68)
	s.border_color = col
	s.set_border_width_all(1)
	s.set_corner_radius_all(7)
	s.content_margin_left = 4
	s.content_margin_right = 4
	s.content_margin_top = 0
	s.content_margin_bottom = 0
	chip.add_theme_stylebox_override("panel", s)

	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", _m("chip_size"))
	l.add_theme_color_override("font_color", col.lightened(0.55))
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chip.add_child(l)
	return chip
```

- [ ] **Step 4: Wire it in**

In `_build()`, replace `_add_abilities(root)` with `_add_keyword_chips(root)`:

```gdscript
	_add_header(root)
	_add_evolve_strip(root)
	_add_art(root)
	_add_keyword_chips(root)
	_add_attacks(root)
	_add_energy_row(root)
```

- [ ] **Step 5: Run the tests to verify they pass**

Run:
```
godot --headless --path "c:/Users/Jonah/OneDrive/Desktop/Godsfall" --script res://scripts/core/CardViewTest.gd
godot --headless --path "c:/Users/Jonah/OneDrive/Desktop/Godsfall" --script res://scripts/core/HeavenTest.gd
godot --headless --path "c:/Users/Jonah/OneDrive/Desktop/Godsfall" --script res://scripts/core/SceneSmokeTest.gd
```
Expected: all three pass, exit 0 each. **`HeavenTest` is the important one** — if it fails, the live-keyword behaviour regressed and the fix is in `_add_keyword_chips`, not in `_live_keyword_line()`.

---

## Task 5: The ability banner

**Files:**
- Modify: `scripts/ui/CardView.gd`
- Modify: `scripts/core/CardViewTest.gd`

Pokémon draws abilities in a colored banner distinct from attacks. This project has a real structural reason to match that: per CLAUDE.md, **abilities and attacks are different mechanics** — an ability resolves immediately, is once-per-turn, and is free except for `Consume`; an attack is queued, resolves at end of turn, and pays an attached cost that is then free forever. The current card marks that difference with a `◆` prefix, which is easy to miss.

- [ ] **Step 1: Write the failing test**

Add to `scripts/core/CardViewTest.gd`, and add `await _test_ability_banner()` to `_initialize()`:

```gdscript
func _test_ability_banner() -> void:
	## Charnel Colossus: one ability (Consume the Fallen, free) + one attack (Crush).
	var card: CardData = CardDB.get_card("charnel_colossus")
	check(card.ability_lines().size() == 1, "fixture has exactly one ability")
	check(card.attack_lines().size() == 1, "fixture has exactly one attack")

	var view := CardView.new(card, null, CardView.Mode.HAND)
	root.add_child(view)
	await process_frame

	var banner := find_node_named(view, "AbilityBanner")
	check(banner != null, "a card with an ability has an AbilityBanner")
	if banner != null:
		check(find_label(banner, "Consume the Fallen") != null, "banner names the ability")
		check(find_label(banner, "ABILITY") != null, "banner is labelled ABILITY")
	view.queue_free()
	await process_frame

	## A unit whose lines are all attacks gets no banner — the banner marks a
	## *different mechanic*, so drawing an empty one would dilute the signal.
	var no_ability: CardData = null
	for cid in CardDB.all_ids():
		var c: CardData = CardDB.get_card(cid)
		if c == null:
			continue
		if c.is_unit() and c.ability_lines().is_empty() and not c.attack_lines().is_empty():
			no_ability = c
			break
	check(no_ability != null, "found an attacks-only unit")
	if no_ability != null:
		var v2 := CardView.new(no_ability, null, CardView.Mode.HAND)
		root.add_child(v2)
		await process_frame
		check(find_node_named(v2, "AbilityBanner") == null, "attacks-only unit has no banner")
		v2.queue_free()
		await process_frame
```

- [ ] **Step 2: Run it to verify it fails**

Run:
```
godot --headless --path "c:/Users/Jonah/OneDrive/Desktop/Godsfall" --script res://scripts/core/CardViewTest.gd
```
Expected: FAIL on `a card with an ability has an AbilityBanner`.

- [ ] **Step 3: Implement the banner**

In `scripts/ui/CardView.gd`, add:

```gdscript
## Abilities in a colored banner, above the attack rows.
##
## Abilities and attacks are genuinely different mechanics in this game, not two
## flavours of the same one (CLAUDE.md, *Abilities vs. Attacks*): an ability
## resolves immediately, is limited to once per turn, and is free — its only
## possible cost is `Consume N`, which destroys attached energy. An attack is
## queued, resolves at end of turn, and pays a cost that stays attached and is
## free every turn after. The old renderer marked that difference with a small
## "◆" prefix, which is easy to miss on a 132px card. A banner is not decoration
## here; it is the visual form of a rules distinction.
##
## `Consume N` is printed in the banner header rather than in a cost-icon row,
## because it is not a requirement that sits on the unit — it is energy destroyed
## on each use, which is why a Consume ability never becomes a free permanent
## engine. Rendering it as cost icons would read as "attach this much", which is
## the opposite of what it does.
func _add_ability_banner(root: VBoxContainer) -> void:
	if not card.is_unit():
		return
	var abilities: Array = card.ability_lines()
	if abilities.is_empty():
		return

	for atk in abilities:
		var used: bool = unit != null and unit.has_used_ability(atk)
		var col: Color = Palette.ACCENT if not used else Palette.TEXT_DIM

		var panel := PanelContainer.new()
		panel.name = "AbilityBanner"
		panel.mouse_filter = Control.MOUSE_FILTER_IGNORE

		var s := StyleBoxFlat.new()
		s.bg_color = col.darkened(0.72)
		s.border_color = col
		s.set_border_width_all(1)
		s.set_corner_radius_all(4)
		s.content_margin_left = 4
		s.content_margin_right = 4
		s.content_margin_top = 1
		s.content_margin_bottom = 1
		panel.add_theme_stylebox_override("panel", s)
		root.add_child(panel)

		var col_box := VBoxContainer.new()
		col_box.add_theme_constant_override("separation", 0)
		col_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
		panel.add_child(col_box)

		## Header: the ABILITY tag, the line's name, and what it burns.
		var head := HBoxContainer.new()
		head.add_theme_constant_override("separation", 4)
		head.mouse_filter = Control.MOUSE_FILTER_IGNORE
		col_box.add_child(head)

		var tag := Label.new()
		tag.text = "ABILITY"
		tag.add_theme_font_size_override("font_size", max(6, _m("ability_title_size") - 1))
		tag.add_theme_color_override("font_color", col.lightened(0.4))
		tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
		head.add_child(tag)

		var nm := Label.new()
		nm.text = atk.name
		nm.add_theme_font_size_override("font_size", _m("ability_title_size"))
		nm.add_theme_color_override("font_color",
			Palette.TEXT if not used else Palette.TEXT_DIM.darkened(0.25))
		nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		nm.clip_text = true
		nm.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		nm.mouse_filter = Control.MOUSE_FILTER_IGNORE
		head.add_child(nm)

		var cost := Label.new()
		cost.text = "⊘%d" % atk.consume if atk.consume > 0 else "free"
		cost.add_theme_font_size_override("font_size", max(6, _m("ability_title_size") - 1))
		cost.add_theme_color_override("font_color",
			Palette.ACCENT.lightened(0.2) if atk.consume > 0 else Palette.TEXT_DIM)
		cost.mouse_filter = Control.MOUSE_FILTER_IGNORE
		head.add_child(cost)

		## Body: the rules text. Hand cards wrap it; board cards get one trimmed
		## line, because the board frame has no room to grow and clip_contents
		## would otherwise cut a wrapped block mid-sentence.
		if atk.text != "":
			var body := Label.new()
			body.text = atk.text
			body.add_theme_font_size_override("font_size", _m("ability_text_size"))
			body.add_theme_color_override("font_color", Palette.TEXT_DIM)
			body.mouse_filter = Control.MOUSE_FILTER_IGNORE
			if mode == Mode.HAND:
				body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			else:
				body.autowrap_mode = TextServer.AUTOWRAP_OFF
				body.max_lines_visible = 1
				body.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
			col_box.add_child(body)
```

- [ ] **Step 4: Wire it in**

In `_build()`:

```gdscript
	_add_header(root)
	_add_evolve_strip(root)
	_add_art(root)
	_add_keyword_chips(root)
	_add_ability_banner(root)
	_add_attacks(root)
	_add_energy_row(root)
```

- [ ] **Step 5: Run the tests to verify they pass**

Run:
```
godot --headless --path "c:/Users/Jonah/OneDrive/Desktop/Godsfall" --script res://scripts/core/CardViewTest.gd
godot --headless --path "c:/Users/Jonah/OneDrive/Desktop/Godsfall" --script res://scripts/core/SceneSmokeTest.gd
```
Expected: both pass. Note that at this point abilities render **twice** — once in the banner and once in the old `_add_attacks()` list. Task 6 removes the duplicate.

---

## Task 6: Attack rows with inline energy cost icons

**Files:**
- Modify: `scripts/ui/CardView.gd`
- Modify: `scripts/core/CardViewTest.gd`

This replaces both `_add_attacks()` (line 422) and `_add_energy_row()` (line 486). Costs currently live in a separate pip block at the bottom of the card, disconnected from the attack they belong to — on a two-attack card the player has to match rows to pip-rows by position. The request is for cost icons **next to the attack name**, which is what Pokémon does and what removes that matching step.

Two behaviours from `_add_energy_row()` must survive:
- **Attached energy fills icons left-to-right**, so a unit's progress toward affording an attack is visible.
- **Costs above 8 collapse to a numeric chip**, because nine-plus icons overflow the frame.

- [ ] **Step 1: Write the failing test**

Add to `scripts/core/CardViewTest.gd`, and add `await _test_attack_rows()` to `_initialize()`:

```gdscript
func _test_attack_rows() -> void:
	var card: CardData = CardDB.get_card("charnel_colossus")   ## Crush: 3 Hel, 38 dmg

	var view := CardView.new(card, null, CardView.Mode.HAND)
	root.add_child(view)
	await process_frame

	var rows := find_node_named(view, "AttackRows")
	check(rows != null, "unit has an AttackRows block")
	if rows != null:
		check(find_label(rows, "Crush") != null, "attack row names the attack")
		check(find_label(rows, "38") != null, "attack row shows damage")
		## The ability moved to the banner in Task 5 — it must not also appear here.
		check(find_label(rows, "Consume the Fallen") == null,
			"ability is not duplicated in the attack rows")

		var icons: int = _count_icons(rows)
		check(icons == 3, "Crush shows 3 cost icons, got %d" % icons)
	view.queue_free()
	await process_frame

	## In play, attached energy fills the icons so a player can see how close the
	## unit is to affording the attack.
	var u := Unit.new(card)
	u.attached = 2
	var live := CardView.new(card, u, CardView.Mode.BOARD)
	root.add_child(live)
	await process_frame
	var live_rows := find_node_named(live, "AttackRows")
	check(live_rows != null, "board card has attack rows")
	if live_rows != null:
		var filled: int = 0
		for n in _collect_icons(live_rows):
			if (n as EnergyIcon).filled:
				filled += 1
		check(filled == 2, "2 attached energy fills 2 icons, got %d" % filled)
	live.queue_free()
	await process_frame


func _collect_icons(n: Node, out: Array = []) -> Array:
	if n is EnergyIcon:
		out.append(n)
	for c in n.get_children():
		_collect_icons(c, out)
	return out


func _count_icons(n: Node) -> int:
	return _collect_icons(n).size()
```

`u.attached = 2` assumes `Unit.attached` is a settable int — `CardView` reads it at line 506, so it exists. Confirm the constructor as in Task 4.

- [ ] **Step 2: Run it to verify it fails**

Run:
```
godot --headless --path "c:/Users/Jonah/OneDrive/Desktop/Godsfall" --script res://scripts/core/CardViewTest.gd
```
Expected: FAIL on `unit has an AttackRows block`, and on the ability-duplication check (the old renderer still lists it).

- [ ] **Step 3: Implement the attack rows**

In `scripts/ui/CardView.gd`, delete `_add_attacks()` (lines 422–480) and `_add_energy_row()` (lines 486–540). **Keep `_pip()`** — nothing else uses it, so delete that too (lines 595–610); if a later grep shows another caller, keep it. Verify with:

```
grep -rn "_pip(" scripts/
```

Add:

```gdscript
## One row per attack: cost icons, name, damage.
##
## Costs sit beside the attack they pay for. They used to live in a separate pip
## block at the bottom of the card, which meant a player reading a two-attack unit
## had to match rows to pip-rows by position — a step that is pure overhead and
## gets worse on the board card, where both blocks are small. Pokémon puts the
## cost inline for the same reason.
##
## Only attacks get a row. Abilities are drawn in the banner above, because they
## resolve on a different clock and pay a different kind of cost (see
## _add_ability_banner).
func _add_attack_rows(root: VBoxContainer) -> void:
	## Non-units carry rules text instead of attack lines.
	if not card.is_unit():
		var note := Label.new()
		note.name = "RulesText"
		note.text = card.text if card.is_support_like() else "Adds energy to your pool.\nOne per turn."
		note.add_theme_font_size_override("font_size", _m("ability_text_size"))
		note.add_theme_color_override("font_color", Palette.TEXT_DIM)
		note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		note.size_flags_vertical = Control.SIZE_EXPAND_FILL
		note.mouse_filter = Control.MOUSE_FILTER_IGNORE
		root.add_child(note)
		return

	var box := VBoxContainer.new()
	box.name = "AttackRows"
	box.add_theme_constant_override("separation", 2)
	box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(box)

	var attached: int = unit.attached if unit != null else 0

	for atk in card.attack_lines():
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 3)
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.add_child(row)

		var queued: bool = unit != null and unit.queued_attack == atk

		row.add_child(_cost_icons(atk, attached))

		var nm := Label.new()
		nm.text = ("▶ " if queued else "") + atk.name
		nm.add_theme_font_size_override("font_size", _m("attack_name_size"))
		nm.add_theme_color_override("font_color", Palette.GOLD if queued else Palette.TEXT)
		nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		nm.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		nm.clip_text = true
		nm.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		nm.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(nm)

		var dmg := Label.new()
		dmg.text = str(atk.damage) if atk.damage > 0 else "—"
		dmg.add_theme_font_size_override("font_size", _m("attack_dmg_size"))
		dmg.add_theme_color_override("font_color",
			Palette.DANGER if atk.damage > 0 else Palette.TEXT_DIM)
		dmg.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		dmg.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(dmg)


## The cost icons for one attack.
##
## Filled left-to-right by `attached`, so the row doubles as a progress bar
## toward affording the attack — the read that makes accumulating energy on a
## unit legible, and the reason big attacks feel reachable rather than abstract.
##
## Costs above 8 collapse to a numeric chip. Nine or more icons overflow a 132px
## frame, and the cards that cost that much (Cacophony Ramp reaches 14) are
## precisely the ones a player is counting toward, so the number is more useful
## than the row would be anyway.
func _cost_icons(atk: AttackData, attached: int) -> Control:
	var box := HBoxContainer.new()
	box.add_theme_constant_override("separation", 1)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var cost: int = atk.total_cost()

	if cost == 0:
		var free := Label.new()
		free.text = "free"
		free.add_theme_font_size_override("font_size", max(6, _m("icon_size") - 1))
		free.add_theme_color_override("font_color", Palette.TEXT_DIM)
		free.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.add_child(free)
		return box

	if cost > 8:
		var chip := Label.new()
		chip.text = "⬢%d%s" % [cost, ("/%d" % attached) if unit != null else ""]
		chip.add_theme_font_size_override("font_size", _m("icon_size"))
		chip.add_theme_color_override("font_color",
			Palette.GOLD if attached >= cost else Palette.TEXT_DIM)
		chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.add_child(chip)
		return box

	## The attack's printed color, falling back to the card's own faction when the
	## cost block named none (a purely colorless cost).
	var col: Color = Palette.faction_color(
		atk.cost_color if atk.cost_color != "" else card.faction)

	for i in cost:
		var is_colorless: bool = i >= atk.cost_faction
		var is_filled: bool = unit != null and i < attached
		box.add_child(EnergyIcon.new(col, is_filled, is_colorless, _m("icon_size")))
	return box
```

- [ ] **Step 4: Wire it in**

In `_build()`, the call list becomes:

```gdscript
	_add_header(root)
	_add_evolve_strip(root)
	_add_art(root)
	_add_keyword_chips(root)
	_add_ability_banner(root)
	_add_attack_rows(root)
```

`_add_energy_row(root)` is gone. `_add_hover_text()` still follows — leave it.

- [ ] **Step 5: Run the tests to verify they pass**

Run:
```
godot --headless --path "c:/Users/Jonah/OneDrive/Desktop/Godsfall" --script res://scripts/core/CardViewTest.gd
godot --headless --path "c:/Users/Jonah/OneDrive/Desktop/Godsfall" --script res://scripts/core/SceneSmokeTest.gd
godot --headless --path "c:/Users/Jonah/OneDrive/Desktop/Godsfall" --script res://scripts/core/SupportUITest.gd
```
Expected: all pass. `SupportUITest` drives the real combat UI and is the harness most likely to catch a broken card frame.

---

## Task 7: The footer — retreat cost bottom-right, weakness/resistance reserved

**Files:**
- Modify: `scripts/ui/CardView.gd`
- Modify: `scripts/core/CardViewTest.gd`

- [ ] **Step 1: Write the failing test**

Add to `scripts/core/CardViewTest.gd`, and add `await _test_footer()` to `_initialize()`:

```gdscript
func _test_footer() -> void:
	var card: CardData = CardDB.get_card("charnel_colossus")   ## retreat 2
	check(card.retreat == 2, "fixture retreat is 2, got %d" % card.retreat)

	var view := CardView.new(card, null, CardView.Mode.HAND)
	root.add_child(view)
	await process_frame

	var footer := find_node_named(view, "CardFooter")
	check(footer != null, "unit has a CardFooter")
	if footer != null:
		var icons: int = _count_icons(footer)
		check(icons == 2, "retreat 2 draws 2 icons in the footer, got %d" % icons)
		## Weakness and resistance are reserved but undesigned — they print an
		## em-dash so the frame does not need re-laying-out when the system lands.
		check(find_label(footer, "wk") != null, "footer reserves a weakness slot")
		check(find_label(footer, "res") != null, "footer reserves a resistance slot")
	view.queue_free()
	await process_frame

	## Non-units have no retreat and no weakness — no footer at all.
	var support: CardData = null
	for cid in CardDB.all_ids():
		var c: CardData = CardDB.get_card(cid)
		if c == null:
			continue
		if c.is_support_like():
			support = c
			break
	check(support != null, "found a support card")
	if support != null:
		var sv := CardView.new(support, null, CardView.Mode.HAND)
		root.add_child(sv)
		await process_frame
		check(find_node_named(sv, "CardFooter") == null, "a support has no unit footer")
		sv.queue_free()
		await process_frame
```

- [ ] **Step 2: Run it to verify it fails**

Run:
```
godot --headless --path "c:/Users/Jonah/OneDrive/Desktop/Godsfall" --script res://scripts/core/CardViewTest.gd
```
Expected: FAIL on `unit has a CardFooter`.

- [ ] **Step 3: Implement the footer**

In `scripts/ui/CardView.gd`, add:

```gdscript
## The bottom strip: weakness, resistance, and retreat cost.
##
## Retreat goes bottom-right because it is where Pokémon prints it and because it
## belongs with the other printed constants rather than with the attacks — retreat
## is a *design-time* number (HP / 40, printed on the card) that never changes in
## play. Buffs, damage and debuffs never move it; only evolving does, because the
## evolved card prints its own.
##
## Weakness and resistance print "—". The system is not designed (CLAUDE.md, Open
## Questions), and the slots are reserved so that adding it later is a data change
## rather than a re-layout. This follows the project's established pattern: retreat
## costs themselves shipped on the card for a while before the retreat action
## existed, and the UI said plainly that they did nothing.
func _add_footer(root: VBoxContainer) -> void:
	if not card.is_unit():
		return

	var row := HBoxContainer.new()
	row.name = "CardFooter"
	row.add_theme_constant_override("separation", 5)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(row)

	## Weakness / resistance — reserved, not implemented.
	var wk := Label.new()
	wk.text = "wk —"
	wk.add_theme_font_size_override("font_size", _m("footer_size"))
	wk.add_theme_color_override("font_color", Palette.TEXT_DIM.darkened(0.2))
	wk.tooltip_text = "Weakness — not yet implemented."
	wk.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(wk)

	var res := Label.new()
	res.text = "res —"
	res.add_theme_font_size_override("font_size", _m("footer_size"))
	res.add_theme_color_override("font_color", Palette.TEXT_DIM.darkened(0.2))
	res.tooltip_text = "Resistance — not yet implemented."
	res.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(res)

	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sp.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(sp)

	## Retreat cost, as icons. A unit with retreat 0 shows the label with no icons
	## rather than nothing, so the corner reads consistently across every card.
	var tag := Label.new()
	tag.text = "↩"
	tag.add_theme_font_size_override("font_size", _m("footer_size"))
	tag.add_theme_color_override("font_color", Palette.TEXT_DIM)
	tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(tag)

	var icons := HBoxContainer.new()
	icons.add_theme_constant_override("separation", 1)
	icons.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(icons)

	for _i in card.retreat:
		## Retreat is paid from the unit's own attached energy and is colorless in
		## effect — any attached energy pays it — so it draws as a grey icon rather
		## than in the faction color, which would read as a colored requirement.
		icons.add_child(EnergyIcon.new(Palette.TEXT_DIM, true, true, _m("footer_size")))
```

- [ ] **Step 4: Wire it in**

In `_build()`:

```gdscript
	_add_header(root)
	_add_evolve_strip(root)
	_add_art(root)
	_add_keyword_chips(root)
	_add_ability_banner(root)
	_add_attack_rows(root)
	_add_footer(root)
	_add_hover_text()
```

- [ ] **Step 5: Run the tests to verify they pass**

Run:
```
godot --headless --path "c:/Users/Jonah/OneDrive/Desktop/Godsfall" --script res://scripts/core/CardViewTest.gd
godot --headless --path "c:/Users/Jonah/OneDrive/Desktop/Godsfall" --script res://scripts/core/SceneSmokeTest.gd
```
Expected: both pass.

---

## Task 8: Non-unit cards keep a coherent frame

**Files:**
- Modify: `scripts/ui/CardView.gd`
- Modify: `scripts/core/CardViewTest.gd`

Energy, support, tool and tower-support cards now fall through several builders that return early. This task confirms they still render something complete, and restores the play-cost line that `_add_energy_row()` used to draw for them.

- [ ] **Step 1: Write the failing test**

Add to `scripts/core/CardViewTest.gd`, and add `await _test_non_units()` to `_initialize()`:

```gdscript
func _test_non_units() -> void:
	var kinds := {}
	for cid in CardDB.all_ids():
		var c: CardData = CardDB.get_card(cid)
		if c == null:
			continue
		if c.is_energy() and not kinds.has("energy"):
			kinds["energy"] = c
		elif c.type == CardData.Type.SUPPORT and not kinds.has("support"):
			kinds["support"] = c
		elif c.is_tool() and not kinds.has("tool"):
			kinds["tool"] = c
		elif c.is_tower_support() and not kinds.has("tower"):
			kinds["tower"] = c

	for key in ["energy", "support", "tool", "tower"]:
		check(kinds.has(key), "found a %s card to test" % key)
		if not kinds.has(key):
			continue
		var c: CardData = kinds[key]
		var view := CardView.new(c, null, CardView.Mode.HAND)
		root.add_child(view)
		await process_frame

		## Every non-unit must show its type and a play-cost line. Nothing may
		## render as an empty frame.
		check(find_node_named(view, "StageLabel") != null, "%s shows a type label" % key)
		check(find_node_named(view, "PlayCost") != null, "%s shows a play cost" % key)
		check(all_labels(view).size() >= 3, "%s frame is not empty" % key)

		## Units-only rows must be absent.
		check(find_node_named(view, "CardFooter") == null, "%s has no retreat footer" % key)
		check(find_node_named(view, "KeywordChips") == null, "%s has no keyword chips" % key)

		view.queue_free()
		await process_frame
```

- [ ] **Step 2: Run it to verify it fails**

Run:
```
godot --headless --path "c:/Users/Jonah/OneDrive/Desktop/Godsfall" --script res://scripts/core/CardViewTest.gd
```
Expected: FAIL on `... shows a play cost` for all four kinds — `_add_energy_row()` was deleted in Task 6 and nothing replaced it.

- [ ] **Step 3: Implement the play-cost line**

In `scripts/ui/CardView.gd`, add:

```gdscript
## The play-cost line for non-unit cards.
##
## Most supports are free, which is the point — energy only buys attacks. The
## handful that charge 1-3 pool energy are the one sanctioned exception (CLAUDE.md,
## *Priced supports*), so the line has to distinguish them: a free card and a
## 2-cost card must not read the same.
##
## Priced supports are NOT YET ENFORCED by the engine — CardData.cost is parsed
## and printed but play_support does not spend it. The cost is shown anyway,
## because the card should read correctly now and the data is already right; the
## inspector is where the "not yet implemented" note lives, since that is the
## screen with room to say it.
func _add_play_cost(root: VBoxContainer) -> void:
	if card.is_unit():
		return

	var sep := HSeparator.new()
	sep.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(sep)

	var row := HBoxContainer.new()
	row.name = "PlayCost"
	row.add_theme_constant_override("separation", 3)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(row)

	if card.is_energy():
		var l := Label.new()
		l.text = "⬢ scales with turn"
		l.add_theme_font_size_override("font_size", _m("footer_size"))
		l.add_theme_color_override("font_color", Palette.GOLD)
		l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(l)
		return

	if card.cost <= 0:
		var free := Label.new()
		free.text = "Free to play"
		free.add_theme_font_size_override("font_size", _m("footer_size"))
		free.add_theme_color_override("font_color", Palette.TOWER)
		free.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(free)
		return

	## Priced: icons, so the cost reads the same way an attack's does.
	for _i in card.cost:
		row.add_child(EnergyIcon.new(Palette.faction_color(card.faction), true, false, _m("icon_size")))

	var lbl := Label.new()
	lbl.text = "to play"
	lbl.add_theme_font_size_override("font_size", _m("footer_size"))
	lbl.add_theme_color_override("font_color", Palette.GOLD)
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(lbl)
```

- [ ] **Step 4: Wire it in**

In `_build()`, add `_add_play_cost(root)` after `_add_footer(root)`. The two are mutually exclusive — `_add_footer` returns early for non-units and `_add_play_cost` returns early for units — so the order between them does not matter, but keeping both at the bottom keeps the frame's shape obvious:

```gdscript
	_add_header(root)
	_add_evolve_strip(root)
	_add_art(root)
	_add_keyword_chips(root)
	_add_ability_banner(root)
	_add_attack_rows(root)
	_add_footer(root)
	_add_play_cost(root)
	_add_hover_text()
```

- [ ] **Step 5: Run the tests to verify they pass**

Run:
```
godot --headless --path "c:/Users/Jonah/OneDrive/Desktop/Godsfall" --script res://scripts/core/CardViewTest.gd
godot --headless --path "c:/Users/Jonah/OneDrive/Desktop/Godsfall" --script res://scripts/core/SceneSmokeTest.gd
godot --headless --path "c:/Users/Jonah/OneDrive/Desktop/Godsfall" --script res://scripts/core/SupportUITest.gd
godot --headless --path "c:/Users/Jonah/OneDrive/Desktop/Godsfall" --script res://scripts/core/DragDropTest.gd
```
Expected: all four pass. `DragDropTest` matters because the drag preview builds a second `CardView`.

---

## Task 9: Hover-to-enlarge on board cards

**Files:**
- Modify: `scripts/ui/Combat.gd`

The board card carries the full layout at ~7px type. Hovering a board card raises a scaled copy so it can be read. This is the answer to board legibility, and it is why the board card was allowed to stay at 132×196.

`CardView` already emits `hover_changed(hovering: bool)` (line 46) and `Combat` already connects it for hand cards (the hover lift). This task adds a board handler.

- [ ] **Step 1: Find how Combat hosts overlays**

The enlarged card must float **above** the board without affecting layout — the same constraint that made `CardView`'s hover panel a free-floating anchored child rather than a VBox row. Combat already hosts modal overlays (the card picker, the game-over panel). Find the pattern:

```
grep -n "CanvasLayer\|_overlay\|add_child(.*popup\|top_level" scripts/ui/Combat.gd
```

Use the existing overlay host if there is one. If there is not, add a `CanvasLayer` named `HoverLayer` in `Combat._ready()` so the enlarged card draws above every board node regardless of tree order.

- [ ] **Step 2: Add the enlarge overlay**

In `scripts/ui/Combat.gd`, add these members near the other overlay state (top of the file, alongside `_pending_support` and friends):

```gdscript
## Board cards carry the full card layout at ~7px type, which is readable enough
## to scan but not to study. Hovering one raises a scaled copy.
##
## A copy rather than scaling the board card in place: the board card lives inside
## a fixed-height slot wrapper (_wrap_with_status), and scaling it there would
## either clip against clip_contents or change the row height, which pushes the
## throne and the hand down the screen. A floating copy touches no layout at all.
const HOVER_ZOOM := 1.9
var _zoom_card: Control = null
var _zoom_layer: CanvasLayer = null
```

Add the two methods:

```gdscript
## Raise a scaled copy of a board card near its slot.
func _show_zoom(view: CardView) -> void:
	_hide_zoom()
	if view == null or view.card == null:
		return

	if _zoom_layer == null:
		_zoom_layer = CanvasLayer.new()
		_zoom_layer.layer = 50
		add_child(_zoom_layer)

	## The copy is built in HAND mode: the enlarged card is being *read*, and the
	## hand metrics are the ones authored for reading. Scaling the board metrics
	## would just magnify type that was sized to be small.
	var big := CardView.new(view.card, view.unit, CardView.Mode.HAND)
	big.enemy = view.enemy
	big.scale = Vector2(HOVER_ZOOM, HOVER_ZOOM)
	big.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var holder := Control.new()
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(big)

	## Position beside the hovered slot, then clamp into the viewport so a card at
	## the screen edge is not half off it.
	var slot_rect: Rect2 = view.get_global_rect()
	var big_size: Vector2 = CardView.HAND_SIZE * HOVER_ZOOM
	var vp: Vector2 = get_viewport_rect().size

	var pos := Vector2(
		slot_rect.position.x + slot_rect.size.x + 8,
		slot_rect.position.y + slot_rect.size.y * 0.5 - big_size.y * 0.5)
	## Flip to the left of the slot when there is no room on the right.
	if pos.x + big_size.x > vp.x - 8:
		pos.x = slot_rect.position.x - big_size.x - 8
	pos.x = clamp(pos.x, 8.0, max(8.0, vp.x - big_size.x - 8.0))
	pos.y = clamp(pos.y, 8.0, max(8.0, vp.y - big_size.y - 8.0))
	holder.position = pos

	_zoom_layer.add_child(holder)
	_zoom_card = holder


func _hide_zoom() -> void:
	if _zoom_card != null:
		_zoom_card.queue_free()
		_zoom_card = null
```

- [ ] **Step 3: Connect it to board cards**

In `_slot_widget()`, immediately after the board `CardView` is constructed (currently line 467–469):

```gdscript
	var view := CardView.new(u.card, u, CardView.Mode.BOARD)
	view.selected = (u == _selected_unit or u == _pending_two)
	view.enemy = is_enemy
	## Board type is small by design; hovering raises a readable copy.
	view.hover_changed.connect(func(on: bool):
		if on:
			_show_zoom(view)
		else:
			_hide_zoom())
```

- [ ] **Step 4: Clear the overlay when the board rebuilds**

A hovered card whose node is freed by a board refresh would leave the zoom stranded. Find the function that rebuilds the board (search for where `_slot_widget` is called from) and call `_hide_zoom()` at the top of it:

```
grep -n "_slot_widget(" scripts/ui/Combat.gd
```

Add `_hide_zoom()` as the first statement of that rebuild function.

- [ ] **Step 5: Verify**

Run:
```
godot --headless --path "c:/Users/Jonah/OneDrive/Desktop/Godsfall" --script res://scripts/core/SceneSmokeTest.gd
godot --headless --path "c:/Users/Jonah/OneDrive/Desktop/Godsfall" --script res://scripts/core/PlaythroughTest.gd
godot --headless --path "c:/Users/Jonah/OneDrive/Desktop/Godsfall" --script res://scripts/core/SupportUITest.gd
```
Expected: all pass. Headless runs never fire hover, so these confirm nothing broke rather than exercising the zoom — the zoom itself is checked by hand in Task 11.

---

## Task 10: Inspector note for weakness/resistance

**Files:**
- Modify: `scripts/ui/CardInspector.gd`

The card face prints `wk —` and `res —`. Per the project's standing rule, the UI must say plainly that this does nothing yet, and the inspector is the screen with room to say it.

- [ ] **Step 1: Add the note**

In `scripts/ui/CardInspector.gd`, inside `_add_costs()` (line 248), after the `how` label is added to `col` (line 277), add:

```gdscript
	## The card face reserves weakness and resistance slots that print an em-dash.
	## Never let a card promise something the engine cannot do — same reasoning
	## that put a "not yet implemented" line on priced supports.
	var wk := Palette.label(
		"Weakness / Resistance: NOT YET IMPLEMENTED. The card reserves both slots and prints '—'; no card has a weakness or a resistance, and no damage is modified by either.",
		11, Palette.TEXT_DIM)
	wk.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	wk.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_child(wk)
```

Note that `_add_costs()` returns early (line 249) when a card has neither retreat nor Toll. That is acceptable — such a card has no footer decisions to explain either. If the note should appear on every unit, move it into `_add_attacks()` instead; leave it here unless a card is found where it matters.

- [ ] **Step 2: Verify**

Run:
```
godot --headless --path "c:/Users/Jonah/OneDrive/Desktop/Godsfall" --script res://scripts/core/SceneSmokeTest.gd
```
Expected: `all scenes loaded`.

---

## Task 11: Full harness sweep and a real playtest

**Files:** none

- [ ] **Step 1: Run every harness**

Run each of these and record the result. **Report the actual output — do not claim a pass that was not observed.**

```
godot --headless --path "c:/Users/Jonah/OneDrive/Desktop/Godsfall" --script res://scripts/core/RulesTest.gd
godot --headless --path "c:/Users/Jonah/OneDrive/Desktop/Godsfall" --script res://scripts/core/SupportTest.gd
godot --headless --path "c:/Users/Jonah/OneDrive/Desktop/Godsfall" --script res://scripts/core/DeckStoreTest.gd
godot --headless --path "c:/Users/Jonah/OneDrive/Desktop/Godsfall" --script res://scripts/core/DragDropTest.gd
godot --headless --path "c:/Users/Jonah/OneDrive/Desktop/Godsfall" --script res://scripts/core/SceneSmokeTest.gd
godot --headless --path "c:/Users/Jonah/OneDrive/Desktop/Godsfall" --script res://scripts/core/PlaythroughTest.gd
godot --headless --path "c:/Users/Jonah/OneDrive/Desktop/Godsfall" --script res://scripts/core/SupportUITest.gd
godot --headless --path "c:/Users/Jonah/OneDrive/Desktop/Godsfall" --script res://scripts/core/HeavenTest.gd
godot --headless --path "c:/Users/Jonah/OneDrive/Desktop/Godsfall" --script res://scripts/core/VoidTest.gd
godot --headless --path "c:/Users/Jonah/OneDrive/Desktop/Godsfall" --script res://scripts/core/CardViewTest.gd
```

Expected: all pass. **Two known flakes** are documented in CLAUDE.md and are not caused by this change:
- `RulesTest.gd`'s unit-only AI mirror stalls roughly 1 run in 14
- `SupportTest.gd`'s support-heavy mirror stalls roughly 1 run in 10

If one of those two fails, re-run once to confirm it is the known flake. **Capture the output either way** — CLAUDE.md notes that an intermittent failure is information, not noise. Any failure in a different harness is a real regression from this work.

- [ ] **Step 2: Play the game**

Launch from the `Godsfall` desktop shortcut and check, by eye:

1. A unit in hand shows: stage top-left, name centered, HP top-right with a faction dot, the evolves-from strip on evolutions, keyword chips, the ability banner where there is an ability, cost icons beside each attack, and the retreat corner.
2. The board row has not changed height — the throne, pool bar and hand sit where they did.
3. Hovering a board card raises a readable enlarged copy, positioned on-screen even for the rightmost slot.
4. Charging a unit fills its attack cost icons left to right.
5. A Heaven unit that spends its Judgment loses the chip. A Sanctuary unit's chip counts down as it absorbs.
6. Energy, support, tool and tower-support cards all render a complete frame.
7. The deck builder grid and the card inspector both look right — they build the same `CardView`.

- [ ] **Step 3: Check the error log**

```
type logs\errors.log
```

Expected: empty. If not, fix the causes, then archive:

```
powershell -ExecutionPolicy Bypass -File tools\archive-errors.ps1 -Note "card layout rework"
```

---

## Task 12: Document the change in CLAUDE.md

**Files:**
- Modify: `CLAUDE.md`

Per CLAUDE.md's own standing rule, docs are updated **when a change lands and Jonah confirms it works** — so this task runs after Task 11's playtest, not before.

- [ ] **Step 1: Add the card layout section**

In `CLAUDE.md`, in the *Status* section near the existing "Cards can be clicked or dragged" and "Clicking a card in the deck builder inspects it" paragraphs, add:

```markdown
**Cards use a Pokémon-TCG-style frame.** One layout, built by `CardView` and
rendered at both sizes — hand cards at 168×262 and board cards at 132×196 — with
every font size and box height coming from a single `METRICS` table keyed by mode.
Top to bottom: stage and HP in opposite top corners, an evolves-from strip, art,
keyword chips, an ability banner, one row per attack with its cost as inline
energy icons, and a footer holding retreat cost and the reserved
weakness/resistance slots.

**The board card is deliberately small and hover-enlarges instead of simplifying.**
Packing the full frame into 196px means ~7px type, which reads well enough to scan
a board but not to study a card. Hovering a board card raises a scaled copy built
at hand metrics. The alternative — a trimmed board layout — was rejected because a
card that reads differently in two places is exactly the drift that made the
inspector reuse `CardView` rather than draw its own big card.

**Energy costs sit beside the attack they pay for**, as faction-colored hexagons
drawn by `EnergyIcon.gd` rather than as a bitmap, so they stay crisp at the four
scales the game renders cards at. Attached energy fills an attack's icons
left-to-right, so the row doubles as a progress bar toward affording it — that read
was the whole job of the old bottom-of-card pip block, and it survived the move.
Costs above 8 collapse to a numeric chip, because nine icons overflow the frame and
a Cacophony Ramp player counting toward a 14-cost attack wants the number anyway.

**Keywords render as chips, and the chips are live.** They are built from
`CardView._live_keyword_line()`, not from the printed card, so a spent `Judgment`
or `Rise` disappears and `Sanctuary N` shows its remaining pool. One chip per
keyword, tinted by `Palette.keyword_color()`, because "does that body still hold
its charge?" is a lookup rather than a sentence to read.
```

- [ ] **Step 2: Add the decision log entries**

Append to the *Decision log*:

```markdown
- **Cards are laid out like Pokémon cards, in one layout rendered at two sizes.**
  HP top-right, an explicit evolves-from strip, a banner for abilities, cost icons
  inline with each attack, retreat bottom-right. The frame follows a card game
  players already know how to read, and each position was chosen for a reason the
  rules supply: HP is the number checked most often and fastest, so it gets a fixed
  corner; evolves-from decides whether a card in hand is playable at all, so it
  stops being a suffix on the stage badge; the ability banner is the visual form of
  a real rules distinction (abilities resolve immediately, once per turn, free
  except for `Consume`, while an attack is queued and pays an attached cost that is
  free forever after); and cost beside the attack removes the row-matching step the
  old bottom-of-card pip block forced on every two-attack unit.
- **The board card keeps its 132×196 slot and hover-enlarges rather than dropping
  rows.** A trimmed board layout was the obvious alternative and was rejected: a
  card that reads differently in hand and on the board is the drift `CardView`
  exists to prevent, and it is the same reasoning that made `CardInspector` scale a
  real `CardView` instead of drawing its own large card. Growing `BOARD_SIZE`
  instead would have cost ~88px of vertical budget across two board rows, which
  `Combat` spends on the throne, the pool bar and the hand. Small type plus
  hover-to-enlarge keeps one layout, one slot size, and one renderer.
- **Weakness and resistance are printed as reserved em-dashes before the system
  exists.** The footer draws both slots and the inspector says plainly that neither
  does anything. Same pattern as retreat costs, which sat on cards for a while
  before the retreat action was built: shipping the printed value early means the
  frame does not need re-laying-out when the rule lands, and saying so in the UI
  means a card never promises something the engine cannot do.
```

- [ ] **Step 3: Add the open questions**

Append to *Open Questions*:

```markdown
- **Is ~7px board type legible enough in practice?** The board card carries the
  full frame at 132×196, which puts attack names at 8px and ability text at 7px.
  Hover-to-enlarge is the intended answer, and it makes the card *readable on
  demand* — the open question is whether the at-a-glance read (which unit is hurt,
  which has a charge left, which attack is queued) survives at that size without
  hovering, because that read is what board decisions are actually made from. If it
  does not, the dial is enlarging `BOARD_SIZE` and giving back the vertical budget
  from the hand row, not reintroducing a second board-only layout.
- **What is the weakness/resistance system?** The card frame reserves both slots
  and prints "—". Undesigned deliberately: Pokémon's version is a ×2 / −20 against
  a fixed type chart, and this game's factions are energy colors rather than
  elemental types, so a chart would need to say something about Hel vs. Void that
  the fiction does not yet say. Worth deciding what it is *for* first — a
  deckbuilding constraint that rewards color matching, or a combat modifier that
  makes some matchups swingy — because those want different shapes.
```

- [ ] **Step 4: Verify the docs match what shipped**

Re-read the three added blocks against the code. Every claim about behaviour must be one the playtest in Task 11 actually confirmed. Delete or correct anything that describes intent rather than what the build does.

---

## Self-review notes

**Spec coverage** — every element the request named maps to a task:

| Request | Task |
|---|---|
| HP in the top right | 2 |
| Clear "evolves from" | 3 |
| Ability cards styled like the reference, in a different color | 5 |
| Energy costs as icons next to the attack name | 6 |
| Retreat cost in the bottom right | 7 |
| Keywords need a clear place | 4 |
| Weakness/resistance discussed later, noted in CLAUDE.md | 7 (reserved slots), 10 (inspector note), 12 (open question) |
| Add to CLAUDE.md | 12 |
| Plan before implementing | this document |
| Simple non-full-art version (the Charmeleon reference) | 5 and 8 — the banner and the play-cost line are what make a plain ability card read correctly |
| Tiny board text is fine, hover to enlarge | 9 |

**Type consistency** — names used across tasks: `_m(key)`, `EnergyIcon.new(color, filled, colorless, px)`, `Palette.keyword_color(kw)`, and the node names `StageLabel`, `NameLabel`, `HPLabel`, `EvolveStrip`, `KeywordChips`, `AbilityBanner`, `AttackRows`, `CardFooter`, `PlayCost`, `RulesText`. Tests address nodes by these names, so renaming one means updating `CardViewTest.gd`.

**Signatures verified against the code before execution** (see the block under Task 3 Step 1):
- `CardDB.all_ids()` is the enumeration accessor — there is no `all_cards()`. Every test loop resolves ids through `CardDB.get_card()`.
- `Unit._init(c: CardData)`, with `attached` / `judgment_spent` / `queued_attack` as settable members and `max_hp()` / `has_used_ability()` as methods.

Both are used by the new test file only, so a mismatch would fail loudly at test time rather than shipping a broken card.
