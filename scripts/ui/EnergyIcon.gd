class_name EnergyIcon
extends Control

## One energy cost icon: a filled hexagon in the faction's color, or a hollow
## grey one for colorless.
##
## Drawn rather than built from a texture because the icon appears at four
## different sizes across the game (board attack rows at 7px, hand rows at 10px,
## the inspector's 1.55x scale, the deck builder grid) and a bitmap would be
## either soft when scaled up or heavy when scaled down. A polygon is crisp at
## every size and costs one draw call.
##
## `filled` is styling only — solid token or hollow socket. It carries no meaning
## about what a unit holds, and **cost rows always pass `true`**: an attack's cost
## states what it *requires*, and a requirement does not change with the board.
##
## It used to mean the opposite. Cost icons were filled left-to-right by the unit's
## attached energy so the row doubled as a progress bar, which cost the requirement
## its colour entirely: `unit` is null for every card in hand, so every icon there
## was unfilled, and the unfilled branch below paints a black well and returns
## before either shade ramp is touched. A player's hand showed rows of empty grey
## sockets on the one screen where the colours are what you are deciding from.
##
## The progress read moved to the attached-energy badge in the card footer, which
## states the total as a number. Two stated numbers compare more directly than a
## count of filled sockets, and neither one has to borrow the other's channel.

var color: Color = Color.WHITE
var filled: bool = true
var colorless: bool = false
## The faction this icon was built for, used to look up its deep/base/bright
## ramp. Empty for a generic/colorless icon, which falls back to a gold ramp.
var faction: String = ""


func _init(c: Color, is_filled: bool = true, is_colorless: bool = false, px: float = 10.0, fac: String = "") -> void:
	color = c
	filled = is_filled
	colorless = is_colorless
	faction = fac
	custom_minimum_size = Vector2(px, px)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


## The three shades this icon is drawn from.
##
## `Palette` is fetched through the scene tree rather than named directly. Under
## `--script` the autoload does not exist at compile time, so a class-scope
## reference to it makes this whole file fail to compile and takes every
## dependent harness down with it — the `Identifier not found: Palette` trap the
## decision log already records for `CardViewTest`. Resolving it at call time
## keeps the icon usable from a headless test.
func _shades() -> Array:
	var pal: Object = null
	var loop := Engine.get_main_loop()
	if loop != null and loop.root.has_node("Palette"):
		pal = loop.root.get_node("Palette")

	if pal != null and faction != "" and pal.FACTION_RAMPS.has(faction.to_lower()):
		var r: Dictionary = pal.faction_ramp(faction)
		return [r["deep"], r["base"], r["bright"]]
	return [color.darkened(0.5), color, color.lightened(0.45)]


## The muted trio used for a colorless cost, resolved the same lazy way.
func _grey_shades() -> Array:
	var loop := Engine.get_main_loop()
	if loop != null and loop.root.has_node("Palette"):
		var pal: Object = loop.root.get_node("Palette")
		return [pal.TEXT_FAINT.darkened(0.3), pal.TEXT_DIM, pal.TEXT_DIM.lightened(0.4)]
	var g := Color("9691ad")
	return [g.darkened(0.5), g, g.lightened(0.4)]


func _draw() -> void:
	var r: float = min(size.x, size.y) * 0.5
	var c: Vector2 = size * 0.5
	var pts := _hex(c, r)

	var sh: Array = _grey_shades() if colorless else _shades()
	var deep: Color = sh[0]
	var base: Color = sh[1]
	var bright: Color = sh[2]

	if not filled:
		## A hollow socket: a recessed well rather than an empty outline, so it
		## reads as a slot with nothing in it. No cost row asks for this any more
		## (see the header) — it is kept for callers that want an unfilled token,
		## and it deliberately drops the colour, which is exactly why a cost row
		## must never use it.
		draw_colored_polygon(pts, Color(0, 0, 0, 0.5))
		_outline(pts, deep.lightened(0.1), max(1.0, r * 0.16))
		return

	## Body, then a lit upper face, then a bright rim. Three tones is the minimum
	## that reads as a struck token rather than a coloured polygon, and it is why
	## the icon has a ramp at all.
	draw_colored_polygon(pts, base)

	## The upper face: the top vertices pulled toward the centre, filled with the
	## bright shade at low alpha. This is the specular hit implying a light source
	## above, consistent with every lit panel in the UI.
	var face := PackedVector2Array()
	for i in [3, 4, 5, 0]:
		face.append(pts[i].lerp(c, 0.18))
	face.append(c)
	draw_colored_polygon(face, Color(bright.r, bright.g, bright.b, 0.32))

	_outline(pts, bright, max(1.0, r * 0.18))


## The six points of a flat-top hexagon: 60-degree steps offset 30 degrees, so
## the silhouette reads as a hex rather than as a circle at small sizes.
func _hex(c: Vector2, r: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in 6:
		var a: float = deg_to_rad(30.0 + 60.0 * i)
		pts.append(c + Vector2(cos(a), sin(a)) * r)
	return pts


func _outline(pts: PackedVector2Array, col: Color, w: float) -> void:
	var o := PackedVector2Array(pts)
	o.append(pts[0])
	draw_polyline(o, col, w, true)
