extends Control

## Deck builder: collection on the left, current deck on the right,
## card detail at the bottom.
##
## The two halves are deliberately different shapes. The collection is a text
## list — an index you search by name. The deck is a grid of real card frames,
## because that side is judged as a whole: you want to see the shape of what
## you've built, not read its names.
##
## Clicking a card *inspects* it — the +/− buttons are what edit the deck.
## Inspecting and adding are separate actions because reading a card you're
## deciding about shouldn't be the same gesture as committing to it.

const SELECT_SCENE := "res://scenes/DeckSelect.tscn"
const TUTORIAL_SCENE := "res://scenes/Tutorial.tscn"
const COMPENDIUM_SCENE := "res://scenes/Compendium.tscn"

## The deck grid draws real card frames, shrunk to thumbnails. Four across fits
## the right-hand pane without forcing a horizontal scrollbar.
##
## The count badge and remove button sit in a strip *under* each card rather than
## on top of it: overlaid, they covered the card's name, which is the one thing
## you need to identify a thumbnail by.
const DECK_GRID_COLUMNS := 5
const DECK_CARD_SCALE := 0.86
const DECK_TILE_FOOTER := 24

var _collection_box: VBoxContainer
var _deck_box: Container
var _detail: RichTextLabel
var _header: Label
var _title: Label
var _errors: Label
var _selected: CardData = null

var _inspector: CardInspector = null
var _inspector_layer: Control = null

## Deckbuilding-lesson coaching. Null in an ordinary visit to the builder.
var _coach_box: VBoxContainer = null

## Which layout this screen was built for. Latched at build time so every part
## of one build agrees about its shape; see _on_layout_changed.
var _mobile: bool = false

## --- collection filters
##
## The collection lists every card in the game, which was fine with one faction and
## is not with two — a Heaven player scrolling past 15 Hel cards to reach theirs is
## the whole problem. Faction picks *whose* cards; type narrows to one card class.
##
## Deliberately two independent filters rather than one combined dropdown: "show me
## Heaven" and "show me Tools" are different questions, and a player usually wants
## one faction and all its types, or one type across everything.
const FILTER_ALL := "all"

var _faction_filter: String = FILTER_ALL
var _type_filter: int = -1                  ## -1 = all types, else a CardData.Type
var _collection_title: Label = null
var _faction_buttons: Dictionary = {}       ## faction id -> Button
var _type_buttons: Dictionary = {}          ## type int -> Button


func _ready() -> void:
	_build()
	DeckStore.deck_changed.connect(_refresh)
	DeckStore.decks_changed.connect(_refresh)
	ViewportFit.layout_changed.connect(_on_layout_changed)
	_refresh()


## Rebuild when the window crosses the mobile threshold. The two layouts differ
## in structure (tabs vs. a split), and the deck itself lives in DeckStore rather
## than in these nodes, so nothing is lost by discarding them.
func _on_layout_changed(is_mobile: bool) -> void:
	if is_mobile == _mobile:
		return
	for child in get_children():
		remove_child(child)
		child.queue_free()
	_build()
	_refresh()


## The coaching strip for the deckbuilding lesson. Sits above the builder rather
## than beside it: this lesson has no board to obscure, and the advice is meant to
## be read while you look at the real collection underneath it.
func _build_coach() -> PanelContainer:
	var panel := Palette.make_panel(Palette.PANEL_LIGHT, Palette.ACCENT)
	_coach_box = VBoxContainer.new()
	_coach_box.add_theme_constant_override("separation", 4)
	panel.add_child(_coach_box)
	_refresh_coach()
	return panel


func _refresh_coach() -> void:
	if _coach_box == null:
		return
	for c in _coach_box.get_children():
		c.queue_free()
	if not Tutorial.active:
		return

	var s := Tutorial.step()
	if s.is_empty():
		return

	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 8)
	_coach_box.add_child(head)

	var t := Palette.label(String(s.get("title", "")), 15, Palette.ACCENT)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(t)
	head.add_child(Palette.label(
		"%d/%d" % [Tutorial.step_index + 1, Tutorial.step_count()], 12, Palette.TEXT_DIM))

	var body := RichTextLabel.new()
	body.bbcode_enabled = true
	body.fit_content = true
	body.custom_minimum_size = Vector2(0, 54)
	body.add_theme_font_size_override("normal_font_size", 13)
	body.add_theme_font_size_override("bold_font_size", 13)
	body.add_theme_color_override("default_color", Palette.TEXT)
	body.text = String(s.get("text", ""))
	_coach_box.add_child(body)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	_coach_box.add_child(row)

	if Tutorial.step_index > 0:
		row.add_child(_coach_btn("Back", func():
			Tutorial.go_back()
			_refresh_coach()))

	row.add_child(_coach_btn("Next", func():
		var was_last := Tutorial.is_last_step()
		Tutorial.advance()
		if was_last:
			get_tree().change_scene_to_file(TUTORIAL_SCENE)
		else:
			_refresh_coach()))

	var more := String(s.get("read_more", ""))
	if more != "":
		row.add_child(_coach_btn("Read more", func(): _open_compendium(more)))

	row.add_child(_coach_btn("Quit lesson", func():
		Tutorial.end()
		get_tree().change_scene_to_file(TUTORIAL_SCENE)))


func _coach_btn(text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.add_theme_font_size_override("font_size", 11)
	Palette.style_button(b, Palette.PANEL, Palette.BORDER)
	b.pressed.connect(cb)
	return b


func _open_compendium(page_id: String) -> void:
	var scene: PackedScene = load(COMPENDIUM_SCENE)
	if scene == null:
		return
	var screen := scene.instantiate()
	screen.open_page = page_id
	var tree := get_tree()
	tree.root.add_child(screen)
	tree.current_scene.queue_free()
	tree.current_scene = screen


func _build() -> void:
	_mobile = ViewportFit.mobile
	set_anchors_preset(Control.PRESET_FULL_RECT)

	## The cosmic backdrop rather than a flat fill, so every screen shares one
	## ground and the game reads as a place rather than as a dark theme.
	add_child(Starfield.new())

	var root := VBoxContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("separation", 8)
	root.offset_left = 12
	root.offset_right = -12
	root.offset_top = 12
	root.offset_bottom = -12
	add_child(root)

	## The deckbuilding lesson is the one chapter that is not a battle — it is read
	## alongside this screen, because deckbuilding is not something you can do on a
	## board. Inert in an ordinary visit.
	if Tutorial.active and Tutorial.is_builder_lesson():
		root.add_child(_build_coach())

	## --- top bar
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 12)
	root.add_child(top)

	var back := Button.new()
	back.text = "< Decks"
	Palette.style_button(back)
	back.pressed.connect(func(): get_tree().change_scene_to_file(SELECT_SCENE))
	top.add_child(back)

	## The title goes first on a phone — the screen is named by the button that
	## opened it, and the card count is the number actually worth the width.
	_title = Palette.label("Deck Builder", 24)
	_title.visible = not _mobile
	top.add_child(_title)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(spacer)

	_header = Palette.label("", 16, Palette.GOLD)
	top.add_child(_header)

	var reset := Button.new()
	reset.text = "Reset" if _mobile else "Reset to default"
	Palette.style_button(reset)
	reset.pressed.connect(func(): DeckStore.reset_to_default())
	top.add_child(reset)

	var clear := Button.new()
	clear.text = "Clear"
	Palette.style_button(clear, Palette.PANEL_LIGHT, Palette.DANGER)
	clear.pressed.connect(func(): DeckStore.clear())
	top.add_child(clear)

	## Keep clear of the settings cog, drawn on a CanvasLayer above the scene and
	## therefore invisible to this layout — "Clear" sat underneath it.
	var cog_gap := Control.new()
	cog_gap.custom_minimum_size = Vector2(Palette.COG_RESERVE, 0)
	top.add_child(cog_gap)

	_errors = Palette.label("", 13, Palette.DANGER)
	root.add_child(_errors)

	## --- middle: collection | deck
	##
	## Side by side on a desktop. On a phone they become tabs rather than a
	## vertical stack, which is the one place this screen differs from the other
	## two: both halves are tall scrolling lists, so stacking them would mean
	## scrolling past the whole collection to reach the deck. Tabs also match how
	## the screen is actually used — you browse, then you review, and rarely need
	## to see both at once.
	if _mobile:
		var tabs := TabContainer.new()
		tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
		root.add_child(tabs)
		var coll := _make_column("Collection", true)
		coll.name = "Collection"
		tabs.add_child(coll)
		var deck := _make_column("Your Deck", false)
		deck.name = "Your Deck"
		tabs.add_child(deck)
	else:
		var middle := HSplitContainer.new()
		middle.size_flags_vertical = Control.SIZE_EXPAND_FILL
		## The deck grid needs the wider half — five card frames plus the
		## scrollbar. The collection is text and reads fine narrower.
		middle.split_offset = 470
		root.add_child(middle)
		middle.add_child(_make_column("Collection", true))
		middle.add_child(_make_column("Your Deck", false))

	## --- bottom: card detail
	##
	## Shorter on a phone: 120 units of always-reserved detail is a large share
	## of the vertical budget, and the tapped card's full text is one tap away in
	## the inspector anyway.
	var detail_panel := Palette.make_panel(Palette.PANEL)
	detail_panel.custom_minimum_size = Vector2(0, 72 if _mobile else 120)
	root.add_child(detail_panel)

	_detail = RichTextLabel.new()
	_detail.bbcode_enabled = true
	_detail.fit_content = true
	_detail.add_theme_color_override("default_color", Palette.TEXT)
	_detail.text = "[color=#8f88a3]Select a card to see its details.[/color]"
	detail_panel.add_child(_detail)


func _make_column(title: String, is_collection: bool) -> Control:
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 6)

	var head := Palette.label(title, 16, Palette.ACCENT)
	col.add_child(head)
	if is_collection:
		_collection_title = head
		col.add_child(_make_filter_bar())

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	col.add_child(scroll)

	## The collection stays a text list — it's a scannable index of everything
	## available. The deck is a grid of real card frames, because that's the side
	## you're judging as a whole: you want to see the shape of what you've built,
	## not read its names.
	var box: Container
	if is_collection:
		box = VBoxContainer.new()
		box.add_theme_constant_override("separation", 4)
		_collection_box = box
	else:
		var grid := GridContainer.new()
		## Four across on a phone: at a 0.62 tile scale that is 4 x 82 + gaps,
		## which fits 540 while keeping enough tiles per row that a 60-card deck is
		## still scannable rather than a single long column.
		grid.columns = 4 if _mobile else DECK_GRID_COLUMNS
		grid.add_theme_constant_override("h_separation", 6)
		grid.add_theme_constant_override("v_separation", 6)
		box = grid
		_deck_box = box

	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(box)
	return col


## Two rows of toggle buttons: faction, then card type. Factions are read from the
## card database rather than hardcoded, so a new colour appears here the moment its
## cards land — the collection used to hardcode "hel", which made Heaven's cards
## invisible in the builder even though they were in `data/cards.json`.
func _make_filter_bar() -> Control:
	var bar := VBoxContainer.new()
	bar.add_theme_constant_override("separation", 4)

	## --- faction row
	var frow := HBoxContainer.new()
	frow.add_theme_constant_override("separation", 4)
	bar.add_child(frow)

	_faction_buttons.clear()
	frow.add_child(_filter_button("All", func(): _set_faction(FILTER_ALL), _faction_buttons, FILTER_ALL))
	for f in _known_factions():
		var label := str(f).capitalize()
		frow.add_child(_filter_button(label, func(): _set_faction(f), _faction_buttons, f))

	## --- type row
	var trow := HBoxContainer.new()
	trow.add_theme_constant_override("separation", 4)
	bar.add_child(trow)

	_type_buttons.clear()
	trow.add_child(_filter_button("All", func(): _set_type(-1), _type_buttons, -1))
	for entry in [
		{ "label": "Units", "type": CardData.Type.UNIT },
		{ "label": "Support", "type": CardData.Type.SUPPORT },
		{ "label": "Tools", "type": CardData.Type.TOOL },
		{ "label": "Tower", "type": CardData.Type.TOWER_SUPPORT },
		{ "label": "Energy", "type": CardData.Type.ENERGY },
	]:
		var t: int = entry["type"]
		trow.add_child(_filter_button(entry["label"], func(): _set_type(t), _type_buttons, t))

	return bar


func _filter_button(text: String, on_press: Callable, registry: Dictionary, key) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	Palette.style_button(b)
	b.add_theme_font_size_override("font_size", 12)
	b.pressed.connect(on_press)
	registry[key] = b
	return b


## Every faction that actually has cards, in a stable order. Neutral is listed last
## because it is not a deck's identity — it is the shared support pool.
func _known_factions() -> Array:
	var seen: Dictionary = {}
	for id in CardDB.all_ids():
		seen[CardDB.get_card(id).faction] = true
	var out: Array = []
	for f in ["hel", "heaven", "void", "gaia"]:
		if seen.has(f):
			out.append(f)
			seen.erase(f)
	seen.erase("neutral")
	for f in seen:
		out.append(f)
	if CardDB.all_ids().any(func(i): return CardDB.get_card(i).faction == "neutral"):
		out.append("neutral")
	return out


func _set_faction(f: String) -> void:
	_faction_filter = f
	_refresh()


func _set_type(t: int) -> void:
	_type_filter = t
	_refresh()


## Highlight whichever filter is active, so the current view is always readable off
## the bar rather than inferred from what the list happens to contain.
func _sync_filter_buttons() -> void:
	for key in _faction_buttons:
		_style_filter_button(_faction_buttons[key], key == _faction_filter)
	for key2 in _type_buttons:
		_style_filter_button(_type_buttons[key2], key2 == _type_filter)


func _style_filter_button(b: Button, active: bool) -> void:
	## `style_button`'s second argument is the *border*, not the font colour, so the
	## active state is an accent border plus an accent label rather than a fill.
	Palette.style_button(b,
		Palette.PANEL_LIGHT,
		Palette.ACCENT if active else Palette.BORDER)
	b.add_theme_font_size_override("font_size", 12)
	b.add_theme_color_override("font_color", Palette.ACCENT if active else Palette.TEXT_DIM)


func _refresh() -> void:
	## The inspector shows live deck counts, so it has to follow edits made
	## while it is open.
	if _inspector != null and is_instance_valid(_inspector):
		_inspector.refresh_counts()

	_title.text = "Editing: %s" % DeckStore.active_name()
	var total := DeckStore.total_cards()
	## Decks must land on exactly DECK_SIZE, so the count is the main thing the
	## builder has to communicate — colour it until it's there.
	_header.text = "%d / %d cards   ·   %d energy" % [
		total, DeckStore.DECK_SIZE, DeckStore.energy_count()
	]
	_header.add_theme_color_override("font_color",
		Palette.TEXT if total == DeckStore.DECK_SIZE else Palette.DANGER)
	var errs := DeckStore.validation_errors()
	_errors.text = ("! " + "  ".join(errs)) if not errs.is_empty() else ""

	_rebuild_collection()
	_rebuild_deck()


## `queue_free` defers to the end of the frame but `add_child` is immediate, so
## two refreshes in one frame would stack two copies of the list. Detaching the
## old rows first makes the rebuild correct however often it's called.
func _clear(box: Container) -> void:
	for c in box.get_children():
		box.remove_child(c)
		c.queue_free()


func _rebuild_collection() -> void:
	_clear(_collection_box)
	_sync_filter_buttons()

	## Which factions to show. "All" means every colour *plus* neutral, because the
	## neutral pool is legal in every deck and hiding it would misrepresent what you
	## can build. Picking a colour still shows neutral, for the same reason.
	var factions: Array = _known_factions() if _faction_filter == FILTER_ALL else [_faction_filter]

	var shown := 0
	for f in factions:
		if f == "neutral":
			continue
		shown += _add_faction_section(f)

	## Neutral supports are playable in *every* deck, so they stay visible whichever
	## colour is selected — filtering to Heaven and losing access to the shared
	## support pool would misrepresent what a Heaven deck can actually contain.
	shown += _add_neutral_sections()

	if shown == 0:
		_collection_box.add_child(Palette.label("No cards match this filter.", 13, Palette.TEXT_DIM))

	_collection_title.text = "Collection — %s" % _filter_summary()


## One faction's own cards: its energy card, then its units by stage. Returns how
## many rows were added, so the caller can tell an empty filter from a full one.
func _add_faction_section(faction: String) -> int:
	var rows := 0
	var header_added := false

	## Only label the faction when more than one is on screen — with a single
	## colour showing, the header is noise.
	var multi: bool = _faction_filter == FILTER_ALL and _known_factions().size() > 2

	if _type_allows(CardData.Type.ENERGY):
		var energy := CardDB.energy_card_of(faction)
		if energy != null:
			if multi and not header_added:
				_collection_box.add_child(Palette.label("— %s —" % faction.capitalize(), 14, Palette.GOLD))
				header_added = true
			_collection_box.add_child(_collection_row(energy))
			rows += 1

	if _type_allows(CardData.Type.UNIT):
		var by_stage := {
			CardData.Stage.BASIC: [], CardData.Stage.STAGE1: [], CardData.Stage.STAGE2: []
		}
		for card in CardDB.units_of(faction):
			by_stage[card.stage].append(card)

		for stage in [CardData.Stage.BASIC, CardData.Stage.STAGE1, CardData.Stage.STAGE2]:
			if by_stage[stage].is_empty():
				continue
			if multi and not header_added:
				_collection_box.add_child(Palette.label("— %s —" % faction.capitalize(), 14, Palette.GOLD))
				header_added = true
			_collection_box.add_child(Palette.label(_stage_label(stage), 13, Palette.TEXT_DIM))
			for card in by_stage[stage]:
				_collection_box.add_child(_collection_row(card))
				rows += 1

	return rows


func _add_neutral_sections() -> int:
	var rows := 0
	for section in [
		{ "label": "— Supports —", "type": CardData.Type.SUPPORT },
		{ "label": "— Tools —", "type": CardData.Type.TOOL },
		{ "label": "— Tower Support —", "type": CardData.Type.TOWER_SUPPORT },
	]:
		if not _type_allows(section["type"]):
			continue
		var cards: Array = CardDB.supports_of_type("neutral", section["type"])
		if cards.is_empty():
			continue
		_collection_box.add_child(Palette.label(section["label"], 13, Palette.TEXT_DIM))
		for card in cards:
			_collection_box.add_child(_collection_row(card))
			rows += 1
	return rows


func _type_allows(t: int) -> bool:
	return _type_filter == -1 or _type_filter == t


func _filter_summary() -> String:
	var f: String = "All factions" if _faction_filter == FILTER_ALL else _faction_filter.capitalize()
	if _type_filter == -1:
		return f
	var t := "?"
	match _type_filter:
		CardData.Type.UNIT: t = "Units"
		CardData.Type.SUPPORT: t = "Support"
		CardData.Type.TOOL: t = "Tools"
		CardData.Type.TOWER_SUPPORT: t = "Tower Support"
		CardData.Type.ENERGY: t = "Energy"
	return "%s · %s" % [f, t]


func _stage_label(stage: int) -> String:
	match stage:
		CardData.Stage.STAGE1: return "— Stage 1 —"
		CardData.Stage.STAGE2: return "— Stage 2 —"
		_: return "— Basics —"


func _collection_row(card: CardData) -> Control:
	var count := DeckStore.count_of(card.id)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)

	## The wide part of the row opens the inspector. It is never disabled — a card
	## you can't add is still a card you may want to read.
	var btn := Button.new()
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	btn.text = _row_text(card)
	btn.tooltip_text = "Click to inspect %s" % card.name
	Palette.style_button(btn, Palette.PANEL_LIGHT if count == 0 else Palette.ACCENT_DIM.darkened(0.4))
	btn.pressed.connect(func(): _open_inspector(card))
	btn.mouse_entered.connect(func(): _show_detail(card))
	row.add_child(btn)

	var add := Button.new()
	add.text = "+"
	add.custom_minimum_size = Vector2(34, 0)
	add.disabled = not DeckStore.can_add(card.id)
	add.tooltip_text = "Add a copy to your deck"
	Palette.style_button(add, Palette.PANEL_LIGHT, Palette.ACCENT)
	add.pressed.connect(func(): DeckStore.add(card.id))
	row.add_child(add)

	var badge := Palette.label("×%d" % count, 14, Palette.GOLD if count > 0 else Palette.TEXT_DIM)
	badge.custom_minimum_size = Vector2(36, 0)
	badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(badge)

	return row


func _row_text(card: CardData) -> String:
	if not card.is_unit():
		return "%s   (energy)" % card.name
	var kws := card.keyword_line()
	var suffix := ("   [%s]" % kws) if kws != "" else ""
	return "%s   %d HP%s" % [card.name, card.max_hp, suffix]


## Energy first, then units, then everything played for an effect.
func _sort_group(c: CardData) -> int:
	if c.is_energy():
		return 0
	if c.is_unit():
		return 1
	return 2


func _rebuild_deck() -> void:
	_clear(_deck_box)

	## Grouped the way you read a deck: energy, then units by stage, then the
	## support-likes. Within a group, by name.
	var ids := DeckStore.deck.keys()
	ids.sort_custom(func(a, b):
		var ca: CardData = CardDB.get_card(a)
		var cb: CardData = CardDB.get_card(b)
		var ga := _sort_group(ca)
		var gb := _sort_group(cb)
		if ga != gb:
			return ga < gb
		if ca.is_unit() and cb.is_unit() and ca.stage != cb.stage:
			return ca.stage < cb.stage
		return ca.name < cb.name
	)

	if ids.is_empty():
		_deck_box.add_child(Palette.label("Deck is empty.", 14, Palette.TEXT_DIM))
		return

	for id in ids:
		var card: CardData = CardDB.get_card(id)
		if card == null:
			continue
		_deck_box.add_child(_deck_tile(card))


## One card in the deck grid: the real card frame shrunk to a thumbnail, with a
## copy count and a remove button in a strip underneath.
##
## A deck holds up to 60 cards but only ~16 distinct ones, so the grid shows one
## tile per *distinct* card with a ×N count — 60 identical thumbnails would be
## unreadable and would bury the two-of you were looking for.
func _deck_tile(card: CardData) -> Control:
	var id := card.id
	## The deck grid is thumbnails, not board slots, so it sizes off the DESKTOP
	## board card and scales that — deliberately not `size_for()`. The phone board
	## card is 150 units because Combat stacks its two boards and can afford it;
	## inheriting that here would push the two-column grid to 677 units and
	## overflow the 540 viewport. What this grid needs is "small enough that a
	## 60-card deck is scannable", which is a different question from "large enough
	## to read during a turn".
	var tile_scale: float = 0.62 if _mobile else DECK_CARD_SCALE
	var card_size: Vector2 = CardView.BOARD_SIZE * tile_scale

	var tile := VBoxContainer.new()
	tile.add_theme_constant_override("separation", 2)

	## The card frame, with a click target over it. A scaled node still reports
	## its unscaled size to the layout, so it needs a holder of the real size.
	var holder := Control.new()
	holder.custom_minimum_size = card_size

	var view := CardView.new(card, null, CardView.Mode.BOARD)
	view.scale = Vector2(tile_scale, tile_scale)
	holder.add_child(view)

	var hit := Button.new()
	hit.flat = true
	hit.set_anchors_preset(Control.PRESET_FULL_RECT)
	hit.tooltip_text = "Click to inspect %s" % card.name
	hit.pressed.connect(func(): _open_inspector(card))
	hit.mouse_entered.connect(func(): _show_detail(card))
	holder.add_child(hit)

	tile.add_child(holder)
	tile.add_child(_tile_footer(id, card_size.x))
	return tile


## Copy count on the left, remove on the right, under the card.
func _tile_footer(id: String, width: float) -> Control:
	var footer := HBoxContainer.new()
	footer.custom_minimum_size = Vector2(width, DECK_TILE_FOOTER)
	footer.add_theme_constant_override("separation", 4)

	var count := Palette.label("×%d" % DeckStore.count_of(id), 14, Palette.GOLD)
	count.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	footer.add_child(count)

	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	footer.add_child(sp)

	var rem := Button.new()
	rem.text = "−"
	rem.custom_minimum_size = Vector2(30, DECK_TILE_FOOTER)
	rem.tooltip_text = "Remove one copy"
	rem.add_theme_font_size_override("font_size", 15)
	Palette.style_button(rem, Palette.PANEL_LIGHT, Palette.DANGER)
	rem.pressed.connect(func(): DeckStore.remove(id))
	footer.add_child(rem)

	return footer


func _show_detail(card: CardData) -> void:
	if not card.is_unit():
		_detail.text = "[b]%s[/b]  [color=#8f88a3](Energy)[/color]\n\n%s\n\n[color=#8f88a3]Exempt from the 4-copy limit.[/color]" % [card.name, card.flavor]
		return

	var s := "[b][color=#e6e1f0]%s[/color][/b]   [color=#8f88a3]%s · %d HP[/color]\n" % [card.name, card.stage_name(), card.max_hp]

	if card.evolves_from != "":
		var base: CardData = CardDB.get_card(card.evolves_from)
		if base != null:
			s += "[color=#8f88a3]Evolves from %s[/color]\n" % base.name

	var kws := card.keyword_line()
	if kws != "":
		s += "[color=#7c4dff]%s[/color]\n" % kws

	for atk in card.attacks:
		s += "\n+ [b]%s[/b]  [color=#d9b45b]%s[/color] — %s" % [atk.name, atk.cost_string(), atk.text]

	if card.flavor != "":
		s += "\n\n[i][color=#8f88a3]%s[/color][/i]" % card.flavor

	_detail.text = s


# ------------------------------------------------------------------ inspector

## Open the full card view over the builder. Re-opening on a different card
## (by walking the evolution chain) tears the old one down first, so only one
## inspector ever exists.
func _open_inspector(card: CardData) -> void:
	_close_inspector()
	_selected = card
	_show_detail(card)

	## A dimming scrim that also catches clicks outside the panel, so the
	## inspector reads as modal without a real popup window.
	_inspector_layer = Control.new()
	_inspector_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	_inspector_layer.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_inspector_layer)

	var scrim := ColorRect.new()
	scrim.color = Color(0, 0, 0, 0.62)
	scrim.set_anchors_preset(Control.PRESET_FULL_RECT)
	scrim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_inspector_layer.add_child(scrim)

	var dismiss := Button.new()
	dismiss.flat = true
	dismiss.set_anchors_preset(Control.PRESET_FULL_RECT)
	dismiss.pressed.connect(_close_inspector)
	_inspector_layer.add_child(dismiss)

	## Inset from the screen edges rather than sized to its content, so a card
	## with a lot of text scrolls inside the panel instead of growing off-screen.
	_inspector = CardInspector.new(card)
	_inspector.set_anchors_preset(Control.PRESET_FULL_RECT)
	_inspector.offset_left = 90
	_inspector.offset_right = -90
	_inspector.offset_top = 40
	_inspector.offset_bottom = -40
	_inspector.closed.connect(_close_inspector)
	_inspector.add_requested.connect(func(id: String): DeckStore.add(id))
	_inspector.remove_requested.connect(func(id: String): DeckStore.remove(id))
	_inspector.inspect_requested.connect(_open_inspector)
	_inspector_layer.add_child(_inspector)


func _close_inspector() -> void:
	if _inspector_layer != null and is_instance_valid(_inspector_layer):
		_inspector_layer.queue_free()
	_inspector_layer = null
	_inspector = null


## Escape closes the inspector rather than falling through to the screen.
func _unhandled_input(event: InputEvent) -> void:
	if _inspector == null:
		return
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		_close_inspector()
		get_viewport().set_input_as_handled()
