class_name OverflowMenu
extends MenuButton

## A row's secondary actions, collapsed behind one "…" button.
##
## Deck select listed Rename / Copy / Delete as three buttons on every row, so
## ten decks presented thirty buttons — and every one of them was a destructive
## or renaming action competing for attention with the only thing the screen is
## actually for, which is picking a deck. The actions are still one tap away;
## they are simply no longer the loudest thing in the list.
##
## Built on `MenuButton` rather than a hand-rolled popup so it inherits keyboard
## navigation, outside-click dismissal and correct positioning near a screen
## edge — all of which a custom panel would have to reimplement, and which is
## exactly the sort of thing that gets reimplemented slightly wrong.
##
## Entries are `{ "label": String, "cb": Callable, "danger": bool,
## "disabled": bool, "tooltip": String }`. Only `label` and `cb` are required.

const SIZE := Vector2(38, 40)

var _entries: Array = []


func _init(entries: Array, compact: bool = false) -> void:
	_entries = entries
	text = Palette.glyph("more")
	tooltip_text = "More actions"
	focus_mode = Control.FOCUS_ALL
	custom_minimum_size = Vector2(SIZE.x, 44.0 if compact else SIZE.y)
	add_theme_font_size_override("font_size", Palette.TYPE_SUBHEAD)
	Palette.style_button(self)

	var pop := get_popup()
	Palette.style_popup(pop)

	## Built in one forward pass so an item's popup index is never disturbed
	## after the fact. The id carried on each item is its index into `_entries`,
	## which is what `_on_id` dispatches on — separators are added *before* the
	## item they precede, so nothing ever needs moving.
	for i in _entries.size():
		var e: Dictionary = _entries[i]
		## A separator above the first destructive entry: the standard way to say
		## "the rest of this menu is different". Deliberately not a colour —
		## `set_item_icon_modulate` tints an item's icon, and these have none, so
		## it would have silently done nothing.
		if bool(e.get("danger", false)) and i > 0:
			pop.add_separator()
		pop.add_item(String(e.get("label", "?")), i)
		var idx := pop.item_count - 1
		if bool(e.get("disabled", false)):
			pop.set_item_disabled(idx, true)
		if String(e.get("tooltip", "")) != "":
			pop.set_item_tooltip(idx, String(e["tooltip"]))

	pop.id_pressed.connect(_on_id)


func _on_id(id: int) -> void:
	if id < 0 or id >= _entries.size():
		return
	var cb = _entries[id].get("cb")
	if cb is Callable and cb.is_valid():
		cb.call()
