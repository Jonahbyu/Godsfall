extends Control

## The rules reference. A sectioned, browsable index of every rule in the game —
## the half of the tutorial you consult rather than play.
##
## Content comes from `TutorialData.compendium()`. Nothing here restates a rule
## inline: a page's body is data, so a rules change is a text edit in one file.
##
## Keyword pages show a REAL `CardView` of a card carrying that keyword — the
## same renderer the hand, the board and the inspector use. A second "example
## card" renderer would drift the first time either changed, which is the same
## reasoning that made `CardInspector` scale a real CardView.

const MENU_SCENE := "res://scenes/MainMenu.tscn"
const TUTORIAL_SCENE := "res://scenes/Tutorial.tscn"

const EXAMPLE_SCALE := 0.85

## Which card to show beside each keyword page. Chosen to be the clearest
## printed example of the keyword rather than the strongest card.
const KEYWORD_EXAMPLES := {
	"toll":        "barrow_knight",
	"decay":       "carrion_crawler",
	"rise":        "hollow_servant",
	"retribution": "thornshade",
	"consume":     "hels_chorus",
	"judgment":    "censer_bearer",
	"sanctuary":   "radiant_bastion",
	"resist":      "gaia_bulwark_of_stone",
	"siphon":      "hollow_acolyte",
	"void":        "unwrite",
	"rift":        "null_adept",
	"earth":       "gaia_sapling_warden",
	"essence":     "gaia_living_conduit",
}

## Set by a caller that wants a specific page open — the "Read more" link on a
## lesson step sets this before switching scenes.
var open_page: String = ""

var _body: RichTextLabel
var _nav: VBoxContainer
var _example_box: VBoxContainer
var _current: String = ""
var _buttons: Dictionary = {}   ## page id -> Button


func _ready() -> void:
	_build()
	var want := open_page if open_page != "" else _first_page_id()
	_show_page(want)


func _first_page_id() -> String:
	var pages := TutorialData.all_pages()
	return String(pages[0].get("id", "")) if not pages.is_empty() else ""


func _build() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)

	var bg := ColorRect.new()
	bg.color = Palette.BG
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var root := VBoxContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.offset_left = 20
	root.offset_right = -20
	root.offset_top = 14
	root.offset_bottom = -14
	root.add_theme_constant_override("separation", 8)
	add_child(root)

	## ---- header
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 12)
	root.add_child(top)

	var back := Button.new()
	back.text = "← Lessons"
	Palette.style_button(back)
	back.pressed.connect(func(): get_tree().change_scene_to_file(TUTORIAL_SCENE))
	top.add_child(back)

	var menu := Button.new()
	menu.text = "Menu"
	Palette.style_button(menu)
	menu.pressed.connect(func(): get_tree().change_scene_to_file(MENU_SCENE))
	top.add_child(menu)

	top.add_child(Palette.label("Rules Reference", 22, Palette.TEXT))

	## ---- two columns: nav on the left, page on the right
	var cols := HBoxContainer.new()
	cols.size_flags_vertical = Control.SIZE_EXPAND_FILL
	cols.add_theme_constant_override("separation", 14)
	root.add_child(cols)

	var nav_scroll := ScrollContainer.new()
	nav_scroll.custom_minimum_size = Vector2(230, 0)
	nav_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	cols.add_child(nav_scroll)

	_nav = VBoxContainer.new()
	_nav.custom_minimum_size = Vector2(210, 0)
	_nav.add_theme_constant_override("separation", 2)
	nav_scroll.add_child(_nav)

	_build_nav()

	## page + example card side by side
	var page_row := HBoxContainer.new()
	page_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	page_row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	page_row.add_theme_constant_override("separation", 12)
	cols.add_child(page_row)

	var body_panel := Palette.make_panel(Palette.PANEL)
	body_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	page_row.add_child(body_panel)

	_body = RichTextLabel.new()
	_body.bbcode_enabled = true
	_body.fit_content = false
	_body.scroll_active = true
	_body.add_theme_font_size_override("normal_font_size", 14)
	_body.add_theme_font_size_override("bold_font_size", 14)
	_body.add_theme_font_size_override("mono_font_size", 12)
	_body.add_theme_color_override("default_color", Palette.TEXT)
	body_panel.add_child(_body)

	_example_box = VBoxContainer.new()
	_example_box.custom_minimum_size = Vector2(CardView.HAND_SIZE.x * EXAMPLE_SCALE + 16, 0)
	_example_box.add_theme_constant_override("separation", 6)
	page_row.add_child(_example_box)


func _build_nav() -> void:
	for c in _nav.get_children():
		c.queue_free()
	_buttons.clear()

	for sec in TutorialData.compendium():
		var head := Palette.label(String(sec.get("title", "")).to_upper(), 11, Palette.ACCENT)
		head.custom_minimum_size = Vector2(0, 22)
		head.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
		_nav.add_child(head)

		for p in sec.get("pages", []):
			var id := String(p.get("id", ""))
			var b := Button.new()
			b.text = String(p.get("title", ""))
			b.alignment = HORIZONTAL_ALIGNMENT_LEFT
			b.add_theme_font_size_override("font_size", 12)
			b.custom_minimum_size = Vector2(0, 26)
			Palette.style_button(b, Palette.PANEL, Palette.PANEL)
			b.pressed.connect(func(): _show_page(id))
			_nav.add_child(b)
			_buttons[id] = b


func _show_page(id: String) -> void:
	var page := TutorialData.page_by_id(id)
	if page.is_empty():
		return
	_current = id

	## Highlight the active entry. Restyling every button each time is cheap at
	## this list size and avoids tracking the previous selection.
	for pid in _buttons:
		var b: Button = _buttons[pid]
		if pid == id:
			Palette.style_button(b, Palette.PANEL_LIGHT, Palette.ACCENT)
		else:
			Palette.style_button(b, Palette.PANEL, Palette.PANEL)

	var header := "[font_size=22][b]%s[/b][/font_size]" % String(page.get("title", ""))
	var faction := String(page.get("faction", ""))
	if faction != "":
		header += "\n[color=#%s][i]%s[/i][/color]" % [
			Palette.GOLD.to_html(false), faction]
	_body.text = "%s\n\n%s" % [header, String(page.get("body", ""))]
	_body.scroll_to_line(0)

	_show_example(page)


## The example card for a keyword page, if the keyword has one and the card
## exists. Silently shows nothing otherwise — a missing example must never stop
## the page rendering, the same way a card with no art falls back rather than
## failing.
func _show_example(page: Dictionary) -> void:
	for c in _example_box.get_children():
		c.queue_free()

	var kw := String(page.get("keyword", ""))
	if kw == "" or not KEYWORD_EXAMPLES.has(kw):
		return
	var card_id := String(KEYWORD_EXAMPLES[kw])
	var card = CardDB.get_card(card_id)
	if card == null:
		return

	_example_box.add_child(Palette.label("Example", 11, Palette.TEXT_DIM))

	var view := CardView.new(card, null, CardView.Mode.HAND)
	view.scale = Vector2(EXAMPLE_SCALE, EXAMPLE_SCALE)

	## Wrapped in a fixed-size Control because a scaled node still reports its
	## unscaled size to the container — the same wrapper CardInspector uses.
	var holder := Control.new()
	holder.custom_minimum_size = CardView.HAND_SIZE * EXAMPLE_SCALE
	holder.add_child(view)
	_example_box.add_child(holder)
