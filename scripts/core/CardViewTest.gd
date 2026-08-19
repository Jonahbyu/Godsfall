extends SceneTree

## Total assertions this harness is expected to run; see the check at
## the end of the run. Update deliberately when assertions change.
const EXPECTED_ASSERTIONS := 114  ## +6 attack rider text (2026-08-16)

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
	await _test_cost_icons_show_required_color(db)
	await _test_attached_badge(db)
	await _test_keyword_tooltips(db)
	await _test_cost_tooltips(db)
	await _test_cost_tooltip_reads_the_tool_tax(db)
	await _test_faction_marks(db)
	await _test_attack_rider_text(db)

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

	## Read the name off the card rather than hardcoding the string. The bestiary
	## pass (2026-08-15) renamed every unit, and a literal here broke while the
	## frame it is testing was perfectly correct — the assertion is about the
	## name being *rendered*, not about what the name happens to be.
	check(find_label(view, card.name) != null, "name is present")

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
		## Damage and cost are read off the card rather than hardcoded: this test
		## is about the frame *rendering* what the card says, and pinning the
		## numbers makes it fail on any re-pricing pass that never touched the UI.
		## `db`, not the CardDB autoload: under --script the identifier is not
		## resolvable at compile time, which is the trap this file's header
		## documents and which this line hit on the first attempt.
		var crush: AttackData = null
		for a in db.get_card("charnel_colossus").attack_lines():
			if a.name == "Crush":
				crush = a
		check(crush != null, "Crush is on the card")
		if crush != null:
			check(find_label(rows, str(crush.damage)) != null, "attack row shows damage")
		## The ability moved to the banner in Task 5 — it must not also appear here.
		check(find_label(rows, "Consume the Fallen") == null,
			"ability is not duplicated in the attack rows")

		var icons: int = _count_icons(rows)
		var want_icons: int = crush.total_cost() if crush != null else 0
		check(icons == want_icons,
			"Crush shows %d cost icons, got %d" % [want_icons, icons])
	view.queue_free()
	await process_frame

	## Partial attached energy does NOT change the cost row. This assertion used to
	## read the other way — "2 attached energy fills 2 icons" — because the row was
	## a progress bar toward affording the attack. That is what cost every card in
	## hand its cost colours, since `unit` is null there and an unfilled icon never
	## reaches the faction ramp. The row states the requirement now, and the
	## progress read lives in the footer's attached-energy badge.
	var u = load("res://scripts/core/Unit.gd").new(card)
	u.attached = 2
	var live := make_view(card, u, MODE_BOARD)
	root.add_child(live)
	await process_frame
	var live_rows := find_node_named(live, "AttackRows")
	check(live_rows != null, "board card has attack rows")
	if live_rows != null:
		var want: int = 0
		for a in card.attack_lines():
			want += a.total_cost()
		var filled: int = 0
		for n in _collect_icons(live_rows):
			if n.filled:
				filled += 1
		check(filled == want,
			"partial charge still shows the full requirement (%d), got %d" % [want, filled])
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
		## Matched on the em-dash rather than the caption: the captions were
		## shortened to buy width for the attached-energy badge, and the assertion
		## is about the slots existing, not about what they are labelled.
		var dashes: int = 0
		for l in all_labels(footer):
			if (l as Label).text.contains("—"):
				dashes += 1
		check(dashes >= 2, "footer reserves weakness and resistance slots, found %d" % dashes)
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


## An attack's cost states what it REQUIRES, in the colour it requires, whether the
## card is in hand or on the board.
##
## This is a regression test for a real bug: `is_filled` was `unit != null and i <
## attached`, so in hand (where `unit` is always null) every icon rendered unfilled —
## and `EnergyIcon`'s unfilled branch paints a black well and returns before the
## faction colour is ever used. A card in hand showed its requirement as a row of
## empty grey sockets. The progress-bar reading moves to the bottom-left badge in a
## later task, so the cost row is now free to just state the requirement.
func _test_cost_icons_show_required_color(db) -> void:
	var card: CardData = db.get_card("grave_whelp")
	if card == null:
		check(false, "a unit exists to test costs")
		return
	var atk: AttackData = null
	if card.attack_lines().size() > 0:
		atk = card.attack_lines()[0]
	if atk == null or atk.total_cost() <= 0:
		check(false, "test card has a priced attack")
		return

	## In hand: no unit, so nothing is attached — and the icons must STILL be solid
	## and coloured, because the requirement does not depend on what is attached.
	var view := make_view(card, null, MODE_HAND)
	root.add_child(view)
	await process_frame
	var icons: Array = _collect_icons(find_node_named(view, "AttackRows"))
	check(icons.size() > 0, "hand card draws its cost icons")
	var all_filled := true
	var any_faction_colored := false
	for ic in icons:
		if not ic.filled:
			all_filled = false
		if not ic.colorless:
			any_faction_colored = true
	check(all_filled, "hand cost icons are solid, not empty sockets")
	check(any_faction_colored, "hand cost icons carry the required faction colour")
	view.queue_free()
	await process_frame

	## On the board with ZERO attached: still solid. The old code drew these empty.
	## Unit._init already sets hp from the card's printed max, so the body is
	## undamaged and — the point of this half — carries zero attached energy.
	var u = load("res://scripts/core/Unit.gd").new(card)
	var bv := make_view(card, u, MODE_BOARD)
	root.add_child(bv)
	await process_frame
	var bicons: Array = _collect_icons(find_node_named(bv, "AttackRows"))
	check(bicons.size() > 0, "uncharged board card draws its cost icons")
	var board_all_filled := true
	for ic in bicons:
		if not ic.filled:
			board_all_filled = false
	check(board_all_filled, "uncharged board card still shows a solid requirement")
	bv.queue_free()
	await process_frame


## The footer's attached-energy badge: what the unit HOLDS, as opposed to what an
## attack REQUIRES.
##
## Position is asserted, not merely presence. "Bottom-left" is the whole request —
## a badge sitting on the right of the footer would satisfy an existence check and
## still be the wrong card.
func _test_attached_badge(db) -> void:
	var card: CardData = db.get_card("charnel_colossus")

	## In hand there is no unit, so there is nothing to hold.
	var hv := make_view(card, null, MODE_HAND)
	root.add_child(hv)
	await process_frame
	check(find_node_named(hv, "AttachedBadge") == null,
		"a card in hand has no attached-energy badge")
	hv.queue_free()
	await process_frame

	## A charged body states its total. Unit._init sets hp from the card's printed
	## max, so nothing but `attached` needs setting to get a living unit.
	var u = load("res://scripts/core/Unit.gd").new(card)
	u.attached = 5
	var view := make_view(card, u, MODE_BOARD)
	root.add_child(view)
	await process_frame

	var badge := find_node_named(view, "AttachedBadge")
	check(badge != null, "a charged board card has an attached-energy badge")
	if badge != null:
		check(find_label(badge, "5") != null, "badge states the attached total (5)")
		check(_count_icons(badge) == 1, "badge draws one energy symbol, got %d"
			% _count_icons(badge))

		## Bottom-left means the footer row's FIRST child, ahead of the reserved
		## weakness/resistance slots.
		var footer := find_node_named(view, "CardFooter")
		check(footer != null, "charged board card has a CardFooter")
		if footer != null:
			check(footer.get_child_count() > 0 and footer.get_child(0) == badge,
				"badge is the footer row's first child (bottom-left)")
			## The reservation must survive the addition.
			var reserved: int = 0
			for l in all_labels(footer):
				if (l as Label).text.contains("—"):
					reserved += 1
			check(reserved >= 2,
				"footer still reserves both w/r slots, found %d" % reserved)
	view.queue_free()
	await process_frame

	## Nothing attached, nothing drawn — a "0" on every uncharged body is noise.
	var u0 = load("res://scripts/core/Unit.gd").new(card)
	var zv := make_view(card, u0, MODE_BOARD)
	root.add_child(zv)
	await process_frame
	check(find_node_named(zv, "AttachedBadge") == null,
		"an uncharged board card draws no badge")
	zv.queue_free()
	await process_frame


## The chips carry hover help, and every coloured keyword has an entry.
##
## The coverage assertion is the one that earns its keep long-term: it builds a
## list of KEYWORD_COLORS keys with no help text and asserts the list is empty, so
## the failure message *names* the keyword rather than saying a count is wrong.
## That makes a newly-printed keyword fail this suite until someone writes its
## help, which is the same guard TutorialTest applies to Compendium coverage.
##
## What this cannot check is whether the hover actually reaches the chip: mouse
## routing needs a real cursor and never runs under --headless. It asserts the
## tooltip text is *attached to the right node*, which is the half a harness can
## see; a human has to confirm it appears.
func _test_keyword_tooltips(db) -> void:
	var pal = root.get_node("Palette")

	## `null_adept` (Sevwane) prints Rift 1 — Rift is the least guessable keyword
	## in the game and the reason these tooltips exist, since it scales off a
	## board-wide number the chip itself cannot show.
	var card: CardData = db.get_card("null_adept")
	check(card != null and card.has_kw("rift"), "fixture prints Rift")
	if card == null:
		return

	var view := make_view(card, null, MODE_HAND)
	root.add_child(view)
	await process_frame

	var chips := find_node_named(view, "KeywordChips")
	var tip := ""
	if chips != null:
		for c in chips.get_children():
			if (c as Control) != null and (c as Control).tooltip_text != "":
				tip = (c as Control).tooltip_text
				break
	check(tip != "", "a Rift chip carries a tooltip")
	var low := tip.to_lower()
	check(low.contains("rift") or low.contains("gap"),
		"the Rift tooltip mentions Rift or the Gap, got '%s'" % tip)
	view.queue_free()
	await process_frame

	## Coverage. Not a census — this asserts a property (every coloured keyword is
	## explained), so it stays correct as keywords are added rather than needing a
	## number bumped.
	var missing: Array = []
	for kw in pal.KEYWORD_COLORS.keys():
		if str(pal.keyword_help(str(kw))).strip_edges() == "":
			missing.append(str(kw))
	check(missing.is_empty(), "every coloured keyword has help, missing: %s" % str(missing))


## Every energy cost explains itself on hover.
##
## The icons state the requirement; the tooltip states how much of it is already
## paid, which is the half the row has no channel for. These assertions check the
## tooltip EXISTS on the node that receives the hover and that it reads the LIVE
## cost — a `Deadweight` Tool raises what an attack costs on that body, and a
## tooltip quoting the printed cost would be confidently wrong on exactly the unit
## whose cost is surprising.
##
## Note what is checked and what is not: that the row is hoverable and that the
## text names the right numbers. Whether a tooltip actually POPS UP is mouse
## routing, which a headless harness cannot exercise — the same limit the keyword
## chip tooltips carry.
func _test_cost_tooltips(db) -> void:
	print("Energy costs carry hover tooltips:")

	## An attack cost row, in hand: hoverable, and it names the cost.
	var card: CardData = db.get_card("grave_whelp")
	var atk: AttackData = null
	if card != null and card.attack_lines().size() > 0:
		atk = card.attack_lines()[0]
	if atk == null or atk.total_cost() <= 0:
		check(false, "a priced attack exists to test")
		return

	var view := make_view(card, null, MODE_HAND)
	root.add_child(view)
	await process_frame

	var rows := find_node_named(view, "AttackRows")
	var box: Control = null
	if rows != null and rows.get_child_count() > 0:
		var row: Node = rows.get_child(0)
		if row.get_child_count() > 0 and row.get_child(0) is Control:
			box = row.get_child(0)

	check(box != null, "the attack cost row is a node of its own")
	if box != null:
		check(box.tooltip_text != "", "the cost row carries a tooltip")
		check(box.mouse_filter != Control.MOUSE_FILTER_IGNORE,
			"the cost row can receive a hover")
		check(box.tooltip_text.contains(str(atk.total_cost())),
			"the tooltip names the cost")
	view.queue_free()
	await process_frame

	## On a real body the tooltip must state what is attached and what is still owed.
	var u := Unit.new(card)
	u.attached = 1
	var bview := make_view(card, u, MODE_HAND)
	root.add_child(bview)
	await process_frame
	var brows := find_node_named(bview, "AttackRows")
	var bbox: Control = null
	if brows != null and brows.get_child_count() > 0:
		var brow: Node = brows.get_child(0)
		if brow.get_child_count() > 0 and brow.get_child(0) is Control:
			bbox = brow.get_child(0)
	check(bbox != null and bbox.tooltip_text.contains("attached"),
		"on a unit, the tooltip states what is already attached")
	bview.queue_free()
	await process_frame

	## A priced support states its pool cost; a free one says it is free.
	var priced: CardData = db.get_card("field_surgery")
	if priced != null and priced.cost > 0:
		var pv := make_view(priced, null, MODE_HAND)
		root.add_child(pv)
		await process_frame
		var prow := find_node_named(pv, "PlayCost")
		check(prow != null and prow.tooltip_text.contains(str(priced.cost)),
			"a priced support's tooltip names its pool cost")
		check(prow != null and prow.mouse_filter != Control.MOUSE_FILTER_IGNORE,
			"the play-cost row can receive a hover")
		pv.queue_free()
		await process_frame
	else:
		check(false, "a priced support exists to test")
		check(false, "a priced support row is hoverable")

	## An energy card explains the turn + 1 rule rather than printing a cost.
	var nrg: CardData = null
	for id in db.all_ids():
		var c: CardData = db.get_card(id)
		if c != null and c.is_energy():
			nrg = c
			break
	if nrg != null:
		var nv := make_view(nrg, null, MODE_HAND)
		root.add_child(nv)
		await process_frame
		var nrow := find_node_named(nv, "PlayCost")
		check(nrow != null and nrow.tooltip_text != "",
			"an energy card's cost row explains its scaling")
		nv.queue_free()
		await process_frame
	else:
		check(false, "an energy card exists to test")


## A Deadweight Tool raises what every attack on that unit costs, and the tooltip
## must report the raised number rather than the print.
##
## This is the assertion that justifies reading `Unit.attack_cost()` instead of
## `AttackData.total_cost()`. Without it the tooltip would be wrong only on the one
## card whose whole point is that it changes costs, which is the least likely place
## for anyone to notice.
func _test_cost_tooltip_reads_the_tool_tax(db) -> void:
	var card: CardData = db.get_card("grave_whelp")
	if card == null or card.attack_lines().size() == 0:
		check(false, "a unit with an attack exists for the Tool tax test")
		return
	var atk: AttackData = card.attack_lines()[0]

	var tool_card: CardData = null
	for id in db.all_ids():
		var c: CardData = db.get_card(id)
		if c != null and c.is_tool() and c.has_effect("attack_cost_increase"):
			tool_card = c
			break
	if tool_card == null:
		check(false, "a cost-raising Tool exists")
		return

	var u := Unit.new(card)
	u.tool = tool_card
	var taxed: int = u.attack_cost(atk)
	check(taxed > atk.total_cost(), "the Tool raises this unit's attack cost")

	var view := make_view(card, u, MODE_HAND)
	root.add_child(view)
	await process_frame
	var rows := find_node_named(view, "AttackRows")
	var box: Control = null
	if rows != null and rows.get_child_count() > 0:
		var row: Node = rows.get_child(0)
		if row.get_child_count() > 0 and row.get_child(0) is Control:
			box = row.get_child(0)
	## Asserted against the exact sentence rather than with `contains(str(taxed))`.
	## A bare digit search is far too weak here: the printed cost is 1 and the taxed
	## cost is 2, and the tooltip's colour-split line already contains a "1", so a
	## substring check passed even with the bug deliberately reintroduced. Verified
	## by sabotage in both directions — this form fails when the helper quotes the
	## printed cost, the loose form did not.
	check(box != null and box.tooltip_text.contains("Costs %d energy" % taxed),
		"the tooltip reports the RAISED cost, not the printed one")
	check(box != null and not box.tooltip_text.contains("Costs %d energy" % atk.total_cost()),
		"the tooltip does not quote the printed cost on a taxed unit")
	## And it names the tax rather than leaving an unexplained gap between the icons
	## drawn and the number charged.
	check(box != null and box.tooltip_text.contains("Tool on this unit adds"),
		"the tooltip explains where the extra cost comes from")
	view.queue_free()
	await process_frame


## Each faction's energy token carries a distinct drawn mark, so colour is never
## the only channel saying which energy this is.
##
## Checked as geometry rather than as pixels: `_mark_shape` must return a real
## polygon for every faction in the palette, and no two factions may return the
## same one. A pixel comparison would break on every tweak to a coordinate, which
## is the same reason the rest of this file checks nodes rather than positions.
func _test_faction_marks(db) -> void:
	print("Every faction's energy token has its own mark:")
	var Icon = load("res://scripts/ui/EnergyIcon.gd")
	var seen := {}
	var pal: Object = root.get_node_or_null("Palette")
	if pal == null:
		check(false, "Palette is available for the mark test")
		return

	for key in pal.FACTION_RAMPS.keys():
		var ic = Icon.new(Color.WHITE, true, false, 12.0, str(key))
		var shape: PackedVector2Array = ic._mark_shape(str(key), Vector2(6, 6), 6.0)
		## Void is the sanctioned exception: it is drawn as a hole with a hot rim
		## rather than as a figure, so it has no polygon by design.
		if str(key) == "void":
			check(shape.size() == 0, "void draws a hole rather than a figure")
		else:
			check(shape.size() >= 3, "%s has a mark polygon" % key)
			var sig := str(shape)
			check(not seen.has(sig), "%s's mark is distinct from every other" % key)
			seen[sig] = true
		ic.free()

	## The mark is skipped below MARK_MIN_PX, which is what keeps a 7px board card
	## from drawing a smudge. Asserted against the real metric rather than a literal,
	## so a change to either one surfaces here.
	var CV = load(CARD_VIEW)
	var board_px: float = float(CV.METRICS["icon_size"]["board"])
	var hand_px: float = float(CV.METRICS["icon_size"]["hand"])
	var probe = Icon.new(Color.WHITE, true, false, 12.0, "hel")
	check(probe.MARK_MIN_PX > board_px,
		"the mark is skipped at the board card's icon size (%d)" % board_px)
	check(probe.MARK_MIN_PX <= hand_px,
		"the mark is drawn at the hand card's icon size (%d)" % hand_px)
	probe.free()

## An attack's conditional rider has to be ON the card.
##
## The attack row drew cost icons, name and damage and never `atk.text`, so every
## conditional was invisible on the frame that printed it: `Ember Strike` rendered
## as "28" with nothing to say stoking adds 10, and `THE LAST TOLL` rendered as "—"
## with nothing to say it destroys both boards. That is the same "correct in the
## engine, invisible on the board" failure the spent-Judgment chip was fixed for,
## and it had been live for 26 attack lines across every faction.
##
## The other half of the rule is that a rider must NOT restate the damage — a
## "28 damage" line next to a "28" is noise on a 132px card.
func _test_attack_rider_text(db) -> void:
	var forge: CardData = db.get_card("forge_cindspark")
	check(forge != null, "fixture forge_cindspark exists")
	if forge != null:
		var view := make_view(forge, null, MODE_HAND)
		root.add_child(view)
		await process_frame
		check(find_label(view, "stoked this turn") != null,
			"a Stoke payoff rider is drawn on the attack row")
		check(find_label(view, "+10 damage") != null,
			"the rider states the actual bonus")
		view.queue_free()

	## The pre-existing case: an effect attack with no damage number at all.
	var queen: CardData = db.get_card("hel_queen")
	if queen != null:
		var qv := make_view(queen, null, MODE_HAND)
		root.add_child(qv)
		await process_frame
		check(find_label(qv, "Destroy every unit") != null,
			"THE LAST TOLL prints what it does")
		qv.queue_free()

	## And a plain damage attack stays clean — no restatement of its own number.
	var plain: CardData = db.get_card("grave_whelp")
	if plain != null:
		var pv := make_view(plain, null, MODE_HAND)
		root.add_child(pv)
		await process_frame
		check(find_label(pv, "12 damage") == null,
			"a plain damage attack does not restate its number as a rider")
		check(find_label(pv, "Gnaw") != null, "but the attack name is still there")
		pv.queue_free()
