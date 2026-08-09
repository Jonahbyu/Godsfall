extends SceneTree

## Total assertions this harness is expected to run; see the check at
## the end of the run. Update deliberately when assertions change.
const EXPECTED_ASSERTIONS := 62

## Structural assertions on the card frame.
##
## These check the *shape* of what CardView builds — that the header exists, that
## HP is in the right-hand cell, that a keyword chip disappears when its charge is
## spent. They deliberately do not check pixel positions, which would break on
## every metric tweak; they check that the nodes a player needs to read are
## present and carry the right text.
##
##   godot --headless --path <project> --script res://scripts/core/CardViewTest.gd

## CardView.gd cannot be referenced by its class_name here. Under `--script`, the
## script is compiled before the autoloads register, and CardView's body
## references the `Palette` autoload — so resolving `CardView` drags in an
## identifier that does not exist yet and the whole compile fails. Loading it by
## path sidesteps the compile-time reference; the cost is that `CardView.Mode` is
## unreachable too, hence these constants.
##
## Verified by probe, not assumed: a test using the bare `CardView` identifier
## fails with "Compile Error: Identifier not found: Palette at CardView.gd".
const CARD_VIEW := "res://scripts/ui/CardView.gd"
const MODE_HAND := 0    ## CardView.Mode.HAND
const MODE_BOARD := 1   ## CardView.Mode.BOARD

var _pass := 0
var _fail := 0


## Build a CardView without naming its class. Keeps the mode magic numbers in one
## place, so a reordered Mode enum breaks here rather than in every test.
func make_view(c: CardData, u, mode_id: int) -> Control:
	return load(CARD_VIEW).new(c, u, mode_id)


func check(ok: bool, label: String) -> void:
	if ok:
		_pass += 1
	else:
		_fail += 1
		print("  FAIL %s" % label)


## Depth-first search for a Label whose text contains `needle`.
func find_label(n: Node, needle: String) -> Label:
	if n is Label and (n as Label).text.contains(needle):
		return n
	for c in n.get_children():
		var got := find_label(c, needle)
		if got != null:
			return got
	return null


## Every Label under a node, in tree order.
func all_labels(n: Node, out: Array = []) -> Array:
	if n is Label:
		out.append(n)
	for c in n.get_children():
		all_labels(c, out)
	return out


func find_node_named(n: Node, want: String) -> Node:
	if n.name == want:
		return n
	for c in n.get_children():
		var got := find_node_named(c, want)
		if got != null:
			return got
	return null


func _initialize() -> void:
	## Under --script the CardDB autoload exists but is not resolvable as a typed
	## identifier at compile time (see HeavenTest.gd / RulesTest.gd) — go through
	## the node directly instead.
	var db = root.get_node_or_null("CardDB")
	if db == null:
		db = load("res://scripts/core/CardDB.gd").new()
		db.name = "CardDB"
		root.add_child(db)
	if db._cards.is_empty():
		db._load()

	## CardView.gd references the Palette autoload (scripts/ui/Theme.gd) by its
	## global name too. Same fix as CardDB above.
	if root.get_node_or_null("Palette") == null:
		var pal = load("res://scripts/ui/Theme.gd").new()
		pal.name = "Palette"
		root.add_child(pal)

	print("\n=== CardView layout test ===\n")

	await _test_header(db)
	await _test_evolve_strip(db)
	await _test_keyword_chips(db)
	await _test_ability_banner(db)
	await _test_attack_rows(db)
	await _test_footer(db)
	await _test_non_units(db)

	## A harness that errors out mid-run still reports "0 failed", because an
	## assertion that never RUNS cannot fail — that is how the Gaia harness passed
	## for several rounds while executing 7 of its 40 checks. Pinning the total
	## makes a crash that skips whole test functions a failure instead of silence.
	## Update this number deliberately when adding or removing assertions.
	if _pass + _fail != EXPECTED_ASSERTIONS:
		print("FAIL: expected %d assertions, ran %d — a test crashed before finishing."
			% [EXPECTED_ASSERTIONS, _pass + _fail])
		_fail += 1

	print("\n%d passed, %d failed\n" % [_pass, _fail])
	quit(1 if _fail > 0 else 0)


func _test_header(db) -> void:
	var card: CardData = db.get_card("charnel_colossus")
	check(card != null, "fixture card charnel_colossus exists")
	if card == null:
		return

	var view := make_view(card, null, MODE_HAND)
	root.add_child(view)
	await process_frame

	## HP lives in its own named node so the layout can move without the test
	## chasing it, and so Combat/DeckBuilder could address it if they ever need to.
	var hp := find_node_named(view, "HPLabel") as Label
	check(hp != null, "header has an HPLabel")
	if hp != null:
		check(hp.text.contains("90"), "HP label shows printed HP (90), got '%s'" % hp.text)

	var stage := find_node_named(view, "StageLabel") as Label
	check(stage != null, "header has a StageLabel")
	if stage != null:
		check(stage.text.to_upper().contains("BASIC"), "stage reads BASIC, got '%s'" % stage.text)

	check(find_label(view, "Charnel Colossus") != null, "name is present")

	view.queue_free()
	await process_frame


func _test_evolve_strip(db) -> void:
	## A Stage 1 or Stage 2 that names a base form shows the strip.
	var evolved: CardData = null
	for cid in db.all_ids():
		var c: CardData = db.get_card(cid)
		if c == null:
			continue
		if c.is_unit() and c.evolves_from != "" and db.get_card(c.evolves_from) != null:
			evolved = c
			break
	check(evolved != null, "found an evolving unit to test with")
	if evolved == null:
		return

	var base: CardData = db.get_card(evolved.evolves_from)

	var view := make_view(evolved, null, MODE_HAND)
	root.add_child(view)
	await process_frame

	var strip := find_node_named(view, "EvolveStrip") as Label
	check(strip != null, "evolving unit has an EvolveStrip")
	if strip != null:
		check(strip.text.contains(base.name),
			"strip names the base form '%s', got '%s'" % [base.name, strip.text])
	view.queue_free()
	await process_frame

	## A Basic has no base form, so it must NOT reserve a strip — an empty row
	## would waste the scarcest thing on the board card, vertical space.
	var basic: CardData = db.get_card("charnel_colossus")
	var bview := make_view(basic, null, MODE_HAND)
	root.add_child(bview)
	await process_frame
	check(find_node_named(bview, "EvolveStrip") == null, "a Basic has no EvolveStrip")
	bview.queue_free()
	await process_frame


func _test_keyword_chips(db) -> void:
	var card: CardData = db.get_card("charnel_colossus")   ## Toll 3
	check(card.has_kw("toll"), "fixture has Toll")

	var view := make_view(card, null, MODE_HAND)
	root.add_child(view)
	await process_frame

	var chips := find_node_named(view, "KeywordChips")
	check(chips != null, "card with keywords has a KeywordChips row")
	if chips != null:
		var texts: Array = []
		for l in all_labels(chips):
			texts.append((l as Label).text)
		check(texts.size() == 1, "one chip per keyword, got %d" % texts.size())
		check(str(texts).contains("Toll 3"), "chip reads 'Toll 3', got %s" % str(texts))
	view.queue_free()
	await process_frame

	## A spent charge must disappear from the board. This is the rule CLAUDE.md
	## records as "state the rules engine tracks per-unit has to be visible
	## per-unit" — a Judgment unit that has cashed its charge still printed
	## "Judgment 30" before _live_keyword_line() existed, which made the decision
	## the keyword is built around impossible to make.
	var judged: CardData = null
	for cid in db.all_ids():
		var c: CardData = db.get_card(cid)
		if c == null:
			continue
		if c.is_unit() and c.has_kw("judgment"):
			judged = c
			break
	check(judged != null, "found a Judgment unit to test with")
	if judged == null:
		return

	var u = load("res://scripts/core/Unit.gd").new(judged)
	var live := make_view(judged, u, MODE_BOARD)
	root.add_child(live)
	await process_frame
	var before := find_node_named(live, "KeywordChips")
	var n_before: int = 0 if before == null else all_labels(before).size()
	check(n_before >= 1, "unspent Judgment shows a chip")
	live.queue_free()
	await process_frame

	u.judgment_spent = true
	var after_view := make_view(judged, u, MODE_BOARD)
	root.add_child(after_view)
	await process_frame
	var after := find_node_named(after_view, "KeywordChips")
	var n_after: int = 0 if after == null else all_labels(after).size()
	check(n_after < n_before, "spent Judgment drops its chip (%d -> %d)" % [n_before, n_after])
	after_view.queue_free()
	await process_frame


func _test_ability_banner(db) -> void:
	## Charnel Colossus: one ability (Consume the Fallen, free) + one attack (Crush).
	var card: CardData = db.get_card("charnel_colossus")
	check(card.ability_lines().size() == 1, "fixture has exactly one ability")
	check(card.attack_lines().size() == 1, "fixture has exactly one attack")

	var view := make_view(card, null, MODE_HAND)
	root.add_child(view)
	await process_frame

	var banner := find_node_named(view, "AbilityBanner")
	check(banner != null, "a card with an ability has an AbilityBanner")
	if banner != null:
		check(find_label(banner, "Consume the Fallen") != null, "banner names the ability")
		check(find_label(banner, "ABILITY") != null, "banner is labelled ABILITY")
	view.queue_free()
	await process_frame

	## A unit whose lines are all attacks gets no banner — the banner marks a
	## *different mechanic*, so drawing an empty one would dilute the signal.
	var no_ability: CardData = null
	for cid in db.all_ids():
		var c: CardData = db.get_card(cid)
		if c == null:
			continue
		if c.is_unit() and c.ability_lines().is_empty() and not c.attack_lines().is_empty():
			no_ability = c
			break
	check(no_ability != null, "found an attacks-only unit")
	if no_ability != null:
		var v2 := make_view(no_ability, null, MODE_HAND)
		root.add_child(v2)
		await process_frame
		check(find_node_named(v2, "AbilityBanner") == null, "attacks-only unit has no banner")
		v2.queue_free()
		await process_frame


func _collect_icons(n: Node, out: Array = []) -> Array:
	if n is EnergyIcon:
		out.append(n)
	for c in n.get_children():
		_collect_icons(c, out)
	return out


func _count_icons(n: Node) -> int:
	return _collect_icons(n).size()


func _test_attack_rows(db) -> void:
	var card: CardData = db.get_card("charnel_colossus")   ## Crush: 3 Hel, 38 dmg

	var view := make_view(card, null, MODE_HAND)
	root.add_child(view)
	await process_frame

	var rows := find_node_named(view, "AttackRows")
	check(rows != null, "unit has an AttackRows block")
	if rows != null:
		check(find_label(rows, "Crush") != null, "attack row names the attack")
		check(find_label(rows, "38") != null, "attack row shows damage")
		## The ability moved to the banner in Task 5 — it must not also appear here.
		check(find_label(rows, "Consume the Fallen") == null,
			"ability is not duplicated in the attack rows")

		var icons: int = _count_icons(rows)
		check(icons == 3, "Crush shows 3 cost icons, got %d" % icons)
	view.queue_free()
	await process_frame

	## In play, attached energy fills the icons so a player can see how close the
	## unit is to affording the attack.
	var u = load("res://scripts/core/Unit.gd").new(card)
	u.attached = 2
	var live := make_view(card, u, MODE_BOARD)
	root.add_child(live)
	await process_frame
	var live_rows := find_node_named(live, "AttackRows")
	check(live_rows != null, "board card has attack rows")
	if live_rows != null:
		var filled: int = 0
		for n in _collect_icons(live_rows):
			if n.filled:
				filled += 1
		check(filled == 2, "2 attached energy fills 2 icons, got %d" % filled)
	live.queue_free()
	await process_frame


func _test_footer(db) -> void:
	var card: CardData = db.get_card("charnel_colossus")   ## retreat 2
	check(card.retreat == 2, "fixture retreat is 2, got %d" % card.retreat)

	var view := make_view(card, null, MODE_HAND)
	root.add_child(view)
	await process_frame

	var footer := find_node_named(view, "CardFooter")
	check(footer != null, "unit has a CardFooter")
	if footer != null:
		var icons: int = _count_icons(footer)
		check(icons == 2, "retreat 2 draws 2 icons in the footer, got %d" % icons)
		## Weakness and resistance are reserved but undesigned — they print an
		## em-dash so the frame does not need re-laying-out when the system lands.
		check(find_label(footer, "wk") != null, "footer reserves a weakness slot")
		check(find_label(footer, "res") != null, "footer reserves a resistance slot")
	view.queue_free()
	await process_frame

	## Non-units have no retreat and no weakness — no footer at all.
	var support: CardData = null
	for cid in db.all_ids():
		var c: CardData = db.get_card(cid)
		if c == null:
			continue
		if c.is_support_like():
			support = c
			break
	check(support != null, "found a support card")
	if support != null:
		var sv := make_view(support, null, MODE_HAND)
		root.add_child(sv)
		await process_frame
		check(find_node_named(sv, "CardFooter") == null, "a support has no unit footer")
		sv.queue_free()
		await process_frame


func _test_non_units(db) -> void:
	var kinds := {}
	for cid in db.all_ids():
		var c: CardData = db.get_card(cid)
		if c == null:
			continue
		if c.is_energy() and not kinds.has("energy"):
			kinds["energy"] = c
		elif c.type == CardData.Type.SUPPORT and not kinds.has("support"):
			kinds["support"] = c
		elif c.is_tool() and not kinds.has("tool"):
			kinds["tool"] = c
		elif c.is_tower_support() and not kinds.has("tower"):
			kinds["tower"] = c

	for key in ["energy", "support", "tool", "tower"]:
		check(kinds.has(key), "found a %s card to test" % key)
		if not kinds.has(key):
			continue
		var c: CardData = kinds[key]
		var view := make_view(c, null, MODE_HAND)
		root.add_child(view)
		await process_frame

		## Every non-unit must show its type and a play-cost line. Nothing may
		## render as an empty frame.
		check(find_node_named(view, "StageLabel") != null, "%s shows a type label" % key)
		check(find_node_named(view, "PlayCost") != null, "%s shows a play cost" % key)
		check(all_labels(view).size() >= 3, "%s frame is not empty" % key)

		## Units-only rows must be absent.
		check(find_node_named(view, "CardFooter") == null, "%s has no retreat footer" % key)
		check(find_node_named(view, "KeywordChips") == null, "%s has no keyword chips" % key)

		view.queue_free()
		await process_frame
