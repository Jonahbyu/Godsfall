extends Node

## Autoload: ViewportFit
##
## Owns two related things: how large the UI is drawn, and whether screens use
## their single-column ("mobile") layout.
##
## ## Why this exists
##
## The project designs at 1440x900 with `stretch/aspect = "expand"`. Expand gives
## the viewport the window's *real* aspect at a fixed scale, which is right on a
## desktop — a wider window should mean more room, not bigger cards — and fatal
## on a phone, where it means the viewport is genuinely 390 units wide against a
## combat screen needing ~1180. Nothing gets scaled; the board and the side panel
## are simply off-screen with no way to reach them.
##
## Switching the project to `aspect = "keep"` would fix mobile and regress the
## case that actually gets played, letterboxing a real monitor back to 1440x900.
## So `expand` stays and this node controls `content_scale_size`, which is the
## reference resolution expand measures against.
##
## ## The two jobs, and why they are one node
##
## **Scale.** A smaller `content_scale_size` means the same window holds fewer
## design units, so everything is drawn *bigger*. That is the whole of "zoom in".
##
## **Layout.** Drawing bigger costs width, and the desktop layouts are built from
## fixed-width columns that cannot survive losing it. So the zoom is useless on
## its own: raising the scale without restacking just pushes content off the
## other edge. `mobile` is what tells each screen to go single-column and give
## the width back.
##
## They live together because they are one decision made from one measurement,
## and a screen that rebuilt for one without the other would be wrong either way.

## The smallest viewport the desktop UI fits in, in design units.
##
## Width is set by the combat screen, the tightest of the four: two board rows of
## three 132px slots (792) + inter-board separation + the 320px action/log column
## + margins. Height is set by that same screen stacking two board rows (196
## each), two throne labels, the pool bar, and a 262px hand card plus its 26px
## hover lift.
const MIN_DESIGN := Vector2i(1180, 780)

## The reference *width* mobile mode targets. Everything is drawn as though the
## screen were this many design units across, so a 390px phone renders the UI at
## roughly 0.72x instead of the 0.33x a 1180-wide layout would force — which is
## the difference between "small" and "unreadable".
##
## 540 rather than something smaller because the hand card is 168 design units
## wide and three of them plus separation is the narrowest useful hand row.
const MOBILE_DESIGN_WIDTH := 540

## Below this window width the device is treated as a phone. A question about the
## *device*, not the design, so it matches the common tablet breakpoint rather
## than anything in the layout.
const NARROW_WIDTH := 820

## Manual override of the automatic detection.
##   AUTO  - follow the window width (the default)
##   ON    - force mobile mode, for testing the layout on a desktop
##   OFF   - force the desktop layout, e.g. on a tablet that is wide enough
enum Override { AUTO, ON, OFF }

## Where the layout override persists.
##
## A **variable**, not a const, so a harness can redirect it — the same rule
## `DeckStore.save_path` follows, and for the same reason. This was learned the
## hard way twice already for decks, and then a third time here: a verification
## script wrote `Override.ON` to the real file, failed to clean it up, and left
## the actual game stuck in phone mode on a desktop. A test that shares a mutable
## file with the user is a data-loss bug, not a hygiene nitpick.
##
## Any harness touching this MUST call `use_sandbox_path()` before it writes.
var save_path: String = "user://display.cfg"


## Point persistence at a throwaway file. Call before any test writes.
func use_sandbox_path(tag: String) -> void:
	save_path = "user://test_display_%s.cfg" % tag

## True while screens should use their single-column layout. Read by every
## screen at build time; see `layout_changed`.
var mobile: bool = false

var _override: int = Override.AUTO

## Emitted when `mobile` flips, so a screen already on-screen can rebuild rather
## than waiting to be re-entered. Rotating a phone is exactly this case, and so
## is flipping the override from the menu.
signal layout_changed(is_mobile: bool)


func _ready() -> void:
	_load()
	## Nothing below should run in a headless harness: there is no real window,
	## and the harnesses drive the rules engine rather than the viewport.
	if DisplayServer.get_name() == "headless":
		return
	get_tree().root.size_changed.connect(_apply)
	_apply()


## The current override setting, for the menu control that edits it.
func override_mode() -> int:
	return _override


## Change the override and re-apply immediately. Persisted, because a player who
## forced a layout meant it for more than one session.
func set_override(mode: int) -> void:
	if mode == _override:
		return
	_override = mode
	_save()
	if DisplayServer.get_name() != "headless":
		_apply()


## Whether the window is narrow enough that AUTO would pick mobile. Exposed so
## the settings UI can label the AUTO option with what it currently resolves to.
func auto_would_be_mobile() -> bool:
	if DisplayServer.get_name() == "headless":
		return false
	return _window_size().x < NARROW_WIDTH


## The real window, in physical pixels.
##
## NOT `root.get_visible_rect()`, which returns the *viewport* — a value this
## node sets itself. Measuring it made the detection self-latching: entering
## phone mode shrank the viewport to 540, the next measurement saw 540 < 820 and
## concluded "phone" again, so a 1440-wide desktop window could never get back
## out. The window is the input; the viewport is the output, and reading your own
## output as your input is how a control loop sticks.
func _window_size() -> Vector2:
	var w := DisplayServer.window_get_size()
	if w.x > 0 and w.y > 0:
		return Vector2(w)
	return get_tree().root.get_visible_rect().size


## Recompute the reference resolution and the layout flag from the window size.
##
## Called on every resize, which on the web includes rotating a phone and the
## browser's URL bar sliding away — both of which change the canvas size with no
## other notification.
func _apply() -> void:
	var root := get_tree().root
	var win := _window_size()

	## A zero-sized window happens for a frame during startup on some platforms,
	## and dividing by it below would produce an infinite scale.
	if win.x <= 0.0 or win.y <= 0.0:
		return

	var want_mobile := win.x < NARROW_WIDTH
	if _override == Override.ON:
		want_mobile = true
	elif _override == Override.OFF:
		want_mobile = false

	if want_mobile:
		## Target a fixed design width and let height follow the real aspect, so
		## the UI is drawn at a consistent size on every phone and only the
		## amount of vertical content differs. Height is not clamped upward here
		## because the mobile screens scroll.
		var s := float(MOBILE_DESIGN_WIDTH) / win.x
		root.content_scale_size = Vector2i(
			MOBILE_DESIGN_WIDTH, int(round(win.y * s)))
	else:
		## Desktop: clamp to the layout's minimum so a small window scales down
		## rather than clipping, and otherwise pass the window straight through —
		## which is exactly what expand computes on its own.
		var shortfall := maxf(
			float(MIN_DESIGN.x) / win.x,
			float(MIN_DESIGN.y) / win.y,
		)
		var scale := maxf(shortfall, 1.0)
		root.content_scale_size = Vector2i(
			int(round(win.x * scale)), int(round(win.y * scale)))

	_set_mobile(want_mobile)


func _set_mobile(value: bool) -> void:
	if value == mobile:
		return
	mobile = value
	layout_changed.emit(mobile)


func _load() -> void:
	var f := FileAccess.open(save_path, FileAccess.READ)
	if f == null:
		return
	var text := f.get_as_text()
	f.close()

	## Parsed through a JSON instance rather than `JSON.parse_string`, which
	## prints a parse error to the console on bad input. A corrupt display.cfg is
	## a recoverable nothing — we fall back to AUTO — but the launcher scrapes
	## stderr into `logs/errors.log`, which is meant to hold only problems that
	## are still outstanding. A settings file the user can clear by any means
	## must not leave a permanent-looking error there.
	var json := JSON.new()
	if json.parse(text) != OK:
		return
	var data: Variant = json.data
	if typeof(data) != TYPE_DICTIONARY:
		return
	var m: int = int(data.get("layout_override", Override.AUTO))
	if m >= 0 and m <= Override.OFF:
		_override = m


func _save() -> void:
	## A headless process is never a player, so it must never persist a layout
	## override to the live file. Sandboxing via `use_sandbox_path()` is still
	## the rule, but it is opt-in — a throwaway verification script has to
	## remember to call it, and three separate times one did not, leaving the
	## real game forced into phone mode on a 1440-wide desktop. The symptom is
	## the worst part: it looks exactly like the layout bug that had just been
	## fixed, so the obvious diagnosis is the wrong one.
	##
	## This makes the unsafe case unreachable rather than merely discouraged.
	## A harness that genuinely wants to exercise persistence sandboxes the path
	## first, and is then writing a test file this guard does not care about.
	if DisplayServer.get_name() == "headless" and not save_path.contains("test_"):
		return

	var f := FileAccess.open(save_path, FileAccess.WRITE)
	if f == null:
		return
	f.store_string(JSON.stringify({"layout_override": _override}))
	f.close()
