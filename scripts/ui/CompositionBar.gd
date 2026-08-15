class_name CompositionBar
extends Control

## A deck's card-type mix as one horizontal bar: units, supports, tools, tower
## support, energy — each segment proportional to its share of the sixty.
##
## The builder could tell you a deck held 60 cards and 19 energy and nothing at
## all about its *shape*, which is the question you actually ask while editing:
## am I unit-heavy, have I run out of room for supports, is the energy count
## sane for this curve. Every deckbuilder in the genre answers that with a bar
## or a curve, because it is a proportion and proportions are compared by area
## rather than by reading five numbers and doing the arithmetic.
##
## Deliberately not a mana curve. This game's costs sit on *attacks*, not on
## cards — cards are free to play — so a cost curve would be measuring something
## the player never pays at deckbuilding time. Type mix is the real axis here,
## which is a good example of why a genre convention has to be re-derived rather
## than copied.

const HEIGHT := 10.0
const GAP := 1.5

## Drawn order, chosen so the bar reads the way a deck list is written: bodies
## first, then the things that support them, then the fuel.
const ORDER := [
	CardData.Type.UNIT,
	CardData.Type.SUPPORT,
	CardData.Type.TOOL,
	CardData.Type.TOWER_SUPPORT,
	CardData.Type.ENERGY,
]

var _mix: Dictionary = {}
var _total: int = 0


func _init(mix: Dictionary) -> void:
	set_mix(mix)
	custom_minimum_size = Vector2(0, HEIGHT)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mouse_filter = Control.MOUSE_FILTER_PASS


func set_mix(mix: Dictionary) -> void:
	_mix = mix
	_total = 0
	for k in _mix:
		_total += int(_mix[k])
	tooltip_text = describe(_mix)
	queue_redraw()


## The colour a card type is drawn in. Chrome tones rather than faction colours:
## a deck's *type* mix is orthogonal to its colours, and borrowing the faction
## ramps here would make a Gaia deck's support segment look like Gaia energy.
static func color_for(t: int) -> Color:
	match t:
		CardData.Type.UNIT:          return Palette.ACCENT
		CardData.Type.SUPPORT:       return Palette.TOWER
		CardData.Type.TOOL:          return Palette.THRONE
		CardData.Type.TOWER_SUPPORT: return Palette.TEXT_FAINT
		_:                           return Palette.GOLD


static func label_for(t: int) -> String:
	match t:
		CardData.Type.UNIT:          return "units"
		CardData.Type.SUPPORT:       return "support"
		CardData.Type.TOOL:          return "tools"
		CardData.Type.TOWER_SUPPORT: return "tower"
		_:                           return "energy"


## "34 units · 7 support · 19 energy" — types the deck does not run are omitted
## rather than shown as zero, so the line describes the deck instead of the
## schema.
static func describe(mix: Dictionary) -> String:
	var parts: Array = []
	for t in ORDER:
		var n: int = int(mix.get(t, 0))
		if n > 0:
			parts.append("%d %s" % [n, label_for(t)])
	return "  ".join(parts) if not parts.is_empty() else "empty"


func _draw() -> void:
	var w := size.x
	if w <= 0.0 or size.y <= 0.0:
		return

	## An empty deck still draws its track, so the bar holds its place in the
	## layout rather than collapsing and shifting everything around it.
	var track := Rect2(0, 0, w, size.y)
	draw_rect(track, Palette.PANEL_LIGHT)
	if _total <= 0:
		draw_rect(track, Palette.BORDER, false, 1.0)
		return

	## Segments are laid out on a running float and rounded only when drawn, so
	## rounding error cannot accumulate and leave a gap at the right edge.
	var x := 0.0
	for t in ORDER:
		var n: int = int(_mix.get(t, 0))
		if n <= 0:
			continue
		var seg: float = w * (float(n) / float(_total))
		draw_rect(Rect2(round(x), 0, maxf(1.0, round(seg) - GAP), size.y),
			color_for(t))
		x += seg

	draw_rect(track, Palette.BORDER, false, 1.0)
