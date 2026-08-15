class_name DeckArtTile
extends Control

## A deck's hero card as a small art plate: the card's emblem on a ground tinted
## by its faction.
##
## The first attempt at this shrank a whole `CardView` to 74px and it was mush —
## a card frame is a *layout* of nine small elements, and scaling it down does
## not simplify it, it just makes every element illegible at once. What a deck
## row actually needs is the one thing that identifies the deck at a glance,
## which is the emblem: it was drawn at 128px to be read small, and it is the
## only part of a card that survives this size.
##
## This is the same reasoning that gave the phone board its reduced frame. The
## rule is that a card must never *contradict* itself in two places; a plate
## that only ever omits is consistent with it, and the full card is one click
## away in the builder's inspector.
##
## It carries no caption. The first version printed the card's name across the
## foot, which clipped to "pyrean Senti" at this width and was redundant anyway
## — the deck's own name sits immediately beside it, and the card's name is in
## the tooltip. The emblem is the whole point; a caption only crowds it.

const RADIUS := 6.0

var _card: CardData
var _art: Texture2D


func _init(card: CardData, height: float) -> void:
	_card = card
	## 3:4, matching the card frames everywhere else in the game, so a deck row
	## reads as holding a card rather than a cropped picture.
	custom_minimum_size = Vector2(round(height * 0.75), height)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	tooltip_text = card.name
	_art = CardArt.get_art(card.id)


func _draw() -> void:
	if size.x <= 0.0 or size.y <= 0.0:
		return

	var r := Rect2(Vector2.ZERO, size)
	var deep: Color = Palette.faction_shade(_card.faction, "deep")
	var base: Color = Palette.faction_shade(_card.faction, "base")

	## Ground: the faction's deep tone over the panel colour, so the plate is
	## recognisably the deck's colour before the emblem resolves.
	draw_rect(r, Palette.PANEL.lerp(deep, 0.55))

	## The emblem, square and centred, filling the plate less a small inset.
	if _art != null:
		var box := Rect2(Vector2(3, 3), size - Vector2(6, 6))
		var side: float = minf(box.size.x, box.size.y)
		draw_texture_rect(_art, Rect2(
			box.position + (box.size - Vector2(side, side)) * 0.5,
			Vector2(side, side)), false)

	## A lit top edge and a faction-toned border: the same "struck material"
	## treatment the energy hexagons and the faction spine get.
	draw_rect(r, base.darkened(0.35), false, 1.0)
	draw_line(Vector2(1, 0.5), Vector2(size.x - 1, 0.5),
		Color(base.r, base.g, base.b, 0.5), 1.0)
