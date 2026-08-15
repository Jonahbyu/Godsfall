extends Control

## Main menu. Title, deck legality warning, and the three entry points.

const DECK_SCENE := "res://scenes/DeckBuilder.tscn"
const SELECT_SCENE := "res://scenes/DeckSelect.tscn"
const COMBAT_SCENE := "res://scenes/Combat.tscn"
const TUTORIAL_SCENE := "res://scenes/Tutorial.tscn"

var _warning: Label


func _ready() -> void:
	_build()
	DeckStore.deck_changed.connect(_refresh)
	DeckStore.decks_changed.connect(_refresh)


func _build() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)

	## The cosmic backdrop, rather than a flat fill. The menu is the first thing
	## anyone sees, so it is where the game's own look has to be stated.
	add_child(Starfield.new())

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", Palette.SPACE_MD)
	col.custom_minimum_size = Vector2(340, 0)
	center.add_child(col)

	## The mark. A menu needs a focal object that is not a button — it is what
	## makes the screen a place rather than a list of links.
	var crest := Crest.new(126.0)
	crest.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	col.add_child(crest)

	## The wordmark, in the display face and letterspaced. Tracking is what makes
	## a title read as a *mark* rather than as a large label — an inscriptional
	## face is designed to be cut with air around each letter.
	var title := Palette.title("GODSFALL", Palette.TYPE_DISPLAY, Palette.TEXT)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_constant_override("outline_size", 0)
	col.add_child(title)

	var rule := Midline.new()
	rule.custom_minimum_size = Vector2(0, 10)
	col.add_child(rule)

	var sub := Palette.label("Death is a resource.", Palette.TYPE_SUBHEAD, Palette.TEXT_DIM)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(sub)

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, Palette.SPACE_LG)
	col.add_child(spacer)

	## One primary action, then the rest. Four identically-styled buttons make the
	## player read all four every time; giving "Play" the accent fill means the
	## common case is found without reading, and the others recede to where they
	## belong. Exactly one primary per screen is what makes primary mean anything.
	col.add_child(_menu_button("Play vs. AI", _on_play, true))
	col.add_child(_menu_button("Learn to Play", _on_tutorial))
	col.add_child(_menu_button("My Decks", _on_decks))

	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, Palette.SPACE_SM)
	col.add_child(gap)
	col.add_child(_menu_button("Quit", _on_quit))

	_warning = Palette.label("", Palette.TYPE_SMALL, Palette.DANGER)
	_warning.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_warning.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(_warning)

	var version := Palette.label("prototype build", Palette.TYPE_SMALL, Palette.TEXT_FAINT)
	version.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(version)

	_refresh()

	## The mark and the title arrive rather than appearing. This is the one screen
	## where a beat of motion is worth spending: it is the first impression, and it
	## is seen once per session rather than once per turn.
	crest.ready.connect(func(): Motion.fade_in(crest, Motion.SLOW), CONNECT_ONE_SHOT)
	title.ready.connect(func(): Motion.slide_in(title, Vector2(0, -14), Motion.SLOW),
		CONNECT_ONE_SHOT)
	sub.ready.connect(func(): Motion.fade_in(sub, Motion.SLOW), CONNECT_ONE_SHOT)


func _menu_button(text: String, cb: Callable, primary: bool = false) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, 50 if primary else 42)
	b.add_theme_font_size_override("font_size",
		Palette.TYPE_SUBHEAD if primary else Palette.TYPE_BODY)
	if primary:
		Palette.style_primary_button(b)
	else:
		Palette.style_button(b)
	b.pressed.connect(cb)
	return b


func _refresh() -> void:
	var errs := DeckStore.validation_errors()
	if errs.is_empty():
		_warning.text = "%s — %d cards (%d energy)   ·   %d saved" % [
			DeckStore.active_name(), DeckStore.total_cards(),
			DeckStore.energy_count(), DeckStore.deck_count()
		]
		_warning.add_theme_color_override("font_color", Palette.TEXT_DIM)
	else:
		_warning.text = "! %s: %s" % [DeckStore.active_name(), errs[0]]
		_warning.add_theme_color_override("font_color", Palette.DANGER)


## Both entry points land on deck select — the difference is whether it offers
## to start a fight or just manage the collection.
func _on_play() -> void:
	_go_to_select(true)


## The tutorial is its own entry point rather than a prompt on first run: a
## player who wants it should always be able to find it, and one who does not
## should never be made to sit through it.
##
## `Tutorial.end()` first, so a lesson abandoned by walking back to the menu can
## never leak into the next ordinary game.
func _on_tutorial() -> void:
	Tutorial.end()
	get_tree().change_scene_to_file(TUTORIAL_SCENE)


func _on_decks() -> void:
	_go_to_select(false)


func _go_to_select(for_combat: bool) -> void:
	var scene: PackedScene = load(SELECT_SCENE)
	if scene == null:
		return
	var screen := scene.instantiate()
	screen.for_combat = for_combat
	## Swap the scene by hand so `for_combat` is set before _ready() runs.
	var tree := get_tree()
	tree.root.add_child(screen)
	tree.current_scene.queue_free()
	tree.current_scene = screen


func _on_quit() -> void:
	get_tree().quit()
