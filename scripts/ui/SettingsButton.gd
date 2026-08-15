extends CanvasLayer

## Autoload: Settings
##
## A settings cog pinned to the top-right of every screen, and the small panel it
## opens. Currently one setting: the layout override.
##
## ## Why an autoload on a CanvasLayer, not a widget each screen adds
##
## The layout override is the recovery path for a UI that has become unusable —
## a desktop stuck in phone mode, or a phone that guessed wrong. A recovery
## control has to be reachable from wherever you are when you notice, which
## means every screen, unconditionally. Wiring it into four `_build()` methods
## would mean four chances to forget it, and the screen most likely to need it
## is Combat, whose layout is also the most crowded.
##
## A CanvasLayer sits above the scene's own tree and is unaffected by scene
## changes, so the cog survives every `change_scene_to_file` without being
## rebuilt and can never be pushed off the edge by a screen's own layout.
##
## The cog deliberately does NOT hide itself on any screen. It is small, it is
## in the one corner nothing else claims, and a recovery control that disappears
## exactly when a layout breaks would be worse than useless.

const MARGIN := 10

var _panel: PanelContainer
var _btn: Button
var _pick: OptionButton
var _auto_lbl: Label


## Above the hover-zoom layer Combat uses (50), so the cog is never covered by an
## enlarged card. Set as an initialiser rather than in `_ready` so it holds even
## on the headless path, which returns before building any nodes.
func _init() -> void:
	layer = 100


func _ready() -> void:
	if DisplayServer.get_name() == "headless":
		return
	_build()
	ViewportFit.layout_changed.connect(func(_m): _sync())
	get_tree().root.size_changed.connect(_reposition)


func _build() -> void:
	_btn = Button.new()
	_btn.text = Palette.glyph("settings")
	_btn.tooltip_text = "Display settings"
	_btn.add_theme_font_size_override("font_size", 14)
	_btn.custom_minimum_size = Vector2(44, 32)
	Palette.style_button(_btn, Palette.PANEL, Palette.BORDER)
	_btn.pressed.connect(_toggle)
	add_child(_btn)

	_panel = Palette.make_panel(Palette.PANEL, Palette.ACCENT)
	_panel.visible = false
	add_child(_panel)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 6)
	_panel.add_child(col)

	col.add_child(Palette.label("Display", 14, Palette.ACCENT))

	col.add_child(Palette.label("Layout", 12, Palette.TEXT_DIM))

	_pick = OptionButton.new()
	_pick.custom_minimum_size = Vector2(190, 32)
	_pick.add_theme_font_size_override("font_size", 12)
	Palette.style_button(_pick)
	_pick.add_item("Auto", ViewportFit.Override.AUTO)
	_pick.add_item("Phone", ViewportFit.Override.ON)
	_pick.add_item("Desktop", ViewportFit.Override.OFF)
	_pick.item_selected.connect(func(i: int):
		ViewportFit.set_override(_pick.get_item_id(i))
		_sync()
	)
	col.add_child(_pick)

	## Says what Auto currently resolves to, so the control reports the state it
	## is in and not merely the rule it follows. Without this, "Auto" on a
	## desktop stuck in phone mode tells you nothing about why.
	_auto_lbl = Palette.label("", 11, Palette.TEXT_DIM)
	_auto_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_auto_lbl.custom_minimum_size = Vector2(190, 0)
	col.add_child(_auto_lbl)

	_sync()
	_reposition()


func _toggle() -> void:
	_panel.visible = not _panel.visible
	if _panel.visible:
		_sync()
	_reposition()


func _sync() -> void:
	if _pick == null:
		return
	_pick.selected = ViewportFit.override_mode()
	var now := "phone" if ViewportFit.mobile else "desktop"
	var auto_is := "phone" if ViewportFit.auto_would_be_mobile() else "desktop"
	_auto_lbl.text = "Currently %s. Auto would pick %s for this window." % [now, auto_is]
	_reposition()


## Pin to the top-right of the *visible* viewport.
##
## Positioned by hand rather than with anchors because a CanvasLayer child is not
## laid out by a container — and the panel's height is not known until its
## contents have been measured, so it is placed relative to the button.
func _reposition() -> void:
	if _btn == null:
		return
	var view := get_tree().root.get_visible_rect().size
	var bs := _btn.get_combined_minimum_size()
	_btn.size = bs
	_btn.position = Vector2(view.x - bs.x - MARGIN, MARGIN)

	if _panel != null and _panel.visible:
		var ps := _panel.get_combined_minimum_size()
		_panel.size = ps
		_panel.position = Vector2(
			maxf(MARGIN, view.x - ps.x - MARGIN), MARGIN + bs.y + 4)
