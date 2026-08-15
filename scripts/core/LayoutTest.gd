extends SceneTree

## Harness: layout + glyph safety.
##
## Two things that are invisible to every other harness because they are
## properties of what the UI *draws*, not of what the rules engine computes.
##
## **Glyphs.** The UI renders in bundled Inter, which like any text face has no
## arrows, no geometric shapes and no emoji. Any of those render as an empty box
## — and a box looks fine in the editor, fine in a code review, and broken only
## on screen. This walks every string literal the UI can print and asserts the
## theme font can draw it.
##
## The font is resolved off a live `Label` rather than loaded by path, so this
## checks whatever the game actually renders with. Changing the bundled font
## re-runs the whole check against the new one for free, which is the property
## that makes it worth reading the theme instead of hardcoding a path.
##
## **Layouts.** Every screen now builds in two shapes. Both have to construct
## without error and produce the nodes the rest of the screen expects, or the
## mobile path is a crash nobody hits until they open the game on a phone.
##
## Loaded by path, not by class name: under `--script` this file compiles before
## autoloads register, so naming a class that references `Palette` or `CardDB`
## fails the whole compile with "Identifier not found". Same reason
## CardViewTest.gd does it.

## 3 glyph-table + 9 source files + 4 screens x 2 layouts + 4 overflow.
const EXPECTED_ASSERTIONS := 34

## The phone viewport, in design units: ViewportFit.MOBILE_DESIGN_WIDTH by the
## height a 390x844 phone maps to at that scale.
const PHONE_VIEW := Vector2i(540, 1170)

var _passed := 0
var _failed := 0
var _count := 0


func _initialize() -> void:
	print("Layout + glyph harness\n")
	## Redirect the layout override away from the player's real display.cfg
	## before anything can write it. A verification script once wrote
	## `Override.ON` to the live file and left the actual game stuck in phone
	## mode on a desktop; the same rule DeckStore follows applies here.
	root.get_node("ViewportFit").use_sandbox_path("layout")

	_test_glyph_table()
	_test_ui_strings()
	_test_screens_build()
	await _test_no_phone_overflow()

	print("\n%d passed, %d failed" % [_passed, _failed])
	if _count != EXPECTED_ASSERTIONS:
		## A harness that crashes midway reports "0 failed" and exits 0, so the
		## count is the only thing that proves the file actually ran. See the
		## decision-log entry about GaiaTest running 7 of 40 assertions.
		print("MISCOUNT: ran %d assertions, expected %d" % [_count, EXPECTED_ASSERTIONS])
		quit(1)
	quit(1 if _failed > 0 else 0)


func _ok(label: String, cond: bool) -> void:
	_count += 1
	if cond:
		_passed += 1
		print("  ok   %s" % label)
	else:
		_failed += 1
		print("  FAIL %s" % label)


## The theme font every Control renders with by default.
func _theme_font() -> Font:
	var l := Label.new()
	root.add_child(l)
	var f: Font = l.get_theme_font("font")
	l.free()
	return f


func _drawable(f: Font, s: String) -> bool:
	for i in s.length():
		var cp := s.unicode_at(i)
		## Space and the ASCII range are always fine; has_char() is only
		## interesting above them.
		if cp > 32 and not f.has_char(cp):
			return false
	return true


func _test_glyph_table() -> void:
	print("Palette.GLYPH is drawable:")
	var f := _theme_font()
	_ok("a theme font exists", f != null)
	if f == null:
		return

	## Reached through the tree, not by name: under `--script` this file compiles
	## before autoloads register, so `Palette` is not an identifier yet.
	var pal = root.get_node("Palette")

	var bad: Array = []
	for key in pal.GLYPH:
		var g: String = pal.GLYPH[key]
		if not _drawable(f, g):
			bad.append("%s=%s" % [key, g])
	_ok("every glyph in the table renders (%d entries)" % pal.GLYPH.size(),
		bad.is_empty())
	if not bad.is_empty():
		print("       undrawable: %s" % ", ".join(bad))

	_ok("unknown keys return empty, not a box", pal.glyph("nope") == "")


## Walk the UI source and assert every double-quoted literal is drawable.
##
## Reading the source rather than the running scene is deliberate: a label built
## only in a rare branch (an error state, a disabled button's tooltip) would
## never be instantiated by a smoke test, and those are exactly the strings that
## ship broken because nobody looked at them.
func _test_ui_strings() -> void:
	print("\nNo undrawable characters in UI strings:")
	var f := _theme_font()
	var files := [
		"res://scripts/ui/Combat.gd",
		"res://scripts/ui/DeckSelect.gd",
		"res://scripts/ui/DeckBuilder.gd",
		"res://scripts/ui/MainMenu.gd",
		"res://scripts/ui/CardView.gd",
		"res://scripts/ui/CardInspector.gd",
		"res://scripts/ui/Tutorial.gd",
		"res://scripts/ui/Compendium.gd",
		"res://scripts/ui/SettingsButton.gd",
		"res://scripts/ui/DragScroll.gd",
		"res://scripts/ui/Motion.gd",
		"res://scripts/ui/Starfield.gd",
		"res://scripts/ui/Midline.gd",
		"res://scripts/ui/Crest.gd",
		"res://scripts/ui/LanePanel.gd",
		"res://scripts/ui/SlotSocket.gd",
		"res://scripts/ui/TowerGlyph.gd",
		"res://scripts/ui/FactionSpine.gd",
		"res://scripts/core/TutorialData.gd",
	]
	var lit := RegEx.new()
	lit.compile("\"(?:[^\"\\\\]|\\\\.)*\"")

	for path in files:
		var fa := FileAccess.open(path, FileAccess.READ)
		if fa == null:
			_ok("%s readable" % path.get_file(), false)
			continue
		var text := fa.get_as_text()
		fa.close()

		var offenders: Array = []
		var line_no := 0
		for line in text.split("\n"):
			line_no += 1
			## Comments hold ASCII diagrams and design notes that are read in an
			## editor and never rendered, so they are exempt.
			if line.strip_edges().begins_with("#"):
				continue
			for m in lit.search_all(line):
				var s: String = m.get_string()
				if not _drawable(f, s):
					offenders.append("L%d %s" % [line_no, s.substr(0, 40)])

		_ok("%s clean" % path.get_file(), offenders.is_empty())
		if not offenders.is_empty():
			for o in offenders:
				print("       %s" % o)


## Build every screen in both layouts.
##
## `_build()` is called directly rather than instantiating the scene, because
## Combat's `_ready` also starts a full AI game — which is slow and has nothing
## to do with whether the layout constructs.
func _test_screens_build() -> void:
	print("\nEvery screen builds in both layouts:")
	var VF = root.get_node("ViewportFit")

	var screens := {
		"MainMenu":   "res://scripts/ui/MainMenu.gd",
		"DeckSelect": "res://scripts/ui/DeckSelect.gd",
		"DeckBuilder": "res://scripts/ui/DeckBuilder.gd",
		"Combat":     "res://scripts/ui/Combat.gd",
	}

	for want_mobile in [false, true]:
		VF.mobile = want_mobile
		var shape := "phone" if want_mobile else "desktop"
		for name in screens:
			var scr = load(screens[name])
			var c := Control.new()
			c.set_script(scr)
			root.add_child(c)

			var built := true
			if name == "Combat":
				c.auto_resolve_choices = true
				c._build_ui()
				built = c._my_boards_row != null and c._hand_row != null \
					and c._end_turn_btn != null
				## The log drawer exists only in the phone build.
				built = built and ((c._log_toggle != null) == want_mobile)
			else:
				c._build()
				built = c.get_child_count() > 0

			_ok("%s builds (%s)" % [name, shape], built)
			c.free()


## Nothing in a phone layout may be wider than the phone.
##
## This is the assertion whose absence let "mobile mode" ship as pure zoom. The
## containers were told to be narrower and the cards inside them were not, so
## Combat's layout still demanded 931 units against a 540 viewport and the board
## simply ran off the right edge. Every screen looked fine in a headless build
## test, because *building* was never the problem.
##
## `get_combined_minimum_size().x` is the honest number: it is the width the
## layout cannot shrink below. Anything above the viewport is clipped content.
##
## The hand row is the one sanctioned exception — it lives in a horizontally
## scrolling container on purpose, because six hand cards are meant to be swiped
## through rather than shrunk to illegibility.
func _test_no_phone_overflow() -> void:
	print("\nNo phone layout exceeds the phone viewport:")
	var VF = root.get_node("ViewportFit")
	VF.mobile = true
	root.content_scale_size = PHONE_VIEW

	var screens := {
		"MainMenu": "res://scripts/ui/MainMenu.gd",
		"DeckSelect": "res://scripts/ui/DeckSelect.gd",
		"DeckBuilder": "res://scripts/ui/DeckBuilder.gd",
		"Combat": "res://scripts/ui/Combat.gd",
	}

	for name in screens:
		var c := Control.new()
		c.set_script(load(screens[name]))
		root.add_child(c)
		if name == "Combat":
			c.auto_resolve_choices = true
			c._build_ui()
		else:
			c._build()

		## Let the container tree settle; minimum sizes propagate over frames.
		for i in 4:
			await process_frame

		var offenders: Array = []
		_collect_wide(c, PHONE_VIEW.x, offenders)
		_ok("%s fits %d units wide" % [name, PHONE_VIEW.x], offenders.is_empty())
		for o in offenders:
			print("       %-46s min_w=%.0f" % [o[0], o[1]])

		c.free()

	VF.mobile = false


## Controls whose own minimum width exceeds `limit`, ignoring anything inside a
## ScrollContainer that scrolls horizontally — that content is reachable.
func _collect_wide(n: Node, limit: int, out: Array, path: String = "",
		scrollable: bool = false) -> void:
	var scrolls := scrollable
	if n is ScrollContainer:
		scrolls = scrolls or n.horizontal_scroll_mode != ScrollContainer.SCROLL_MODE_DISABLED

	if n is Control and not scrollable:
		var w: float = n.get_combined_minimum_size().x
		if w > limit:
			out.append([path + "/" + n.get_class(), w])

	for ch in n.get_children():
		_collect_wide(ch, limit, out, path + "/" + n.get_class(), scrolls)
