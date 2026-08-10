class_name CardInspector
extends PanelContainer

## A full card detail view, opened by clicking a card in the deck builder.
##
## Layout:
##   ┌──────────┬────────────────────────────┐
##   │          │ name / typing              │
##   │ the real │ KEYWORDS (expanded rules)  │
##   │ in-game  │ ATTACKS (cost + effect)    │
##   │ CardView │ Toll · Retreat · flavor    │
##   ├──────────┴────────────────────────────┤
##   │ EVOLUTION LINE — clickable mini cards │
##   ├───────────────────────────────────────┤
##   │ In deck: ×3        [ − ]  [ + ]       │
##   └───────────────────────────────────────┘
##
## The card art on the left is a real `CardView`, the same node the hand and the
## board build, so the card reads identically here and in play. It's scaled up
## rather than restyled — a second "big card" renderer would drift out of sync
## with the real one the first time either changed.

const CARD_SCALE := 1.55
const CHAIN_SCALE := 0.62

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

## Emitted when a card in the evolution chain is clicked, so the host can
## re-open the inspector on that card.
signal inspect_requested(card: CardData)
signal add_requested(card_id: String)
signal remove_requested(card_id: String)
signal closed()

var _count_label: Label
var _add_btn: Button
var _remove_btn: Button


func _init(c: CardData) -> void:
	card = c


func _ready() -> void:
	add_theme_stylebox_override("panel", Palette.panel_style(Palette.PANEL, Palette.ACCENT, 2, 10))
	_build()
	refresh_counts()


func _build() -> void:
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 10)
	add_child(root)

	root.add_child(_header_row())
	root.add_child(_top_half())

	## The chain scrolls horizontally: a four-wide line of mini cards is wider
	## than the panel, and the panel must not grow to fit it.
	var chain := _evolution_section()
	if chain != null:
		root.add_child(HSeparator.new())
		root.add_child(_section("EVOLUTION LINE"))
		var chain_scroll := ScrollContainer.new()
		chain_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		chain_scroll.custom_minimum_size = Vector2(0, CardView.BOARD_SIZE.y * CHAIN_SCALE + 34)
		chain_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		chain_scroll.add_child(chain)
		root.add_child(chain_scroll)

	root.add_child(HSeparator.new())
	root.add_child(_deck_controls())


# ------------------------------------------------------------------ header

func _header_row() -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)

	var title := Palette.label(card.name, 22, Palette.TEXT)
	row.add_child(title)

	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(sp)

	var close := Button.new()
	close.text = "x"
	Palette.style_button(close, Palette.PANEL_LIGHT, Palette.BORDER)
	close.pressed.connect(func(): closed.emit())
	row.add_child(close)
	return row


## The card frame on the left, the rules text on the right.
func _top_half() -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL

	row.add_child(_big_card())

	var detail := ScrollContainer.new()
	detail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detail.size_flags_vertical = Control.SIZE_EXPAND_FILL
	detail.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	row.add_child(detail)

	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", 8)
	detail.add_child(col)

	col.add_child(Palette.label(_typing_line(), 13, Palette.TEXT_DIM))

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
		col.add_child(HSeparator.new())
		var fl := Palette.label(card.flavor, 12, Palette.TEXT_DIM)
		fl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		fl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		col.add_child(fl)

	return row


func _typing_line() -> String:
	if card.is_support_like():
		return "%s · %s" % [card.type_label(), card.faction.capitalize()]
	if not card.is_unit():
		return "Energy · %s" % card.faction.capitalize()
	return "%s · %s · %d HP" % [card.stage_name(), card.faction.capitalize(), card.max_hp]


## A real CardView, scaled up. Wrapped in a Control of the scaled size because a
## scaled node still reports its unscaled size to the layout, which would
## otherwise let the rules column overlap the card.
func _big_card() -> Control:
	var view := CardView.new(card, null, CardView.Mode.HAND)
	view.scale = Vector2(CARD_SCALE, CARD_SCALE)

	var holder := Control.new()
	holder.custom_minimum_size = CardView.HAND_SIZE * CARD_SCALE
	holder.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	holder.add_child(view)
	return holder


# ------------------------------------------------------------------ sections

func _section(title: String) -> Label:
	return Palette.label(title, 12, Palette.ACCENT)


func _add_keywords(col: VBoxContainer) -> void:
	if card.keywords.is_empty():
		return
	col.add_child(_section("KEYWORDS"))

	for k in card.keywords:
		var n: int = int(card.keywords[k])
		var name_text: String = str(k).capitalize() if n == 0 else "%s %d" % [str(k).capitalize(), n]

		var line := Palette.label(name_text, 14, Palette.TEXT)
		col.add_child(line)

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
		var l := Palette.label(body, 12, Palette.TEXT_DIM)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		col.add_child(l)


func _add_attacks(col: VBoxContainer) -> void:
	if card.attacks.is_empty():
		return
	col.add_child(_section("ATTACKS"))

	for atk in card.attacks:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		col.add_child(row)

		row.add_child(Palette.label(atk.name, 14, Palette.TEXT))

		var sp := Control.new()
		sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(sp)

		row.add_child(Palette.label(atk.cost_string(), 12, Palette.GOLD))
		if atk.damage > 0:
			row.add_child(Palette.label("%d dmg" % atk.damage, 13, Palette.DANGER))

		if atk.text != "":
			var l := Palette.label(atk.text, 12, Palette.TEXT_DIM)
			l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			col.add_child(l)

		if atk.targeting == "friendly_unit":
			col.add_child(Palette.label("Targets a friendly unit.", 11, Palette.TOWER))


## Toll and Retreat read off the same stat, so they're shown together — the
## comparison (*worth N if it dies, costs N if I save it*) is the decision the
## player is meant to be making.
func _add_costs(col: VBoxContainer) -> void:
	if card.retreat <= 0 and not card.has_kw("toll"):
		return

	col.add_child(HSeparator.new())

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	col.add_child(row)

	var toll_text: String = ("Toll %d" % card.kw("toll")) if card.has_kw("toll") else "No Toll"
	row.add_child(Palette.label(toll_text, 13, Palette.GOLD))
	row.add_child(Palette.label("Retreat %d" % card.retreat, 13, Palette.GOLD))

	var note := ""
	if card.has_kw("toll"):
		note = "Worth %d if it dies, costs %d if you save it." % [card.kw("toll"), card.retreat]
	else:
		note = "No refund on death — retreating is this card's only way off the board."
	var l := Palette.label(note, 11, Palette.TEXT_DIM)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_child(l)

	var how := Palette.label(
		"Paid from this unit's own attached energy — never the pool. Leftover attached energy returns to your pool, and the card comes back to hand healed and locked for a turn.",
		11, Palette.TEXT_DIM)
	how.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	how.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_child(how)


## The card face reserves weakness and resistance slots that print an em-dash.
## Never let a card promise something the engine cannot do — the same reasoning
## that put a "not yet implemented" line on priced supports.
##
## Shown for every unit rather than from inside _add_costs(), which returns early
## on a card with neither retreat nor Toll: the slots are printed on that card's
## face too, so the explanation has to reach it.
func _add_weakness_note(col: VBoxContainer) -> void:
	var wk := Palette.label(
		"Weakness / Resistance: NOT YET IMPLEMENTED. The card reserves both slots and prints '—'; no card has a weakness or a resistance, and no damage is modified by either.",
		11, Palette.TEXT_DIM)
	wk.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	wk.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_child(wk)


## Supports print their rules text and the one rule that defines the type.
func _add_support_rules(col: VBoxContainer) -> void:
	col.add_child(_section("RULES"))

	if card.text != "":
		var t := Palette.label(card.text, 14, Palette.TEXT)
		t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		col.add_child(t)

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
		var l2 := Palette.label(line, 12, Palette.TEXT_DIM)
		l2.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		col.add_child(l2)


func _add_energy_rules(col: VBoxContainer) -> void:
	col.add_child(_section("RULES"))
	for line in [
		"Adds (turn + 1) energy of its color to your pool. Played on turn 5, it adds 6.",
		"One energy card may be played per turn. A skipped turn can never be made up.",
		"Exempt from the 4-copy limit — how much energy to run is yours to tune.",
	]:
		var l := Palette.label(line, 12, Palette.TEXT_DIM)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		col.add_child(l)


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

func _deck_controls() -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)

	_count_label = Palette.label("", 15, Palette.GOLD)
	row.add_child(_count_label)

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

	_add_btn.disabled = not DeckStore.can_add(card.id)
	if _add_btn.disabled:
		_add_btn.tooltip_text = ("Deck is full (%d cards)." % DeckStore.DECK_SIZE
			if DeckStore.total_cards() >= DeckStore.DECK_SIZE
			else "Already at the %d-copy limit." % maximum)
	else:
		_add_btn.tooltip_text = ""

	_remove_btn.disabled = n <= 0
