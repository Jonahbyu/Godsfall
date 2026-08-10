extends Control

## Lesson select. The tutorial's front door: fourteen chapters, each independently
## selectable and independently completable.
##
## No lesson depends on state from another — each builds its own GameState from
## its own fixed deck — so a player who only wants the Void lesson can take it.

const MENU_SCENE := "res://scenes/MainMenu.tscn"
const COMBAT_SCENE := "res://scenes/Combat.tscn"
const BUILDER_SCENE := "res://scenes/DeckBuilder.tscn"
const COMPENDIUM_SCENE := "res://scenes/Compendium.tscn"

var _list_box: VBoxContainer
var _progress: Label


func _ready() -> void:
	_build()


func _build() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)

	var bg := ColorRect.new()
	bg.color = Palette.BG
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var root := VBoxContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.offset_left = 40
	root.offset_right = -40
	root.offset_top = 20
	root.offset_bottom = -20
	root.add_theme_constant_override("separation", 10)
	add_child(root)

	## ---- header
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 12)
	root.add_child(top)

	var back := Button.new()
	back.text = "← Menu"
	Palette.style_button(back)
	back.pressed.connect(func(): get_tree().change_scene_to_file(MENU_SCENE))
	top.add_child(back)

	var title := Palette.label("Learn to Play", 26, Palette.TEXT)
	top.add_child(title)

	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(sp)

	_progress = Palette.label("", 13, Palette.TEXT_DIM)
	_progress.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	top.add_child(_progress)

	var ref := Button.new()
	ref.text = "Rules Reference"
	Palette.style_button(ref, Palette.PANEL_LIGHT, Palette.GOLD)
	ref.pressed.connect(_open_compendium)
	top.add_child(ref)

	var sub := Palette.label(
		"Fourteen lessons. Take them in order, or jump to whatever you want to learn.",
		13, Palette.TEXT_DIM)
	root.add_child(sub)

	## ---- the lesson list
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	root.add_child(scroll)

	_list_box = VBoxContainer.new()
	_list_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list_box.add_theme_constant_override("separation", 6)
	scroll.add_child(_list_box)

	## ---- footer
	var foot := HBoxContainer.new()
	foot.add_theme_constant_override("separation", 10)
	root.add_child(foot)

	var reset := Button.new()
	reset.text = "Reset progress"
	reset.add_theme_font_size_override("font_size", 12)
	Palette.style_button(reset, Palette.PANEL, Palette.BORDER)
	reset.pressed.connect(func():
		Tutorial.reset_progress()
		_refresh())
	foot.add_child(reset)

	_refresh()


func _refresh() -> void:
	for c in _list_box.get_children():
		c.queue_free()

	var lessons := TutorialData.lessons()
	for i in lessons.size():
		_list_box.add_child(_lesson_row(i, lessons[i]))

	_progress.text = "%d of %d complete" % [Tutorial.completed_count(), lessons.size()]


func _lesson_row(i: int, l: Dictionary) -> Control:
	var id := String(l.get("id", ""))
	var done: bool = Tutorial.is_complete(id)

	var panel := Palette.make_panel(
		Palette.PANEL_LIGHT if done else Palette.PANEL,
		Palette.ACCENT if done else Palette.BORDER)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	panel.add_child(row)

	## number / tick
	var num := Palette.label(
		"✓" if done else str(i + 1),
		20, Palette.ACCENT if done else Palette.TEXT_DIM)
	num.custom_minimum_size = Vector2(34, 0)
	num.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	num.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(num)

	## text block
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", 1)
	row.add_child(col)

	var name_lbl := Palette.label(String(l.get("title", "")), 17, Palette.TEXT)
	col.add_child(name_lbl)

	var blurb := Palette.label(String(l.get("blurb", "")), 12, Palette.TEXT_DIM)
	blurb.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(blurb)

	var teaches := String(l.get("teaches", ""))
	if teaches != "":
		var t := Palette.label(teaches, 11, Palette.GOLD)
		t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		col.add_child(t)

	## start
	var go := Button.new()
	go.text = "Replay" if done else "Start"
	go.custom_minimum_size = Vector2(96, 36)
	Palette.style_button(go, Palette.ACCENT_DIM, Palette.ACCENT)
	go.pressed.connect(func(): _start(id))
	row.add_child(go)

	return panel


func _start(id: String) -> void:
	if not Tutorial.begin(id):
		return
	## The deckbuilding lesson is the one chapter that is not a battle — it runs
	## alongside the deck builder, because deckbuilding is not something you can
	## do on a board.
	if Tutorial.is_builder_lesson():
		get_tree().change_scene_to_file(BUILDER_SCENE)
	else:
		get_tree().change_scene_to_file(COMBAT_SCENE)


func _open_compendium() -> void:
	get_tree().change_scene_to_file(COMPENDIUM_SCENE)
