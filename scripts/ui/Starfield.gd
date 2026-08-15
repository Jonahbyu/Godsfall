class_name Starfield
extends Control

## The cosmic backdrop: a vertical depth wash with a scatter of stars over it.
##
## Godsfall's factions are cosmic domains and its throne is what remains when
## they fall, but every screen sat on one flat near-black fill — which reads as
## "dark UI theme", not as space. This is the cheapest thing that fixes that: no
## texture to download, no shader, one `_draw` of gradient bands and points.
##
## ## Why bands rather than a real gradient
##
## `GradientTexture2D` cannot be used in a code-built `StyleBoxFlat` here — the
## assignment hangs under `--headless`, which every harness runs (see
## `Palette.lit_style`). Drawing horizontal bands in `_draw` has no such problem,
## because it never leaves the CPU until the frame is actually rasterised, and a
## headless run simply never calls `_draw`.
##
## ## Why the stars are deterministic
##
## Seeded from a fixed value, so the field is identical on every build and every
## reload. A backdrop that reshuffles whenever a screen rebuilds — which Combat
## does on every state change — would twinkle distractingly at exactly the
## moments the player is trying to read the board.

## How many bands the wash is drawn in. 24 is past the point where banding is
## visible at any window size the game runs at, and cheap enough to redraw on
## every resize.
const BANDS := 24
const STAR_COUNT := 110
const SEED := 20260814

## Stars are dimmer than they look like they should be. At full brightness a
## starfield competes with the cards for attention, which is exactly backwards:
## this is the furthest thing from the player and must read as depth, not detail.
const STAR_MIN_ALPHA := 0.05
const STAR_MAX_ALPHA := 0.34

var _stars: Array = []


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_seed_stars()


## Positions are stored in 0..1 space so a resize repositions them without
## regenerating — which is what keeps the field stable across Combat's rebuilds.
func _seed_stars() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED
	_stars.clear()
	for i in STAR_COUNT:
		_stars.append({
			"p": Vector2(rng.randf(), rng.randf()),
			"r": rng.randf_range(0.6, 1.7),
			"a": rng.randf_range(STAR_MIN_ALPHA, STAR_MAX_ALPHA),
			## A few stars take the accent hue rather than white, which is what
			## stops the field reading as grey noise.
			"tint": rng.randf() < 0.18,
		})


func _draw() -> void:
	if size.x <= 0.0 or size.y <= 0.0:
		return

	## The wash: deep at the top, lifting toward the horizon, settling again at
	## the bottom. Two stops rather than one so the middle of the screen — where
	## the board sits — is the lightest part, which frames the play area without
	## drawing a frame.
	var top: Color = Palette.VOID_DEEP
	var mid: Color = Palette.BG
	var bot: Color = Palette.VOID_DEEP.lerp(Palette.BG, 0.45)

	var h: float = size.y / float(BANDS)
	for i in BANDS:
		var t: float = float(i) / float(BANDS - 1)
		var c: Color = top.lerp(mid, t / 0.6) if t < 0.6 else mid.lerp(bot, (t - 0.6) / 0.4)
		draw_rect(Rect2(0.0, i * h, size.x, h + 1.0), c)

	for s in _stars:
		var p: Vector2 = Vector2(s["p"].x * size.x, s["p"].y * size.y)
		var base: Color = Palette.ACCENT_GLOW if s["tint"] else Color.WHITE
		draw_circle(p, s["r"], Color(base.r, base.g, base.b, s["a"]))


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		queue_redraw()
