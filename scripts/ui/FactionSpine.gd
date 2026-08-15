class_name FactionSpine
extends Control

## A vertical bar of a deck's colours, drawn down the left edge of its row.
##
## Deck select listed ten decks as ten identical panels distinguished only by
## their names, so "where is my Gaia deck" was a reading task rather than a
## looking one. Every card game solves this the same way — colour the entry by
## what it plays — and this project already has faction ramps to do it with.
##
## Segments are proportional in nothing: each faction the deck runs gets an equal
## share. Weighting by card count was the alternative and is worse here, because a
## splash of four cards is exactly the thing you want to *see*, and at 5px wide a
## proportional segment for it would be invisible.

const WIDTH := 5.0

var factions: Array = []


func _init(f: Array) -> void:
	factions = f
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(WIDTH, 0)
	size_flags_vertical = Control.SIZE_EXPAND_FILL


func _draw() -> void:
	if size.y <= 0.0:
		return

	## A colourless deck still gets a bar, in the neutral border grey, so every
	## row has the same shape and the list does not go ragged.
	if factions.is_empty():
		draw_rect(Rect2(0, 0, WIDTH, size.y), Palette.BORDER)
		return

	var n: int = factions.size()
	var h: float = size.y / float(n)
	for i in n:
		var f: String = str(factions[i])
		## The ramp's base for the body and its bright for a thin inner highlight,
		## so the spine reads as a lit edge rather than as flat swatches — the same
		## treatment the energy icons get, for consistency.
		var base: Color = Palette.faction_shade(f, "base")
		var bright: Color = Palette.faction_shade(f, "bright")
		draw_rect(Rect2(0, i * h, WIDTH, h + 0.5), base)
		draw_rect(Rect2(WIDTH - 1.5, i * h, 1.5, h + 0.5),
			Color(bright.r, bright.g, bright.b, 0.7))
