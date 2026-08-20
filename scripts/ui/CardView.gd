class_name CardView
extends PanelContainer

## A card frame, used by both the hand and the board so a card reads as the same
## object in either place.
##
## Layout, top to bottom:
##   name
##   HP + typing (stage / faction)
##   art box (placeholder: initials on a tinted, bordered frame)
##   abilities (keyword line)
##   attacks (name + damage)
##   energy pips (attack costs; filled by attached energy when in play)

enum Mode { HAND, BOARD }

const HAND_SIZE := Vector2(168, 262)
## Board cards are deliberately smaller than hand cards: two board rows stack in
## the same column as the hand, so every pixel here costs two below. Kept large
## enough that the name, HP and keyword lines stay readable at a glance.
const BOARD_SIZE := Vector2(132, 196)

## Phone sizes.
##
## These are not a style choice, they are arithmetic. A board row is two boards
## of three slots — six cards — side by side, and the mobile viewport is 540
## design units wide. At the desktop BOARD_SIZE of 132 that row alone needs
## `6 x 132 + separations` = ~850 units, which is why the first cut of mobile
## mode was "zoomed in and cut off": the container was told to be narrower and
## the cards inside it were not, so everything past the second card fell off the
## edge. 78 x 116 is what actually fits: `6 x 78 + 5 x 4 + 2 x 10` = 508.
##
## The hand keeps a larger card because the hand row *scrolls* horizontally —
## it is the one row that may exceed the viewport — and the hand is where cards
## are read before being played, so it is the wrong place to economise.
const BOARD_SIZE_MOBILE := Vector2(78, 116)
const HAND_SIZE_MOBILE := Vector2(112, 175)


## The card size for a mode, honouring the current layout.
##
## Static-ish helper rather than a constant because the answer depends on
## ViewportFit, and every call site that positions or reserves space for a card
## has to get the same answer — a mix of the two is what produces a row that is
## almost right and clips one card.
static func size_for(m: int) -> Vector2:
	var phone: bool = Engine.get_main_loop() != null \
		and Engine.get_main_loop().root.has_node("ViewportFit") \
		and Engine.get_main_loop().root.get_node("ViewportFit").mobile
	if m == Mode.HAND:
		return HAND_SIZE_MOBILE if phone else HAND_SIZE
	return BOARD_SIZE_MOBILE if phone else BOARD_SIZE

## Every font size and box height on the card, keyed by metric name, for each
## mode. One layout is built at both sizes (CLAUDE.md decision log), so the only
## thing that varies between hand and board is what comes out of this table.
##
## The desktop board numbers are deliberately small — the full Pokémon-style
## structure does not get to drop rows just because the frame is 132px wide,
## because a card that reads differently in two places is the drift this renderer
## exists to prevent. Board legibility is answered by hover-to-enlarge
## (Combat.gd), not by a second layout.
##
## The phone board card is the one place that rule bends, and only because 78
## units admits no font size at which the full frame is readable. See `_is_micro`.
##
## `board_m` and `hand_m` are the phone columns. They are *not* the desktop
## numbers scaled down: a 78-unit card cannot carry the full frame at all, so the
## phone board card drops to the three things a board read is actually made from
## — name, HP, and whether a charge is held (see `_is_micro`). The type that
## survives is therefore printed *larger* relative to the card than on desktop,
## because there is far less of it competing for the space.
const METRICS := {
	"title_size":         { "hand": 12, "board": 9,  "hand_m": 10, "board_m": 8 },
	"stage_size":         { "hand": 8,  "board": 7,  "hand_m": 7,  "board_m": 6 },
	"hp_size":            { "hand": 15, "board": 11, "hand_m": 12, "board_m": 11 },
	"evolve_size":        { "hand": 8,  "board": 7,  "hand_m": 7,  "board_m": 6 },
	"art_h":              { "hand": 74, "board": 40, "hand_m": 46, "board_m": 34 },
	"chip_size":          { "hand": 8,  "board": 7,  "hand_m": 7,  "board_m": 7 },
	"chip_h":             { "hand": 15, "board": 13, "hand_m": 13, "board_m": 12 },
	"ability_title_size": { "hand": 9,  "board": 7,  "hand_m": 8,  "board_m": 6 },
	"ability_text_size":  { "hand": 8,  "board": 7,  "hand_m": 7,  "board_m": 6 },
	"attack_name_size":   { "hand": 10, "board": 8,  "hand_m": 9,  "board_m": 7 },
	"attack_dmg_size":    { "hand": 11, "board": 9,  "hand_m": 10, "board_m": 9 },
	"icon_size":          { "hand": 10, "board": 7,  "hand_m": 9,  "board_m": 7 },
	"footer_size":        { "hand": 8,  "board": 7,  "hand_m": 7,  "board_m": 6 },
}

var card: CardData
var unit: Unit                       ## null when the card is in hand
var mode: int = Mode.HAND

var selected: bool = false
var dimmed: bool = false             ## unplayable / not actionable
var enemy: bool = false              ## opposing side — tinted cooler and slightly muted
var highlight: Color = Color(0, 0, 0, 0)   ## override border (evolve target, queued, etc.)

## Drag source. When set, the card can be picked up and dropped on a slot or
## unit; Combat fills this in with what the payload should say.
## Shape: { "kind": "hand_card", "hand_index": int, "card_id": String }
var drag_payload: Dictionary = {}

## Drop target, same contract as DropZone: func(data) -> bool / func(data) -> void.
var can_drop: Callable = Callable()
var on_drop: Callable = Callable()
var _drop_hover: bool = false

signal pressed()
signal drag_started()
## Emitted as the pointer enters/leaves the frame. Combat uses this to lift the
## hovered hand card and drop the previously hovered one.
signal hover_changed(hovering: bool)

var _button: Button

## Whether this card was built for the phone layout. Latched in `_init` rather
## than read live, so a card cannot end up sized by one layout and laid out by
## the other — that mix is exactly what clips a row.
var _phone: bool = false

## Extra rules text shown only while the card is hovered in hand. Empty hides the
## panel entirely, so a card with nothing more to say doesn't grow a blank box.
var hover_text: String = ""
var _hover_panel: PanelContainer


func _init(c: CardData, u: Unit = null, m: int = Mode.HAND) -> void:
	card = c
	unit = u
	mode = m
	var loop := Engine.get_main_loop()
	_phone = loop != null and loop.root.has_node("ViewportFit") \
		and loop.root.get_node("ViewportFit").mobile


func _ready() -> void:
	## A board card is exactly its slot's size — the frame is a fixed slot, not a
	## box that grows to fit. clip_contents makes that a hard cap: a long name or
	## an extra attack line is trimmed rather than stretching the card, which
	## would push the board row, the throne and the hand down the screen.
	##
	## Hand cards are deliberately *not* clipped: the hover panel is anchored
	## below the frame on purpose and clipping would cut it off.
	var sz := size_for(mode)
	custom_minimum_size = sz
	if mode == Mode.BOARD:
		size = sz
		clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_PASS
	_build()


# ------------------------------------------------------------------ building

func _build() -> void:
	for c in get_children():
		c.queue_free()

	add_theme_stylebox_override("panel", _frame_style())

	## An invisible button covering the whole frame gives us hover + click
	## without fighting the layout. It forwards drags to this CardView so a
	## press-and-move picks the card up instead of being eaten as a click.
	_button = Button.new()
	_button.flat = true
	_button.set_anchors_preset(Control.PRESET_FULL_RECT)
	_button.mouse_filter = Control.MOUSE_FILTER_PASS
	_button.pressed.connect(func(): pressed.emit())
	## Tactile press. A card that visually depresses under the cursor is the
	## cheapest way to make a UI feel like objects rather than regions, and it is
	## the thing Pocket does that a static frame cannot fake. `button_down` rather
	## than `pressed` so the feedback lands on the press, not on the release.
	_button.button_down.connect(func(): Motion.press(self, true))
	_button.button_up.connect(func(): Motion.press(self, false))
	_button.set_drag_forwarding(_get_drag_data, Callable(), Callable())
	## The button covers the whole frame, so its hover is the card's hover.
	_button.mouse_entered.connect(func(): hover_changed.emit(true))
	_button.mouse_exited.connect(func(): hover_changed.emit(false))
	add_child(_button)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 1 if _is_micro() else 3)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	_add_header(root)

	## The phone board card carries only what a *board* read is made of: which
	## unit this is, how hurt it is, and what it still holds. Everything below is
	## reference material that belongs on the enlarged card, and at 78 units wide
	## each of these rows would be a two-pixel smear that reads as damage to the
	## frame rather than as information.
	if _is_micro():
		_add_art(root)
		_add_keyword_chips(root)
		_add_micro_status(root)
	else:
		_add_evolve_strip(root)
		_add_art(root)
		_add_keyword_chips(root)
		_add_ability_banner(root)
		_add_attack_rows(root)
		_add_footer(root)
		_add_play_cost(root)
		_add_hover_text()

	## Dimming is a soft cue, not a "disabled" look — a card you can't play right
	## now must still be readable.
	if dimmed:
		modulate = Color(1, 1, 1, 0.72)
	elif enemy:
		modulate = Color(0.86, 0.89, 1.0, 0.94)   ## cooler cast for the enemy side
	else:
		modulate = Color.WHITE


## Look up a metric for this card's mode. Unknown keys return 0 rather than
## erroring, so a typo shows as a collapsed row instead of crashing the board.
func _m(key: String) -> int:
	var entry: Dictionary = METRICS.get(key, {})
	var col := "hand" if mode == Mode.HAND else "board"
	if _phone:
		## Fall back to the desktop column if a phone value was never authored,
		## so adding a metric cannot silently render at size 0.
		return int(entry.get(col + "_m", entry.get(col, 0)))
	return int(entry.get(col, 0))


## A phone board card is 78 units wide, which is not enough for the full frame
## at any font size — the art box, the ability banner and the attack rows would
## each be a few pixels tall and legible as nothing.
##
## So the phone board card is deliberately a *different* card: name, HP, keyword
## chips and the queued-attack marker, and nothing else. That is a real departure
## from the "one layout at two sizes" rule this renderer was built on, and it is
## justified by the same reasoning that rule was: the point was never uniformity
## for its own sake, it was that a card must not *read* differently in two
## places. A micro card omits information; it never contradicts the full one, and
## tapping it opens the full frame (Combat's hover/tap zoom).
func _is_micro() -> bool:
	return _phone and mode == Mode.BOARD


func _frame_style() -> StyleBoxFlat:
	var border := Palette.BORDER
	var bg := _ground()

	if card.is_energy():
		border = Palette.GOLD
		bg = _tinted(Palette.GOLD, 0.16)
	elif card.is_support_like():
		## Supports read as their own class at a glance: teal rather than the
		## energy gold or the unit's HP-tinted border.
		border = Palette.TOWER
		bg = _tinted(Palette.TOWER, 0.14)

	if unit != null:
		border = Palette.hp_color(unit.hp, unit.max_hp())
		if unit.queued_attack != null:
			border = Palette.GOLD

	if highlight.a > 0.0:
		border = highlight
	if selected:
		border = Palette.ACCENT
		bg = _tinted(Palette.ACCENT, 0.2)

	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(3 if selected else 2)
	## The top edge is drawn a shade brighter than the rest, which is how every
	## surface in the UI implies the same overhead light. A real gradient fill is
	## unavailable here — see `Palette.lit_style`, which documents the headless
	## hang that rules it out.
	s.set_corner_radius_all(9)
	s.content_margin_left = 7
	s.content_margin_right = 7
	s.content_margin_top = 6
	s.content_margin_bottom = 6
	## A card should read as an object lying above the board, not as a region
	## painted onto it. Selected cards lift further, which is the depth cue doing
	## the work an outline alone used to do.
	s.shadow_color = Color(0, 0, 0, 0.55 if selected else 0.42)
	s.shadow_size = 7 if selected else 4
	s.shadow_offset = Vector2(0, 3 if selected else 2)
	return s


## The card's resting background: the neutral panel ground, pulled a little way
## toward its own faction colour.
##
## Every card used to sit on the same two fills (one for yours, one cooler for
## the enemy's), so a hand of four factions read as four identical grey frames
## with differently-coloured text on them. A faint tint — deliberately faint, a
## sixth of the way — makes a Gaia card recognisably green-grounded and a Void
## card slate before a single word is read, which is the whole job of faction
## colour on a card.
func _ground() -> Color:
	var base: Color = Palette.PANEL_LIGHT
	if enemy:
		## The enemy's side stays cooler and darker, so the two sides separate
		## instantly even when both are playing the same faction.
		base = Color("121826")
	if card == null or card.faction == "":
		return base
	return base.lerp(Palette.faction_shade(card.faction, "deep"), 0.22)


## The ground tinted toward an arbitrary colour, for the card classes that are
## identified by role rather than by faction (energy, supports, selection).
func _tinted(c: Color, amount: float) -> Color:
	var base: Color = Color("121826") if enemy else Palette.PANEL_LIGHT
	return base.lerp(c, amount)


## The header, in Pokémon's reading order:
##
##   STAGE 2                             330 HP ⬢
##   Hel, Queen of the Unclaimed
##
## HP is top-right because that is the number a player checks most often and the
## one they check *fastest* — it is the read that decides whether an attack kills.
## Putting it in a fixed corner means it is found without scanning, on both sides
## of the board, at either size.
##
## **Two rows, not one.** The first attempt put stage, name and HP on a single
## row, which is what a real Pokémon card does — but a real card is 63mm wide and
## this frame is 168px in hand, 132px on the board. With a fixed stage cell on the
## left and HP on the right, the name got whatever was left over, and that was not
## enough: "Thornshade" rendered as "Thorns…" and "Hel, Queen of the Unclaimed" as
## "Hel, Qu…". A layout whose first casualty is the card's own *name* has its
## priorities backwards. Giving the name its own full-width row costs one line of
## vertical space and buys back the identity of every card in the game.
func _add_header(root: VBoxContainer) -> void:
	## The header sits in its own banded field, tinted toward the card's faction
	## and separated from the body by a hairline.
	##
	## Every printed card game does this and for the same reason: the header is
	## *identity* (what this card is) and everything below it is *content* (what
	## it does). Running them together on one background makes the card a list of
	## text, which is what the frame looked like before — a band gives the eye a
	## fixed place to find the name and the HP, and it is what makes the faction
	## colour a property of the card rather than a dot in the corner.
	var band := PanelContainer.new()
	band.mouse_filter = Control.MOUSE_FILTER_IGNORE
	band.add_theme_stylebox_override("panel", _header_style())
	root.add_child(band)

	var head := VBoxContainer.new()
	head.add_theme_constant_override("separation", 0)
	head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	band.add_child(head)

	## Row 1 — stage on the left, HP and the faction dot on the right.
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	head.add_child(row)

	var stage := Label.new()
	stage.name = "StageLabel"
	stage.text = card.stage_name().to_upper() if card.is_unit() else card.type_label().to_upper()
	stage.add_theme_font_size_override("font_size", _m("stage_size"))
	stage.add_theme_color_override("font_color", _stage_color() if card.is_unit() else _type_color())
	stage.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	stage.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stage.clip_text = true
	stage.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	row.add_child(stage)

	if card.is_unit():
		var hp := Label.new()
		hp.name = "HPLabel"
		var hp_col: Color = Palette.HP_GREEN
		if unit != null:
			## In play, HP is current/max and colored by how hurt the unit is.
			hp.text = "%d/%d" % [max(0, unit.hp), unit.max_hp()]
			hp_col = Palette.hp_color(unit.hp, unit.max_hp())
		else:
			hp.text = "%d HP" % card.max_hp
		hp.add_theme_font_size_override("font_size", _m("hp_size"))
		hp.add_theme_color_override("font_color", hp_col)
		hp.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		hp.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(hp)

	## The faction dot. A card's color is its energy color (CLAUDE.md: a faction
	## *is* an energy color), so one dot in a fixed corner identifies the color
	## without spending a row on the word.
	var dot := EnergyIcon.new(Palette.faction_color(card.faction), true, false, _m("hp_size") * 0.72, card.faction)
	row.add_child(dot)

	## Row 2 — the name, at the frame's full width.
	var nm := Label.new()
	nm.name = "NameLabel"
	nm.text = card.name
	nm.add_theme_color_override("font_color", Palette.TEXT)
	nm.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	nm.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	nm.mouse_filter = Control.MOUSE_FILTER_IGNORE
	## Trim from the right with an ellipsis rather than clip_text, which is centred
	## and eats the *start* of the name too — "Hel, Queen of the Unclaimed" came
	## out as "el, Queen of the Unclaime". The opening words identify the card.
	nm.autowrap_mode = TextServer.AUTOWRAP_OFF
	nm.max_lines_visible = 1
	nm.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	## Long names step down a size before resorting to trimming. Even at full width
	## a few ("Hel, Queen of the Unclaimed") do not fit outright.
	var title_px: int = _m("title_size")
	if card.name.length() > 22:
		title_px = max(6, title_px - 3)
	elif card.name.length() > 17:
		title_px = max(6, title_px - 1)
	nm.add_theme_font_size_override("font_size", title_px)
	head.add_child(nm)


## The header band's fill: the card's faction at low saturation over the frame
## ground, with a brighter hairline along the bottom acting as the divider
## between identity and content.
##
## Non-unit cards (energy, supports, tools) take their type colour instead, so a
## support's band reads teal and an energy card's gold — the class of the card is
## legible from the band alone, before the type word is read.
func _header_style() -> StyleBoxFlat:
	var tint: Color = Palette.faction_color(card.faction) if card.faction != "" 		else _type_color()
	var s := StyleBoxFlat.new()
	s.bg_color = _ground().lerp(tint, 0.20)
	s.set_corner_radius_all(4)
	## The divider. A bottom border only — a full outline would box the header
	## and make the card read as two stacked panels rather than one object.
	s.border_color = Color(tint.r, tint.g, tint.b, 0.55)
	s.border_width_bottom = 1
	var pad: int = 2 if _is_micro() else 3
	s.content_margin_left = pad + 1
	s.content_margin_right = pad + 1
	s.content_margin_top = pad - 1
	s.content_margin_bottom = pad
	return s


## "↑ Evolves from Charmeleon" — its own strip under the header.
##
## This used to be tacked onto the end of the stage badge's text, where it was
## the least prominent thing on the card despite being the one piece of
## information that decides whether a card in hand is playable *at all*: a Stage 1
## with no base form on the board is a dead card. It gets its own row for the same
## reason Pokémon gives it one.
##
## Only drawn when the card actually evolves from something. A Basic gets no
## empty strip — vertical space is the scarcest thing on a 196px board card, and
## reserving a row to say "nothing" is the worst possible use of it.
func _add_evolve_strip(root: VBoxContainer) -> void:
	if not card.is_unit() or card.evolves_from == "":
		return
	var base: CardData = CardDB.get_card(card.evolves_from)
	if base == null:
		return

	var panel := PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var col: Color = _stage_color()
	var s := StyleBoxFlat.new()
	s.bg_color = col.darkened(0.72)
	s.border_color = col.darkened(0.35)
	s.set_border_width_all(1)
	s.set_corner_radius_all(3)
	s.content_margin_top = 0
	s.content_margin_bottom = 0
	s.content_margin_left = 4
	s.content_margin_right = 4
	panel.add_theme_stylebox_override("panel", s)
	root.add_child(panel)

	var l := Label.new()
	l.name = "EvolveStrip"
	l.text = "^ Evolves from %s" % base.name
	l.add_theme_font_size_override("font_size", _m("evolve_size"))
	l.add_theme_color_override("font_color", col.lightened(0.5))
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.clip_text = true
	l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(l)


## The accent color for a non-unit card's type label, matching the frame border
## each type already gets in _frame_style().
func _type_color() -> Color:
	if card.is_energy():
		return Palette.GOLD
	return Palette.TOWER


## Faction only — the stage has its own badge row above.
func _typing_text() -> String:
	return card.faction.capitalize()


func _stage_color() -> Color:
	match card.stage:
		CardData.Stage.STAGE2: return Palette.ACCENT
		CardData.Stage.STAGE1: return Palette.TOWER
		_: return Palette.TEXT_DIM


## Card art: the emblem from assets/art/<id>.png, falling back to the card's
## initials on a tinted box when a card has no art yet.
##
## The emblem is square but the art box is wide, so it is centred at the box's
## height rather than stretched — a squashed emblem reads worse than a small
## one, and the tinted panel behind it fills the rest of the row.
func _add_art(root: VBoxContainer) -> void:
	var art := PanelContainer.new()
	var box_h: int = 48 if mode == Mode.BOARD else 74
	art.custom_minimum_size = Vector2(0, box_h)
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var s := StyleBoxFlat.new()
	s.bg_color = _art_tint()
	s.border_color = Palette.BORDER
	s.set_border_width_all(1)
	s.set_corner_radius_all(4)
	art.add_theme_stylebox_override("panel", s)
	root.add_child(art)

	var center := CenterContainer.new()
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	art.add_child(center)

	var tex: Texture2D = CardArt.get_art(card.id)
	if tex != null:
		var img := TextureRect.new()
		img.texture = tex
		## expand_mode is what actually holds the art to box_h. custom_minimum_size
		## is a floor, not a cap, so without this the 128px source texture reports
		## its own size as the minimum and wins — which made every board card ~80px
		## taller than its slot and pushed the hand off the bottom of the screen.
		img.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		img.custom_minimum_size = Vector2(box_h, box_h)
		img.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		img.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		img.mouse_filter = Control.MOUSE_FILTER_IGNORE
		center.add_child(img)
		return

	var initials := Label.new()
	initials.text = _initials()
	initials.add_theme_font_size_override("font_size", 26 if mode == Mode.BOARD else 30)
	initials.add_theme_color_override("font_color", Palette.TEXT_DIM.darkened(0.15))
	initials.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.add_child(initials)


func _art_tint() -> Color:
	if card.is_support_like():
		return Palette.TOWER.darkened(0.72)
	if not card.is_unit():
		return Color("3a2f14")
	match card.stage:
		CardData.Stage.STAGE2: return Palette.ACCENT_DIM.darkened(0.45)
		CardData.Stage.STAGE1: return Palette.ACCENT_DIM.darkened(0.62)
		_: return Palette.PANEL.lightened(0.05)


func _initials() -> String:
	var out := ""
	for word in card.name.replace(",", " ").split(" ", false):
		var w := str(word)
		if w.length() == 0:
			continue
		var first := w.substr(0, 1)
		if first == first.to_upper() and first != "'":
			out += first
		if out.length() >= 3:
			break
	return out.to_upper() if out != "" else "?"


## Keywords as a row of tinted chips, under the art.
##
## The values come from _live_keyword_line(), NOT from CardData.keyword_line() —
## a spent Judgment or Rise must vanish from the board, and Sanctuary must show
## its remaining pool rather than its printed one. See that function's comment;
## HeavenTest.gd asserts the behaviour.
##
## Chips rather than one comma-joined line because a keyword is a discrete thing
## a player checks for ("does that body still hold its charge?"), and a row of
## separated pills answers that with a glance where a sentence has to be read.
## Each chip is colored by keyword via Palette.keyword_color(), so Toll and
## Judgment are told apart before either word is read.
##
## The row is omitted entirely when the card has no live keywords — the old
## renderer printed a placeholder em-dash, which spent a row saying nothing.
func _add_keyword_chips(root: VBoxContainer) -> void:
	if not card.is_unit():
		return

	var text := _live_keyword_line()
	if text.strip_edges() == "":
		return

	var row := HBoxContainer.new()
	row.name = "KeywordChips"
	row.add_theme_constant_override("separation", 3)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.custom_minimum_size = Vector2(0, _m("chip_h"))
	## PASS, not IGNORE: the chips carry hover tooltips and this row is their parent.
	## PASS still lets the click fall through to the card's own button underneath, so
	## the only thing it changes is that the hover reaches the chips.
	row.mouse_filter = Control.MOUSE_FILTER_PASS
	root.add_child(row)

	for part in text.split(",", false):
		var p := str(part).strip_edges()
		if p == "":
			continue
		row.add_child(_keyword_chip(p))


## One chip. `text` is a live keyword phrase like "Toll 3" or "Sanctuary 40";
## the first word is what selects the color.
func _keyword_chip(text: String) -> Control:
	var kw_name := text.split(" ")[0].to_lower()
	var col: Color = Palette.keyword_color(kw_name)

	var chip := PanelContainer.new()
	## PASS rather than IGNORE: the chip has to receive a hover to show its tooltip,
	## and PASS still lets the click fall through to the card's own button underneath,
	## so hovering a keyword never costs the player the ability to select the card.
	## The inner Label stays IGNORE so the tooltip belongs to exactly one node.
	chip.mouse_filter = Control.MOUSE_FILTER_PASS
	var help: String = Palette.keyword_help(kw_name)
	if help != "":
		chip.tooltip_text = help

	var s := StyleBoxFlat.new()
	s.bg_color = col.darkened(0.68)
	s.border_color = col
	s.set_border_width_all(1)
	s.set_corner_radius_all(7)
	s.content_margin_left = 4
	s.content_margin_right = 4
	s.content_margin_top = 0
	s.content_margin_bottom = 0
	chip.add_theme_stylebox_override("panel", s)

	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", _m("chip_size"))
	l.add_theme_color_override("font_color", col.lightened(0.55))
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chip.add_child(l)
	return chip


## The keyword line as it is *right now*, not as printed.
##
## `CardData.keyword_line()` reads the printed card, which never changes — correct
## for the deck builder and the inspector, wrong on the board. Spent one-shot
## keywords have to visibly disappear, because each is a resource the player is
## deciding when to cash: a board where you cannot see which units still hold a
## charge makes the decision impossible to make.
##
## Three keywords are spendable, and each drops out when used:
##   Rise       — spent on death, `lost_rise`
##   Judgment   — spent by either half, `judgment_spent`
##   Sanctuary  — spent when it absorbs, `sanctuary_active`
##
## Sanctuary N additionally shows its *remaining* pool rather than the printed one,
## since a depleted pool is the whole state that matters when deciding what to
## attack into.
func _live_keyword_line() -> String:
	var text := card.keyword_line()
	if unit == null:
		return text

	var kept: Array[String] = []
	for part in text.split(",", false):
		var p := str(part).strip_edges()
		var lower := p.to_lower()

		if lower.begins_with("rise"):
			if unit.lost_rise:
				continue
		elif lower.begins_with("judgment"):
			if unit.judgment_spent:
				continue
		elif lower.begins_with("sanctuary"):
			if not unit.sanctuary_active:
				continue
			## Show what is left in the pool, not what was printed.
			p = "Sanctuary" if unit.sanctuary_pool <= 0 else "Sanctuary %d" % unit.sanctuary_pool
		elif lower.begins_with("charge"):
			## Show what is BANKED, with the rate after it. The printed number is
			## the rate; the interesting number — the one every decision about
			## this unit turns on — is the counter. Same rule as Sanctuary's pool.
			p = "Charge %d (+%d)" % [unit.charge, unit.charge_rate()]
		elif lower.begins_with("molt"):
			## Same shape as Rise: a spent one-shot keyword disappears from the
			## board entirely, because "does this body still hold its charge?"
			## has to be a lookup, not a sentence to read (CLAUDE.md).
			if unit.lost_molt:
				continue
		elif lower.begins_with("ferocity"):
			## Show what is BANKED, with the rate after it — identical reasoning
			## to Charge above. The printed number is the per-death rate; the
			## number every decision about this unit turns on is the stack count.
			p = "Ferocity %d (+%d)" % [unit.ferocity_stacks, unit.ferocity_rate()]

		## A keyword a card has RAISED on this body shows its live value, not its
		## print. Same rule as the spent-Judgment fix: state the rules engine
		## tracks per-unit has to be visible per-unit, or a mechanic is correct
		## and invisible — which to a player is indistinguishable from broken.
		var kw_name := lower.split(" ")[0]
		if unit.kw_is_modified(kw_name):
			var live: int = unit.kw_value(kw_name)
			if live <= 0:
				continue
			p = "%s %d" % [p.split(" ")[0], live]

		kept.append(p)
	return ", ".join(kept)


## Abilities in a colored banner, above the attack rows.
##
## Abilities and attacks are genuinely different mechanics in this game, not two
## flavours of the same one (CLAUDE.md, *Abilities vs. Attacks*): an ability
## resolves immediately, is limited to once per turn, and is free — its only
## possible cost is `Consume N`, which destroys attached energy. An attack is
## queued, resolves at end of turn, and pays a cost that stays attached and is
## free every turn after. The old renderer marked that difference with a small
## "◆" prefix, which is easy to miss on a 132px card. A banner is not decoration
## here; it is the visual form of a rules distinction.
##
## `Consume N` is printed in the banner header rather than in a cost-icon row,
## because it is not a requirement that sits on the unit — it is energy destroyed
## on each use, which is why a Consume ability never becomes a free permanent
## engine. Rendering it as cost icons would read as "attach this much", which is
## the opposite of what it does.
func _add_ability_banner(root: VBoxContainer) -> void:
	if not card.is_unit():
		return
	var abilities: Array = card.ability_lines()
	if abilities.is_empty():
		return

	for atk in abilities:
		var used: bool = unit != null and unit.has_used_ability(atk)
		var col: Color = Palette.ACCENT if not used else Palette.TEXT_DIM

		var panel := PanelContainer.new()
		panel.name = "AbilityBanner"
		panel.mouse_filter = Control.MOUSE_FILTER_IGNORE

		var s := StyleBoxFlat.new()
		s.bg_color = col.darkened(0.72)
		s.border_color = col
		s.set_border_width_all(1)
		s.set_corner_radius_all(4)
		s.content_margin_left = 4
		s.content_margin_right = 4
		s.content_margin_top = 1
		s.content_margin_bottom = 1
		panel.add_theme_stylebox_override("panel", s)
		root.add_child(panel)

		var col_box := VBoxContainer.new()
		col_box.add_theme_constant_override("separation", 0)
		col_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
		panel.add_child(col_box)

		## Header: the ABILITY tag, the line's name, and what it burns.
		var head := HBoxContainer.new()
		head.add_theme_constant_override("separation", 4)
		head.mouse_filter = Control.MOUSE_FILTER_IGNORE
		col_box.add_child(head)

		var tag := Label.new()
		tag.text = "ABILITY"
		tag.add_theme_font_size_override("font_size", max(6, _m("ability_title_size") - 1))
		tag.add_theme_color_override("font_color", col.lightened(0.4))
		tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
		head.add_child(tag)

		var nm := Label.new()
		nm.text = atk.name
		nm.add_theme_font_size_override("font_size", _m("ability_title_size"))
		nm.add_theme_color_override("font_color",
			Palette.TEXT if not used else Palette.TEXT_DIM.darkened(0.25))
		nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		nm.clip_text = true
		nm.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		nm.mouse_filter = Control.MOUSE_FILTER_IGNORE
		head.add_child(nm)

		var cost := Label.new()
		cost.text = "-%d" % atk.consume if atk.consume > 0 else "free"
		cost.add_theme_font_size_override("font_size", max(6, _m("ability_title_size") - 1))
		cost.add_theme_color_override("font_color",
			Palette.ACCENT.lightened(0.2) if atk.consume > 0 else Palette.TEXT_DIM)
		## PASS, so the hover reaches it. `-2` on a banner is not self-explanatory:
		## it is attached energy DESTROYED, which is a different kind of cost from
		## anything else on the card, and the tooltip is where that is said.
		cost.mouse_filter = Control.MOUSE_FILTER_PASS
		cost.tooltip_text = _ability_cost_help(atk)
		head.add_child(cost)

		## Body: the rules text. Hand cards wrap it; board cards get one trimmed
		## line, because the board frame has no room to grow and clip_contents
		## would otherwise cut a wrapped block mid-sentence.
		if atk.text != "":
			var body := Label.new()
			body.text = atk.text
			body.add_theme_font_size_override("font_size", _m("ability_text_size"))
			body.add_theme_color_override("font_color", Palette.TEXT_DIM)
			body.mouse_filter = Control.MOUSE_FILTER_IGNORE
			if mode == Mode.HAND:
				body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			else:
				body.autowrap_mode = TextServer.AUTOWRAP_OFF
				body.max_lines_visible = 1
				body.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
			col_box.add_child(body)


## One row per attack: cost icons, name, damage.
##
## Costs sit beside the attack they pay for. They used to live in a separate pip
## block at the bottom of the card, which meant a player reading a two-attack unit
## had to match rows to pip-rows by position — a step that is pure overhead and
## gets worse on the board card, where both blocks are small. Pokemon puts the
## cost inline for the same reason.
##
## Only attacks get a row. Abilities are drawn in the banner above, because they
## resolve on a different clock and pay a different kind of cost (see
## _add_ability_banner).
func _add_attack_rows(root: VBoxContainer) -> void:
	## Non-units carry rules text instead of attack lines.
	if not card.is_unit():
		var note := Label.new()
		note.name = "RulesText"
		note.text = card.text if card.is_support_like() else "Adds energy to your pool.
One per turn."
		note.add_theme_font_size_override("font_size", _m("ability_text_size"))
		note.add_theme_color_override("font_color", Palette.TEXT_DIM)
		note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		note.size_flags_vertical = Control.SIZE_EXPAND_FILL
		note.mouse_filter = Control.MOUSE_FILTER_IGNORE
		root.add_child(note)
		return

	var box := VBoxContainer.new()
	box.name = "AttackRows"
	box.add_theme_constant_override("separation", 2)
	box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(box)

	var attached: int = unit.attached if unit != null else 0

	for atk in card.attack_lines():
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 3)
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.add_child(row)

		var queued: bool = unit != null and unit.queued_attack == atk

		row.add_child(_cost_icons(atk, attached))

		var nm := Label.new()
		nm.text = ("> " if queued else "") + atk.name
		nm.add_theme_font_size_override("font_size", _m("attack_name_size"))
		nm.add_theme_color_override("font_color", Palette.GOLD if queued else Palette.TEXT)
		nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		nm.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		nm.clip_text = true
		nm.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		nm.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(nm)

		var dmg := Label.new()
		dmg.text = str(atk.damage) if atk.damage > 0 else "—"
		dmg.add_theme_font_size_override("font_size", _m("attack_dmg_size"))
		dmg.add_theme_color_override("font_color",
			Palette.DANGER if atk.damage > 0 else Palette.TEXT_DIM)
		dmg.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		dmg.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(dmg)

		## The attack's RIDER, under the row — everything its text says beyond the
		## damage number already shown to the right.
		##
		## Without this an attack renders as name + number, so every conditional
		## is invisible on the card that prints it: `Ember Strike` showed "28" with
		## no hint that stoking adds 10, and `THE LAST TOLL` showed "—" with no hint
		## that it destroys the board. The rules engine had them right the whole
		## time, which is the same "correct and invisible" failure the spent-Judgment
		## chip was fixed for — state a card's behaviour depends on has to be ON the
		## card.
		var rider := _attack_rider(atk)
		if rider != "":
			var rl := Label.new()
			rl.text = rider
			rl.add_theme_font_size_override("font_size", _m("ability_text_size"))
			rl.add_theme_color_override("font_color", Palette.TEXT_DIM)
			rl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			rl.mouse_filter = Control.MOUSE_FILTER_IGNORE
			box.add_child(rl)


## What an attack's text says BEYOND the damage number already rendered beside it.
##
## Returns "" when the text is only a restatement of the damage ("28 damage"),
## because repeating the number next to itself is noise on a 132px card. Anything
## else — a condition, a Siphon rider, a Stoke payoff — is the part that cannot be
## inferred from the frame and therefore has to be drawn.
func _attack_rider(atk: AttackData) -> String:
	var t: String = atk.text.strip_edges()
	if t == "":
		return ""

	## Strip a leading "N damage" restatement by hand rather than with a RegEx.
	## Plain scanning is easier to read than an escaped pattern here, and GDScript
	## string literals do not take the backslash escapes a regex wants.
	var i := 0
	while i < t.length() and t[i] >= "0" and t[i] <= "9":
		i += 1
	if i > 0:
		var rest_after_num: String = t.substr(i).strip_edges()
		if rest_after_num.to_lower().begins_with("damage"):
			rest_after_num = rest_after_num.substr(6)
		elif not rest_after_num.begins_with("to "):
			## A number followed by anything else is part of the sentence, not a
			## restatement of the damage — keep the whole text.
			rest_after_num = t
		t = rest_after_num.strip_edges()

	## Drop a leading separator left behind by the strip.
	while t.length() > 0 and (t[0] == "." or t[0] == ";" or t[0] == ","):
		t = t.substr(1).strip_edges()
	if t == "":
		return ""

	## Re-capitalise, since the remainder usually starts mid-sentence.
	return t.substr(0, 1).to_upper() + t.substr(1)


## The cost icons for one attack.
##
## These state what the attack REQUIRES, so they are always solid and always in
## the required colour. `attached` is still read by the numeric chip below, which
## states both numbers rather than encoding one of them as fill.
##
## Costs above 8 collapse to a numeric chip. Nine or more icons overflow a 132px
## frame, and the cards that cost that much (Cacophony Ramp reaches 14) are
## precisely the ones a player is counting toward, so the number is more useful
## than the row would be anyway.
##
## The whole row carries a hover tooltip spelling the cost out in words — see
## `_attack_cost_help`. The icons are the glance read; the tooltip is the one that
## says how much of it is *already paid*, which no arrangement of six 7px hexagons
## can state. It is `PASS` for the same reason the keyword chips are: the hover has
## to reach the row, and PASS still lets the click fall through to the card's own
## button, so reading a cost never costs the player the ability to select the card.
func _cost_icons(atk: AttackData, attached: int) -> Control:
	var box := HBoxContainer.new()
	box.add_theme_constant_override("separation", 1)
	box.mouse_filter = Control.MOUSE_FILTER_PASS
	box.tooltip_text = _attack_cost_help(atk)

	var cost: int = atk.total_cost()

	if cost == 0:
		var free := Label.new()
		free.text = "free"
		free.add_theme_font_size_override("font_size", max(6, _m("icon_size") - 1))
		free.add_theme_color_override("font_color", Palette.TEXT_DIM)
		free.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.add_child(free)
		return box

	if cost > 8:
		var chip := Label.new()
		chip.text = "#%d%s" % [cost, ("/%d" % attached) if unit != null else ""]
		chip.add_theme_font_size_override("font_size", _m("icon_size"))
		chip.add_theme_color_override("font_color",
			Palette.GOLD if attached >= cost else Palette.TEXT_DIM)
		chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.add_child(chip)
		return box

	## The attack's printed color, falling back to the card's own faction when the
	## cost block named none (a purely colorless cost).
	var fac: String = atk.cost_color if atk.cost_color != "" else card.faction
	var col: Color = Palette.faction_color(fac)

	## Always solid, always in the required colour.
	##
	## These icons state what the attack REQUIRES, which does not depend on what the
	## unit happens to hold — so they are drawn the same in hand, on an uncharged
	## body, and on a fully charged one. They used to be filled left-to-right by
	## attached energy, which meant a card in hand (where `unit` is null) drew every
	## icon unfilled, and `EnergyIcon`'s unfilled branch paints a black well and
	## never reaches the faction colour: the requirement rendered as empty grey
	## sockets on every card in your hand.
	##
	## "How close am I to affording this" is answered by the attached-energy badge in
	## the footer, which states the total as a number — a comparison of two stated
	## numbers rather than a count of filled sockets.
	for i in cost:
		var is_colorless: bool = i >= atk.cost_faction
		box.add_child(EnergyIcon.new(col, true, is_colorless, _m("icon_size"), fac))
	return box


## ------------------------------------------------------------- cost tooltips
##
## Every energy cost on a card explains itself on hover: what it takes to fire an
## attack, to use an ability, and to play the card at all.
##
## The icons alone cannot carry this. They state the requirement well — solid, in
## the colour demanded, one per energy — but a requirement is only half of what the
## player is deciding from. The other half is *how much of it is already paid*, and
## that is a per-unit number the row has no channel left to express: the row used to
## encode it as fill, and doing so cost the requirement its colour entirely (see
## `_cost_icons`). A tooltip is the right home for it because it is the reading you
## want on one card at a time, on demand, rather than across a whole board at once.
##
## Three rules these follow:
##
## - **Read the LIVE cost, never the printed one, whenever a unit exists.** A
##   `Deadweight` Tool raises what every attack on that body costs, so a tooltip
##   quoting `AttackData.total_cost()` would be confidently wrong on exactly the
##   unit whose cost is surprising. `Unit.attack_cost()` is the authority and the
##   tooltip names the tax as a separate line, because an unexplained +2 reads as a
##   bug in the card.
## - **State the split.** `2 Hel, 2 colorless` is a different card from `4 Hel` once
##   multi-colour enforcement lands, and the data is already right (see
##   `AttackData.cost_color`). Saying so now costs nothing and stops the tooltip
##   having to be rewritten when the rule ships.
## - **Never promise what the engine cannot do.** Colour requirements are display
##   only today — the pool is a single untyped int, so any energy pays anything —
##   and the tooltip says so rather than implying an enforcement that does not
##   exist. Same discipline as `Windfury`'s keyword help.


## The cost of one attack, in words. Used as the tooltip on its icon row.
func _attack_cost_help(atk: AttackData) -> String:
	var printed: int = atk.total_cost()

	if printed <= 0:
		return "Free — this attack needs no energy attached, so it can be queued every turn from the moment the unit lands."

	var lines: Array[String] = []

	## The live cost on THIS body, which is not the printed cost when a Deadweight
	## Tool is attached.
	var live: int = unit.attack_cost(atk) if unit != null else printed
	lines.append("Costs %d energy to queue." % live)

	## The colour split, when the card prints one.
	if atk.cost_faction > 0 and atk.cost_colorless > 0:
		lines.append("Printed as %d %s and %d colorless. Colorless is payable with any colour." % [
			atk.cost_faction, _faction_label(atk.cost_color), atk.cost_colorless])
	elif atk.cost_colorless > 0 and atk.cost_faction == 0:
		lines.append("Entirely colorless — payable with any colour of energy.")
	elif atk.cost_faction > 0:
		lines.append("Printed as %d %s. A pure colour requirement, which is this card's faction identity." % [
			atk.cost_faction, _faction_label(atk.cost_color)])

	## The Deadweight tax, named explicitly. An unexplained gap between the icons
	## drawn and the number charged reads as a bug in the card, not as a Tool.
	if live > printed:
		lines.append("Printed cost is %d; a Tool on this unit adds +%d." % [printed, live - printed])

	## What is paid and what is still owed. Only meaningful on a real body — a card
	## in hand has no attached energy and nothing to compare against.
	if unit != null:
		var owed: int = unit.pool_needed(atk)
		if owed <= 0:
			lines.append("Fully paid: %d already attached, so queueing it takes nothing from your pool." % unit.attached)
		else:
			lines.append("%d attached, so %d more comes from your pool when you queue it." % [unit.attached, owed])

	lines.append("Queueing pulls exactly the cost from your pool onto the unit, where it stays — the attack is free every turn after.")
	return "
".join(lines)


## The cost of one ability. Abilities are free except for Consume, and the
## difference between "free" and "free but it burns your investment" is the whole
## reason the two are drawn differently.
func _ability_cost_help(ab: AttackData) -> String:
	var used: bool = unit != null and unit.has_used_ability(ab)
	var lines: Array[String] = []

	if ab.consume > 0:
		lines.append("Consume %d — using this DESTROYS %d energy attached to this unit." % [ab.consume, ab.consume])
		lines.append("Nothing comes from your pool. Consume is the only cost an ability may carry, and unlike an attack's cost it is spent for good: the unit has to be recharged to use this again.")
		if unit != null:
			if unit.attached >= ab.consume:
				lines.append("%d attached, so this can be used now." % unit.attached)
			else:
				lines.append("Only %d attached — needs %d more before this can be used." % [
					unit.attached, ab.consume - unit.attached])
	else:
		lines.append("Free — abilities never cost pool energy.")
		lines.append("An ability resolves immediately rather than at end of turn, and its only limit is once per turn per unit.")

	if used:
		lines.append("Already used this turn.")
	return "
".join(lines)


## The cost of playing the card itself: units and most supports are free, a
## minority of supports charge 1-3 from the pool, and energy cards are the one
## card whose value depends on when you play it.
func _play_cost_help() -> String:
	if card.is_energy():
		return "An energy card adds turn + 1 energy of its colour to your pool — 2 on turn 1, 6 on turn 5. Holding it makes it worth more, but only one may be played per turn, so a skipped turn can never be made up."

	if card.is_unit():
		return "Free to play. Units are always free — energy only buys attacks, so the constraint in this game is acting, not deploying."

	if card.cost <= 0:
		return "Free to play. Most supports cost nothing; the cost of one is that you drew it instead of a unit."

	return "
".join([
		"Costs %d energy from your pool to play." % card.cost,
		"Paid from the pool rather than from a unit, so it competes directly with queueing an attack this turn — and unlike an attack's cost, it is spent for good rather than staying attached.",
		"If you cannot pay it, the card cannot be played.",
	])


## A faction's display name for a cost line. Falls back to the raw key rather than
## to a guess, so a colour added to the data before the UI knows about it still
## reads as itself instead of as "colored".
func _faction_label(key: String) -> String:
	if key == "":
		return "colored"
	return key.capitalize()


## The bottom strip: weakness, resistance, and retreat cost.
##
## Retreat goes bottom-right because it is where Pokémon prints it and because it
## belongs with the other printed constants rather than with the attacks — retreat
## is a *design-time* number (HP / 40, printed on the card) that never changes in
## play. Buffs, damage and debuffs never move it; only evolving does, because the
## evolved card prints its own.
##
## Weakness and resistance print "—". The system is not designed (CLAUDE.md, Open
## Questions), and the slots are reserved so that adding it later is a data change
## rather than a re-layout. This follows the project's established pattern: retreat
## costs themselves shipped on the card for a while before the retreat action
## existed, and the UI said plainly that they did nothing.
func _add_footer(root: VBoxContainer) -> void:
	if not card.is_unit():
		return

	var row := HBoxContainer.new()
	row.name = "CardFooter"
	row.add_theme_constant_override("separation", 5)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(row)

	## Attached energy, bottom-left: the faction's energy symbol and a plain total.
	##
	## This is what a unit HOLDS, as opposed to what an attack REQUIRES — the cost
	## icons beside each attack. The two used to share one widget, with cost icons
	## filled left-to-right by attached energy, and that overload is what rendered
	## every requirement in hand as an empty colourless socket: `unit` is null there,
	## so every icon was unfilled, and an unfilled icon never reaches the faction
	## ramp. Splitting them is what let the cost row state its colours again.
	##
	## Attached energy is also the half of the economy that DIES WITH THE UNIT, so
	## its total is the number a trade is judged on — worth stating plainly rather
	## than leaving to be counted off a row of icons.
	##
	## Drawn only when something is attached. A "0" on every uncharged body is noise
	## at this size.
	if unit != null and unit.attached > 0:
		var badge := HBoxContainer.new()
		badge.name = "AttachedBadge"
		badge.add_theme_constant_override("separation", 1)
		badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(badge)

		## The card's own faction colour, so the symbol says WHICH energy this is.
		badge.add_child(EnergyIcon.new(
			Palette.faction_color(card.faction), true, false,
			_m("footer_size") + 1, card.faction))

		var n := Label.new()
		n.text = str(unit.attached)
		n.add_theme_font_size_override("font_size", _m("footer_size") + 1)
		n.add_theme_color_override("font_color", Palette.GOLD)
		n.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		n.mouse_filter = Control.MOUSE_FILTER_IGNORE
		badge.add_child(n)

	## Weakness / resistance — reserved, not implemented.
	##
	## Abbreviated to a single letter to buy back the width the attached-energy badge
	## costs. The footer's content box is 118px on a board card, and with a retreat-4
	## body and a two-digit attached total the row reached exactly 118 — no slack, and
	## the card clips silently rather than erroring. The slots are the reservation, not
	## their captions, so shortening them keeps the whole point of having them.
	var wk := Label.new()
	wk.text = "w —"
	wk.add_theme_font_size_override("font_size", _m("footer_size"))
	wk.add_theme_color_override("font_color", Palette.TEXT_DIM.darkened(0.2))
	wk.tooltip_text = "Weakness — not yet implemented."
	wk.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(wk)

	var res := Label.new()
	res.text = "r —"
	res.add_theme_font_size_override("font_size", _m("footer_size"))
	res.add_theme_color_override("font_color", Palette.TEXT_DIM.darkened(0.2))
	res.tooltip_text = "Resistance — not yet implemented."
	res.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(res)

	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sp.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(sp)

	## Retreat cost, as icons. A unit with retreat 0 shows the label with no icons
	## rather than nothing, so the corner reads consistently across every card.
	var tag := Label.new()
	tag.text = "R"
	tag.add_theme_font_size_override("font_size", _m("footer_size"))
	tag.add_theme_color_override("font_color", Palette.TEXT_DIM)
	tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(tag)

	var icons := HBoxContainer.new()
	icons.add_theme_constant_override("separation", 1)
	icons.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(icons)

	for _i in card.retreat:
		## Retreat is paid from the unit's own attached energy and is colorless in
		## effect — any attached energy pays it — so it draws as a grey icon rather
		## than in the faction color, which would read as a colored requirement.
		icons.add_child(EnergyIcon.new(Palette.TEXT_DIM, true, true, _m("footer_size")))


## The play-cost line for non-unit cards.
##
## Most supports are free, which is the point — energy only buys attacks. The
## handful that charge 1-3 pool energy are the one sanctioned exception (CLAUDE.md,
## *Priced supports*), so the line has to distinguish them: a free card and a
## 2-cost card must not read the same.
##
## Priced supports are NOT YET ENFORCED by the engine — CardData.cost is parsed
## and printed but play_support does not spend it. The cost is shown anyway,
## because the card should read correctly now and the data is already right; the
## inspector is where the "not yet implemented" note lives, since that is the
## screen with room to say it.
func _add_play_cost(root: VBoxContainer) -> void:
	if card.is_unit():
		return

	var sep := HSeparator.new()
	sep.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(sep)

	var row := HBoxContainer.new()
	row.name = "PlayCost"
	row.add_theme_constant_override("separation", 3)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	## PASS plus a tooltip, the same contract the attack cost row and the keyword
	## chips use. "Free to play" is the line most worth explaining rather than the
	## least: it is the game's core rule, and a new player reading it on every card
	## has no way to know it is a rule instead of a property of that card.
	row.mouse_filter = Control.MOUSE_FILTER_PASS
	row.tooltip_text = _play_cost_help()
	root.add_child(row)

	if card.is_energy():
		var l := Label.new()
		l.text = "# scales with turn"
		l.add_theme_font_size_override("font_size", _m("footer_size"))
		l.add_theme_color_override("font_color", Palette.GOLD)
		l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(l)
		return

	if card.cost <= 0:
		var free := Label.new()
		free.text = "Free to play"
		free.add_theme_font_size_override("font_size", _m("footer_size"))
		free.add_theme_color_override("font_color", Palette.TOWER)
		free.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(free)
		return

	## Priced: icons, so the cost reads the same way an attack's does.
	for _i in card.cost:
		row.add_child(EnergyIcon.new(Palette.faction_color(card.faction), true, false, _m("icon_size"), card.faction))

	var lbl := Label.new()
	lbl.text = "to play"
	lbl.add_theme_font_size_override("font_size", _m("footer_size"))
	lbl.add_theme_color_override("font_color", Palette.GOLD)
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(lbl)


## The expanded rules text, revealed while the card is hovered in hand.
##
## It is added as a free-floating child anchored under the frame rather than
## inside the layout VBox: a panel in the flow would stretch the card past
## HAND_SIZE and shove the whole hand row around every time one was hovered.
## Hidden by default and toggled by set_hover_open(), so raising a card costs no
## layout work beyond showing a node that already exists.
func _add_hover_text() -> void:
	if hover_text == "":
		return

	_hover_panel = PanelContainer.new()
	_hover_panel.visible = false
	_hover_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	## Pinned to the frame's bottom edge, spanning its width, growing downward.
	_hover_panel.anchor_left = 0.0
	_hover_panel.anchor_right = 1.0
	_hover_panel.anchor_top = 1.0
	_hover_panel.anchor_bottom = 1.0
	_hover_panel.offset_top = 2

	## Opaque: this panel floats outside the card frame over the hand row, so a
	## translucent background would leave the neighbouring card showing through.
	var s := StyleBoxFlat.new()
	s.bg_color = Palette.PANEL.darkened(0.25)
	s.border_color = Palette.ACCENT
	s.set_border_width_all(1)
	s.set_corner_radius_all(4)
	s.content_margin_left = 5
	s.content_margin_right = 5
	s.content_margin_top = 3
	s.content_margin_bottom = 3
	s.shadow_color = Color(0, 0, 0, 0.5)
	s.shadow_size = 4
	_hover_panel.add_theme_stylebox_override("panel", s)
	add_child(_hover_panel)

	var l := Label.new()
	l.text = hover_text
	l.add_theme_font_size_override("font_size", 9)
	l.add_theme_color_override("font_color", Palette.TEXT)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hover_panel.add_child(l)


## Show or hide the hover text. Safe to call on a card that has none.
func set_hover_open(open: bool) -> void:
	if _hover_panel != null:
		_hover_panel.visible = open


# ------------------------------------------------------------------ dragging

## Picking a card up is the same intent as clicking it, so a drag starts only
## when the card is actually actionable. Returning null leaves the click
## behaviour untouched, which keeps click-then-click working alongside drag.
func _get_drag_data(_at: Vector2) -> Variant:
	if drag_payload.is_empty():
		return null
	set_drag_preview(_make_drag_preview())
	drag_started.emit()
	return drag_payload


## A translucent copy of the card that follows the cursor. Centred on the
## pointer so the card sits under the hand, not off to one corner.
func _make_drag_preview() -> Control:
	var ghost := CardView.new(card, unit, mode)
	ghost.enemy = enemy
	ghost.modulate = Color(1, 1, 1, 0.82)

	## The preview is positioned by its top-left, so wrap it to centre it.
	var wrap := Control.new()
	wrap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var size: Vector2 = size_for(mode)
	ghost.position = -size * 0.5
	wrap.add_child(ghost)
	return wrap


func _can_drop_data(_at: Vector2, data: Variant) -> bool:
	var ok: bool = can_drop.is_valid() and bool(can_drop.call(data))
	if ok != _drop_hover:
		_drop_hover = ok
		queue_redraw()
	return ok


func _drop_data(_at: Vector2, data: Variant) -> void:
	_drop_hover = false
	if on_drop.is_valid():
		on_drop.call(data)


func _notification(what: int) -> void:
	if what == NOTIFICATION_MOUSE_EXIT or what == NOTIFICATION_DRAG_END:
		if _drop_hover:
			_drop_hover = false
			queue_redraw()


func _draw() -> void:
	if _drop_hover:
		draw_rect(Rect2(Vector2.ONE * 2, size - Vector2.ONE * 4), Palette.ACCENT, false, 3.0)


## The phone board card's one status row, replacing the ability banner, the
## attack rows and the footer all at once.
##
## Those three answer "what can this unit do", which is a question you ask about
## *one* unit while deciding — and deciding is done on the enlarged card. What a
## board scan needs is the state that changes turn to turn and differs between
## the six units in front of you: how much energy is committed here, whether an
## attack is already queued, and whether this body is about to die anyway.
func _add_micro_status(root: VBoxContainer) -> void:
	if unit == null:
		return

	var bits: Array[String] = []
	if unit.attached > 0:
		bits.append("%s%d" % [Palette.glyph("energy"), unit.attached])
	if unit.queued_attack != null:
		bits.append(Palette.glyph("queued"))
	if unit.dies_at_eot:
		bits.append(Palette.glyph("dead"))
	if bits.is_empty():
		return

	var l := Palette.label("  ".join(bits), _m("attack_dmg_size"), Palette.GOLD)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(l)


# ------------------------------------------------------------------ helpers

## Extra badges drawn under the frame — attached total, "dies EOT", etc.
func status_line() -> String:
	if unit == null:
		return ""
	var bits: Array[String] = []
	if unit.attached > 0:
		bits.append("# %d attached" % unit.attached)
	if unit.dies_at_eot:
		bits.append("+ dies EOT")
	return "   ".join(bits)
