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

## Set false by the main menu's "Manage Decks" entry, so the screen shows
## "Edit" as the primary action instead of "Fight".
var for_combat: bool = true

var _list_box: VBoxContainer
var _detail: RichTextLabel
var _fight_btn: Button
var _status: Label
var _rename_row: HBoxContainer
var _rename_edit: LineEdit
var _renaming: int = -1
var _opponent_row: HBoxContainer
var _opponent_pick: OptionButton
var _opponent_note: Label

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
	for child in get_children():
		remove_child(child)
		child.queue_free()
	_build()
	_refresh()


func _build() -> void:
	_mobile = ViewportFit.mobile
	set_anchors_preset(Control.PRESET_FULL_RECT)

	var bg := ColorRect.new()
	bg.color = Palette.BG
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

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
		top.add_child(Palette.label("Choose Your Deck", 24))

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(spacer)

	var new_btn := Button.new()
	new_btn.text = "+ New" if _mobile else "+ New Deck"
	Palette.style_button(new_btn, Palette.PANEL_LIGHT, Palette.ACCENT)
	new_btn.pressed.connect(_on_new)
	top.add_child(new_btn)

	## --- rename row, hidden until a rename starts
	_rename_row = HBoxContainer.new()
	_rename_row.add_theme_constant_override("separation", 8)
	_rename_row.visible = false
	root.add_child(_rename_row)

	_rename_row.add_child(Palette.label("Name:", 14, Palette.ACCENT))

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
	var middle: Container
	if _mobile:
		middle = VBoxContainer.new()
		middle.add_theme_constant_override("separation", 10)
	else:
		var split := HSplitContainer.new()
		split.split_offset = 560
		middle = split
	middle.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(middle)

	var left := VBoxContainer.new()
	left.add_theme_constant_override("separation", 6)
	## Stacked, each pane has to claim vertical space or the list collapses to
	## nothing and the contents take the whole column.
	if _mobile:
		left.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left.add_child(Palette.label("Saved Decks", 16, Palette.ACCENT))

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	left.add_child(scroll)

	_list_box = VBoxContainer.new()
	_list_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list_box.add_theme_constant_override("separation", 6)
	scroll.add_child(_list_box)
	middle.add_child(left)

	var right := VBoxContainer.new()
	right.add_theme_constant_override("separation", 6)
	if _mobile:
		right.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right.add_child(Palette.label("Contents", 16, Palette.ACCENT))

	var detail_scroll := ScrollContainer.new()
	detail_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	detail_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	right.add_child(detail_scroll)

	var detail_panel := Palette.make_panel(Palette.PANEL)
	detail_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detail_scroll.add_child(detail_panel)

	_detail = RichTextLabel.new()
	_detail.bbcode_enabled = true
	_detail.fit_content = true
	_detail.add_theme_color_override("default_color", Palette.TEXT)
	detail_panel.add_child(_detail)
	middle.add_child(right)

	## --- opponent row: which deck the AI brings. Defaults to Random, which is
	## why it sits here as one compact control rather than a second deck list —
	## most fights want a varied opponent, and picking one is the exception.
	_opponent_row = HBoxContainer.new()
	_opponent_row.add_theme_constant_override("separation", 8)
	root.add_child(_opponent_row)

	_opponent_row.add_child(Palette.label("Opponent:", 14, Palette.ACCENT))

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
	_opponent_note = Palette.label("", 13, Palette.TEXT_DIM)
	_opponent_note.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_opponent_note.visible = not _mobile
	_opponent_row.add_child(_opponent_note)

	## --- bottom bar
	##
	## On a phone the status line moves onto its own row above the buttons: it
	## wraps to two or three lines at this width, and sharing a row with two
	## 140px buttons would squeeze it to a column of single words.
	_status = Palette.label("", 13, Palette.TEXT_DIM)
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
	_fight_btn.add_theme_font_size_override("font_size", 18)
	Palette.style_button(_fight_btn, Palette.ACCENT_DIM.darkened(0.3), Palette.ACCENT)
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

	## Desktop puts the name and the three actions on one line. On a phone the
	## name needs the full width to stay readable, so the actions drop to a
	## second line underneath it and stretch to share it evenly.
	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", 6)
	panel.add_child(outer)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	outer.add_child(row)

	var actions := row
	if _mobile:
		actions = HBoxContainer.new()
		actions.add_theme_constant_override("separation", 6)
		outer.add_child(actions)

	## The whole left side is the select button.
	var pick := Button.new()
	pick.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pick.alignment = HORIZONTAL_ALIGNMENT_LEFT
	pick.custom_minimum_size = Vector2(0, 40)
	pick.add_theme_font_size_override("font_size", 15)
	var mark := "* " if is_active else "  "
	var warn := "" if legal else "   !"
	pick.text = "%s%s%s\n      %d cards · %d energy" % [
		mark, DeckStore.name_at(i), warn, DeckStore.total_at(i), DeckStore.energy_at(i)
	]
	Palette.style_button(pick, Palette.ACCENT_DIM.darkened(0.45) if is_active else Palette.PANEL_LIGHT)
	if not legal:
		pick.add_theme_color_override("font_color", Palette.DANGER)
	pick.pressed.connect(func():
		DeckStore.select(i)
		_show_detail(i)
	)
	row.add_child(pick)

	actions.add_child(_icon_button("Rename", func(): _start_rename(i)))
	actions.add_child(_icon_button("Copy", func(): DeckStore.duplicate_deck(i)))

	var del := _icon_button("Delete", func(): DeckStore.delete_deck(i))
	del.disabled = DeckStore.deck_count() <= 1
	del.tooltip_text = "The last deck can't be deleted." if del.disabled else "Delete this deck"
	Palette.style_button(del, Palette.PANEL_LIGHT, Palette.DANGER if not del.disabled else Palette.BORDER)
	actions.add_child(del)

	return panel


func _icon_button(text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	## 40 tall on a desktop is already a fine pointer target; on a phone it is
	## the minimum comfortable touch target, and the three of them share the row
	## rather than sitting at their text width.
	b.custom_minimum_size = Vector2(0, 44 if _mobile else 40)
	b.add_theme_font_size_override("font_size", 13)
	if _mobile:
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	Palette.style_button(b)
	b.pressed.connect(cb)
	return b


func _show_detail(i: int) -> void:
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

	var s := "[b][color=#e6e1f0]%s[/color][/b]\n[color=#8f88a3]%d cards · %d energy[/color]\n\n" % [
		DeckStore.name_at(i), DeckStore.total_at(i), DeckStore.energy_at(i)
	]

	var last_group := ""
	for id in ids:
		var card: CardData = CardDB.get_card(id)
		if card == null:
			continue
		var group := "Energy" if not card.is_unit() else card.stage_name()
		if group != last_group:
			s += "\n[color=#7c4dff]— %s —[/color]\n" % group
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
