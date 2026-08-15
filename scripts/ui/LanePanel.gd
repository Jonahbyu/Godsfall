class_name LanePanel
extends PanelContainer

## A board's playing surface.
##
## Each player has two boards and each board is one lane of three slots. Those
## lanes were flat `PANEL`-coloured rectangles, identical for both players, which
## is why the battlefield read as "six containers" rather than as ground being
## fought over.
##
## What this adds, all drawn:
##
##   * A **surface** that is lighter at the far edge and darker at the near one,
##     so the lane reads as a plane receding rather than as a flat card.
##   * **Ownership tint**, a faint warm/cool bias toward the owner. The single
##     most important read on this screen is whose half you are looking at, and
##     it should not require parsing the contents.
##   * A **front edge**: a bright line along the side facing the enemy. It is the
##     boundary that matters — the line units are defending — and drawing it makes
##     the two lanes face each other instead of merely sitting near each other.
##
## Deliberately *not* a texture. Same reasoning as `Starfield` and the card art:
## drawn geometry is regenerable, cannot drift from the palette, and adds nothing
## to the download.

## How strongly the surface is tinted toward its owner. Small — this is a ground
## the cards sit on, and a saturated lane would compete with them.
const OWNER_TINT := 0.10
const BANDS := 10

var _enemy: bool = false
var _compact: bool = false


func _init(is_enemy: bool, compact: bool = false) -> void:
	_enemy = is_enemy
	_compact = compact
	mouse_filter = Control.MOUSE_FILTER_PASS
	var s := Palette.panel_style(Color(0, 0, 0, 0), Palette.BORDER, 1, 8)
	## The container itself draws nothing; `_draw` paints under the children.
	var pad: int = Palette.SPACE_XS if compact else Palette.SPACE_MD
	s.content_margin_left = pad
	s.content_margin_right = pad
	s.content_margin_top = Palette.SPACE_XS + 1 if compact else Palette.SPACE_SM + 1
	s.content_margin_bottom = Palette.SPACE_XS + 1 if compact else Palette.SPACE_SM + 1
	add_theme_stylebox_override("panel", s)


## The lane's base colour: the panel ground biased toward its owner.
##
## The enemy runs cool and slightly darker, you run marginally warmer and
## lighter. This is the same convention the card frames already use for
## `enemy`, so the two agree instead of each inventing their own.
func _ground() -> Color:
	var base: Color = Palette.PANEL
	if _enemy:
		return base.lerp(Palette.TOWER.darkened(0.35), OWNER_TINT)
	return base.lerp(Palette.GOLD.darkened(0.55), OWNER_TINT * 0.8)


func _draw() -> void:
	if size.x <= 0.0 or size.y <= 0.0:
		return

	var g: Color = _ground()
	var far: Color = g.lightened(0.10)
	var near: Color = g.darkened(0.14)

	## The surface, banded from far edge to near edge. "Far" is the top of your
	## lane and the bottom of theirs, because the two boards face each other
	## across the midline — the light comes from the middle of the table.
	var h: float = size.y / float(BANDS)
	for i in BANDS:
		var t: float = float(i) / float(BANDS - 1)
		var f: float = (1.0 - t) if _enemy else t
		draw_rect(Rect2(0.0, i * h, size.x, h + 1.0), near.lerp(far, f))

	## The front edge: the side facing the enemy. Yours is on top, theirs on the
	## bottom, so the two bright lines end up adjacent across the midline and the
	## board reads as two armies at a contact line.
	var y: float = 0.5 if not _enemy else size.y - 1.0
	var edge: Color = Palette.TOWER if _enemy else Palette.GOLD
	draw_rect(Rect2(0.0, y, size.x, 1.5), Color(edge.r, edge.g, edge.b, 0.42))
