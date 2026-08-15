class_name Crest
extends Control

## The Godsfall mark: a throne under a fracture.
##
## A game's menu needs something to look at that is not a button. Hearthstone
## opens on a tavern, Arena on a plane — both are *places*, and what they have in
## common mechanically is a focal object above the menu that says what the game is
## before a word is read. Godsfall had a centred column of four identical buttons
## on a flat field.
##
## Drawn in code for the same reasons the card art is: it is regenerable, it
## cannot drift from the palette, and it stays crisp at any size without shipping
## a bitmap. It is also the only honest option here — this project has no artist
## and no licensed art, so an emblem built from geometry is the ceiling, and
## geometry is enough if the shape means something.
##
## ## The shape
##
## A throne silhouette (the thing every game of Godsfall is a race toward),
## bisected by a crack that runs up through it and out the top, with the crack
## lit in the chrome accent. The name is *Godsfall*; the mark is a seat of power
## with a fault line through it. The ring around it is deliberately broken at the
## fracture, so the damage reads as having come from outside.

const RING_GAP := 0.34    ## radians of ring left open at the top
const CRACK_W  := 0.028   ## crack width as a fraction of the box


func _init(px: float = 120.0) -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(px, px)


func _draw() -> void:
	var d: float = min(size.x, size.y)
	if d <= 0.0:
		return
	var c: Vector2 = size * 0.5
	var r: float = d * 0.46

	_ring(c, r)
	_throne(c, d)
	_crack(c, d)


## The broken ring. Drawn as two arcs with a gap at the top, because a closed
## circle reads as a logo badge and an interrupted one reads as something that
## was whole and is not any more.
func _ring(c: Vector2, r: float) -> void:
	var col: Color = Palette.BORDER_LIT
	var start: float = -PI * 0.5 + RING_GAP
	var end: float = -PI * 0.5 - RING_GAP + TAU
	draw_arc(c, r, start, end, 96, col, max(1.5, r * 0.035), true)

	## A second, fainter ring just inside it gives the mark some weight without
	## making the line itself heavy.
	draw_arc(c, r * 0.9, start + 0.06, end - 0.06, 96,
		Color(col.r, col.g, col.b, 0.35), max(1.0, r * 0.018), true)


## The throne: a high back tapering to a seat, on a two-step dais. Blocky on
## purpose — at 120px a detailed chair is mud, and the silhouette is the part
## that has to survive.
func _throne(c: Vector2, d: float) -> void:
	var col: Color = Palette.TEXT_DIM
	var w: float = d * 0.26          ## half-width of the throne back
	var top: float = c.y - d * 0.30
	var seat: float = c.y + d * 0.06
	var base: float = c.y + d * 0.24

	## The back, slightly tapered so it reads as a seat rather than a slab.
	var back := PackedVector2Array([
		c + Vector2(-w * 0.78, top),
		c + Vector2(w * 0.78, top),
		c + Vector2(w, seat),
		c + Vector2(-w, seat),
	])
	draw_colored_polygon(back, Color(col.r, col.g, col.b, 0.30))
	_outline(back, col, max(1.0, d * 0.012))

	## Two dais steps, each wider than the one above.
	for i in 2:
		var t: float = float(i)
		var hw: float = w * (1.18 + 0.26 * t)
		var y0: float = seat + (base - seat) * (t / 2.0)
		var y1: float = seat + (base - seat) * ((t + 1.0) / 2.0)
		var step := PackedVector2Array([
			c + Vector2(-hw, y0), c + Vector2(hw, y0),
			c + Vector2(hw, y1), c + Vector2(-hw, y1),
		])
		draw_colored_polygon(step, Color(col.r, col.g, col.b, 0.22 - 0.06 * t))
		_outline(step, Color(col.r, col.g, col.b, 0.75), max(1.0, d * 0.010))


## The fracture. A jagged polyline from below the seat up through the throne and
## out through the gap in the ring, lit in the accent so it is the one bright
## thing in the mark — the eye should land on the break, not on the furniture.
func _crack(c: Vector2, d: float) -> void:
	var pts := PackedVector2Array()
	## Offsets in 0..1 of the box, walked bottom to top with a lateral wobble.
	var path := [
		Vector2(0.03, 0.30), Vector2(-0.02, 0.16), Vector2(0.05, 0.02),
		Vector2(-0.03, -0.14), Vector2(0.02, -0.30), Vector2(-0.01, -0.44),
		Vector2(0.04, -0.56),
	]
	for o in path:
		pts.append(c + Vector2(o.x * d, o.y * d))

	var glow: Color = Palette.ACCENT
	## Drawn twice: a wide soft pass for the glow, a thin bright one for the edge.
	draw_polyline(pts, Color(glow.r, glow.g, glow.b, 0.22), max(2.0, d * CRACK_W * 2.2), true)
	draw_polyline(pts, Palette.ACCENT_GLOW, max(1.0, d * CRACK_W * 0.5), true)


func _outline(pts: PackedVector2Array, col: Color, w: float) -> void:
	var o := PackedVector2Array(pts)
	o.append(pts[0])
	draw_polyline(o, col, w, true)
