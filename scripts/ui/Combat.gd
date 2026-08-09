extends Control

## Combat screen.
##
## Layout, top to bottom:
##   enemy throne | enemy boards | your boards | your throne | pool + hand | log
##
## Interaction model — click and drag both work, and neither is required:
##   - click a hand card, then click an empty slot to deploy (or a unit to evolve)
##   - or drag a hand card onto an empty slot / its base form / a unit to charge
##   - click one of your units to open its action panel (charge / queue attacks)
##   - End Turn resolves everything, then the AI takes its turn.
##
## Drag is an input method for actions that already exist, not a new rule.
## There is deliberately no drag-to-rearrange: placement *is* targeting, and
## repositioning is the printed effect of the Reposition support card.

const MENU_SCENE := "res://scenes/MainMenu.tscn"

## Preloaded rather than relying on the `class_name` global, which isn't
## registered when a headless harness runs before a filesystem scan.
const DropZoneScript := preload("res://scripts/ui/DropZone.gd")

var gs: GameState
var ai: AIPlayer

## Resolve card-choice prompts automatically instead of opening the modal picker.
## Off for real play. Headless harnesses that drive this scene through end_turn()
## set it, because end_turn() waits for the choice and there is no pointer to
## click the picker with — see _on_choice_required.
var auto_resolve_choices: bool = false

var _selected_hand: int = -1
var _selected_unit: Unit = null

## Support targeting. When a support in hand needs a target, the board goes into
## a pick mode: legal targets light up and everything else is inert.
## `_pending_two` holds the first unit of a two-unit support (Tithe, Reposition).
var _pending_support: CardData = null
var _pending_two: Unit = null

## Drag state, used only to light up legal targets while a card is in flight.
var _drag_card: CardData = null
var _dragging_basic: bool = false

## UI nodes
var _enemy_throne_lbl: Label
var _my_throne_lbl: Label
var _turn_lbl: Label
var _pool_lbl: Label
var _hint_lbl: Label
var _enemy_boards_row: HBoxContainer
var _my_boards_row: HBoxContainer
var _hand_row: HBoxContainer
var _pool_bar: ProgressBar
var _pool_bar_fill: StyleBoxFlat
var _pool_count_lbl: Label
var _pool_decay_lbl: Label

## Hover lift. Exactly one hand card is raised at a time: hovering a new card
## lowers the previous one, so the hand never ends up with two cards up.
const HOVER_LIFT := 26.0            ## pixels — "up a little", not a full popout
const HOVER_TIME := 0.09            ## seconds; short enough to feel like tracking

## The status strip under every board slot. Reserved unconditionally — see
## _wrap_with_status for why the board row's height must not depend on what is
## standing in it.
const STATUS_HEIGHT := 13
const STATUS_SEPARATION := 2

## Board cards carry the full card layout at ~7px type, which is readable enough
## to scan but not to study. Hovering one raises a scaled copy.
##
## A copy rather than scaling the board card in place: the board card lives inside
## a fixed-height slot wrapper (_wrap_with_status), and scaling it there would
## either clip against clip_contents or change the row height, which pushes the
## throne and the hand down the screen. A floating copy touches no layout at all.
const HOVER_ZOOM := 1.9
var _zoom_card: Control = null
var _zoom_layer: CanvasLayer = null
var _hovered_card: CardView = null
var _hover_tweens: Dictionary = {}  ## CardView -> Tween, so a lift can cancel a drop
var _log: RichTextLabel
var _action_panel: PanelContainer
var _action_box: VBoxContainer
var _end_turn_btn: Button
var _mulligan_btn: Button
var _overlay: Control
var _global_lock_btn: Button


func _ready() -> void:
	_build_ui()
	_start_game()


func _start_game() -> void:
	var my_deck := DeckStore.to_card_list()

	## The AI brings whichever deck was chosen on the deck select screen, or a
	## random legal one — the default. It no longer mirrors your list: a mirror
	## makes every fight a test of play rather than of decks, which is the
	## opposite of what a deckbuilder is for.
	var ai_index := DeckStore.resolve_opponent_index()

	gs = GameState.new(my_deck, DeckStore.list_at(ai_index))
	gs.deck_names = [DeckStore.active_name(), DeckStore.name_at(ai_index)]
	ai = AIPlayer.new(gs)
	gs.log_line.connect(_on_log)
	gs.state_changed.connect(_refresh)
	gs.game_over.connect(_on_game_over)
	gs.choice_required.connect(_on_choice_required)

	gs.start()

	## The AI commits its setup board immediately, without seeing yours — setup is
	## not interactive, and a side that could counter-place would be handed the whole
	## targeting geometry. It stays in setup until you finish yours, since
	## `finish_setup` only starts round 1 once both sides are ready.
	ai.take_setup(gs.players[GameState.P2])

	_refresh()


# ------------------------------------------------------------------ UI build

func _build_ui() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)

	var bg := ColorRect.new()
	bg.color = Palette.BG
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var root := HBoxContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.offset_left = 10
	root.offset_right = -10
	root.offset_top = 8
	root.offset_bottom = -8
	root.add_theme_constant_override("separation", 10)
	add_child(root)

	## ---------------- left: the battlefield
	var left := VBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	## Tight: this column stacks two board rows, two throne labels, the pool bar
	## and the hand, so separation is paid ~9 times over.
	left.add_theme_constant_override("separation", 3)
	root.add_child(left)

	## top bar
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 12)
	left.add_child(top)

	var back := Button.new()
	back.text = "← Menu"
	Palette.style_button(back)
	back.pressed.connect(func(): get_tree().change_scene_to_file(MENU_SCENE))
	top.add_child(back)

	_turn_lbl = Palette.label("", 16, Palette.ACCENT)
	top.add_child(_turn_lbl)

	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(sp)

	_hint_lbl = Palette.label("", 13, Palette.GOLD)
	top.add_child(_hint_lbl)

	## enemy throne
	_enemy_throne_lbl = Palette.label("", 15, Palette.THRONE)
	_enemy_throne_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	left.add_child(_enemy_throne_lbl)

	## enemy boards
	_enemy_boards_row = HBoxContainer.new()
	_enemy_boards_row.add_theme_constant_override("separation", 12)
	_enemy_boards_row.alignment = BoxContainer.ALIGNMENT_CENTER
	left.add_child(_enemy_boards_row)

	var divider := Palette.label("- - - - - - - - - - - - - - - - - - - - - - - - -", 12, Palette.BORDER)
	divider.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	left.add_child(divider)

	## my boards
	_my_boards_row = HBoxContainer.new()
	_my_boards_row.add_theme_constant_override("separation", 12)
	_my_boards_row.alignment = BoxContainer.ALIGNMENT_CENTER
	left.add_child(_my_boards_row)

	## my throne
	_my_throne_lbl = Palette.label("", 15, Palette.THRONE)
	_my_throne_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	left.add_child(_my_throne_lbl)

	## pool + end turn
	var poolbar := HBoxContainer.new()
	poolbar.add_theme_constant_override("separation", 12)
	poolbar.alignment = BoxContainer.ALIGNMENT_BEGIN
	left.add_child(poolbar)

	## The spacer comes first, so everything after it is pushed to the right edge:
	## deck/discard counts, then the pool meter, then the turn controls.
	var sp2 := Control.new()
	sp2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	poolbar.add_child(sp2)

	_pool_lbl = Palette.label("", 12, Palette.TEXT_DIM)
	_pool_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	poolbar.add_child(_pool_lbl)

	poolbar.add_child(_build_pool_meter())

	_global_lock_btn = Button.new()
	_global_lock_btn.toggle_mode = true
	_global_lock_btn.add_theme_font_size_override("font_size", 12)
	_global_lock_btn.pressed.connect(_on_global_lock_toggled)
	poolbar.add_child(_global_lock_btn)

	## Setup only. Hidden the moment round 1 begins — the mulligan is a decision made
	## on the opening hand alone, so it cannot outlive the phase.
	_mulligan_btn = Button.new()
	_mulligan_btn.text = "Mulligan"
	_mulligan_btn.custom_minimum_size = Vector2(110, 40)
	Palette.style_button(_mulligan_btn, Palette.PANEL, Palette.GOLD)
	_mulligan_btn.pressed.connect(_on_mulligan)
	poolbar.add_child(_mulligan_btn)

	_end_turn_btn = Button.new()
	_end_turn_btn.text = "End Turn"
	_end_turn_btn.custom_minimum_size = Vector2(140, 40)
	Palette.style_button(_end_turn_btn, Palette.ACCENT_DIM, Palette.ACCENT)
	_end_turn_btn.pressed.connect(_on_end_turn)
	poolbar.add_child(_end_turn_btn)

	## hand
	left.add_child(Palette.label("Hand", 13, Palette.TEXT_DIM))

	var hand_scroll := ScrollContainer.new()
	## Exactly the holder height from _wrap_hand_card — the lift needs its 26px,
	## but nothing needs padding on top of that.
	hand_scroll.custom_minimum_size = Vector2(0, CardView.HAND_SIZE.y + HOVER_LIFT)
	hand_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	left.add_child(hand_scroll)

	_hand_row = HBoxContainer.new()
	_hand_row.add_theme_constant_override("separation", 8)
	hand_scroll.add_child(_hand_row)

	## ---------------- right: action panel + log
	var right := VBoxContainer.new()
	right.custom_minimum_size = Vector2(320, 0)
	right.add_theme_constant_override("separation", 6)
	root.add_child(right)

	_action_panel = Palette.make_panel(Palette.PANEL, Palette.ACCENT)
	_action_panel.visible = false
	right.add_child(_action_panel)

	_action_box = VBoxContainer.new()
	_action_box.add_theme_constant_override("separation", 4)
	_action_panel.add_child(_action_box)

	right.add_child(Palette.label("Battle Log", 13, Palette.TEXT_DIM))
	var log_panel := Palette.make_panel(Palette.PANEL)
	log_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right.add_child(log_panel)

	var log_scroll := ScrollContainer.new()
	log_panel.add_child(log_scroll)

	_log = RichTextLabel.new()
	_log.bbcode_enabled = true
	_log.fit_content = true
	_log.custom_minimum_size = Vector2(290, 0)
	_log.add_theme_color_override("default_color", Palette.TEXT_DIM)
	log_scroll.add_child(_log)


## ------------------------------------------------------------- pool meter

## The energy pool as a small bar, tinted by the deck's energy colour.
##
## The pool is a single untyped integer today because Hel is the only colour in
## the game, so the tint is read off the deck's faction rather than off the pool
## itself. When multi-colour pools arrive this is the one place that has to
## change: the bar becomes one segment per colour, and everything below already
## asks Palette for the colour by faction name.
##
## The bar has no fixed maximum — the pool is persistent and unbounded. Decay
## stabilises it around `5 * (turn + 1)` (CLAUDE.md), so that value is used as
## the full-bar mark: the bar reads "ahead or behind the curve for this turn",
## which is the only thing a pool number means in isolation.
func _build_pool_meter() -> Control:
	var col: Color = _pool_color()

	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel",
		Palette.panel_style(Palette.PANEL, col.darkened(0.45)))
	panel.tooltip_text = "Your energy pool. It carries across turns but decays 20% (minimum 1) at end of turn.\nEnergy attached to a unit is safe from decay, but is lost if that unit dies."

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	panel.add_child(row)

	## The pip echoes the energy symbol used on card costs, so the bar and the
	## card frames read as the same currency.
	var pip := Label.new()
	pip.text = "⬢"
	pip.add_theme_font_size_override("font_size", 20)
	pip.add_theme_color_override("font_color", col)
	pip.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(pip)

	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 1)
	row.add_child(stack)

	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 6)
	stack.add_child(head)

	_pool_count_lbl = Palette.label("0", 18, col)
	head.add_child(_pool_count_lbl)

	_pool_decay_lbl = Palette.label("", 10, Palette.TEXT_DIM)
	_pool_decay_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	head.add_child(_pool_decay_lbl)

	_pool_bar = ProgressBar.new()
	_pool_bar.show_percentage = false
	_pool_bar.custom_minimum_size = Vector2(150, 7)

	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0, 0, 0, 0.45)
	bg.set_corner_radius_all(4)
	_pool_bar.add_theme_stylebox_override("background", bg)

	_pool_bar_fill = StyleBoxFlat.new()
	_pool_bar_fill.bg_color = col
	_pool_bar_fill.set_corner_radius_all(4)
	_pool_bar.add_theme_stylebox_override("fill", _pool_bar_fill)

	stack.add_child(_pool_bar)
	return panel


## The energy colour of the deck being played, read from whichever energy card the
## deck actually holds — so it follows the faction rather than assuming one.
## Falls back to Hel only for a deck with no energy card at all, which is illegal
## anyway; the fallback exists so the UI has a colour rather than rendering grey.
func _deck_faction() -> String:
	for cid in DeckStore.to_card_list():
		var c: CardData = CardDB.get_card(cid)
		if c != null and c.is_energy():
			return c.faction
	return "hel"


func _pool_color() -> Color:
	return Palette.faction_color(_deck_faction())


func _refresh_pool_meter(you: Player) -> void:
	if _pool_bar == null:
		return

	## The decay-stable pool for this turn, used as the bar's full mark.
	var target: int = max(1, 5 * (gs.turn + 1))
	_pool_bar.max_value = target
	_pool_bar.value = min(you.pool, target)

	_pool_count_lbl.text = str(you.pool)

	## Show what end of turn will actually take, so "spend or save" is a decision
	## made against a real number rather than a percentage the player computes.
	var loss: int = 0 if you.pool <= 0 else min(you.pool, max(1, int(floor(you.pool * 0.2))))
	_pool_decay_lbl.text = "−%d at end of turn" % loss if loss > 0 else "empty"

	## A pool past the stable point is the one worth flagging: it is being taxed
	## harder than income replaces it.
	var over: bool = you.pool > target
	_pool_bar_fill.bg_color = _pool_color().lightened(0.2) if over else _pool_color()


# ------------------------------------------------------------------ refresh

func _refresh() -> void:
	if gs == null:
		return
	## A rebuild frees the board cards, and with them the node the zoom was raised
	## for. Drop it here rather than waiting for a mouse-exit that will never come
	## from a node that no longer exists.
	_hide_zoom()
	var you: Player = gs.players[GameState.P1]
	var foe: Player = gs.players[GameState.P2]

	if gs.in_setup():
		_turn_lbl.text = "Setup — place your Basics   ·   Towers hold fire in round 1"
	else:
		## Round 1 shows "silent" rather than "Tower damage 0", because a 0 reads as a
		## bug where the real rule is a deliberate grace round.
		var td := gs.tower_damage()
		_turn_lbl.text = "Round %d — %s   ·   %s" % [
			gs.turn, gs.players[gs.active].display_name,
			"Towers silent" if td <= 0 else "Tower damage %d" % td
		]
	_enemy_throne_lbl.text = "ENEMY THRONE   %d / %d" % [max(0, foe.throne_hp), foe.throne_max_hp]
	_my_throne_lbl.text = "YOUR THRONE   %d / %d" % [max(0, you.throne_hp), you.throne_max_hp]
	_pool_lbl.text = "Deck %d   ·   Discard %d   ·   Hand %d/%d" % [
		you.deck.size(), you.discard.size(), you.hand.size(), Player.MAX_HAND
	]
	_refresh_pool_meter(you)
	_refresh_global_lock(you)

	if gs.in_setup():
		if you.mulligan_used:
			_hint_lbl.text = "Place Basics on your empty slots, then press Ready."
		else:
			_hint_lbl.text = "Place Basics, or Mulligan for a fresh hand. Then press Ready."
	elif _pending_support != null:
		if _pending_two != null:
			_hint_lbl.text = "%s — now pick the second unit.  (Esc cancels)" % _pending_support.name
		else:
			_hint_lbl.text = "%s — pick a target.  (Esc cancels)" % _pending_support.name
	elif _drag_card != null:
		if _drag_card.is_unit():
			_hint_lbl.text = "Drop on an empty slot to deploy, or on its base form to evolve."
		else:
			_hint_lbl.text = "Drop on a unit to charge it, or release to add to pool."
	elif _selected_hand >= 0:
		_hint_lbl.text = "Click a slot to deploy, or a unit to evolve.  (Esc cancels)"
	elif _selected_unit != null:
		_hint_lbl.text = "Choose an action for %s." % _selected_unit.card.name
	else:
		_hint_lbl.text = "Click or drag a card from hand. Drag energy onto a unit to charge it."

	_rebuild_boards(_enemy_boards_row, foe, true)
	_rebuild_boards(_my_boards_row, you, false)
	_rebuild_hand(you)
	_rebuild_action_panel(you)

	## The mulligan lives only in setup, and only until it is spent.
	_mulligan_btn.visible = gs.in_setup() and not you.mulligan_used
	_mulligan_btn.disabled = not gs.in_setup() or you.mulligan_used

	if gs.in_setup():
		_end_turn_btn.text = "Ready"
		_end_turn_btn.disabled = false
	else:
		_end_turn_btn.text = "End Turn"
		_end_turn_btn.disabled = gs.finished or gs.active != GameState.P1


func _rebuild_boards(row: HBoxContainer, p: Player, is_enemy: bool) -> void:
	for c in row.get_children():
		c.queue_free()

	for bi in p.boards.size():
		var b: Board = p.boards[bi]
		var panel := Palette.make_panel(Palette.PANEL)
		row.add_child(panel)

		var lane := HBoxContainer.new()
		lane.add_theme_constant_override("separation", 4)
		panel.add_child(lane)

		## Enemy lanes read right-to-left so slot 0 sits across from your slot 0.
		var order: Array = range(Board.SLOT_COUNT)
		for si in order:
			lane.add_child(_slot_widget(p, b, bi, si, is_enemy))


## The card currently selected in hand, or null. Bounds-safe: the hand shrinks
## underneath us when a card is played, so never index it blindly.
func _selected_card() -> CardData:
	if _selected_hand < 0:
		return null
	var h: Array = gs.players[GameState.P1].hand
	if _selected_hand >= h.size():
		return null
	return CardDB.get_card(h[_selected_hand])


func _slot_widget(p: Player, b: Board, bi: int, si: int, is_enemy: bool) -> Control:
	## Tower slot, tower alive
	if si == Board.TOWER_SLOT and b.tower_alive():
		return _wrap_with_status(_tower_widget(b, bi, is_enemy), null)

	var u: Unit = b.unit_at(si)

	## Empty slot
	if u == null:
		## Click-to-deploy needs a card already selected; drag-to-deploy only
		## needs the slot to be legal, since the card arrives with the drop.
		var droppable := (not is_enemy) and b.is_slot_playable(si)
		## During a support pick the board belongs to the support: an empty slot
		## is never a target, so don't offer to deploy into it.
		var playable := droppable and _selected_hand >= 0 and _pending_support == null
		var e: Button = DropZoneScript.new()
		e.custom_minimum_size = CardView.BOARD_SIZE
		e.text = "+ deploy" if playable else ("drop here" if _dragging_basic else "empty")
		e.add_theme_font_size_override("font_size", 12)
		Palette.style_button(e, Palette.PANEL_LIGHT.darkened(0.45),
			Palette.ACCENT if (playable or (droppable and _dragging_basic)) else Palette.BORDER)
		e.disabled = not playable
		e.mouse_filter = Control.MOUSE_FILTER_PASS
		if playable:
			e.pressed.connect(func(): _deploy_to(bi, si))
		## A Basic dropped on an empty, legal slot deploys there.
		if droppable:
			e.set("can_drop", func(data): return _is_basic_payload(data))
			e.set("on_drop", func(data): _deploy_from_drag(data, bi, si))
		return _wrap_with_status(e, null)

	## Occupied slot — render the full card
	var view := CardView.new(u.card, u, CardView.Mode.BOARD)
	view.selected = (u == _selected_unit or u == _pending_two)
	view.enemy = is_enemy
	## Board type is small by design; hovering raises a readable copy.
	view.hover_changed.connect(func(on: bool):
		if on:
			_show_zoom(view)
		else:
			_hide_zoom())

	## Support targeting takes over the board: only legal targets respond.
	if _pending_support != null:
		if _is_legal_support_target(u):
			view.highlight = Palette.GOLD
			view.pressed.connect(func(): _pick_support_target(u))
		else:
			view.dimmed = true
		return _wrap_with_status(view, u)

	if is_enemy:
		pass                                     ## enemy units are display-only
	elif _selected_hand >= 0:
		var c := _selected_card()
		if c != null and c.is_unit() and c.evolves_from == u.card.id:
			view.highlight = Palette.ACCENT      ## valid evolution target
			view.pressed.connect(func(): _evolve_into(u))
		else:
			view.dimmed = true
	else:
		view.pressed.connect(func(): _select_unit(u))

	## Your units accept a dragged evolution, and a dragged energy card charges
	## them. Both are live regardless of the click selection.
	if not is_enemy:
		if _dragging_evolution_for(u):
			view.highlight = Palette.ACCENT
		view.can_drop = func(data): return _can_drop_on_unit(data, u)
		view.on_drop = func(data): _drop_on_unit(data, u)

	return _wrap_with_status(view, u)


## Raise a scaled copy of a board card near its slot.
func _show_zoom(view: CardView) -> void:
	_hide_zoom()
	if view == null or view.card == null:
		return

	if _zoom_layer == null:
		_zoom_layer = CanvasLayer.new()
		_zoom_layer.layer = 50
		add_child(_zoom_layer)

	## The copy is built in HAND mode: the enlarged card is being *read*, and the
	## hand metrics are the ones authored for reading. Scaling the board metrics
	## would just magnify type that was sized to be small.
	var big := CardView.new(view.card, view.unit, CardView.Mode.HAND)
	big.enemy = view.enemy
	big.scale = Vector2(HOVER_ZOOM, HOVER_ZOOM)
	big.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var holder := Control.new()
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(big)

	## Position beside the hovered slot, then clamp into the viewport so a card at
	## the screen edge is not half off it.
	var slot_rect: Rect2 = view.get_global_rect()
	var big_size: Vector2 = CardView.HAND_SIZE * HOVER_ZOOM
	var vp: Vector2 = get_viewport_rect().size

	var pos := Vector2(
		slot_rect.position.x + slot_rect.size.x + 8,
		slot_rect.position.y + slot_rect.size.y * 0.5 - big_size.y * 0.5)
	## Flip to the left of the slot when there is no room on the right.
	if pos.x + big_size.x > vp.x - 8:
		pos.x = slot_rect.position.x - big_size.x - 8
	pos.x = clamp(pos.x, 8.0, max(8.0, vp.x - big_size.x - 8.0))
	pos.y = clamp(pos.y, 8.0, max(8.0, vp.y - big_size.y - 8.0))
	holder.position = pos

	_zoom_layer.add_child(holder)
	_zoom_card = holder


func _hide_zoom() -> void:
	if _zoom_card != null:
		_zoom_card.queue_free()
		_zoom_card = null


## Status badges live under the frame so they never overflow it.
##
## The strip's height is reserved whether or not a badge is showing, and every
## slot goes through this wrapper — empty slots and towers included. Otherwise
## the board row is one height while the lane is empty and a taller one the
## moment a unit lands in it, and that difference pushes the throne, the pool
## bar and the whole hand down the screen. Same reasoning as the hand's hover
## panel in CardView: nothing on the board may change the row's height.
func _wrap_with_status(view: Control, u: Unit) -> Control:
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", STATUS_SEPARATION)
	col.add_child(view)

	var status := "" if u == null else _unit_status(u, view is CardView and (view as CardView).enemy)
	var lbl := Palette.label(status, 9, Palette.GOLD)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.custom_minimum_size = Vector2(0, STATUS_HEIGHT)
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(lbl)
	return col


func _tower_widget(b: Board, bi: int, is_enemy: bool) -> Control:
	## A tower is a legal click target for tower support (yours) and for
	## Toppling Blow (theirs).
	var targetable := _tower_is_target(b, bi, is_enemy)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = CardView.BOARD_SIZE

	var s := StyleBoxFlat.new()
	s.bg_color = Palette.TOWER.darkened(0.62)
	s.border_color = Palette.GOLD if targetable else Palette.TOWER
	s.set_border_width_all(3 if targetable else 2)
	s.set_corner_radius_all(8)
	s.content_margin_left = 7
	s.content_margin_right = 7
	s.content_margin_top = 6
	s.content_margin_bottom = 6
	panel.add_theme_stylebox_override("panel", s)

	var col := VBoxContainer.new()
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", 6)
	panel.add_child(col)

	var title := Palette.label("TOWER", 14, Palette.TEXT)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(title)

	var hp := Palette.label("%d / %d" % [b.tower_hp, b.tower_max_hp], 16,
		Palette.hp_color(b.tower_hp, b.tower_max_hp))
	hp.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(hp)

	var bar := ProgressBar.new()
	bar.max_value = max(1, b.tower_max_hp)
	bar.value = b.tower_hp
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(0, 6)
	col.add_child(bar)

	## The board this tower shoots at belongs to the *other* player. If nothing is
	## alive there the shot chips structures at a quarter, so say so rather than
	## printing a full number the tower will not deal.
	var full: int = gs.tower_damage() + b.tower_damage_bonus
	var facing: Board = gs.players[GameState.P1 if is_enemy else GameState.P2].boards[bi]
	var dmg_text := "fires for %d" % full
	if not facing.has_living_unit():
		dmg_text = "chips for %d" % max(1, full / 4)
	var dmg := Palette.label(dmg_text, 10, Palette.TEXT_DIM)
	dmg.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(dmg)

	## Every permanent modification this tower carries. They stack without limit,
	## so repeats are collapsed into "⚒ Name ×2" rather than repeating the row —
	## the frame is short and a fortified tower can hold several.
	var seen: Array[String] = []
	var counts := {}
	for m in b.tower_mods:
		if m == null:
			continue
		if not counts.has(m.name):
			seen.append(m.name)
		counts[m.name] = int(counts.get(m.name, 0)) + 1
	for nm in seen:
		var n: int = counts[nm]
		var mod := Palette.label("⚒ %s%s" % [nm, ("" if n == 1 else " ×%d" % n)], 9, Palette.ACCENT)
		mod.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		mod.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		col.add_child(mod)

	if not targetable:
		return panel

	## An invisible button over the frame makes the tower clickable without
	## disturbing the layout, the same trick CardView uses.
	var btn := Button.new()
	btn.flat = true
	btn.set_anchors_preset(Control.PRESET_FULL_RECT)
	btn.tooltip_text = "Target this tower with %s" % _pending_support.name
	btn.pressed.connect(func(): _pick_tower_target(bi))
	panel.add_child(btn)

	return panel


## Tower support targets a tower you control; Toppling Blow targets theirs.
func _tower_is_target(b: Board, bi: int, is_enemy: bool) -> bool:
	if _pending_support == null or not b.tower_alive():
		return false
	if _pending_support.is_tower_support():
		return not is_enemy and gs.can_play_support(gs.players[GameState.P1], _pending_support, bi)
	if _pending_support.has_effect("damage_tower"):
		return is_enemy
	return false


## `is_enemy` gates the padlock: the lock is your setting, so showing it on the
## opponent's units would be reading their board against your toggle.
func _unit_status(u: Unit, is_enemy: bool = false) -> String:
	var bits: Array[String] = []
	if u.attached > 0:
		bits.append("⬢ %d" % u.attached)
	if u.dies_at_eot:
		bits.append("☠ EOT")
	## A padlock on the frame is how you see at a glance which units will fire
	## again next turn without opening each one's action panel.
	if not is_enemy and u.last_attack != null \
			and u.is_attack_locked(gs.players[GameState.P1].auto_lock_attacks):
		bits.append("🔒")
	return "   ".join(bits)


func _rebuild_hand(p: Player) -> void:
	## The hand is rebuilt wholesale on every state change, so the raised card is
	## a dead reference from here on — drop it rather than tweening a freed node.
	_hovered_card = null
	_hover_tweens.clear()
	for c in _hand_row.get_children():
		c.queue_free()

	for i in p.hand.size():
		var card: CardData = CardDB.get_card(p.hand[i])
		if card == null:
			continue

		## In setup only Basics are playable, and nothing else in hand should look
		## live. Outside setup this is the ordinary my-turn check.
		var my_turn := _my_turn() or gs.in_setup()
		var playable: bool
		if gs.in_setup():
			playable = _can_deploy() and card.is_unit() \
				and card.stage == CardData.Stage.BASIC
		else:
			playable = my_turn and _hand_card_playable(p, card)

		var view := CardView.new(card, null, CardView.Mode.HAND)
		view.selected = (i == _selected_hand)
		view.dimmed = not playable

		if my_turn and not playable:
			view.tooltip_text = "Only Basic units may be placed during setup." \
				if gs.in_setup() else _why_unplayable(p, card)

		var idx := i
		if playable:
			view.pressed.connect(func(): _on_hand_pressed(idx, card))
			## Only cards that can actually be played are draggable, so a drag
			## can never start a move the rules would reject on drop. Supports
			## other than Tools are click-only — see _can_drop_on_unit.
			if not (card.is_support_like() and not card.is_tool()):
				view.drag_payload = {
					"kind": "hand_card", "hand_index": idx, "card_id": card.id,
				}
				view.drag_started.connect(func(): _on_drag_started(idx, card))

		## The card's own words, revealed by hovering rather than by a tooltip that
		## has to be waited for.
		view.hover_text = _hand_hover_text(p, card)

		_hand_row.add_child(_wrap_hand_card(view))


## Hand cards live inside a fixed-size holder so the raised card can move without
## the HBoxContainer immediately laying it back down. The holder keeps the slot;
## the CardView inside it is what actually lifts.
func _wrap_hand_card(view: CardView) -> Control:
	var holder := Control.new()
	## Room above the card for the lift, so raising it can't clip at the top.
	holder.custom_minimum_size = CardView.HAND_SIZE + Vector2(0, HOVER_LIFT)
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE

	## Anchored to the bottom of the holder: the card sits low and travels up.
	view.position = Vector2(0, HOVER_LIFT)
	view.size = CardView.HAND_SIZE
	holder.add_child(view)

	view.hover_changed.connect(func(on: bool): _on_card_hover(view, on))
	return holder


## Raise the hovered card and lower whichever card was up before it, so moving
## along the hand hands the lift from one card to the next.
func _on_card_hover(view: CardView, hovering: bool) -> void:
	if hovering:
		if _hovered_card == view:
			return
		if _hovered_card != null and is_instance_valid(_hovered_card):
			_set_card_raised(_hovered_card, false)
		_hovered_card = view
		_set_card_raised(view, true)
	elif _hovered_card == view:
		_hovered_card = null
		_set_card_raised(view, false)


func _set_card_raised(view: CardView, up: bool) -> void:
	if not is_instance_valid(view):
		return

	## One tween per card: a fast sweep across the hand would otherwise stack
	## competing tweens on the same card and leave it stranded mid-lift.
	var prev = _hover_tweens.get(view)
	if prev != null and is_instance_valid(prev) and prev.is_running():
		prev.kill()

	view.set_hover_open(up)
	## Raised cards draw over their neighbours — without this the lifted card
	## slides *behind* the next card in the row.
	view.z_index = 1 if up else 0

	var tw := create_tween()
	tw.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(view, "position:y", 0.0 if up else HOVER_LIFT, HOVER_TIME)
	_hover_tweens[view] = tw


## What a card says when you hover it in hand. This is the card's rules text
## first — the thing the player is actually asking for — with the timing note
## that only matters while it is in hand appended.
func _hand_hover_text(p: Player, card: CardData) -> String:
	if p.is_locked(card.id):
		return "Returned to hand this turn.\nPlayable again next turn."

	if card.is_energy():
		return "Adds %d energy to your pool if played now.\nOne energy card per turn." % (gs.turn + 1)

	if card.is_support_like():
		var note := "Free to play, any number per turn."
		if card.is_tool():
			note = "Attaches to a unit. One Tool per unit.\nDiscarded if that unit dies or retreats."
		elif card.is_tower_support():
			note = "Names a tower you control.\nLost if that tower dies." if card.permanent \
				else "Names a tower you control. One-shot."
		return "%s\n\n%s" % [card.text, note] if card.text != "" else note

	## Units: the printed ability line, then how this card enters play.
	var bits: Array[String] = []
	var kws := card.keyword_line()
	if kws != "":
		bits.append(kws)
	for atk in card.attacks:
		if atk.text != "":
			bits.append("%s — %s" % [atk.name, atk.text])
	if card.evolves_from != "":
		var base: CardData = CardDB.get_card(card.evolves_from)
		if base != null:
			bits.append("Evolves from %s." % base.name)
	return "\n".join(bits)


## Tells the player *why* a card is greyed out, rather than leaving them guessing.
func _why_unplayable(p: Player, card: CardData) -> String:
	if p.is_locked(card.id):
		return "Returned to hand this turn — playable again next turn."
	if card.is_tool():
		return "No unit without a Tool to attach this to."
	if card.is_tower_support():
		return "Needs one of your towers alive, and a free modification slot if permanent."
	if card.is_support_like():
		return "Nothing on the board this card can legally target right now."
	if card.is_energy():
		return "You have already played an energy card this turn."
	if card.stage == CardData.Stage.BASIC:
		return "No empty slot — every usable slot on both boards is full."
	var base: CardData = CardDB.get_card(card.evolves_from)
	var base_name: String = base.name if base != null else "its base form"
	return "Needs a %s on the board to evolve from." % base_name


func _hand_card_playable(p: Player, card: CardData) -> bool:
	## A card returned by retreat this turn is locked until next turn.
	if p.is_locked(card.id):
		return false
	if card.is_support_like():
		return gs.support_has_any_target(p, card)
	if card.is_energy():
		return not p.energy_played_this_turn
	if card.stage == CardData.Stage.BASIC:
		return p.empty_slots_total() > 0
	## Non-basic: need a matching unit on board to evolve
	for u in p.all_units():
		if u.card.id == card.evolves_from:
			return true
	return false


## The global autolock. Flipping it changes the behaviour of every unit still on
## LOCK_DEFAULT and deliberately leaves individually-set units alone — a unit you
## explicitly unlocked stays unlocked when you turn the global lock on, which is
## the entire reason the per-unit state is tri-state.
func _on_global_lock_toggled() -> void:
	var p: Player = gs.players[GameState.P1]
	p.auto_lock_attacks = _global_lock_btn.button_pressed
	_refresh()


func _refresh_global_lock(p: Player) -> void:
	if _global_lock_btn == null:
		return

	var on := p.auto_lock_attacks
	_global_lock_btn.button_pressed = on
	_global_lock_btn.text = "🔒 Autolock: ON" if on else "🔓 Autolock: OFF"
	Palette.style_button(_global_lock_btn, Palette.PANEL_LIGHT,
		Palette.GOLD if on else Palette.BORDER)

	## Count the units that have opted out, so the button can admit that "ON"
	## doesn't necessarily mean everything is firing.
	var overrides := 0
	for unit_any in p.all_units():
		var u: Unit = unit_any
		if u.lock_mode != Unit.LOCK_DEFAULT:
			overrides += 1

	var tip := "When ON, every unit automatically re-queues the attack it used last turn, at the start of your turn, if you can afford it.\n\nAbilities are never auto-used — they resolve immediately and some destroy attached energy, so they stay manual.\n\nIndividual units can be locked or unlocked on their own; those choices override this setting."
	if overrides > 0:
		tip += "\n\n%d unit(s) currently override this setting." % overrides
	_global_lock_btn.tooltip_text = tip


## The per-unit lock toggle, shown under each attack.
##
## The toggle is per *unit*, not per attack line — the lock re-fires "whatever
## this unit attacked with last turn", so a unit with two attacks has one lock
## that follows whichever it last used. The row is drawn under each attack so the
## control is where the player is looking when they decide.
func _lock_toggle_row(u: Unit, atk: AttackData) -> Control:
	var p: Player = gs.players[GameState.P1]
	var locked := u.is_attack_locked(p.auto_lock_attacks)
	var is_last := u.last_attack == atk

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)

	var b := Button.new()
	b.toggle_mode = true
	b.button_pressed = locked
	b.add_theme_font_size_override("font_size", 11)
	b.text = "🔒 Locked" if locked else "🔓 Unlocked"
	Palette.style_button(b, Palette.PANEL_LIGHT,
		Palette.GOLD if locked else Palette.BORDER)

	## Say which of the three states this unit is actually in, since "locked"
	## can mean either "following the global setting" or "overridden here".
	var origin := ""
	match u.lock_mode:
		Unit.LOCK_ON: origin = "locked for this unit specifically"
		Unit.LOCK_OFF: origin = "unlocked for this unit specifically"
		_: origin = "following the global setting (%s)" % ("on" if p.auto_lock_attacks else "off")

	b.tooltip_text = "%s.\n\nWhen locked, %s automatically re-queues the attack it used last turn at the start of your turn, if you can afford it. Click to change just this unit." % [
		origin.capitalize(), u.card.name
	]
	b.pressed.connect(func():
		u.cycle_lock(p.auto_lock_attacks)
		_refresh()
	)
	row.add_child(b)

	## Which attack the lock would actually re-fire. Without this the toggle is
	## ambiguous on a two-attack unit.
	var note := ""
	if u.last_attack == null:
		note = "nothing recorded yet"
	elif is_last:
		note = "will re-fire this" if locked else "last used"
	else:
		note = "re-fires %s" % u.last_attack.name if locked else ""
	if note != "":
		var l := Palette.label(note, 10, Palette.GOLD if (locked and is_last) else Palette.TEXT_DIM)
		l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		row.add_child(l)

	return row


## Queue an attack and redraw. Queueing is all that's needed to arm the lock:
## queue_attack records the choice as the unit's `last_attack`, and whether it
## re-fires is decided by the toggles, not by how it was queued.
func _queue_and_maybe_lock(p: Player, u: Unit, atk: AttackData) -> void:
	gs.queue_attack(p, u, atk)
	_refresh()


## One activated ability. Abilities are free and resolve on the spot, so the
## button says plainly what it costs (nothing, or a Consume) and why it is
## unavailable when it is — spent this turn, or short on attached energy to burn.
func _ability_button(p: Player, u: Unit, ab: AttackData) -> Button:
	var b := Button.new()
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.add_theme_font_size_override("font_size", 12)

	var used := u.has_used_ability(ab)
	var can := u.can_use_ability(ab)

	var state := ""
	if used:
		state = "already used this turn"
	elif ab.consume > 0 and u.attached < ab.consume:
		state = "needs %d attached to consume — has %d" % [ab.consume, u.attached]
	elif ab.consume > 0:
		state = "destroys %d attached energy" % ab.consume
	else:
		state = "free — resolves immediately"

	b.text = "◆ %s — %s\n%s\n%s" % [ab.name, ab.cost_string(), ab.text, state]
	Palette.style_button(b, Palette.PANEL_LIGHT,
		Palette.ACCENT if can else Palette.BORDER)
	b.disabled = not can

	b.tooltip_text = "An ability, not an attack: it resolves the moment you use it rather than at end of turn, and never costs pool energy. Once per turn per unit."
	if ab.consume > 0:
		b.tooltip_text += "\n\nConsume %d destroys %d of this unit's attached energy — that investment is gone, not returned to the pool." % [ab.consume, ab.consume]

	b.pressed.connect(func():
		gs.use_ability(p, u, ab)
		_refresh()
	)
	return b


func _rebuild_action_panel(p: Player) -> void:
	for c in _action_box.get_children():
		c.queue_free()

	if _selected_unit == null or not _selected_unit.is_alive():
		_action_panel.visible = false
		return
	_action_panel.visible = true

	var u: Unit = _selected_unit
	_action_box.add_child(Palette.label(u.card.name, 16, Palette.TEXT))
	_action_box.add_child(Palette.label("%d / %d HP   ·   ⬢ %d attached" % [u.hp, u.max_hp(), u.attached], 13, Palette.GOLD))

	var kws := u.card.keyword_line()
	if kws != "":
		_action_box.add_child(Palette.label(kws, 12, Palette.ACCENT))

	## Charge buttons
	_action_box.add_child(Palette.label("Charge from pool (free)", 12, Palette.TEXT_DIM))
	var charge_row := HBoxContainer.new()
	charge_row.add_theme_constant_override("separation", 4)
	_action_box.add_child(charge_row)
	for n in [1, 3, 5]:
		var cb := Button.new()
		cb.text = "+%d" % n
		Palette.style_button(cb)
		cb.disabled = p.pool < n
		cb.pressed.connect(func(): gs.charge(p, u, n))
		charge_row.add_child(cb)
	var call_btn := Button.new()
	call_btn.text = "All (%d)" % p.pool
	Palette.style_button(call_btn)
	call_btn.disabled = p.pool <= 0
	call_btn.pressed.connect(func(): gs.charge(p, u, p.pool))
	charge_row.add_child(call_btn)

	## Abilities — resolve immediately, once per turn, and never cost pool energy.
	var abilities := u.card.ability_lines()
	if not abilities.is_empty():
		_action_box.add_child(Palette.label("Abilities  ·  free, once per turn", 12, Palette.TEXT_DIM))
		for ab in abilities:
			_action_box.add_child(_ability_button(p, u, ab))

	## Attacks — queued now, resolved at end of turn.
	var attack_lines := u.card.attack_lines()
	if not attack_lines.is_empty():
		_action_box.add_child(Palette.label("Attacks  ·  resolve at end of turn", 12, Palette.TEXT_DIM))
	for atk in attack_lines:
		var need := u.pool_needed(atk)
		var b := Button.new()
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.add_theme_font_size_override("font_size", 12)
		b.text = "%s — %s\n%s\n%s" % [
			atk.name, atk.cost_string(), atk.text,
			("ready (free)" if need == 0 else "needs %d more from pool" % need)
		]
		var affordable := need <= p.pool
		Palette.style_button(b, Palette.PANEL_LIGHT, Palette.GOLD if affordable else Palette.BORDER)
		b.disabled = not affordable or u.queued_attack != null
		b.pressed.connect(func(): _queue_and_maybe_lock(p, u, atk))
		_action_box.add_child(b)

		## Per-card lock toggle, sitting directly under the attack it locks.
		_action_box.add_child(_lock_toggle_row(u, atk))

	## Retreat: paid from the unit's own attached energy, never the pool.

	var cost := u.retreat_cost()
	var rb := Button.new()
	rb.text = "Retreat  (%d attached)" % cost
	Palette.style_button(rb, Palette.PANEL_LIGHT, Palette.TOWER)
	rb.disabled = not u.can_retreat()
	if u.can_retreat():
		rb.tooltip_text = "Returns %s to hand, healed and locked until next turn. %d leftover energy goes back to your pool. The slot stays empty." % [
			u.card.name, u.attached - cost
		]
	else:
		rb.tooltip_text = "Needs %d attached energy to retreat — this unit has %d. Retreat cannot be paid from the pool." % [cost, u.attached]
	rb.pressed.connect(func():
		_selected_unit = null
		gs.retreat(p, u)
		_refresh()
	)
	_action_box.add_child(rb)

	if u.tool != null:
		_action_box.add_child(Palette.label("⚒ %s — %s" % [u.tool.name, u.tool.text], 10, Palette.TOWER))

	if u.queued_attack != null:
		var cancel := Button.new()
		cancel.text = "Cancel %s" % u.queued_attack.name
		Palette.style_button(cancel, Palette.PANEL_LIGHT, Palette.DANGER)
		cancel.tooltip_text = "Energy already paid stays attached."
		cancel.pressed.connect(func(): gs.cancel_attack(u))
		_action_box.add_child(cancel)

	var close := Button.new()
	close.text = "Close"
	Palette.style_button(close)
	close.pressed.connect(func():
		_selected_unit = null
		_refresh()
	)
	_action_box.add_child(close)


# ------------------------------------------------------------------ actions

func _on_hand_pressed(i: int, card: CardData) -> void:
	_selected_unit = null
	_pending_two = null

	## Energy resolves immediately — no target needed. Clear the selection
	## before playing, since the hand shifts underneath us.
	if card.is_energy():
		_selected_hand = -1
		_pending_support = null
		gs.play_energy(gs.players[GameState.P1], i)
		_refresh()
		return

	if card.is_support_like():
		_on_support_pressed(i, card)
		return

	_pending_support = null
	_selected_hand = -1 if _selected_hand == i else i
	_refresh()


## A support either resolves at once (no target) or puts the board into pick
## mode. Clicking the same card again cancels.
func _on_support_pressed(i: int, card: CardData) -> void:
	var p: Player = gs.players[GameState.P1]

	if _selected_hand == i:
		_selected_hand = -1
		_pending_support = null
		_refresh()
		return

	if not _support_needs_pick(card):
		_selected_hand = -1
		_pending_support = null
		gs.play_support(p, i, null)
		_refresh()
		return

	_selected_hand = i
	_pending_support = card
	_refresh()


## True when the player must click something on the board to resolve this card.
func _support_needs_pick(card: CardData) -> bool:
	if card.is_tool() or card.is_tower_support():
		return true
	if card.has_effect("damage_tower"):
		return true                      ## Toppling Blow picks which enemy tower
	return gs._support_needs_target(card)


## Two-unit supports (Tithe, Reposition) need a second pick; the first unit is
## held in _pending_two and excluded from the legal set.
func _is_two_unit_support(card: CardData) -> bool:
	for op in GameState.TWO_UNIT_OPS:
		if card.has_effect(op):
			return true
	return false


func _is_legal_support_target(u: Unit) -> bool:
	if _pending_support == null or not u.is_alive():
		return false
	var p: Player = gs.players[GameState.P1]

	if _pending_support.is_tool():
		return gs._tool_candidates(p, _pending_support).has(u)

	if _is_two_unit_support(_pending_support):
		if _pending_two == null:
			return p.all_units().has(u)
		return u != _pending_two and p.all_units().has(u)

	return gs._support_unit_candidates(p, _pending_support).has(u)


func _pick_support_target(u: Unit) -> void:
	if _pending_support == null or _selected_hand < 0:
		return
	var p: Player = gs.players[GameState.P1]

	## Two-unit supports collect the first pick, then resolve on the second.
	if _is_two_unit_support(_pending_support):
		if _pending_two == null:
			_pending_two = u
			_refresh()
			return
		var pair := [_pending_two, u]
		var idx := _selected_hand
		_clear_support_pick()
		gs.play_support(p, idx, pair)
		_refresh()
		return

	var i := _selected_hand
	_clear_support_pick()
	gs.play_support(p, i, u)
	_refresh()


## Tower support names one of your towers, so the tower widget is the target.
func _pick_tower_target(bi: int) -> void:
	if _pending_support == null or _selected_hand < 0:
		return
	var p: Player = gs.players[GameState.P1]
	var i := _selected_hand
	_clear_support_pick()
	gs.play_support(p, i, bi)
	_refresh()


func _clear_support_pick() -> void:
	_selected_hand = -1
	_pending_support = null
	_pending_two = null


# ------------------------------------------------------------------ drag & drop

## Lighting up targets needs to know what's in flight. Clearing the click
## selection here keeps the two input styles from fighting: a drag is its own
## complete gesture.
func _on_drag_started(i: int, card: CardData) -> void:
	_drag_card = card
	_dragging_basic = card.is_unit() and card.stage == CardData.Stage.BASIC
	_selected_hand = -1
	_selected_unit = null
	_refresh()


func _end_drag() -> void:
	_drag_card = null
	_dragging_basic = false


## The hand shifts whenever a card is played, so a payload's index is only
## trustworthy if the card still sitting there is the one we picked up.
## Falls back to the first matching id, and returns -1 if the card is gone.
func _payload_index(data: Variant) -> int:
	if typeof(data) != TYPE_DICTIONARY:
		return -1
	var d: Dictionary = data
	if d.get("kind", "") != "hand_card":
		return -1
	var want := str(d.get("card_id", ""))
	var hand: Array = gs.players[GameState.P1].hand
	var i := int(d.get("hand_index", -1))
	if i >= 0 and i < hand.size() and str(hand[i]) == want:
		return i
	return hand.find(want)


func _payload_card(data: Variant) -> CardData:
	var i := _payload_index(data)
	if i < 0:
		return null
	return CardDB.get_card(gs.players[GameState.P1].hand[i])


func _is_basic_payload(data: Variant) -> bool:
	if not _can_deploy():
		return false
	var c := _payload_card(data)
	return c != null and c.is_unit() and c.stage == CardData.Stage.BASIC


## True when the card in flight evolves from this unit — used to pre-light the
## target before the pointer reaches it.
func _dragging_evolution_for(u: Unit) -> bool:
	return _drag_card != null and _drag_card.is_unit() \
		and _drag_card.evolves_from == u.card.id


func _can_drop_on_unit(data: Variant, u: Unit) -> bool:
	if not _my_turn() or not u.is_alive():
		return false
	var c := _payload_card(data)
	if c == null:
		return false
	## A Tool dropped on a legal unit attaches to it.
	if c.is_tool():
		return gs.can_play_support(gs.players[GameState.P1], c, u)
	## Other supports are click-targeted, not dragged — they can need two picks
	## or a tower, which a single drop can't express.
	if c.is_support_like():
		return false
	## Energy dropped on a unit charges it; a matching evolution evolves it.
	if c.is_energy():
		return not gs.players[GameState.P1].energy_played_this_turn
	return c.evolves_from == u.card.id


func _drop_on_unit(data: Variant, u: Unit) -> void:
	var i := _payload_index(data)
	_end_drag()
	if i < 0 or not _my_turn():
		return
	var c := CardDB.get_card(gs.players[GameState.P1].hand[i])
	if c == null:
		return

	_selected_hand = -1
	if c.is_tool():
		gs.play_support(gs.players[GameState.P1], i, u)
	elif c.is_unit():
		gs.evolve(gs.players[GameState.P1], i, u)
	else:
		## Energy onto a unit: play it, then charge that unit with what it added.
		_play_energy_onto(i, u)
	_refresh()


func _deploy_from_drag(data: Variant, bi: int, si: int) -> void:
	var i := _payload_index(data)
	_end_drag()
	if i < 0 or not _can_deploy():
		return
	_selected_hand = -1
	_deploy_card(i, bi, si)
	_refresh()


## Dropping an energy card straight onto a unit is a shortcut for "play energy,
## then charge that unit" — two existing legal actions, not a new rule. Charging
## is free and unlimited, so the only thing this skips is a click.
func _play_energy_onto(hand_index: int, u: Unit) -> void:
	var p: Player = gs.players[GameState.P1]
	var before := p.pool
	if not gs.play_energy(p, hand_index):
		return
	var gained: int = p.pool - before
	if gained > 0 and u.is_alive():
		gs.charge(p, u, gained)


## True when the player may take ordinary main-phase actions. Deliberately FALSE during
## setup, so every interaction that isn't deploying a Basic — charging, evolving, playing
## energy or supports, queueing attacks — is blocked by the check it already had, rather
## than by a phase test added at each site. The two deploy paths opt back in explicitly
## via `_can_deploy()`.
func _my_turn() -> bool:
	return gs != null and not gs.finished and not gs.in_setup() \
		and gs.active == GameState.P1


## True when deploying a Basic is legal: an ordinary turn, or setup before Ready.
func _can_deploy() -> bool:
	if gs == null or gs.finished:
		return false
	if gs.in_setup():
		return not gs.setup_done[GameState.P1]
	return gs.active == GameState.P1


func _deploy_to(bi: int, si: int) -> void:
	if _selected_hand < 0 or not _can_deploy():
		return
	## Clear the selection first: play_unit() removes the card from hand and
	## emits state_changed, which re-renders the board mid-call.
	var idx := _selected_hand
	_selected_hand = -1
	_deploy_card(idx, bi, si)
	_refresh()


## One deploy call for both input styles. Routes through `setup_deploy` during setup so
## the phase gate lives in the engine rather than being re-derived per call site — both
## end in the same `play_unit`, so the legality rules cannot differ between phases.
func _deploy_card(hand_index: int, bi: int, si: int) -> void:
	var you: Player = gs.players[GameState.P1]
	if gs.in_setup():
		gs.setup_deploy(you, hand_index, bi, si)
	else:
		gs.play_unit(you, hand_index, bi, si)


func _evolve_into(target: Unit) -> void:
	if _selected_hand < 0:
		return
	var idx := _selected_hand
	_selected_hand = -1
	gs.evolve(gs.players[GameState.P1], idx, target)
	_refresh()


func _select_unit(u: Unit) -> void:
	_selected_hand = -1
	_selected_unit = null if _selected_unit == u else u
	_refresh()


## Setup only: shuffle the opening hand back and take a fresh one. The engine enforces
## once-per-game and the before-you-deploy timing; this only has to not offer the button
## once either is spent.
func _on_mulligan() -> void:
	if gs == null or not gs.in_setup():
		return
	_selected_hand = -1
	gs.mulligan(gs.players[GameState.P1])
	_refresh()


func _on_end_turn() -> void:
	## During setup the same button reads "Ready" and commits the board instead. The
	## AI has already placed, so this is what starts round 1.
	if gs.in_setup():
		_clear_support_pick()
		_selected_hand = -1
		_selected_unit = null
		gs.finish_setup(gs.players[GameState.P1])
		_refresh()
		return

	if gs.finished or gs.active != GameState.P1:
		return
	_clear_support_pick()
	_selected_unit = null

	gs.end_turn()
	if gs.finished:
		return

	## end_turn() may pause on the hand-limit discard prompt, which only resolves
	## once the player has picked. Wait for the turn to actually pass before
	## handing over, or the AI would act during your discard.
	while gs.active == GameState.P1 and not gs.finished:
		await get_tree().process_frame

	## AI turn, then hand control back.
	await get_tree().create_timer(0.35).timeout
	if gs.finished:
		return
	ai.take_turn()
	await get_tree().create_timer(0.35).timeout
	if gs.finished:
		return
	gs.end_turn()
	_refresh()


func _on_log(text: String) -> void:
	var color := "#8f88a3"
	if text.begins_with("==="):
		color = "#7c4dff"
	elif text.begins_with("***"):
		color = "#d9b45b"
	elif text.find("dies") >= 0 or text.find("THRONE") >= 0:
		color = "#c04d4d"
	_log.append_text("[color=%s]%s[/color]\n" % [color, text])


# ------------------------------------------------------------------ picker

## A modal list of cards for the effects that need the player to choose: deck
## search, "discard 2", and the end-of-turn hand limit. The game has no other
## equivalent, so this is deliberately generic — GameState says what to prompt
## and which ids are on offer, and calls back with the index picked.
func _on_choice_required(p, prompt: String, choices: Array, on_pick: Callable) -> void:
	if p != gs.players[GameState.P1]:
		return                          ## the AI resolves its own choices

	## end_turn() blocks until the choice resolves, so a harness that drives this
	## scene but never clicks the picker would hang the whole run. Such harnesses
	## set auto_resolve_choices and get the first option, matching what
	## GameState._choose_from already does for the AI.
	if auto_resolve_choices:
		on_pick.call(0 if not choices.is_empty() else -1)
		return

	var layer := Control.new()
	layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(layer)

	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.78)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(center)

	var panel := Palette.make_panel(Palette.PANEL, Palette.ACCENT)
	center.add_child(panel)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 8)
	panel.add_child(col)

	col.add_child(Palette.label(prompt, 18, Palette.ACCENT))

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(760, CardView.HAND_SIZE.y + 24)
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	col.add_child(scroll)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	scroll.add_child(row)

	## Guard against a double-click resolving the same choice twice: the layer
	## is freed on the first pick, but the callback must fire exactly once.
	var done := [false]
	var finish := func(idx: int) -> void:
		if done[0]:
			return
		done[0] = true
		layer.queue_free()
		on_pick.call(idx)
		_refresh()

	for i in choices.size():
		var card: CardData = CardDB.get_card(choices[i])
		if card == null:
			continue
		var view := CardView.new(card, null, CardView.Mode.HAND)
		var idx := i
		view.pressed.connect(func(): finish.call(idx))
		row.add_child(view)

	if choices.is_empty():
		col.add_child(Palette.label("Nothing to choose.", 14, Palette.TEXT_DIM))

	var skip := Button.new()
	skip.text = "Done"
	Palette.style_button(skip)
	skip.tooltip_text = "Stop choosing. Any remaining picks are skipped."
	skip.pressed.connect(func(): finish.call(-1))
	col.add_child(skip)


func _on_game_over(winner_index: int) -> void:
	_refresh()
	## Append the match to logs/battles.log for later balance analysis. Real
	## games are the readings that matter most — every number in the design docs
	## is currently an AI sample.
	preload("res://scripts/core/BattleLog.gd").record(gs, "Combat")
	_show_overlay("VICTORY" if winner_index == GameState.P1 else "DEFEAT")


func _show_overlay(text: String) -> void:
	if _overlay != null:
		return
	_overlay = Control.new()
	_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_overlay)

	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.72)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.add_child(center)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 16)
	center.add_child(col)

	var t := Palette.label(text, 64, Palette.GOLD if text == "VICTORY" else Palette.DANGER)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(t)

	var again := Button.new()
	again.text = "Play Again"
	again.custom_minimum_size = Vector2(200, 44)
	Palette.style_button(again, Palette.ACCENT_DIM, Palette.ACCENT)
	again.pressed.connect(func(): get_tree().reload_current_scene())
	col.add_child(again)

	var menu := Button.new()
	menu.text = "Main Menu"
	menu.custom_minimum_size = Vector2(200, 44)
	Palette.style_button(menu)
	menu.pressed.connect(func(): get_tree().change_scene_to_file(MENU_SCENE))
	col.add_child(menu)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		_clear_support_pick()
		_selected_unit = null
		_refresh()


## A drag dropped on empty space never reaches a target, so clear the in-flight
## highlights here rather than leaving the board lit up.
func _notification(what: int) -> void:
	if what == NOTIFICATION_DRAG_END and _drag_card != null:
		_end_drag()
		_refresh()
