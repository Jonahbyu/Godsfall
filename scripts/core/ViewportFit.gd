extends Node

## Autoload: ViewportFit
##
## Keeps the game legible on a screen narrower or shorter than the layout needs
## — phones in particular, where the browser window can be 390 CSS pixels wide
## against a combat screen that needs ~1180.
##
## The problem this solves is specific to `stretch/aspect = "expand"`. Expand
## gives the viewport the window's *real* aspect ratio at a fixed scale, which is
## the right behaviour on a desktop monitor: a wider window means more room, not
## bigger cards. On a phone it means the viewport is genuinely 390 units wide,
## so the board rows (2 boards x 3 slots x 132px) and the 320px log panel are
## simply off-screen with no way to reach them. Nothing is scaled down, because
## expand's whole contract is that it does not scale.
##
## Switching the project to `aspect = "keep"` would fix mobile and regress the
## desktop, which is the case that actually gets played: keep letterboxes to
## 1440x900 and throws away the extra width a real monitor has.
##
## So the fix is to keep `expand` and clamp it. `content_scale_size` is the
## reference resolution expand measures against, and Godot recomputes the scale
## factor whenever it changes. Setting it to a size that is never smaller than
## MIN_DESIGN means a narrow window gets a *scaled down* viewport that still
## holds the whole layout, while a window at or above the minimum keeps the
## native 1:1 expand behaviour it has today.
##
## Desktop is untouched by construction: at 1440x900 the clamp is inactive and
## `content_scale_size` is set to exactly the window size, which is what expand
## computes for itself anyway.

## The smallest viewport the UI actually fits in, in design units.
##
## Width is set by the combat screen, which is the tightest of the four: two
## board rows of three 132px slots (792) + inter-board separation + the 320px
## action/log column + margins. 1180 is that sum with the slack the hand row and
## the pool bar need at their minimum sizes.
##
## Height is set by the same screen stacking two board rows (196 each), two
## throne labels, the pool bar, and a 262px hand card plus its 26px hover lift.
const MIN_DESIGN := Vector2i(1180, 780)

## Below this window width the device is treated as a phone and the UI is told
## to compact itself. Matches the common tablet breakpoint rather than anything
## in the layout — it is a question about the *device*, not about the design.
const NARROW_WIDTH := 820

## True while the window is narrow enough that screens should use their compact
## layout. Read by Combat and DeckBuilder; see `compactness_changed`.
var compact: bool = false

## Emitted when `compact` flips, so a screen already on-screen can rebuild rather
## than waiting to be re-entered. Rotating a phone is exactly this case.
signal compactness_changed(is_compact: bool)


func _ready() -> void:
	## Nothing here should run in a headless harness: there is no real window, and
	## the harnesses drive the rules engine rather than the viewport.
	if DisplayServer.get_name() == "headless":
		return

	get_tree().root.size_changed.connect(_apply)
	_apply()


## Recompute the reference resolution from the window's current size.
##
## Called on every resize, which on the web includes rotating a phone and the
## browser's URL bar sliding away — both of which change the canvas size without
## any other notification.
func _apply() -> void:
	var root := get_tree().root
	var win := root.get_visible_rect().size

	## A zero-sized window happens for a frame during startup on some platforms;
	## dividing by it below would produce an infinite scale.
	if win.x <= 0.0 or win.y <= 0.0:
		return

	## How much the window falls short of the minimum on each axis, as a factor
	## >= 1. Taking the larger of the two means the axis that is *most* cramped
	## decides the scale, so neither ends up clipped.
	var shortfall := maxf(
		float(MIN_DESIGN.x) / win.x,
		float(MIN_DESIGN.y) / win.y,
	)

	## At or above the minimum on both axes there is no shortfall, and the
	## reference size is just the window — which is what expand does natively.
	var scale := maxf(shortfall, 1.0)

	root.content_scale_size = Vector2i(
		int(round(win.x * scale)),
		int(round(win.y * scale)),
	)

	_set_compact(win.x < NARROW_WIDTH)


func _set_compact(value: bool) -> void:
	if value == compact:
		return
	compact = value
	compactness_changed.emit(compact)
