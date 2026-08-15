class_name TowerGlyph
extends Control

## The tower, drawn as a structure.
##
## A tower occupies a lane slot and is the thing the whole early game is spent
## breaking, but it rendered as a rectangle containing the word "TOWER" and two
## numbers — visually the least substantial object on a board full of illustrated
## cards, which is backwards for the most durable thing on it.
##
## Drawn as crenellated battlements on a tapering body, with a damage state: as
## HP falls the merlons break away and cracks open in the wall. That last part is
## the reason to draw it at all rather than restyle the panel — **the structure's
## condition becomes readable as a silhouette**, so "which tower is nearly down"
## is answered by shape across the room, not by comparing two fractions.
##
## Sized to the card slot it occupies, so the board grid is unchanged.

var hp: int = 50
var max_hp: int = 50
var enemy: bool = false
## Drawn brighter when the tower is a legal target for a support or an attack.
var targeted: bool = false

const MERLONS := 5


func _init(current: int, maximum: int, is_enemy: bool, is_target: bool = false) -> void:
	hp = current
	max_hp = max(1, maximum)
	enemy = is_enemy
	targeted = is_target
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _frac() -> float:
	return clamp(float(hp) / float(max_hp), 0.0, 1.0)


func _draw() -> void:
	if size.x <= 0.0 or size.y <= 0.0:
		return

	var f: float = _frac()
	var body: Color = Palette.TOWER
	if targeted:
		body = Palette.GOLD
	## The stone darkens as it is damaged, so a hurt tower is dimmer as well as
	## more broken — two cues for one state, which is what makes it readable at
	## the small end.
	var stone: Color = body.darkened(0.45 + 0.20 * (1.0 - f))
	var edge: Color = body.lightened(0.15 * f)

	var w: float = size.x
	var h: float = size.y
	## The body tapers slightly toward the top, which is what stops it reading as
	## a plain rectangle at a glance.
	var bw_bot: float = w * 0.62
	var bw_top: float = w * 0.50
	var top: float = h * 0.30
	var bot: float = h * 0.86
	var cx: float = w * 0.5

	## Shaft.
	var shaft := PackedVector2Array([
		Vector2(cx - bw_top * 0.5, top),
		Vector2(cx + bw_top * 0.5, top),
		Vector2(cx + bw_bot * 0.5, bot),
		Vector2(cx - bw_bot * 0.5, bot),
	])
	draw_colored_polygon(shaft, stone)
	_outline(shaft, edge, 1.5)

	## Battlements. Merlons break off as HP falls — at full health all five
	## stand, at a sliver only the outermost remain, which reads as a wall that
	## has been shot away rather than as a bar that has emptied.
	var standing: int = int(ceil(MERLONS * f))
	var mw: float = (bw_top * 1.14) / float(MERLONS)
	var mx: float = cx - (bw_top * 1.14) * 0.5
	var mh: float = h * 0.11
	for i in MERLONS:
		if i >= standing:
			continue
		var r := Rect2(mx + i * mw + 1.0, top - mh, mw - 2.0, mh)
		draw_rect(r, stone)
		draw_rect(r, edge, false, 1.0)

	## The parapet the merlons stand on, always intact while the tower lives.
	draw_rect(Rect2(cx - bw_top * 0.60, top - 2.0, bw_top * 1.20, 3.0), edge)

	## Cracks, appearing below half and multiplying as it falls. Drawn from a
	## fixed table rather than randomly, so a tower does not re-crack differently
	## every time Combat rebuilds the board.
	if f < 0.66:
		var cracks := [
			[Vector2(0.46, 0.42), Vector2(0.52, 0.56), Vector2(0.47, 0.70)],
			[Vector2(0.58, 0.50), Vector2(0.54, 0.62), Vector2(0.59, 0.78)],
			[Vector2(0.42, 0.52), Vector2(0.38, 0.66), Vector2(0.43, 0.80)],
		]
		var n: int = 1 if f >= 0.45 else (2 if f >= 0.25 else 3)
		var cc := Color(0, 0, 0, 0.55)
		for ci in n:
			var pts := PackedVector2Array()
			for o in cracks[ci]:
				pts.append(Vector2(o.x * w, o.y * h))
			draw_polyline(pts, cc, 1.5, true)

	## Rubble at the base once badly hurt, so the damage has somewhere to have
	## gone. Small, and only at the bottom third of health.
	if f < 0.34:
		var rc := Color(stone.r, stone.g, stone.b, 0.7)
		for o in [Vector2(0.30, 0.90), Vector2(0.68, 0.92), Vector2(0.40, 0.94)]:
			draw_rect(Rect2(o.x * w, o.y * h, w * 0.06, h * 0.03), rc)


func _outline(pts: PackedVector2Array, col: Color, wd: float) -> void:
	var o := PackedVector2Array(pts)
	o.append(pts[0])
	draw_polyline(o, col, wd, true)
