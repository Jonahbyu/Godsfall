extends Control

## Deck select. Sits between the main menu and combat: pick which saved deck
## you're taking into the fight, or manage the collection (new / rename /
## duplicate / delete) before you commit.
##
## Selecting a deck makes it active, so both Combat and the Deck Builder
## operate on whatever was chosen here.

const MENU_SCENE := "res://scenes/MainMenu.tscn"
const COMBAT_SCENE := "res://scenes/Combat.tscn"
const BUILDER_SCENE := "res://scenes/DeckBuilder.tscn"

## Height of a deck row's hero card thumbnail. Sized so a row stays comfortably
## clickable and about eight decks are visible at once on a 900-unit desktop —
## a shelf you scan rather than a list you scroll.
const HERO_H := 74.0

## Set false by the main menu's "Manage Decks" entry, so the screen shows
## "Edit" as the primary action instead of "Fight".
var for_combat: bool = true

var _list_box: VBoxContainer
var _detail: RichTextLabel
var _detail_head: Control = null
var _mix_bar: CompositionBar = null
var _fight_btn: Button
var _status: Label
var _rename_row: HBoxContainer
var _rename_edit: LineEdit
var _renaming: int = -1
var _opponent_row: HBoxContainer
var _opponent_pick: OptionButton
var _opponent_note: Label

## Phone only: the "Contents" overlay and the button that summons it.
##
## On a desktop the contents pane is always on screen beside the list, so both
## are null there and every path below has to tolerate that.
var _contents_layer: Control = null
var _contents_btn: Button = null
## Hidden owner of `_detail` while the overlay is closed. See `_open_contents`.
var _detail_home: VBoxContainer = null

## Which layout this screen was built for. Latched at build time rather than
## read live, so every part of one build agrees about its shape and
## `_on_layout_changed` can tell that the shape is now stale.
var _mobile: bool = false


func _ready() -> void:
	_build()
	DeckStore.decks_changed.connect(_refresh)
	DeckStore.deck_changed.connect(_refresh)
	ViewportFit.layout_changed.connect(_on_layout_changed)
	_refresh()


## Rebuild wholesale when the window crosses the mobile threshold — rotating a
## phone, or flipping the override in the menu. The two layouts differ in
## parentage and in which nodes exist at all, and this screen holds no state of
## its own beyond a half-finished rename, so rebuilding is both simpler and
## safer than trying to re-parent.
func _on_layout_changed(is_mobile: bool) -> void:
	if is_mobile == _mobile:
		return
	_renaming = -1
	## Close first: the overlay holds `_detail`, and freeing the layer with the
	## label still inside it would take the label with it.
	_close_contents()
	for child in get_children():
		remove_child(child)
		child.queue_free()
	_detail = null
	_contents_btn = null
	_detail_home = null
	_build()
	_refresh()


func _build() -> void:
	_mobile = ViewportFit.mobile
	set_anchors_preset(Control.PRESET_FULL_RECT)

	## The cosmic backdrop rather than a flat fill, so every screen shares one
	## ground and the game reads as a place rather than as a dark theme.
	add_child(Starfield.new())

	var root := VBoxContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("separation", 10)
	root.offset_left = 16
	root.offset_right = -16
	root.offset_top = 16
	root.offset_bottom = -16
	add_child(root)

	## --- top bar
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 12)
	root.add_child(top)

	var back := Button.new()
	back.text = "< Menu"
	Palette.style_button(back)
	back.pressed.connect(func(): get_tree().change_scene_to_file(MENU_SCENE))
	top.add_child(back)

	## The title is the first thing to go on a phone: "< Menu" and "+ New" are
	## both actions, and a heading that pushes an action off the edge has its
	## priorities backwards. The screen is already named by the menu item that
	## opened it.
	if not _mobile:
		top.add_child(Palette.label("Choose Your Deck", Palette.TYPE_TITLE))

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(spacer)

	var new_btn := Button.new()
	new_btn.text = "+ New" if _mobile else "+ New Deck"
	Palette.style_button(new_btn, Palette.PANEL_LIGHT, Palette.ACCENT)
	new_btn.pressed.connect(_on_new)
	top.add_child(new_btn)

	## Keep clear of the settings cog, which is drawn on a CanvasLayer above the
	## scene and is therefore invisible to this layout. Without this reservation
	## "+ New Deck" sits underneath it.
	var cog_gap := Control.new()
	cog_gap.custom_minimum_size = Vector2(Palette.COG_RESERVE, 0)
	top.add_child(cog_gap)

	## --- rename row, hidden until a rename starts
	_rename_row = HBoxContainer.new()
	_rename_row.add_theme_constant_override("separation", 8)
	_rename_row.visible = false
	root.add_child(_rename_row)

	_rename_row.add_child(Palette.label("Name:", Palette.TYPE_BODY, Palette.TEXT_DIM))

	_rename_edit = LineEdit.new()
	_rename_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_rename_edit.max_length = DeckStore.MAX_NAME_LEN
	_rename_edit.placeholder_text = "Deck name"
	_rename_edit.text_submitted.connect(func(_t): _commit_rename())
	_rename_row.add_child(_rename_edit)

	var ok := Button.new()
	ok.text = "Save"
	Palette.style_button(ok, Palette.PANEL_LIGHT, Palette.ACCENT)
	ok.pressed.connect(_commit_rename)
	_rename_row.add_child(ok)

	var cancel := Button.new()
	cancel.text = "Cancel"
	Palette.style_button(cancel)
	cancel.pressed.connect(_cancel_rename)
	_rename_row.add_child(cancel)

	## --- middle: deck list | detail
	##
	## Side by side on a desktop. On a phone a draggable split is the wrong
	## control entirely — there is no width to divide, and a split handle is a
	## fiddly target on a touch screen — so the two panes stack and the page
	## scrolls instead. The list comes first because choosing is the point of the
	## screen; the contents are what you check afterwards.
	## On a phone the contents pane is not stacked under the list at all — it
	## becomes an overlay summoned by a button. Stacking gave each half roughly
	## half the height, which is the worst of both: too few decks visible to
	## choose between, and too little of the contents to read. Choosing is what
	## this screen is *for*, so the list gets the whole column and the contents
	## get the whole screen on demand.
	var middle: Container
	if _mobile:
		middle = VBoxContainer.new()
		middle.add_theme_constant_override("separation", 10)
	else:
		var split := HSplitContainer.new()
		## The list is the screen's purpose and now carries an art plate per row,
		## so it takes the larger share. At 560 the rows were cramped enough to
		## clip an illegal deck's reason mid-word while the contents pane sat
		## half empty — a 60-card list is two narrow columns of short lines, not
		## a wide one.
		split.split_offset = 700
		middle = split
	middle.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(middle)

	var left := VBoxContainer.new()
	left.add_theme_constant_override("separation", 6)
	## Stacked, each pane has to claim vertical space or the list collapses to
	## nothing and the contents take the whole column.
	if _mobile:
		left.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left.add_child(Palette.heading("Saved Decks"))

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	left.add_child(scroll)

	_list_box = VBoxContainer.new()
	_list_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list_box.add_theme_constant_override("separation", 6)
	scroll.add_child(_list_box)
	middle.add_child(left)

	## The contents view itself is identical in both layouts — the same label
	## inside the same scroller. Only its *parent* differs, which is what keeps
	## `_show_detail()` and every caller of it working unchanged.
	_detail = RichTextLabel.new()
	_detail.bbcode_enabled = true
	_detail.fit_content = true
	_detail.add_theme_color_override("default_color", Palette.TEXT)

	if _mobile:
		## While the overlay is shut the label still has to belong to something,
		## or it is an orphan the scene tree will never free — the overlay only
		## borrows it. A zero-height hidden holder inside the screen owns it, so
		## the label's lifetime matches the screen's in both layouts.
		_detail_home = VBoxContainer.new()
		_detail_home.visible = false
		_detail_home.custom_minimum_size = Vector2(0, 0)
		middle.add_child(_detail_home)
		_detail_home.add_child(_detail)

		## A button under the list, rather than a permanently reserved pane.
		## Its label carries the deck name so the row it will open is obvious
		## before it is tapped; `_refresh()` keeps that text current.
		_contents_btn = Button.new()
		_contents_btn.custom_minimum_size = Vector2(0, 40)
		_contents_btn.add_theme_font_size_override("font_size", 15)
		Palette.style_button(_contents_btn)
		_contents_btn.pressed.connect(_open_contents)
		middle.add_child(_contents_btn)
	else:
		var right := VBoxContainer.new()
		right.add_theme_constant_override("separation", Palette.SPACE_SM)
		right.add_child(Palette.heading("Contents"))

		## A header carrying the deck's hero art, its name and its type mix, above
		## the card list. The pane was a plain text list in a mostly empty half of
		## the screen; the deck being previewed deserves to be *shown* here for the
		## same reason its row is, and the mix answers "what kind of deck is this"
		## before the list answers "which cards".
		_detail_head = _build_detail_head()
		right.add_child(_detail_head)

		var detail_scroll := ScrollContainer.new()
		detail_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
		detail_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		right.add_child(detail_scroll)

		var detail_panel := Palette.make_panel(Palette.PANEL)
		detail_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		detail_scroll.add_child(detail_panel)
		detail_panel.add_child(_detail)
		middle.add_child(right)

	## --- opponent row: which deck the AI brings. Defaults to Random, which is
	## why it sits here as one compact control rather than a second deck list —
	## most fights want a varied opponent, and picking one is the exception.
	_opponent_row = HBoxContainer.new()
	_opponent_row.add_theme_constant_override("separation", 8)
	root.add_child(_opponent_row)

	_opponent_row.add_child(Palette.label("Opponent:", Palette.TYPE_BODY, Palette.TEXT_DIM))

	_opponent_pick = OptionButton.new()
	_opponent_pick.custom_minimum_size = Vector2(0 if _mobile else 260, 34)
	if _mobile:
		_opponent_pick.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	Palette.style_button(_opponent_pick)
	_opponent_pick.item_selected.connect(_on_opponent_selected)
	_opponent_row.add_child(_opponent_pick)

	## The note explains what Random does. It is the least important thing in the
	## row and the only one that can be dropped without losing a control, so on a
	## phone the dropdown takes its width instead.
	##
	## It is still constructed, and `_refresh` still writes to it, so the mobile
	## path needs no branch there — an off-tree Label accepts text harmlessly.
	## Parented to the row either way so it is freed with the screen rather than
	## leaking; on mobile it is simply hidden.
	_opponent_note = Palette.label("", Palette.TYPE_BODY, Palette.TEXT_DIM)
	_opponent_note.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_opponent_note.visible = not _mobile
	_opponent_row.add_child(_opponent_note)

	## --- bottom bar
	##
	## On a phone the status line moves onto its own row above the buttons: it
	## wraps to two or three lines at this width, and sharing a row with two
	## 140px buttons would squeeze it to a column of single words.
	_status = Palette.label("", Palette.TYPE_BODY, Palette.TEXT_DIM)
	_status.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

	var bottom := HBoxContainer.new()
	bottom.add_theme_constant_override("separation", 12)
	if _mobile:
		root.add_child(_status)
	root.add_child(bottom)
	if not _mobile:
		bottom.add_child(_status)

	var edit_btn := Button.new()
	edit_btn.text = "Edit Deck"
	edit_btn.custom_minimum_size = Vector2(140, 42)
	edit_btn.add_theme_font_size_override("font_size", 16)
	Palette.style_button(edit_btn)
	edit_btn.pressed.connect(func(): get_tree().change_scene_to_file(BUILDER_SCENE))
	bottom.add_child(edit_btn)

	_fight_btn = Button.new()
	_fight_btn.text = "Fight >"
	_fight_btn.custom_minimum_size = Vector2(160, 42)
	_fight_btn.add_theme_font_size_override("font_size", Palette.TYPE_SUBHEAD)
	## The one thing you came to this screen to press, so it is the one control
	## carrying saturated colour. Exactly one primary per screen is what makes
	## "primary" mean anything.
	Palette.style_primary_button(_fight_btn)
	_fight_btn.pressed.connect(_on_fight)
	## Both buttons share the row evenly on a phone, so each is a comfortably
	## large touch target instead of two small ones crowded to the right.
	if _mobile:
		edit_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_fight_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bottom.add_child(_fight_btn)


# ------------------------------------------------------------------ refresh

func _refresh() -> void:
	_rebuild_list()
	_rebuild_opponent()
	_show_detail(DeckStore.active_index)

	## The button names the deck it will open, so the overlay's contents are
	## predictable before it is tapped.
	if _contents_btn != null and is_instance_valid(_contents_btn):
		_contents_btn.text = "View contents - %s (%d)" % [
			DeckStore.name_at(DeckStore.active_index),
			DeckStore.total_at(DeckStore.active_index),
		]

	var errs := DeckStore.validation_errors()
	if errs.is_empty():
		_status.text = "“%s” is ready — %d cards, %d energy." % [
			DeckStore.active_name(), DeckStore.total_cards(), DeckStore.energy_count()
		]
		_status.add_theme_color_override("font_color", Palette.TEXT_DIM)
	else:
		_status.text = "! %s — %s" % [DeckStore.active_name(), errs[0]]
		_status.add_theme_color_override("font_color", Palette.DANGER)

	_fight_btn.disabled = not DeckStore.is_legal()
	_fight_btn.visible = for_combat
	## Managing decks isn't a fight, so the opponent choice has nothing to apply to.
	_opponent_row.visible = for_combat


## Rebuild the opponent dropdown. Done on every refresh rather than once at
## build time because deck indices shift when a deck is created or deleted, and
## a stale index here would silently start the fight against the wrong list.
##
## Item 0 is always Random. Illegal decks are listed but disabled — hiding them
## would make a deck the player is halfway through building simply vanish from
## the menu with no explanation of why.
func _rebuild_opponent() -> void:
	var want: int = DeckStore.opponent_index
	_opponent_pick.clear()
	_opponent_pick.add_item("?  Random", DeckStore.OPPONENT_RANDOM)

	for i in DeckStore.deck_count():
		_opponent_pick.add_item(DeckStore.name_at(i), i)
		var item := _opponent_pick.item_count - 1
		if not DeckStore.is_legal_at(i):
			_opponent_pick.set_item_disabled(item, true)
			_opponent_pick.set_item_text(item, "%s  ! incomplete" % DeckStore.name_at(i))

	## A chosen deck that has since been deleted or gutted falls back to Random
	## rather than starting a fight against something the player didn't pick.
	if want >= 0 and (want >= DeckStore.deck_count() or not DeckStore.is_legal_at(want)):
		DeckStore.opponent_index = DeckStore.OPPONENT_RANDOM
		want = DeckStore.OPPONENT_RANDOM

	for item in _opponent_pick.item_count:
		if _opponent_pick.get_item_id(item) == want:
			_opponent_pick.select(item)
			break

	if want == DeckStore.OPPONENT_RANDOM:
		_opponent_note.text = "A random legal deck is rolled each fight."
	else:
		_opponent_note.text = "Every fight is against “%s”." % DeckStore.name_at(want)


func _on_opponent_selected(item: int) -> void:
	DeckStore.opponent_index = _opponent_pick.get_item_id(item)
	_rebuild_opponent()


func _rebuild_list() -> void:
	for c in _list_box.get_children():
		c.queue_free()

	for i in DeckStore.deck_count():
		_list_box.add_child(_deck_row(i))


func _deck_row(i: int) -> Control:
	var is_active := i == DeckStore.active_index
	var legal := DeckStore.is_legal_at(i)

	var panel := Palette.make_panel(
		Palette.PANEL_LIGHT if is_active else Palette.PANEL,
		Palette.ACCENT if is_active else Palette.BORDER
	)

	## A colour spine down the left edge, so a deck is identifiable by what it
	## plays before its name is read. Ten decks as ten identical panels made
	## finding one a reading task.
	var spined := HBoxContainer.new()
	spined.add_theme_constant_override("separation", Palette.SPACE_MD)
	panel.add_child(spined)
	spined.add_child(FactionSpine.new(DeckStore.factions_at(i)))

	## The deck's hero card, as a real card frame. Every card game fronts a saved
	## deck with a picture rather than a name — a shelf of pictures is scanned,
	## a column of identical rows is read. Dropped on a phone, where the width is
	## needed for the name and the spine already carries the colour.
	if not _mobile:
		var hero: CardData = DeckStore.hero_card_at(i)
		if hero != null:
			spined.add_child(DeckArtTile.new(hero, HERO_H))

	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", Palette.SPACE_XS)
	outer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	outer.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	spined.add_child(outer)

	## The whole text block is the select target, so picking a deck is one large
	## click rather than a hunt for a small button.
	var pick := Button.new()
	pick.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pick.alignment = HORIZONTAL_ALIGNMENT_LEFT
	## Sized to the text, not to the art plate beside it. Stretching the button
	## to the plate's full height left the name stranded in a large empty box —
	## the row's height is the plate's job, and the VBox centres this against it.
	pick.custom_minimum_size = Vector2(0, 44 if _mobile else 34)
	pick.add_theme_font_size_override("font_size", Palette.TYPE_SUBHEAD)
	pick.clip_text = true
	pick.tooltip_text = "Play with “%s”" % DeckStore.name_at(i)
	pick.text = "%s%s" % [
		(Palette.glyph("active") + " ") if is_active else "",
		DeckStore.name_at(i),
	]
	## Flat until it is the active deck. Ten filled buttons in a column is ten
	## things claiming to be pressed; the selected row is the only one that reads
	## as a control, and the panel behind it carries the accent border. A filled
	## box the width of the row also made the name look stranded inside it.
	Palette.style_button(pick,
		Palette.ACCENT_DIM.darkened(0.45) if is_active else Palette.PANEL)
	if not is_active:
		pick.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
	if not legal:
		pick.add_theme_color_override("font_color", Palette.DANGER)
	pick.pressed.connect(func():
		DeckStore.select(i)
		_show_detail(i)
	)
	outer.add_child(pick)

	## The stat line sits *outside* the button rather than as a second line of
	## its label, so the count and the warning can be coloured independently of
	## the deck name — an illegal deck needs its reason marked, not its title.
	outer.add_child(_deck_stats(i, legal))

	## Rename / Copy / Delete behind one "…". Thirty buttons for ten decks made
	## the destructive actions the loudest thing on a screen whose only job is
	## picking one — see OverflowMenu.
	var menu := OverflowMenu.new([
		{ "label": "Rename", "cb": func(): _start_rename(i) },
		{ "label": "Duplicate", "cb": func(): DeckStore.duplicate_deck(i) },
		{ "label": "Edit cards", "cb": func():
			DeckStore.select(i)
			get_tree().change_scene_to_file(BUILDER_SCENE) },
		{
			"label": "Delete", "danger": true,
			"disabled": DeckStore.deck_count() <= 1,
			"tooltip": "The last deck can't be deleted.",
			"cb": func(): DeckStore.delete_deck(i),
		},
	], _mobile)
	menu.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	spined.add_child(menu)

	return panel


## "60 cards · 19 energy", or the reason the deck can't be played.
##
## Legal decks say nothing about legality — a green tick on every row is noise.
## An illegal one states what is wrong in the alarm colour, because that is the
## row the player has to act on.
func _deck_stats(i: int, legal: bool) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", Palette.SPACE_SM)

	var counts := Palette.label("%d / %d cards" % [
		DeckStore.total_at(i), DeckStore.DECK_SIZE], Palette.TYPE_SMALL,
		Palette.TEXT_DIM if legal else Palette.DANGER)
	row.add_child(counts)

	row.add_child(Palette.label(Palette.glyph("dot"), Palette.TYPE_SMALL, Palette.TEXT_FAINT))
	row.add_child(Palette.label("%d energy" % DeckStore.energy_at(i),
		Palette.TYPE_SMALL, Palette.TEXT_DIM))

	if not legal:
		var errs := DeckStore.errors_at(i)
		if not errs.is_empty():
			row.add_child(Palette.label(Palette.glyph("dot"),
				Palette.TYPE_SMALL, Palette.TEXT_FAINT))
			var why := Palette.label("%s %s" % [Palette.glyph("warn"), errs[0]],
				Palette.TYPE_SMALL, Palette.DANGER)
			why.clip_text = true
			why.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			row.add_child(why)

	return row


## ------------------------------------------------------------ contents overlay
##
## Phone only. Built to the same recipe as the deck builder's card inspector —
## a full-rect layer, a dimming scrim, a transparent button behind the panel to
## catch outside taps, and Escape handled in `_unhandled_input` — so the two
## modals in the game behave identically rather than each inventing a gesture.
func _open_contents() -> void:
	if _detail == null:
		return
	_close_contents()

	_contents_layer = Control.new()
	_contents_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	_contents_layer.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_contents_layer)

	var scrim := ColorRect.new()
	scrim.color = Color(0, 0, 0, 0.62)
	scrim.set_anchors_preset(Control.PRESET_FULL_RECT)
	scrim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_contents_layer.add_child(scrim)

	var dismiss := Button.new()
	dismiss.flat = true
	dismiss.set_anchors_preset(Control.PRESET_FULL_RECT)
	dismiss.pressed.connect(_close_contents)
	_contents_layer.add_child(dismiss)

	## Inset from the edges rather than sized to content, so a 60-card list
	## scrolls inside the panel instead of growing off the bottom of the screen.
	var panel := Palette.make_panel(Palette.PANEL)
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	panel.offset_left = 16
	panel.offset_right = -16
	panel.offset_top = 28
	panel.offset_bottom = -28
	_contents_layer.add_child(panel)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 8)
	panel.add_child(col)

	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 8)
	col.add_child(head)

	var title := Palette.label(
		DeckStore.name_at(DeckStore.active_index), 16, Palette.ACCENT)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)

	var close := Button.new()
	close.text = "X"
	close.custom_minimum_size = Vector2(40, 34)
	Palette.style_button(close)
	close.pressed.connect(_close_contents)
	head.add_child(close)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	col.add_child(scroll)

	## `_detail` is reparented rather than duplicated, so there is exactly one
	## contents label in the screen and `_show_detail()` keeps addressing it
	## whether the overlay is open or shut.
	var host := VBoxContainer.new()
	host.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(host)
	if _detail.get_parent() != null:
		_detail.get_parent().remove_child(_detail)
	host.add_child(_detail)


func _close_contents() -> void:
	## The label outlives the overlay: pull it back out before the layer is
	## freed, or the next `_show_detail()` writes to a freed node.
	if _detail != null and is_instance_valid(_detail) and _detail.get_parent() != null:
		_detail.get_parent().remove_child(_detail)
		if _detail_home != null and is_instance_valid(_detail_home):
			_detail_home.add_child(_detail)
	if _contents_layer != null and is_instance_valid(_contents_layer):
		_contents_layer.queue_free()
	_contents_layer = null


## Escape closes the overlay rather than falling through to the screen.
func _unhandled_input(event: InputEvent) -> void:
	if _contents_layer == null:
		return
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		_close_contents()
		get_viewport().set_input_as_handled()


## The contents pane's header: hero plate, deck name, and the composition bar.
## Desktop only — on a phone the contents live in an overlay that is already
## titled, and the width is better spent on the list itself.
func _build_detail_head() -> Control:
	var panel := Palette.make_panel(Palette.PANEL)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", Palette.SPACE_SM)
	panel.add_child(col)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", Palette.SPACE_MD)
	col.add_child(row)

	## Rebuilt per refresh by `_show_detail`, so it is only a placeholder here.
	var art_slot := HBoxContainer.new()
	art_slot.name = "ArtSlot"
	row.add_child(art_slot)

	var names := VBoxContainer.new()
	names.add_theme_constant_override("separation", Palette.SPACE_XS)
	names.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	names.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(names)

	var title := Palette.label("", Palette.TYPE_HEADING, Palette.TEXT)
	title.name = "DeckName"
	title.clip_text = true
	names.add_child(title)

	var sub := Palette.label("", Palette.TYPE_SMALL, Palette.TEXT_DIM)
	sub.name = "DeckStats"
	names.add_child(sub)

	_mix_bar = CompositionBar.new({})
	col.add_child(_mix_bar)

	var mix_text := Palette.label("", Palette.TYPE_SMALL, Palette.TEXT_DIM)
	mix_text.name = "MixText"
	mix_text.clip_text = true
	col.add_child(mix_text)

	return panel


## Refresh the contents header for deck `i`. No-op on a phone, where the header
## is not built at all.
func _refresh_detail_head(i: int) -> void:
	if _detail_head == null or not is_instance_valid(_detail_head):
		return

	var slot: HBoxContainer = _detail_head.find_child("ArtSlot", true, false)
	if slot != null:
		for c in slot.get_children():
			slot.remove_child(c)
			c.queue_free()
		var hero: CardData = DeckStore.hero_card_at(i)
		if hero != null:
			slot.add_child(DeckArtTile.new(hero, HERO_H))

	var title: Label = _detail_head.find_child("DeckName", true, false)
	if title != null:
		title.text = DeckStore.name_at(i)

	var sub: Label = _detail_head.find_child("DeckStats", true, false)
	if sub != null:
		var errs := DeckStore.errors_at(i)
		if errs.is_empty():
			sub.text = "%d cards %s %d energy" % [
				DeckStore.total_at(i), Palette.glyph("dot"), DeckStore.energy_at(i)]
			sub.add_theme_color_override("font_color", Palette.TEXT_DIM)
		else:
			sub.text = "%s %s" % [Palette.glyph("warn"), errs[0]]
			sub.add_theme_color_override("font_color", Palette.DANGER)

	var mix := DeckStore.composition_at(i)
	if _mix_bar != null and is_instance_valid(_mix_bar):
		_mix_bar.set_mix(mix)
	var mix_text: Label = _detail_head.find_child("MixText", true, false)
	if mix_text != null:
		mix_text.text = CompositionBar.describe(mix)


func _show_detail(i: int) -> void:
	_refresh_detail_head(i)

	var cards := DeckStore.cards_at(i)
	if cards.is_empty():
		_detail.text = "[color=#8f88a3]“%s” is empty. Hit [b]Edit Deck[/b] to build it.[/color]" % DeckStore.name_at(i)
		return

	var ids := cards.keys()
	ids.sort_custom(func(a, b):
		var ca: CardData = CardDB.get_card(a)
		var cb: CardData = CardDB.get_card(b)
		if ca == null or cb == null:
			return false
		if ca.is_unit() != cb.is_unit():
			return not ca.is_unit()          ## energy at top
		if ca.stage != cb.stage:
			return ca.stage < cb.stage
		return ca.name < cb.name
	)

	## The deck's name and counts are in the header above this list on a desktop,
	## and in the overlay's own title on a phone — so printing them again at the
	## top of the list is duplication in both layouts. This is the card list.
	var s := ""

	var last_group := ""
	for id in ids:
		var card: CardData = CardDB.get_card(id)
		if card == null:
			continue
		var group := "Energy" if not card.is_unit() else card.stage_name()
		if group != last_group:
			## No blank line before the first group, now that nothing precedes it.
			s += "%s[color=#7c4dff]— %s —[/color]\n" % ["" if last_group == "" else "\n", group]
			last_group = group
		s += "  [color=#d9b45b]%d×[/color]  %s\n" % [int(cards[id]), card.name]

	var errs := DeckStore.errors_at(i)
	if not errs.is_empty():
		s += "\n[color=#d94f4f]! %s[/color]" % "  ".join(errs)

	_detail.text = s


# ------------------------------------------------------------------ actions

func _on_new() -> void:
	var i := DeckStore.create_deck()
	_start_rename(i)


func _start_rename(i: int) -> void:
	_renaming = i
	_rename_edit.text = DeckStore.name_at(i)
	_rename_row.visible = true
	_rename_edit.grab_focus()
	_rename_edit.select_all()


func _commit_rename() -> void:
	if _renaming >= 0:
		DeckStore.rename_deck(_rename_edit.text, _renaming)
	_cancel_rename()


func _cancel_rename() -> void:
	_renaming = -1
	_rename_row.visible = false


func _on_fight() -> void:
	if not DeckStore.is_legal():
		_refresh()
		return
	get_tree().change_scene_to_file(COMBAT_SCENE)
