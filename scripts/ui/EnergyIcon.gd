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
##
## ## The faction mark
##
## Each faction's token carries a **distinct drawn mark** as well as its colour, so
## colour is never the only channel carrying which energy this is. That is the same
## correction `KEYWORD_COLORS` needed: at the 7px a board card renders a cost row
## at, Void's slate and Wilds' brown are one grey, and to a colourblind player the
## whole four-colour system collapses. A shape survives both.
##
## The marks are one closed figure each, never linework, for the reason the wave-2
## card art learned the hard way: a thin cross or a line with two dots is not a
## silhouette at this size. Each one restates its faction's own visual grammar so
## the token agrees with the card art beside it — Hel a bone-notched skull dome,
## Heaven a rayed sun, Void a hole with a hot rim, Gaia a leaf.
##
## Below `MARK_MIN_PX` the mark is skipped and the token draws as a plain lit
## hexagon — which is every board card, by design. A figure inside a 7px hexagon is
## mud that reads as dirt on the token rather than as a symbol, which is worse than
## no symbol at all. The board card keeps colour and count; the hand card, the
## inspector and the deck builder get the mark.

## Below this size the faction mark is skipped and the token draws as a plain lit
## hexagon.
##
## 9 is chosen against the sizes the game actually renders, not as a round number.
## `CardView.METRICS["icon_size"]` is **10 in hand, 9 on a phone hand, and 7 on the
## board**, so the mark draws on every hand card and is skipped on every board card
## — which is the right split. The hand is where you decide *which* energy a card
## demands and the card is large enough to say so; the board card is a glance read
## where the colour and the count are the whole message, and a figure inside a 7px
## hexagon is a smudge that reads as dirt on the token rather than as a symbol.
##
## Note this is measured on the **unscaled** size, which is the only size `_draw`
## can see. The inspector scales the whole `CardView` node by 1.55, so its icons are
## built at 10 and rendered at ~15.5 — they clear this because 10 does, not because
## the drawn size is measured. That is the behaviour wanted anyway: the inspector is
## the screen with the most room for the mark.
const MARK_MIN_PX := 9.0

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

	## The faction mark, under the rim so the rim still closes the silhouette.
	if not colorless and min(size.x, size.y) >= MARK_MIN_PX:
		_draw_mark(c, r, deep, bright)

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


## The faction's mark, centred in the token.
##
## Drawn in `deep` — the ramp's shadowed shade — so the mark reads as struck INTO
## the token rather than sitting on top of it, and so it never competes with the
## bright rim for the silhouette. `bright` is passed for the one mark that needs a
## light source of its own (Void's rim).
##
## Coordinates are fractions of `r`, so a mark is identical at every size the game
## renders a token at. `_mark_shape` returns the polygon; anything a single closed
## polygon cannot express belongs in its own branch rather than as added linework.
func _draw_mark(c: Vector2, r: float, deep: Color, bright: Color) -> void:
	var key := faction.to_lower()

	## Void is the exception, and deliberately so: the faction is drawn as an
	## absence everywhere else in the game (see the card-art grammar), so its mark
	## is a hole with a hot rim rather than a figure. Filling it with `deep` alone
	## would be invisible against a slate token, which is exactly why it gets the
	## rim treatment the emblems use.
	if key == "void":
		var hole := _circle(c, r * 0.42, 10)
		draw_colored_polygon(hole, Color(0, 0, 0, 0.72))
		var ring := PackedVector2Array(hole)
		ring.append(hole[0])
		draw_polyline(ring, Color(bright.r, bright.g, bright.b, 0.85), max(1.0, r * 0.11), true)
		return

	## Drawn in a darkened `deep` at full alpha rather than `deep` itself. Heaven's
	## ramp is a pale gold whose `deep` is only a few shades under its `base`, so at
	## 0.88 alpha the mark washed out to a suggestion on exactly the token that most
	## needs to be told apart from Gaia's. Darkening the shade is what makes one
	## treatment work across all eight ramps instead of needing a per-faction alpha.
	var shape := _mark_shape(key, c, r)
	if shape.size() >= 3:
		draw_colored_polygon(shape, deep.darkened(0.35))


## One closed polygon per faction, in units of `r` around `c`.
##
## Each restates its faction's card-art grammar so a token agrees with the emblem
## on the card beside it. Kept to one figure each — the wave-2 art pass established
## that a silhouette this small needs exactly one object, and that thin linework
## is not one.
func _mark_shape(key: String, c: Vector2, r: float) -> PackedVector2Array:
	match key:
		"hel":
			## A bone: a narrow shaft with a lobed knuckle at each end, drawn on the
			## diagonal so it fills a hexagon rather than a rectangle.
			##
			## This was a skull first and it did not work. A skull is identified by
			## its EYE SOCKETS, which are interior negative space — and a single
			## filled polygon has no interior, so what rendered was a domed blob at
			## every size tested. A bone is the other canonical Hel shape and its
			## identity is entirely in its outline, which is the only thing that
			## survives here. Same lesson the wave-2 emblems recorded: at this size
			## the silhouette has to BE the subject, not contain it.
			return _poly(c, r, [
				[-0.50, -0.28], [-0.34, -0.44], [-0.18, -0.34], [0.22, 0.06],
				[0.38, -0.04], [0.52, 0.14], [0.36, 0.30], [0.20, 0.20],
				[-0.20, -0.20], [-0.36, -0.10],
			])
		"heaven":
			## A rayed sun: an eight-pointed star. Heaven's emblems are radially
			## symmetric and lit from within, and radial symmetry is the one thing
			## that survives being shrunk in any direction.
			return _star(c, r * 0.50, r * 0.20, 8)
		"gaia":
			## A leaf: two mirrored arcs meeting at a tip and a stem. Gaia is
			## growth, and a leaf is the one plant shape that is unambiguous
			## without needing a stalk drawn under it.
			return _poly(c, r, [
				[0.00, -0.52], [0.24, -0.24], [0.32, 0.08], [0.16, 0.38],
				[0.00, 0.50], [-0.16, 0.38], [-0.32, 0.08], [-0.24, -0.24],
			])
		"forge":
			## A flame: a leaning teardrop. Forge is fire and the aggro slot.
			return _poly(c, r, [
				[0.00, -0.54], [0.22, -0.18], [0.30, 0.14], [0.14, 0.42],
				[-0.12, 0.44], [-0.30, 0.18], [-0.20, -0.12], [-0.06, -0.30],
			])
		"tempest":
			## A bolt: the classic zigzag, closed. Tempest is storm and speed.
			return _poly(c, r, [
				[0.10, -0.52], [-0.30, 0.06], [-0.04, 0.06], [-0.16, 0.52],
				[0.30, -0.10], [0.04, -0.10], [0.24, -0.52],
			])
		"wyrd":
			## A spiral wedge read as a rune-mark: a four-pointed star turned to
			## sit on its diagonals, so it never reads as Heaven's eight-pointed
			## one at a glance.
			return _star(c, r * 0.54, r * 0.16, 4, PI * 0.25)
		"wilds":
			## A fang: one broad tooth, tapering to a point downward.
			##
			## This was a three-talon claw and it read as a CROWN — the talons rose
			## from a solid base, which is a crown's exact silhouette, so the mark
			## said "Heaven" on the brownest token in the game. Pointing them down
			## instead would have read as a comb. One fang is unambiguous, and it is
			## the same correction the wave-2 art needed twice: one object, not three
			## thin ones.
			return _poly(c, r, [
				[-0.30, -0.44], [0.30, -0.44], [0.22, -0.06], [0.08, 0.34],
				[0.00, 0.52], [-0.08, 0.34], [-0.22, -0.06],
			])
	return PackedVector2Array()


## A polygon from fractional-of-`r` coordinate pairs.
func _poly(c: Vector2, r: float, coords: Array) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for xy in coords:
		pts.append(c + Vector2(float(xy[0]), float(xy[1])) * r)
	return pts


## An n-pointed star alternating between `outer` and `inner` radius.
func _star(c: Vector2, outer: float, inner: float, points: int, rot: float = 0.0) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in points * 2:
		var rad: float = outer if i % 2 == 0 else inner
		var a: float = rot - PI * 0.5 + PI * float(i) / float(points)
		pts.append(c + Vector2(cos(a), sin(a)) * rad)
	return pts


## An approximated circle. `segments` is kept low because these are drawn at
## 11-20px and nobody can see the difference above about ten sides.
func _circle(c: Vector2, rad: float, segments: int) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in segments:
		var a: float = TAU * float(i) / float(segments)
		pts.append(c + Vector2(cos(a), sin(a)) * rad)
	return pts
