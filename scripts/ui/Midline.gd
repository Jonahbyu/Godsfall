class_name Midline
extends Control

## The line between the two armies.
##
## This was a Label containing forty-nine hyphens and spaces, centred. It worked,
## and it read as a placeholder — typed punctuation standing in for a graphic is
## one of the most reliable tells that an interface was assembled rather than
## designed, because the spacing cannot respond to the window and the "line" is
## really a row of glyphs at the mercy of the font.
##
## Drawn instead: a hairline that fades out toward both ends, with a small
## diamond at the centre. The fade is what matters — a hard-edged rule across the
## full width reads as a container boundary, cutting the screen into two unrelated
## halves, whereas a line that dissolves at its ends reads as a frontier between
## two things that are part of one board. That is the correct relationship
## between the two sides here.

const HEIGHT := 14.0
## How much of each end is taken up by the fade.
const FADE := 0.34
const DIAMOND := 4.0


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(0, HEIGHT)


func _draw() -> void:
	if size.x <= 0.0:
		return

	var y: float = size.y * 0.5
	var col: Color = Palette.BORDER_LIT
	## Drawn as segments with per-segment alpha, because a single draw_line
	## takes one colour and the whole point here is that the ends fade.
	var steps := 48
	var w: float = size.x / float(steps)
	for i in steps:
		var t: float = float(i) / float(steps - 1)
		## Triangular falloff: full strength in the middle, zero at both edges.
		var edge: float = min(t, 1.0 - t) / FADE
		var a: float = clamp(edge, 0.0, 1.0) * 0.75
		if a <= 0.01:
			continue
		draw_rect(Rect2(i * w, y - 0.5, w + 0.5, 1.0),
			Color(col.r, col.g, col.b, a))

	## The centre mark: a small diamond, brighter than the line, so the midpoint
	## of the board is findable at a glance on a wide screen.
	var c := Vector2(size.x * 0.5, y)
	var d := PackedVector2Array([
		c + Vector2(0, -DIAMOND), c + Vector2(DIAMOND, 0),
		c + Vector2(0, DIAMOND), c + Vector2(-DIAMOND, 0),
	])
	draw_colored_polygon(d, Color(col.r, col.g, col.b, 0.9))
