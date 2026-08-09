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
## `filled` has a second meaning on the board: an attack's cost icons are filled
## left-to-right by the unit's *attached* energy, so a player can see how close a
## unit is to affording each attack. That is the same information the old pip row
## carried, kept because it is the core read of the energy economy.

var color: Color = Color.WHITE
var filled: bool = true
var colorless: bool = false


func _init(c: Color, is_filled: bool = true, is_colorless: bool = false, px: float = 10.0) -> void:
	color = c
	filled = is_filled
	colorless = is_colorless
	custom_minimum_size = Vector2(px, px)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	var r: float = min(size.x, size.y) * 0.5
	var c: Vector2 = size * 0.5
	var pts := PackedVector2Array()
	## Flat-top hexagon: six points at 60-degree steps, offset 30 degrees so the
	## silhouette reads as a hex rather than as a circle at small sizes.
	for i in 6:
		var a: float = deg_to_rad(30.0 + 60.0 * i)
		pts.append(c + Vector2(cos(a), sin(a)) * r)

	var body: Color = color if filled else Color(0, 0, 0, 0.45)
	var edge: Color = color.lightened(0.3) if filled else color.darkened(0.2)
	if colorless and filled:
		body = Palette.TEXT_DIM
		edge = Palette.TEXT_DIM.lightened(0.3)
	elif colorless:
		edge = Palette.TEXT_DIM

	draw_colored_polygon(pts, body)
	## Close the outline by repeating the first point.
	var outline := PackedVector2Array(pts)
	outline.append(pts[0])
	draw_polyline(outline, edge, max(1.0, r * 0.16), true)
