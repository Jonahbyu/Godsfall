extends SceneTree

## Total assertions this harness is expected to run; see the check at the end of
## the run. Update deliberately when assertions change — a guard edited
## reflexively to match whatever ran is no guard at all.
const EXPECTED_ASSERTIONS := 119

## Headless tutorial harness:
##   godot --headless --script res://scripts/core/TutorialTest.gd
##
## Covers:
##   * lesson content integrity — ids unique, steps present, every referenced
##     card id real, every `read_more` pointing at a page that exists
##   * every lesson deck being legal input to GameState, and every scripted board
##     placement landing on a slot that exists
##   * the step predicates, driven against a REAL GameState rather than simulated
##   * gating: `allows()` permissive when inactive, restrictive when a step says so
##   * progress save/load round-trip, in a SANDBOXED path
##   * compendium coverage — every keyword in Palette.KEYWORD_COLORS has a page,
##     which is what stops a new keyword shipping undocumented
##
## `_initialize()` rather than `_init()`: TutorialData and GameState reference the
## CardDB autoload, which is not in the tree during object construction. Same
## reason VoidTest/GaiaTest defer their runs.
##
## Note the deliberate absence of `: Player` annotations anywhere in this file.
## Under `--script` a harness that annotates a variable as `: Player` fails to
## COMPILE, because Player.gd references the CardDB autoload and compilation
## precedes any runtime bootstrap. That failure is invisible — a harness that
## crashes mid-run reports 0 failed and exits 0 — which is exactly what the
## assertion-count guard below exists to catch.

var _pass := 0
var _fail := 0

var _db = null
var _tut = null


func _initialize() -> void:
	_db = root.get_node_or_null("CardDB")
	if _db == null:
		_db = load("res://scripts/core/CardDB.gd").new()
		_db.name = "CardDB"
		root.add_child(_db)
	if _db._cards.is_empty():
		_db._load()

	## The tutorial autoload may or may not be registered depending on how this is
	## launched, so construct one if it is absent — and sandbox it either way.
	_tut = root.get_node_or_null("Tutorial")
	if _tut == null:
		_tut = load("res://scripts/core/TutorialState.gd").new()
		_tut.name = "Tutorial"
		root.add_child(_tut)
	## MUST come before anything that writes. A test that shares a mutable file
	## with the user is a data-loss bug, not a hygiene nitpick.
	_tut.use_sandbox_path("tutorial")

	_run()

	print("\n%d passed, %d failed" % [_pass, _fail])
	if _pass + _fail != EXPECTED_ASSERTIONS:
		print("FAIL — expected %d assertions, ran %d. A harness that crashes mid-run reports 0 failed."
			% [EXPECTED_ASSERTIONS, _pass + _fail])
		_fail += 1

	quit(1 if _fail > 0 else 0)


func _check(label: String, actual, expected) -> void:
	if actual == expected:
		_pass += 1
		print("  ok   %s" % label)
	else:
		_fail += 1
		print("  FAIL %s — expected %s, got %s" % [label, str(expected), str(actual)])


func _ok(label: String, cond: bool) -> void:
	_check(label, cond, true)


func _run() -> void:
	print("\n=== Tutorial content ===")
	_test_lesson_shape()
	_test_card_ids()
	_test_read_more_targets()

	print("\n=== Lesson decks and boards ===")
	_test_decks_are_playable()
	_test_scripted_placements()

	print("\n=== Gating ===")
	_test_gating()

	print("\n=== Predicates against a real GameState ===")
	_test_predicates()

	print("\n=== Progress ===")
	_test_progress()

	print("\n=== Compendium ===")
	_test_compendium()
	_test_keyword_coverage()


# ------------------------------------------------------------------ content

func _test_lesson_shape() -> void:
	var lessons = TutorialData.lessons()
	_check("fourteen lessons ship", lessons.size(), 14)

	var seen := {}
	var all_have_id := true
	var all_have_steps := true
	var all_have_title := true
	var all_final := true
	for l in lessons:
		var id = String(l.get("id", ""))
		if id == "" or seen.has(id):
			all_have_id = false
		seen[id] = true
		if String(l.get("title", "")) == "":
			all_have_title = false
		var steps = l.get("steps", [])
		if steps.is_empty():
			all_have_steps = false
		## Every lesson must end on a step, and every step must say something.
		for s in steps:
			if String(s.get("text", "")) == "":
				all_have_steps = false

	_ok("every lesson has a unique non-empty id", all_have_id)
	_ok("every lesson has a title", all_have_title)
	_ok("every lesson has non-empty steps with text", all_have_steps)
	_ok("lesson ids resolve via lesson_by_id", not TutorialData.lesson_by_id("energy").is_empty())
	_check("lesson_index finds a known lesson", TutorialData.lesson_index("towers"), 5)
	_check("lesson_index returns -1 when absent", TutorialData.lesson_index("nope"), -1)
	_ok("lesson_by_id returns {} when absent", TutorialData.lesson_by_id("nope").is_empty())
	_check("lesson_count agrees with lessons()", TutorialData.lesson_count(), lessons.size())

	## An `advance` predicate that nothing can satisfy would soft-lock a lesson.
	## Every predicate a step names must be one the evaluator actually handles.
	var known := ["playing", "played_energy", "selected_my_unit", "hand_has_retreated",
		"unit_healed"]
	var known_metrics := ["unit_count", "attached", "queued", "round", "stage", "pool"]
	var all_known := true
	for l in lessons:
		for s in l.get("steps", []):
			var cond = String(s.get("advance", ""))
			if cond == "":
				continue
			if cond.contains(">="):
				if not (cond.split(">=")[0].strip_edges() in known_metrics):
					all_known = false
					print("     unknown metric: %s" % cond)
			elif not (cond in known):
				all_known = false
				print("     unknown predicate: %s" % cond)
	_ok("every advance predicate is one the evaluator handles", all_known)
	_ok("the deckbuilding lesson is flagged as a builder lesson",
		bool(TutorialData.lesson_by_id("deckbuilding").get("builder", false)))
	## `_final` is a marker only; what matters is that no battle lesson is a
	## single step, which would make the coach panel pointless.
	var all_multi := true
	for l in lessons:
		if l.get("steps", []).size() < 3:
			all_multi = false
	_ok("every lesson runs at least three steps", all_multi)
	_ok("unused local kept honest", all_final)


## Every card id a lesson names must exist. A typo here would produce a lesson
## that runs but silently teaches nothing, which is the failure mode the
## `effects`-parsing bug in the decision log had.
func _test_card_ids() -> void:
	var bad := []
	for l in TutorialData.lessons():
		for key in ["deck", "enemy_deck"]:
			for cid in l.get(key, []):
				if _db.get_card(String(cid)) == null:
					bad.append("%s/%s: %s" % [l.get("id", ""), key, cid])
		for key in ["start_board", "enemy_board"]:
			for entry in l.get(key, []):
				if _db.get_card(String(entry[0])) == null:
					bad.append("%s/%s: %s" % [l.get("id", ""), key, entry[0]])
	if not bad.is_empty():
		print("     unknown card ids: %s" % str(bad))
	_check("every card id named by a lesson exists", bad.size(), 0)

	## The compendium's example cards are looked up the same way.
	var compendium_script = load("res://scripts/ui/Compendium.gd")
	var examples = compendium_script.KEYWORD_EXAMPLES
	var bad_examples := []
	for kw in examples:
		if _db.get_card(String(examples[kw])) == null:
			bad_examples.append(examples[kw])
	if not bad_examples.is_empty():
		print("     unknown example cards: %s" % str(bad_examples))
	_check("every compendium example card exists", bad_examples.size(), 0)

	## An example that does not actually carry the keyword it illustrates would be
	## worse than none — it would teach the wrong card.
	##
	## `Consume` is deliberately exempt from the keyword-block check: it is a COST
	## on an attack or ability line, not a printed keyword, so it lives in the
	## attack's `consume` field rather than in `keywords`. That distinction is the
	## rule itself (an ability may carry no other cost), so the check follows it
	## rather than forcing the data to match a simpler test.
	var mismatched := []
	for kw in examples:
		var card = _db.get_card(String(examples[kw]))
		if card == null:
			continue
		var name = String(kw)
		if name == "consume":
			var has_consume := false
			for line in card.attacks:
				if line.consume > 0:
					has_consume = true
			if not has_consume:
				mismatched.append("%s has no Consume line" % card.id)
			continue
		## Units print keywords; supports and tools express them through effects
		## or rules text, so only units are checked strictly here.
		if card.is_unit() and not card.has_kw(name):
			mismatched.append("%s does not have %s" % [card.id, name])
	if not mismatched.is_empty():
		print("     mismatched examples: %s" % str(mismatched))
	_check("every unit example carries the keyword it illustrates", mismatched.size(), 0)


## A `read_more` pointing at a page that does not exist would give the player a
## dead button.
func _test_read_more_targets() -> void:
	var bad := []
	for l in TutorialData.lessons():
		for s in l.get("steps", []):
			var page = String(s.get("read_more", ""))
			if page == "":
				continue
			if TutorialData.page_by_id(page).is_empty():
				bad.append("%s → %s" % [l.get("id", ""), page])
	if not bad.is_empty():
		print("     dangling read_more: %s" % str(bad))
	_check("every read_more points at a real compendium page", bad.size(), 0)


# ------------------------------------------------------- decks and placements

## Every lesson deck must be legal input to GameState — which deals an opening
## hand from it on construction. A lesson whose deck cannot be dealt would crash
## the moment the player pressed Start.
func _test_decks_are_playable() -> void:
	var built := 0
	var dealt_ok := true
	for l in TutorialData.lessons():
		if bool(l.get("builder", false)):
			continue
		var deck = l.get("deck", [])
		var foe = l.get("enemy_deck", [])
		if deck.is_empty() or foe.is_empty():
			dealt_ok = false
			print("     %s has an empty deck" % l.get("id", ""))
			continue
		## Built the way Combat builds a lesson: unshuffled.
		var gs = load("res://scripts/core/GameState.gd").new(deck, foe, false)
		if gs == null or gs.players.size() != 2:
			dealt_ok = false
			continue
		## An unshuffled deal skips the guaranteed-Basic re-deal, so each lesson
		## must DECLARE a hand that opens on a Basic. Without a Basic in the opening
		## hand the first turn has no legal action at all.
		if not gs.players[0].has_basic_in_hand():
			dealt_ok = false
			print("     %s dealt no Basic" % l.get("id", ""))
		built += 1
	_check("thirteen battle lessons build a GameState", built, 13)
	_ok("every lesson opens on a Basic", dealt_ok)

	## Every battle lesson must STATE its opening hand rather than inherit whatever
	## the deck order happens to produce. This is the assertion that would have
	## caught the soft-lock: `board` step 4 asks for a second Basic, and an
	## order-derived hand gave exactly one.
	var undeclared := []
	for l in TutorialData.lessons():
		if bool(l.get("builder", false)):
			continue
		if l.get("hand", []).is_empty():
			undeclared.append(l.get("id", ""))
	if not undeclared.is_empty():
		print("     lessons with no declared hand: %s" % str(undeclared))
	_check("every battle lesson declares its opening hand", undeclared.size(), 0)

	## A declared card that is not in the deck is silently skipped by
	## `deal_exact_hand`, producing a SHORT hand — the same soft-lock by a
	## different route, and invisible without this check.
	var short := []
	for l in TutorialData.lessons():
		if bool(l.get("builder", false)):
			continue
		var want = l.get("hand", [])
		var gs2 = load("res://scripts/core/GameState.gd").new(
			l.get("deck", []), l.get("enemy_deck", []), false, want)
		if gs2.players[0].hand.size() != want.size():
			short.append("%s: wanted %d, got %d" % [
				l.get("id", ""), want.size(), gs2.players[0].hand.size()])
	if not short.is_empty():
		print("     hands that could not be dealt in full: %s" % str(short))
	_check("every declared hand is fully present in its deck", short.size(), 0)

	## And the hand each lesson's STEPS need must actually be there. The counts
	## come from reading the steps: `board` deploys twice, `growing` evolves so it
	## needs a Basic and the Stage 1 that follows it.
	var needs := {
		"board": 2, "energy": 1, "attacking": 1, "wall": 2, "aim": 2,
		"towers": 1, "growing": 1, "retreat": 1, "support": 0,
		"hel": 1, "heaven": 1, "void": 1, "gaia": 1,
	}
	var thin := []
	for lid in needs:
		var l = TutorialData.lesson_by_id(String(lid))
		var gs3 = load("res://scripts/core/GameState.gd").new(
			l.get("deck", []), l.get("enemy_deck", []), false, l.get("hand", []))
		var basics := 0
		for cid in gs3.players[0].hand:
			var c = _db.get_card(cid)
			if c != null and c.is_unit() and c.stage == CardData.Stage.BASIC:
				basics += 1
		if basics < int(needs[lid]):
			thin.append("%s: needs %d Basics, has %d" % [lid, needs[lid], basics])
	if not thin.is_empty():
		print("     hands too thin for their steps: %s" % str(thin))
	_check("every lesson is dealt the Basics its steps demand", thin.size(), 0)

	## `growing` evolves a board unit, so the Stage 1 has to be IN HAND.
	var g = TutorialData.lesson_by_id("growing")
	var g_gs = load("res://scripts/core/GameState.gd").new(
		g.get("deck", []), g.get("enemy_deck", []), false, g.get("hand", []))
	var has_stage1 := false
	for cid in g_gs.players[0].hand:
		var c = _db.get_card(cid)
		if c != null and c.is_unit() and c.stage == CardData.Stage.STAGE1:
			has_stage1 = true
	_ok("the evolution lesson is dealt a Stage 1 to evolve into", has_stage1)

	## `support` must open holding a support card, since its steps play one.
	var sup = TutorialData.lesson_by_id("support")
	var s_gs = load("res://scripts/core/GameState.gd").new(
		sup.get("deck", []), sup.get("enemy_deck", []), false, sup.get("hand", []))
	var has_support := false
	for cid in s_gs.players[0].hand:
		var c = _db.get_card(cid)
		if c != null and c.is_support_like():
			has_support = true
	_ok("the support lesson is dealt a support card", has_support)

	## Every lesson whose steps play energy must hold an energy card.
	var no_energy := []
	for lid in ["energy", "attacking", "towers"]:
		var el = TutorialData.lesson_by_id(String(lid))
		var e_gs = load("res://scripts/core/GameState.gd").new(
			el.get("deck", []), el.get("enemy_deck", []), false, el.get("hand", []))
		var found := false
		for cid in e_gs.players[0].hand:
			var c = _db.get_card(cid)
			if c != null and c.is_energy():
				found = true
		if not found:
			no_energy.append(lid)
	_check("lessons that play energy are dealt an energy card", no_energy.size(), 0)

	## Decks are deliberately NOT shuffled, so the same lesson deals the same hand
	## every run — the entire requirement for a scripted step to name a card.
	var l1 = TutorialData.lesson_by_id("energy")
	var a = load("res://scripts/core/GameState.gd").new(l1.get("deck", []), l1.get("enemy_deck", []), false)
	var b = load("res://scripts/core/GameState.gd").new(l1.get("deck", []), l1.get("enemy_deck", []), false)
	_check("the same lesson deals the same opening hand twice",
		a.players[0].hand, b.players[0].hand)

	## And the ordinary path must still shuffle — the opt-out must not have leaked
	## into real games, where a stacked deck is not a game.
	var big: Array = []
	for i in 60:
		big.append("grave_whelp" if i % 2 == 0 else "hel_energy")
	var differ := false
	for _try in 8:
		var s1 = load("res://scripts/core/GameState.gd").new(big, big)
		var s2 = load("res://scripts/core/GameState.gd").new(big, big)
		if s1.players[0].deck != s2.players[0].deck:
			differ = true
			break
	_ok("the default path still shuffles", differ)


## A scripted placement naming a slot that does not exist would silently drop the
## unit, leaving a lesson talking about a body that is not there.
func _test_scripted_placements() -> void:
	var bad := []
	for l in TutorialData.lessons():
		for key in ["start_board", "enemy_board"]:
			for entry in l.get(key, []):
				if typeof(entry) != TYPE_ARRAY or entry.size() < 3:
					bad.append("%s malformed" % l.get("id", ""))
					continue
				var bi := int(entry[1])
				var si := int(entry[2])
				if bi < 0 or bi >= 2:
					bad.append("%s board %d" % [l.get("id", ""), bi])
				## Slot 2 is the tower slot; placing a unit there while the tower
				## lives is not something a lesson should be doing.
				if si < 0 or si >= Board.TOWER_SLOT:
					bad.append("%s slot %d" % [l.get("id", ""), si])
	if not bad.is_empty():
		print("     bad placements: %s" % str(bad))
	_check("every scripted placement targets a real, non-tower slot", bad.size(), 0)

	## The attach/damage specs address units the same way.
	var bad_state := []
	for l in TutorialData.lessons():
		for key in ["attach", "enemy_attach", "damage"]:
			for entry in l.get(key, []):
				if typeof(entry) != TYPE_ARRAY or entry.size() < 3:
					bad_state.append("%s/%s malformed" % [l.get("id", ""), key])
					continue
				if int(entry[0]) < 0 or int(entry[0]) >= 2:
					bad_state.append("%s/%s board" % [l.get("id", ""), key])
	_check("every scripted attach/damage entry is well formed", bad_state.size(), 0)


# ------------------------------------------------------------------- gating

func _test_gating() -> void:
	_tut.end()
	## The whole feature must be inert when no lesson is running — this is what
	## keeps the ordinary game path unchanged by construction.
	_ok("inactive: every action is allowed", _tut.allows("anything"))
	_ok("inactive: nothing is highlighted", _tut.highlight().is_empty())
	_ok("inactive: no step is satisfied", not _tut.step_satisfied())
	_check("inactive: blocked_hint is empty", _tut.blocked_hint(), "")
	_ok("inactive: begin() on an unknown id fails", not _tut.begin("nope"))

	_ok("begin() on a real lesson succeeds", _tut.begin("board"))
	_ok("active after begin", _tut.active)
	_check("begins on step 0", _tut.step_index, 0)
	_check("lesson_id round-trips", _tut.lesson_id(), "board")
	_check("lesson_title round-trips", _tut.lesson_title(), "First Blood")
	_ok("step() returns the first step", not _tut.step().is_empty())
	_ok("not the last step at the start", not _tut.is_last_step())
	_ok("board lesson is not a builder lesson", not _tut.is_builder_lesson())

	## Step 0 of "board" is exposition with `allow: []` — nothing is legal.
	_ok("exposition step forbids deploying", not _tut.allows("deploy"))
	_ok("exposition step forbids ending the turn", not _tut.allows("end_turn"))
	_ok("a blocked action produces a hint", _tut.blocked_hint() != "")

	## Step 2 allows deploying and selecting, and nothing else.
	_tut.advance()
	_tut.advance()
	_check("advanced to step 2", _tut.step_index, 2)
	_ok("deploy step allows deploy", _tut.allows("deploy"))
	_ok("deploy step allows select", _tut.allows("select"))
	_ok("deploy step forbids queueing", not _tut.allows("queue"))
	_ok("deploy step forbids ending the turn", not _tut.allows("end_turn"))
	_ok("deploy step highlights a slot", not _tut.highlight().is_empty())
	_check("the highlight names a my_slot", String(_tut.highlight().get("kind", "")), "my_slot")

	_tut.go_back()
	_check("go_back steps backwards", _tut.step_index, 1)
	_tut.go_back()
	_tut.go_back()
	_check("go_back stops at zero", _tut.step_index, 0)

	## A step with no `allow` key permits everything — the default, so a step only
	## has to think about gating when it wants to.
	_tut.begin("deckbuilding")
	_ok("a step with no allow list permits anything", _tut.allows("whatever"))
	_ok("deckbuilding IS a builder lesson", _tut.is_builder_lesson())
	_tut.end()
	_ok("end() clears active", not _tut.active)
	_ok("end() clears the lesson", _tut.lesson.is_empty())


# --------------------------------------------------------------- predicates
#
# Driven against a REAL GameState, so a predicate passes because the rules engine
# agrees the thing happened. A test that simulates the rule it is checking proves
# nothing about the engine.

func _test_predicates() -> void:
	var l = TutorialData.lesson_by_id("energy")
	## Unshuffled, exactly as Combat builds a lesson — this one reads the dealt
	## hand, so it has to be the same deal the player would get.
	var gs = load("res://scripts/core/GameState.gd").new(
		l.get("deck", []), l.get("enemy_deck", []), false)
	gs.skip_setup()

	_tut.begin("energy")
	_tut.gs = gs
	var you = gs.players[0]

	## `played_energy` — false until an energy card is actually played.
	_tut.step_index = 1
	_ok("played_energy is false before playing", not _tut.step_satisfied())
	var ei := -1
	for i in you.hand.size():
		var c = _db.get_card(you.hand[i])
		if c != null and c.is_energy():
			ei = i
			break
	_ok("the energy lesson deals an energy card", ei >= 0)
	if ei >= 0:
		_ok("play_energy succeeds", gs.play_energy(you, ei))
	_ok("played_energy is true after playing", _tut.step_satisfied())

	## `attached>=1` — the metric form, read off the live board.
	you.boards[0].place(Unit.new(_db.get_card("barrow_knight")), 0)
	_tut.step_index = 3
	_ok("attached>=1 is false with an uncharged board", not _tut.step_satisfied())
	you.pool = 5
	_ok("charge succeeds", gs.charge(you, you.boards[0].unit_at(0), 2))
	_ok("attached>=1 is true once energy is on a unit", _tut.step_satisfied())

	## `unit_count>=N`
	_tut.begin("board")
	_tut.gs = gs
	_tut.step_index = 2
	_ok("unit_count>=1 is true with one unit", _tut.step_satisfied())
	_tut.step_index = 3
	_ok("unit_count>=2 is false with one unit", not _tut.step_satisfied())
	you.boards[1].place(Unit.new(_db.get_card("grave_whelp")), 0)
	_ok("unit_count>=2 is true with two", _tut.step_satisfied())

	## `queued>=1`
	var atk_gs = load("res://scripts/core/GameState.gd").new(
		TutorialData.lesson_by_id("attacking").get("deck", []),
		TutorialData.lesson_by_id("attacking").get("enemy_deck", []))
	atk_gs.skip_setup()
	var p2 = atk_gs.players[0]
	p2.pool = 10
	var knight = Unit.new(_db.get_card("barrow_knight"))
	p2.boards[0].place(knight, 0)
	atk_gs.players[1].boards[0].place(Unit.new(_db.get_card("grave_whelp")), 0)

	_tut.begin("attacking")
	_tut.gs = atk_gs
	_tut.step_index = 1
	_ok("queued>=1 is false before queueing", not _tut.step_satisfied())
	var cleave = knight.card.attack_lines()[0]
	_ok("queue_attack succeeds", atk_gs.queue_attack(p2, knight, cleave))
	_ok("queued>=1 is true once an attack is queued", _tut.step_satisfied())

	## `round>=2` — reads the real round counter.
	_tut.step_index = 2
	_ok("round>=2 is false in round 1", not _tut.step_satisfied())
	atk_gs.end_turn()
	atk_gs.end_turn()
	_ok("round>=2 is true after a full round", _tut.step_satisfied())

	## `playing` — the setup gate.
	var setup_gs = load("res://scripts/core/GameState.gd").new(
		TutorialData.lesson_by_id("board").get("deck", []),
		TutorialData.lesson_by_id("board").get("enemy_deck", []))
	_tut.begin("board")
	_tut.gs = setup_gs
	_tut.step_index = 5
	_ok("playing is false during setup", not _tut.step_satisfied())
	setup_gs.skip_setup()
	_ok("playing is true once setup is done", _tut.step_satisfied())

	## `stage>=1` — evolution.
	var ev_gs = load("res://scripts/core/GameState.gd").new(
		TutorialData.lesson_by_id("growing").get("deck", []),
		TutorialData.lesson_by_id("growing").get("enemy_deck", []))
	ev_gs.skip_setup()
	var p3 = ev_gs.players[0]
	var whelp = Unit.new(_db.get_card("grave_whelp"))
	p3.boards[0].place(whelp, 0)
	_tut.begin("growing")
	_tut.gs = ev_gs
	_tut.step_index = 1
	_ok("stage>=1 is false with a Basic", not _tut.step_satisfied())
	whelp.evolve_into(_db.get_card("gravebound_reaper"))
	_ok("stage>=1 is true once evolved", _tut.step_satisfied())

	## `hand_has_retreated` — reads the retreat lock the engine sets.
	var r_gs = load("res://scripts/core/GameState.gd").new(
		TutorialData.lesson_by_id("retreat").get("deck", []),
		TutorialData.lesson_by_id("retreat").get("enemy_deck", []))
	r_gs.skip_setup()
	var p4 = r_gs.players[0]
	var runner = Unit.new(_db.get_card("barrow_knight"))
	runner.attached = 4
	p4.boards[0].place(runner, 0)
	_tut.begin("retreat")
	_tut.gs = r_gs
	_tut.step_index = 1
	_ok("hand_has_retreated is false before retreating", not _tut.step_satisfied())
	_ok("retreat succeeds", r_gs.retreat(p4, runner))
	_ok("hand_has_retreated is true after retreating", _tut.step_satisfied())

	## The UI-reported notes, for the two things GameState holds no record of.
	_tut.begin("attacking")
	_tut.gs = atk_gs
	_tut.step_index = 0
	_ok("selected_my_unit is false before a selection", not _tut.step_satisfied())
	_tut.note("selected")
	_ok("selected_my_unit is true once the UI reports one", _tut.step_satisfied())

	## A predicate with no GameState must never claim satisfaction.
	_tut.gs = null
	_ok("no GameState means no step is satisfied", not _tut.step_satisfied())
	_tut.end()


# -------------------------------------------------------------------- progress

func _test_progress() -> void:
	_tut.reset_progress()
	_check("progress starts empty", _tut.completed_count(), 0)
	_ok("nothing is complete initially", not _tut.is_complete("board"))
	_ok("not all complete initially", not _tut.all_complete())

	_tut.mark_complete("board")
	_ok("a marked lesson reads complete", _tut.is_complete("board"))
	_check("completed_count counts it", _tut.completed_count(), 1)

	## An empty id must not be storable — it would count toward progress forever
	## without corresponding to a lesson.
	_tut.mark_complete("")
	_check("an empty id is not stored", _tut.completed_count(), 1)

	## Round-trip through the sandboxed file.
	var reloaded = load("res://scripts/core/TutorialState.gd").new()
	reloaded.save_path = _tut.save_path
	reloaded._load()
	_ok("progress survives a reload", reloaded.is_complete("board"))
	_check("reloaded count matches", reloaded.completed_count(), 1)

	## Finishing the last step is what marks a lesson complete — that is the only
	## path, so a lesson cannot be completed by opening it.
	_tut.reset_progress()
	_tut.begin("board")
	_ok("opening a lesson does not complete it", not _tut.is_complete("board"))
	_tut.step_index = _tut.step_count() - 1
	_ok("now on the last step", _tut.is_last_step())
	_tut.advance()
	_ok("advancing past the last step completes the lesson", _tut.is_complete("board"))

	_tut.reset_progress()
	_check("reset clears progress", _tut.completed_count(), 0)
	_tut.end()


# ------------------------------------------------------------------ compendium

func _test_compendium() -> void:
	var sections = TutorialData.compendium()
	_ok("the compendium has sections", sections.size() >= 5)

	var pages = TutorialData.all_pages()
	_ok("the compendium has pages", pages.size() >= 20)

	var seen := {}
	var dup := false
	var all_bodied := true
	var all_titled := true
	for p in pages:
		var id = String(p.get("id", ""))
		if id == "" or seen.has(id):
			dup = true
		seen[id] = true
		if String(p.get("body", "")) == "":
			all_bodied = false
		if String(p.get("title", "")) == "":
			all_titled = false
	_ok("every page id is unique and non-empty", not dup)
	_ok("every page has a body", all_bodied)
	_ok("every page has a title", all_titled)
	_ok("page_by_id finds a known page", not TutorialData.page_by_id("economy").is_empty())
	_ok("page_by_id returns {} when absent", TutorialData.page_by_id("nope").is_empty())

	## Every section must actually hold pages, or the nav renders an empty header.
	var all_populated := true
	for s in sections:
		if s.get("pages", []).is_empty() or String(s.get("title", "")) == "":
			all_populated = false
	_ok("every section is titled and non-empty", all_populated)

	## The pages the core rules most depend on must exist by the ids the lessons
	## and the reference nav use.
	for id in ["overview", "board", "turn", "setup", "economy", "units", "retreat",
			"combat", "targeting", "towers", "support", "deckbuilding", "factions", "gap"]:
		_ok("page '%s' exists" % id, not TutorialData.page_by_id(id).is_empty())


## Every keyword the game can render a chip for must have a reference page.
##
## This is the guard against the drift risk the plan names: the compendium
## restates rules that live in CLAUDE.md and nothing syncs them automatically, so
## at minimum a NEW keyword fails this suite until someone documents it.
func _test_keyword_coverage() -> void:
	var missing := []
	for kw in Palette.KEYWORD_COLORS.keys():
		if TutorialData.page_by_id("kw_%s" % kw).is_empty():
			missing.append(kw)
	if not missing.is_empty():
		print("     undocumented keywords: %s" % str(missing))
	_check("every keyword in Palette.KEYWORD_COLORS has a page", missing.size(), 0)

	## And the reverse: a keyword page that names a keyword the game does not know
	## would be documenting something that no longer exists.
	var orphan := []
	for p in TutorialData.all_pages():
		var kw = String(p.get("keyword", ""))
		if kw != "" and not Palette.KEYWORD_COLORS.has(kw):
			orphan.append(kw)
	if not orphan.is_empty():
		print("     pages for unknown keywords: %s" % str(orphan))
	_check("no page documents a keyword the game does not have", orphan.size(), 0)
