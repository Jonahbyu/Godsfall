class_name CardInspector
extends PanelContainer

## A full card detail view, opened by clicking a card in the deck builder.
##
## Layout:
##   ┌──────────────┬────────────────────────────┐
##   │              │ name / typing         [ x ]│
##   │  the real    │ ┌────────────────────────┐ │
##   │  in-game     │ │ RULES                  │ │
##   │  CardView    │ └────────────────────────┘ │
##   │  on a lit    │ ┌────────────────────────┐ │
##   │  plate       │ │ KEYWORDS               │ │
##   │              │ └────────────────────────┘ │
##   ├──────────────┴────────────────────────────┤
##   │ EVOLUTION LINE  [basic] > [s1] > [s2]     │
##   ├───────────────────────────────────────────┤
##   │ In deck: ×3                  [ − ]  [ + ] │
##   └───────────────────────────────────────────┘
##
## The card art on the left is a real `CardView`, the same node the hand and the
## board build, so the card reads identically here and in play. It's scaled up
## rather than restyled — a second "big card" renderer would drift out of sync
## with the real one the first time either changed.
##
## **The panel sizes to its content and is centred by its host**, rather than
## stretching to fill the screen. A full-rect inspector turns a four-line
## support card into a wall of empty panel with the card marooned in a corner —
## the screen stops reading as *a card being examined* and starts reading as a
## page that failed to load. `MAX_PANEL` caps the width so a long unit still
## scrolls inside the panel instead of growing off-screen, which is the one
## thing the full-rect version got right.
##
## **The rules text is grouped into boxed sections, not run together.** Every
## line in the right-hand column used to be a flat run of dim labels at the same
## size, so a card's actual printed text and the engine's standing caveat about
## the 4-copy limit had identical visual weight. A box per section restores the
## hierarchy the card itself has: what this card does, then what its keywords
## mean, then what the type always does.

const CARD_SCALE := 1.55
const CHAIN_SCALE := 0.62

## Phone gets a smaller card and a narrower cap; the 540-unit viewport cannot
## take the desktop plate at all.
const CARD_SCALE_PHONE := 1.0
const CHAIN_SCALE_PHONE := 0.5

## The panel's ceiling. It sizes to content below these, so a short support card
## is a small panel — but a unit with two attacks and three keywords still has to
## stop somewhere, and past this the rules column scrolls instead.
## Measured across all 292 cards rather than guessed. On desktop the cap is
## rarely what binds — the card plate, the chain band and the footer set a floor
## of ~830 on the tallest card (censer_bearer: two attacks, a keyword and a
## three-stage line), inside a 907 viewport. It binds on phone, where the plate
## and the rules stack.
const MAX_PANEL := Vector2(940, 660)
## Phone stacks the plate above the rules and puts the chain under the plate, so
## every band adds to one column — 500 rather than 600 keeps the tallest card
## (censer_bearer) inside the 1170-unit phone viewport.
const MAX_PANEL_PHONE := Vector2(500, 500)

## The rules column's width. Fixed rather than expanding, because an autowrapped
## label with no width bound reports its full single-line length as its minimum
## and would drag the panel to whatever the longest sentence measures.
const TEXT_WIDTH := 430
const TEXT_WIDTH_PHONE := 452

## Keyword rules text. The card face prints "Toll 2"; this is what that means.
## Source of truth is the keyword tables in CLAUDE.md and the faction files —
## keep them in step. A keyword missing from here renders as a bare label with no
## explanation, which is why every printed keyword needs an entry.
const KEYWORD_RULES := {
	"toll": "When this unit dies, gain %d Hel energy to your pool. Toll pays into the pool, so it is immediately exposed to decay.",
	"rise": "When this dies, return it to an empty slot on your side at the start of your next turn, at half HP and without Rise. Every other ability and attack returns intact. Attached energy is not restored.",
	"decay": "At end of turn, deal %d damage to the opposing unit. Costs no energy and does not use this unit's attack.",
	"retribution": "When this unit takes damage from an attack, deal %d damage back to the attacker.",
	"consume": "This attack destroys %d attached energy on activation, rather than merely requiring it.",
	## Heaven
	"judgment": "One charge, spent by either use. Defensive: when this unit would die, it survives at %d HP instead. Offensive: when this unit attacks and leaves the defender at that value or below, the defender is destroyed. The charge returns only if the card returns to hand.",
	"sanctuary": "A pool of %d that incoming damage depletes. When the pool is exhausted the shield absorbs one final instance of damage in full, then is spent. Blocks every damage source, not just attacks.",
	## Void
	"siphon": "Move up to %d attached energy from a target enemy unit onto this unit. It takes the slot across, or the leftmost living unit if that slot is empty.",
	"rift": "This unit's attacks deal %d extra damage per point of Gap — your total attached energy minus the opponent's. The Gap is read when the attack resolves.",
}

## Plain Sanctuary prints no number, so the %d version above would read "Sanctuary 0".
const SANCTUARY_PLAIN := "Absorbs the next instance of damage entirely, from any source, then is spent. Blocks every damage source, not just attacks."

var card: CardData
var _phone: bool = false
## Read-only inspectors omit the add/remove footer entirely.
##
## Deck select opens one of these: that screen picks a deck to take into a fight
## and never edits one, so a live "+ Add" there would quietly change the deck you
## were only looking at. Omitted rather than disabled, because a disabled control
## says "not right now" when the truth is "not on this screen".
var _read_only: bool = false

## Emitted when a card in the evolution chain is clicked, so the host can
## re-open the inspector on that card.
signal inspect_requested(card: CardData)
signal add_requested(card_id: String)
signal remove_requested(card_id: String)
signal closed()

var _count_label: Label
var _limit_label: Label
var _add_btn: Button
var _remove_btn: Button


func _init(c: CardData, phone: bool = false, read_only: bool = false) -> void:
	card = c
	_phone = phone
	_read_only = read_only


func _ready() -> void:
	## A raised style rather than a flat panel: the inspector floats over the
	## screen behind it, and a drop shadow is what says so.
	add_theme_stylebox_override("panel",
		Palette.raised_style(Palette.PANEL, Palette.ACCENT, 10, 14))
	_build()
	refresh_counts()
	## Modals scale up from slightly small. A panel that simply appears reads as
	## a screen change; one that grows into place reads as something opening on
	## top of what is still there.
	Motion.pop(self, 1.03, Motion.QUICK)
	Motion.fade_in(self, Motion.QUICK)


func _build() -> void:
	## Content-sized, capped. `custom_minimum_size` is deliberately not set: the
	## panel should be as small as the card allows.
	var cap: Vector2 = MAX_PANEL_PHONE if _phone else MAX_PANEL
	size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	size_flags_vertical = Control.SIZE_SHRINK_CENTER

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", Palette.SPACE_MD)
	add_child(root)

	## The card and the rules sit side by side on a desktop and stack on a phone,
	## for the same reason every other screen does: 540 units cannot hold a
	## 260-unit card plate and a readable column of text at once.
	var body: BoxContainer = VBoxContainer.new() if _phone else HBoxContainer.new()
	body.add_theme_constant_override("separation", Palette.SPACE_LG)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(body)

	body.add_child(_left_column())
	body.add_child(_rules_column(cap))

	if not _read_only:
		root.add_child(HSeparator.new())
		root.add_child(_deck_controls())


## The card plate with its evolution line tucked underneath it.
##
## The chain belongs to the *card*, so it sits in the card's column rather than
## among the rules text or as a full-width band across the panel. A full-width
## band was the first attempt and gave the line far more room than it earns: it
## is a wayfinding strip you glance at to see where a card sits in its family,
## not a third pane of content, and stretched across 749 units it read as the
## most important thing on the panel.
func _left_column() -> Control:
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", Palette.SPACE_MD)
	col.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	col.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN

	col.add_child(_card_plate())

	var chain := _evolution_section()
	if chain != null:
		col.add_child(_section("EVOLUTION LINE"))
		## Scrolls horizontally: at CHAIN_SCALE three stages just fit the plate's
		## width, but a line with branches is wider and the column must not grow
		## to fit it.
		var scroll := ScrollContainer.new()
		scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		var cs: float = CHAIN_SCALE_PHONE if _phone else CHAIN_SCALE
		scroll.custom_minimum_size = Vector2(0, CardView.BOARD_SIZE.y * cs + 14)
		scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		scroll.add_child(chain)
		col.add_child(scroll)

	return col


## The card on a lit plate tinted by its own faction. The plate is what makes the
## left half read as *the card*, rather than as an image floating on the panel —
## and the tint means the colour is legible before the typing line is read.
func _card_plate() -> Control:
	var scale: float = CARD_SCALE_PHONE if _phone else CARD_SCALE

	var plate := PanelContainer.new()
	var tint: Color = Palette.faction_color(card.faction)
	plate.add_theme_stylebox_override("panel", Palette.panel_style(
		Palette.BG.lerp(tint, 0.14), tint.darkened(0.35), 1, 10))
	plate.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	plate.size_flags_horizontal = Control.SIZE_SHRINK_CENTER

	var pad := MarginContainer.new()
	for m in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		pad.add_theme_constant_override(m, Palette.SPACE_LG)
	plate.add_child(pad)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", Palette.SPACE_MD)
	pad.add_child(col)

	## A scaled node still reports its unscaled size to the layout, so it needs a
	## holder of the scaled size or the rules column would overlap it.
	var view := CardView.new(card, null, CardView.Mode.HAND)
	view.scale = Vector2(scale, scale)
	var holder := Control.new()
	holder.custom_minimum_size = CardView.HAND_SIZE * scale
	holder.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	holder.add_child(view)
	col.add_child(holder)

	## The counts sit under the card rather than only in the footer, because the
	## card is what the eye is on while the decision is being made.
	_count_label = Palette.label("", Palette.TYPE_SUBHEAD, Palette.GOLD)
	_count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_count_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_child(_count_label)

	return plate


## Everything to the right of the card: the title row and the boxed rules
## sections. Scrolls as a unit once it passes the panel's cap.
func _rules_column(cap: Vector2) -> Control:
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	## The cap applies to the scrolling region, so the panel around it stays
	## content-sized on a short card and stops growing on a long one.
	scroll.custom_minimum_size = Vector2(
		TEXT_WIDTH_PHONE if _phone else TEXT_WIDTH, 0)
	## Room the panel spends on the separator and footer, which sit outside the
	## scrolling region.
	var view_h: float = cap.y - 96.0

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", Palette.SPACE_MD)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(col)

	col.add_child(_header_row())
	col.add_child(Palette.label(_typing_line(), Palette.TYPE_BODY, Palette.TEXT_DIM))

	if card.is_unit():
		_add_keywords(col)
		_add_attacks(col)
		_add_costs(col)
		_add_weakness_note(col)
	elif card.is_support_like():
		_add_support_rules(col)
	else:
		_add_energy_rules(col)

	## The energy card's flavor text is its rules text, which the RULES block
	## already states in full — printing both just reads as a stutter.
	if card.flavor != "" and (card.is_unit() or card.is_support_like()):
		var fl := _body_label(card.flavor, Palette.TYPE_SMALL)
		fl.add_theme_color_override("font_color", Palette.TEXT_FAINT)
		col.add_child(fl)

	## Cap the scrolling region's height rather than the panel's, so a short card
	## produces a short panel and only a long one scrolls.
	##
	## Deferred, and that is load-bearing: read during `_build()` the column's
	## combined minimum is still 0, because its children have not laid out yet —
	## which sets the scroll region's minimum height to 0 and collapses the whole
	## rules column to nothing. The panel then renders as a bare card plate, and
	## `get_combined_minimum_size()` on the finished panel still reports the
	## correct width because the *minimum* is right while the drawn size is not.
	## Measuring the panel is exactly the check that cannot catch this; only
	## looking at the live node rects can.
	_cap_scroll.call_deferred(scroll, col, view_h)
	return scroll


func _cap_scroll(scroll: ScrollContainer, col: VBoxContainer, view_h: float) -> void:
	if not is_instance_valid(scroll) or not is_instance_valid(col):
		return
	scroll.custom_minimum_size.y = minf(col.get_combined_minimum_size().y, view_h)


# ------------------------------------------------------------------ header

func _header_row() -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", Palette.SPACE_MD)

	## The name wraps rather than clipping. It is the one string on the panel
	## that must never be trimmed, and "Hel, Queen of the Unclaimed" does not fit
	## the column on one line at heading size.
	var title := Palette.title(card.name, Palette.TYPE_HEADING)
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(title)

	var close := Button.new()
	close.text = "x"
	close.tooltip_text = "Close (Esc)"
	close.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	Palette.style_button(close, Palette.PANEL_LIGHT, Palette.BORDER)
	close.pressed.connect(func(): closed.emit())
	row.add_child(close)
	return row


func _typing_line() -> String:
	if card.is_support_like():
		return "%s · %s" % [card.type_label(), card.faction.capitalize()]
	if not card.is_unit():
		return "Energy · %s" % card.faction.capitalize()
	return "%s · %s · %d HP" % [card.stage_name(), card.faction.capitalize(), card.max_hp]


# ------------------------------------------------------------------ sections

## A titled box. Grouping is the whole point: the right-hand column used to be a
## flat run of same-size dim labels, so a card's own printed rules text carried
## exactly as much weight as the standing note that supports obey the 4-copy
## limit. A box per section says which sentences belong together, and the title
## says what question the box answers.
func _box(title: String, accent: Color = Palette.ACCENT) -> VBoxContainer:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel",
		Palette.panel_style(Palette.BG, accent.darkened(0.55), 1, 7))
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var pad := MarginContainer.new()
	pad.add_theme_constant_override("margin_left", Palette.SPACE_MD)
	pad.add_theme_constant_override("margin_right", Palette.SPACE_MD)
	pad.add_theme_constant_override("margin_top", Palette.SPACE_SM + 2)
	pad.add_theme_constant_override("margin_bottom", Palette.SPACE_SM + 2)
	panel.add_child(pad)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", Palette.SPACE_SM)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pad.add_child(col)

	var head := Palette.heading(title, accent)
	col.add_child(head)

	## The box is returned already parented, so callers append content to the
	## inner column and never have to remember to add the panel itself.
	col.set_meta("panel", panel)
	return col


## Attach a box built by `_box` to the rules column.
func _mount(col: VBoxContainer, box: VBoxContainer) -> void:
	col.add_child(box.get_meta("panel"))


## An autowrapping body label. Every explanatory line in the panel is one of
## these — without the width bound an autowrapped label reports its full
## single-line length as its minimum size and drags the panel wide.
func _body_label(text: String, size: int = Palette.TYPE_SMALL) -> Label:
	var l := Palette.label(text, size, Palette.TEXT_DIM)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.custom_minimum_size.x = (TEXT_WIDTH_PHONE if _phone else TEXT_WIDTH) - 40
	return l


func _section(title: String) -> Label:
	return Palette.heading(title, Palette.ACCENT)


func _add_keywords(col: VBoxContainer) -> void:
	if card.keywords.is_empty():
		return
	var box := _box("KEYWORDS")
	_mount(col, box)

	for k in card.keywords:
		var n: int = int(card.keywords[k])
		var name_text: String = str(k).capitalize() if n == 0 else "%s %d" % [str(k).capitalize(), n]

		## Tinted by the keyword's own colour, the same one the board chips use,
		## so a keyword is recognisable here before it is read.
		box.add_child(Palette.label(name_text, Palette.TYPE_SUBHEAD,
			Palette.keyword_color(str(k))))

		var rule: String = str(KEYWORD_RULES.get(str(k), ""))
		## Plain Sanctuary prints no number and has no pool, so the pooled wording
		## would read as "a pool of 0". It is a genuinely different rule, not the
		## same one with a zero in it.
		if str(k) == "sanctuary" and n == 0:
			rule = SANCTUARY_PLAIN
		if rule == "":
			continue
		## Rules that take a value use one %d; the valueless ones (Rise) don't.
		var body: String = (rule % n) if rule.contains("%d") else rule
		box.add_child(_body_label(body))


func _add_attacks(col: VBoxContainer) -> void:
	if card.attacks.is_empty():
		return
	var box := _box("ATTACKS", Palette.GOLD)
	_mount(col, box)

	for atk in card.attacks:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", Palette.SPACE_MD)
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		box.add_child(row)

		var nm := Palette.label(atk.name, Palette.TYPE_SUBHEAD, Palette.TEXT)
		nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(nm)

		row.add_child(Palette.label(atk.cost_string(), Palette.TYPE_BODY, Palette.GOLD))
		if atk.damage > 0:
			row.add_child(Palette.label("%d dmg" % atk.damage, Palette.TYPE_BODY, Palette.DANGER))

		if atk.text != "":
			box.add_child(_body_label(atk.text))

		if atk.targeting == "friendly_unit":
			box.add_child(Palette.label("Targets a friendly unit.", Palette.TYPE_SMALL, Palette.TOWER))


## Toll and Retreat read off the same stat, so they're shown together — the
## comparison (*worth N if it dies, costs N if I save it*) is the decision the
## player is meant to be making.
func _add_costs(col: VBoxContainer) -> void:
	if card.retreat <= 0 and not card.has_kw("toll"):
		return

	var box := _box("TOLL / RETREAT", Palette.GOLD)
	_mount(col, box)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", Palette.SPACE_LG)
	box.add_child(row)

	var toll_text: String = ("Toll %d" % card.kw("toll")) if card.has_kw("toll") else "No Toll"
	row.add_child(Palette.label(toll_text, Palette.TYPE_SUBHEAD, Palette.GOLD))
	row.add_child(Palette.label("Retreat %d" % card.retreat, Palette.TYPE_SUBHEAD, Palette.GOLD))

	var note := ""
	if card.has_kw("toll"):
		note = "Worth %d if it dies, costs %d if you save it." % [card.kw("toll"), card.retreat]
	else:
		note = "No refund on death — retreating is this card's only way off the board."
	box.add_child(_body_label(note))

	box.add_child(_body_label(
		"Paid from this unit's own attached energy — never the pool. Leftover attached energy returns to your pool, and the card comes back to hand healed and locked for a turn."))


## The card face reserves weakness and resistance slots that print an em-dash.
## Never let a card promise something the engine cannot do — the same reasoning
## that put a "not yet implemented" line on priced supports.
##
## Shown for every unit rather than from inside _add_costs(), which returns early
## on a card with neither retreat nor Toll: the slots are printed on that card's
## face too, so the explanation has to reach it.
func _add_weakness_note(col: VBoxContainer) -> void:
	var wk := _body_label(
		"Weakness / Resistance: NOT YET IMPLEMENTED. The card reserves both slots and prints '—'; no card has a weakness or a resistance, and no damage is modified by either.",
		Palette.TYPE_SMALL)
	wk.add_theme_color_override("font_color", Palette.TEXT_FAINT)
	col.add_child(wk)


## Supports print their rules text and the one rule that defines the type.
func _add_support_rules(col: VBoxContainer) -> void:
	## The card's own printed text is the answer to "what does this do", so it
	## gets its own box at full body size. The standing type rules below are a
	## separate question and a separate box — running them together at the same
	## weight is what made the old panel read as undifferentiated grey text.
	if card.text != "":
		var effect := _box("EFFECT")
		_mount(col, effect)
		var t := _body_label(card.text, Palette.TYPE_SUBHEAD)
		t.add_theme_color_override("font_color", Palette.TEXT)
		effect.add_child(t)

	var box := _box("HOW IT PLAYS")
	_mount(col, box)

	var lines: Array[String] = []
	if card.cost > 0:
		lines.append("Costs %d energy from your pool. Any number of supports per turn, as many as the pool covers." % card.cost)
		## Printed ahead of the mechanic, the same way retreat costs shipped early.
		## Never let a card promise something the engine cannot do yet.
		lines.append("NOT YET IMPLEMENTED: the engine does not charge this cost — it currently plays for free.")
	else:
		lines.append("Free to play. Any number of supports per turn — hand size is the cost.")
	match card.type:
		CardData.Type.TOOL:
			lines.append("Attaches to a unit and stays. One Tool per unit; it carries through evolution.")
			lines.append("Discarded when that unit dies or retreats. Retreat saves the body, not the equipment.")
		CardData.Type.TOWER_SUPPORT:
			lines.append("Must name a tower you control, and does nothing if both your towers are dead.")
			if card.permanent:
				lines.append("Permanent: one per tower, and lost when that tower dies.")
			else:
				lines.append("One-shot: resolves and is discarded without taking the tower's modification slot.")
		_:
			lines.append("One-shot: play, resolve, discard.")
	lines.append("Obeys the 4-copy limit, like units.")

	for line in lines:
		box.add_child(_body_label(line))


func _add_energy_rules(col: VBoxContainer) -> void:
	var box := _box("HOW IT PLAYS")
	_mount(col, box)
	for line in [
		"Adds (turn + 1) energy of its color to your pool. Played on turn 5, it adds 6.",
		"One energy card may be played per turn. A skipped turn can never be made up.",
		"Exempt from the 4-copy limit — how much energy to run is yours to tune.",
	]:
		box.add_child(_body_label(line))


# ------------------------------------------------------------------ evolution

## The whole line this card belongs to, walked down from its Basic, with every
## branch off each stage. Returns null when the card is in no line at all.
func _evolution_section() -> Control:
	if not card.is_unit():
		return null

	var root_card := _root_of(card)
	var stages := _chain_from(root_card)
	## A lone Basic that evolves into nothing has no line worth drawing.
	if stages.size() <= 1:
		return null

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	row.alignment = BoxContainer.ALIGNMENT_BEGIN

	for i in stages.size():
		if i > 0:
			var arrow := Palette.label(">", 20, Palette.ACCENT)
			arrow.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			row.add_child(arrow)

		## Several cards can evolve from the same base, so a stage is a column.
		var stack := VBoxContainer.new()
		stack.add_theme_constant_override("separation", 4)
		row.add_child(stack)
		for c in stages[i]:
			stack.add_child(_chain_card(c))

	return row


## Walk up evolves_from to the Basic at the bottom of this card's line.
func _root_of(c: CardData) -> CardData:
	var cur := c
	## Bounded so a data error (a card evolving from itself, or a cycle) can't
	## hang the UI.
	for _i in 8:
		if cur.evolves_from == "":
			return cur
		var base: CardData = CardDB.get_card(cur.evolves_from)
		if base == null:
			return cur
		cur = base
	return cur


## Array of stages, each an Array[CardData] of the cards at that step.
## Deduped by id: two Basics in a line can evolve into the same Stage 1, and
## without this that shared card (and everything above it) is drawn once per
## path that reaches it.
func _chain_from(root_card: CardData) -> Array:
	var stages: Array = [[root_card]]
	var seen: Dictionary = { root_card.id: true }
	for _i in 4:
		var next: Array = []
		for c in stages[stages.size() - 1]:
			for evo in CardDB.evolutions_of(c.id):
				if seen.has(evo.id):
					continue
				seen[evo.id] = true
				next.append(evo)
		if next.is_empty():
			break
		stages.append(next)
	return stages


## One card in the chain: a small real card frame. The card being inspected is
## marked and inert; the others are clickable to walk the line.
func _chain_card(c: CardData) -> Control:
	var is_self: bool = c.id == card.id

	var view := CardView.new(c, null, CardView.Mode.BOARD)
	view.scale = Vector2(CHAIN_SCALE, CHAIN_SCALE)
	view.selected = is_self
	view.dimmed = not is_self

	var holder := Control.new()
	holder.custom_minimum_size = CardView.BOARD_SIZE * CHAIN_SCALE
	holder.add_child(view)

	if is_self:
		return holder

	## An overlay button rather than CardView.pressed: CardView's own button is
	## built inside the scaled node, so its hit box would be scaled too.
	var btn := Button.new()
	btn.flat = true
	btn.set_anchors_preset(Control.PRESET_FULL_RECT)
	btn.tooltip_text = "Inspect %s" % c.name
	btn.pressed.connect(func(): inspect_requested.emit(c))
	holder.add_child(btn)
	return holder


# ------------------------------------------------------------------ deck controls

## The count itself lives under the card on the plate, where the eye already is.
## The footer keeps only the two buttons and the limit hint.
func _deck_controls() -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", Palette.SPACE_MD)

	_limit_label = Palette.label("", Palette.TYPE_SMALL, Palette.TEXT_FAINT)
	row.add_child(_limit_label)

	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(sp)

	_remove_btn = Button.new()
	_remove_btn.text = "− Remove"
	Palette.style_button(_remove_btn, Palette.PANEL_LIGHT, Palette.DANGER)
	_remove_btn.pressed.connect(func(): remove_requested.emit(card.id))
	row.add_child(_remove_btn)

	_add_btn = Button.new()
	_add_btn.text = "+ Add"
	Palette.style_button(_add_btn, Palette.ACCENT_DIM.darkened(0.3), Palette.ACCENT)
	_add_btn.pressed.connect(func(): add_requested.emit(card.id))
	row.add_child(_add_btn)

	return row


## Re-read the deck counts. Called on open and whenever the deck changes, so the
## inspector stays correct while it's open and cards are added behind it.
func refresh_counts() -> void:
	if _count_label == null:
		return
	var n := DeckStore.count_of(card.id)
	var maximum := DeckStore.max_copies_of(card.id)
	var limit_text: String = "" if DeckStore.is_energy(card.id) else " / %d" % maximum
	_count_label.text = "In deck: ×%d%s" % [n, limit_text]
	if _limit_label != null:
		_limit_label.text = ("Energy is exempt from the 4-copy limit."
			if DeckStore.is_energy(card.id)
			else "Maximum %d copies per deck." % maximum)

	## The footer is absent on a read-only inspector, so everything below it is
	## guarded rather than assumed. The count label above still updates.
	if _add_btn == null or not is_instance_valid(_add_btn):
		return

	_add_btn.disabled = not DeckStore.can_add(card.id)
	if _add_btn.disabled:
		_add_btn.tooltip_text = ("Deck is full (%d cards)." % DeckStore.DECK_SIZE
			if DeckStore.total_cards() >= DeckStore.DECK_SIZE
			else "Already at the %d-copy limit." % maximum)
	else:
		_add_btn.tooltip_text = ""

	_remove_btn.disabled = n <= 0
