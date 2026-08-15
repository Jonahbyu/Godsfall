class_name SlotSocket
extends DropZone

## An empty lane position.
##
## This was a `Button` whose label read "empty" — a word describing an absence,
## which is the interface telling you what it does not have. A board with two
## dead units showed the word twice, and the eye had to *read* to learn nothing.
##
## A socket instead: a recessed well with a dashed rim, sized exactly like a
## card, so an empty position reads as a shape waiting to be filled. That is
## Arena's convention and it is the right one — the slot is a place, and places
## are drawn, not captioned.
##
## Extends `DropZone` rather than `Button`, so the whole drag-and-drop contract —
## `can_drop`, `on_drop`, the hover tracking and the NOTIFICATION_DRAG_END
## cleanup — is inherited rather than reimplemented. Click-to-deploy and the
## tutorial highlight also keep working; only the appearance and the label
## change. That is what makes this a reskin of the slot and not a rewrite of it.

enum State { INERT, PLAYABLE, DROP, TUTORIAL }

var state: int = State.INERT
## Set when the slot should say something anyway — during setup, the first empty
## slot is worth labelling because the player has never seen the board before.
var caption: String = ""


func _init() -> void:
	flat = true
	## The button's own chrome is removed entirely; `_draw` is the whole look.
	## Without this the default StyleBox draws a filled rect over the socket.
	for st in ["normal", "hover", "pressed", "disabled", "focus"]:
		add_theme_stylebox_override(st, _blank())
	add_theme_color_override("font_color", Palette.TEXT_FAINT)
	add_theme_color_override("font_hover_color", Palette.ACCENT)
	add_theme_font_size_override("font_size", Palette.TYPE_SMALL)


func _blank() -> StyleBoxEmpty:
	return StyleBoxEmpty.new()


func _rim_color() -> Color:
	match state:
		State.TUTORIAL:
			return Palette.GOLD
		State.DROP:
			return Palette.ACCENT_GLOW
		State.PLAYABLE:
			return Palette.ACCENT
		_:
			return Palette.BORDER


func _draw() -> void:
	if size.x <= 0.0 or size.y <= 0.0:
		return

	## `DropZone._draw` paints the valid-payload ring. Ours replaces it, so the
	## hover state is folded into `state` by the caller instead — see
	## `Combat._slot_widget`, which sets State.DROP while a card is over it.
	var r := Rect2(Vector2(2, 2), size - Vector2(4, 4))
	var live: bool = state != State.INERT

	## The well. Darker than the lane it sits in, so it reads as depth rather
	## than as a panel — an empty slot is a hole in the surface, not a tile on it.
	var fill := Color(0, 0, 0, 0.30 if not live else 0.18)
	draw_rect(r, fill, true)

	## A dashed rim. Dashes rather than a solid outline because a solid rectangle
	## reads as a filled, disabled card, while a broken line reads as a boundary
	## that is expecting something.
	var col: Color = _rim_color()
	var a: float = 0.85 if live else 0.42
	_dashed_rect(r, Color(col.r, col.g, col.b, a), 2.0 if live else 1.0)

	## A small centre mark, so the slot has a target even with no caption. It is
	## a cross rather than a dot because a dot at this size reads as a bullet.
	var c: Vector2 = size * 0.5
	var m: float = min(size.x, size.y) * 0.055
	var mc := Color(col.r, col.g, col.b, 0.55 if live else 0.28)
	draw_rect(Rect2(c.x - m, c.y - 0.75, m * 2.0, 1.5), mc)
	draw_rect(Rect2(c.x - 0.75, c.y - m, 1.5, m * 2.0), mc)


## A dashed rectangle, walked as four runs. Godot has no dashed-stroke primitive,
## and stepping it manually is cheap at this size.
func _dashed_rect(r: Rect2, col: Color, w: float) -> void:
	var dash: float = 5.0
	var gap: float = 4.0
	var step: float = dash + gap
	var x: float = r.position.x
	while x < r.end.x:
		var seg: float = min(dash, r.end.x - x)
		draw_rect(Rect2(x, r.position.y, seg, w), col)
		draw_rect(Rect2(x, r.end.y - w, seg, w), col)
		x += step
	var y: float = r.position.y
	while y < r.end.y:
		var seg: float = min(dash, r.end.y - y)
		draw_rect(Rect2(r.position.x, y, w, seg), col)
		draw_rect(Rect2(r.end.x - w, y, w, seg), col)
		y += step
