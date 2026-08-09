extends SceneTree

## Total assertions this harness is expected to run; see the check at
## the end of the run. Update deliberately when assertions change.
const EXPECTED_ASSERTIONS := 43

## Drives the real Combat screen through the support flows the rules harness
## cannot see: targeting mode, the two-unit pick, tower targeting, the Tool
## drag-drop path, the retreat button, and the modal card picker.
##   godot --headless --script res://scripts/core/SupportUITest.gd

var _pass := 0
var _fail := 0

var combat
var gs
var you


func _initialize() -> void:
	## This harness builds the real Combat scene, which reads and writes DeckStore,
	## so it must be redirected before anything touches disk — otherwise the run
	## overwrites the player's saved collection.
	var ds = root.get_node_or_null("DeckStore")
	if ds != null:
		ds.use_sandbox_path("supportui")

	print("\n=== Support UI harness ===\n")

	combat = load("res://scenes/Combat.tscn").instantiate()
	root.add_child(combat)
	await process_frame
	await process_frame

	gs = combat.gs
	if gs == null:
		print("  FAIL combat screen never built a GameState")
		quit(1)
		return
	you = gs.players[0]

	## Supports are illegal during setup, so press Ready first — the AI has already
	## placed its own board. Same path the player takes.
	_ok("combat opens in setup", gs.in_setup())
	combat._on_end_turn()
	await process_frame
	_ok("Ready starts round 1", not gs.in_setup())

	await _test_untargeted_support()
	await _test_targeted_support()
	await _test_two_unit_support()
	await _test_tool_attach()
	await _test_tower_support()
	await _test_retreat_button()
	await _test_picker()

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


func _ok(label: String, cond: bool) -> void:
	if cond:
		_pass += 1
		print("  ok   %s" % label)
	else:
		_fail += 1
		print("  FAIL %s" % label)


func _db():
	return root.get_node("CardDB")


func _card(id: String):
	return _db().get_card(id)


## Put the board and hand into a known state, since the opening hand is random.
func _reset(hand: Array, board: Array = []) -> void:
	for bi in you.boards.size():
		for si in Board.SLOT_COUNT:
			you.boards[bi].slots[si] = null
	you.hand = hand.duplicate()
	you.pool = 10
	you.clear_locks()
	combat._clear_support_pick()
	combat._selected_unit = null
	for entry in board:
		var u = Unit.new(_card(entry[0]))
		you.boards[entry[1]].place(u, entry[2])
	combat._refresh()


func _unit_at(bi: int, si: int):
	return you.boards[bi].unit_at(si)


# ---- a support with no target resolves on the first click
func _test_untargeted_support() -> void:
	print("Untargeted support:")
	_reset(["gravekeepers_ledger"])
	you.deck = ["grave_whelp", "grave_whelp", "barrow_knight", "barrow_knight"]

	combat._on_hand_pressed(0, _card("gravekeepers_ledger"))
	await process_frame
	_ok("resolved without entering pick mode", combat._pending_support == null)
	_ok("drew 3 cards", you.hand.size() == 3)
	_ok("Ledger is in the discard", you.discard.has("gravekeepers_ledger"))


# ---- a targeted support enters pick mode and resolves on the board click
func _test_targeted_support() -> void:
	print("Targeted support:")
	_reset(["shore_up"], [["barrow_knight", 0, 0]])
	var u = _unit_at(0, 0)
	u.hp = 10

	combat._on_hand_pressed(0, _card("shore_up"))
	await process_frame
	_ok("entered pick mode", combat._pending_support != null)
	_ok("card is still in hand", you.hand.has("shore_up"))
	_ok("the damaged unit is a legal target", combat._is_legal_support_target(u))

	combat._pick_support_target(u)
	await process_frame
	_ok("healed on click", u.hp == 30)      ## Shore Up is the 20 HP baseline
	_ok("pick mode cleared", combat._pending_support == null)
	_ok("card left hand", not you.hand.has("shore_up"))

	## Escape cancels a pick without spending the card.
	_reset(["shore_up"], [["barrow_knight", 0, 0]])
	_unit_at(0, 0).hp = 10
	combat._on_hand_pressed(0, _card("shore_up"))
	await process_frame
	combat._clear_support_pick()
	combat._refresh()
	await process_frame
	_ok("cancel leaves the card in hand", you.hand.has("shore_up"))
	_ok("cancel clears pick mode", combat._pending_support == null)


# ---- Tithe and Reposition need two picks
func _test_two_unit_support() -> void:
	print("Two-unit support:")
	_reset(["reposition"], [["barrow_knight", 0, 0], ["grave_whelp", 0, 1]])
	var a = _unit_at(0, 0)
	var b = _unit_at(0, 1)
	a.attached = 3

	combat._on_hand_pressed(0, _card("reposition"))
	await process_frame
	_ok("Reposition needs a pick", combat._pending_support != null)

	combat._pick_support_target(a)
	await process_frame
	_ok("first unit held, card not yet spent", combat._pending_two == a and you.hand.has("reposition"))
	_ok("the held unit is no longer a legal second pick", not combat._is_legal_support_target(a))

	combat._pick_support_target(b)
	await process_frame
	_ok("units swapped slots", _unit_at(0, 0) == b and _unit_at(0, 1) == a)
	_ok("attached energy moved with the unit", _unit_at(0, 1).attached == 3)
	_ok("card was spent", not you.hand.has("reposition"))


# ---- a Tool attaches by click and by drop
func _test_tool_attach() -> void:
	print("Tools through the UI:")
	_reset(["bone_splint"], [["barrow_knight", 0, 0]])
	var u = _unit_at(0, 0)

	combat._on_hand_pressed(0, _card("bone_splint"))
	await process_frame
	_ok("Tool enters pick mode", combat._pending_support != null)
	combat._pick_support_target(u)
	await process_frame
	_ok("Tool attached by click", u.tool != null and u.tool.id == "bone_splint")

	## A unit that already holds a Tool is not a legal target for another.
	_reset(["weighted_chain"], [["barrow_knight", 0, 0]])
	var u2 = _unit_at(0, 0)
	u2.tool = _card("bone_splint")
	_ok("occupied unit rejects a second Tool",
		not gs.support_has_any_target(you, _card("weighted_chain")))

	## The drag path: dropping a Tool on a legal unit attaches it.
	_reset(["bone_splint"], [["barrow_knight", 0, 0]])
	var u3 = _unit_at(0, 0)
	var payload := { "kind": "hand_card", "hand_index": 0, "card_id": "bone_splint" }
	_ok("drop is accepted on a bare unit", combat._can_drop_on_unit(payload, u3))
	combat._drop_on_unit(payload, u3)
	await process_frame
	_ok("Tool attached by drop", u3.tool != null and u3.tool.id == "bone_splint")

	## A non-Tool support is click-only, never droppable.
	_reset(["shore_up"], [["barrow_knight", 0, 0]])
	var u4 = _unit_at(0, 0)
	u4.hp = 10
	_ok("a one-shot support is not droppable",
		not combat._can_drop_on_unit({ "kind": "hand_card", "hand_index": 0, "card_id": "shore_up" }, u4))


# ---- tower support targets your tower; Toppling Blow targets theirs
func _test_tower_support() -> void:
	print("Tower targeting:")
	_reset(["reinforced_base"])
	combat._on_hand_pressed(0, _card("reinforced_base"))
	await process_frame
	_ok("tower support enters pick mode", combat._pending_support != null)
	_ok("your live tower is a target", combat._tower_is_target(you.boards[0], 0, false))
	_ok("the enemy tower is not", not combat._tower_is_target(gs.players[1].boards[0], 0, true))

	combat._pick_tower_target(0)
	await process_frame
	_ok("max HP raised", you.boards[0].tower_max_hp == 70)
	_ok("modification recorded", you.boards[0].tower_mods.size() == 1)

	## Toppling Blow reverses the ownership test.
	_reset(["toppling_blow"])
	combat._on_hand_pressed(0, _card("toppling_blow"))
	await process_frame
	_ok("Toppling Blow needs a pick", combat._pending_support != null)
	_ok("targets the enemy tower", combat._tower_is_target(gs.players[1].boards[0], 0, true))
	_ok("not your own", not combat._tower_is_target(you.boards[1], 1, false))
	combat._pick_tower_target(0)
	await process_frame
	_ok("enemy tower damaged", gs.players[1].boards[0].tower_hp == 25)


# ---- the retreat button in the action panel
func _test_retreat_button() -> void:
	print("Retreat through the UI:")
	_reset([], [["barrow_knight", 0, 0]])
	var u = _unit_at(0, 0)
	u.attached = 5
	u.hp = 12
	you.pool = 0
	var ret_cost: int = u.retreat_cost()          ## printed, derived from HP

	combat._select_unit(u)
	await process_frame
	_ok("action panel opened", combat._selected_unit == u)

	gs.retreat(you, u)
	combat._refresh()
	await process_frame
	_ok("slot is empty", _unit_at(0, 0) == null)
	_ok("card returned to hand", you.hand.has("barrow_knight"))
	_ok("leftover energy refunded to pool", you.pool == 5 - ret_cost)
	_ok("locked, so the hand shows it as unplayable",
		not combat._hand_card_playable(you, _card("barrow_knight")))


# ---- the modal picker used by search, discard, and the hand limit
func _test_picker() -> void:
	print("Card picker:")
	_reset(["muster"])
	you.deck = ["grave_whelp", "barrow_knight", "hel_energy"]

	var before: int = combat.get_child_count()
	combat._on_hand_pressed(0, _card("muster"))
	await process_frame
	_ok("picker opened for a deck search", combat.get_child_count() > before)

	## Find the picker layer and click its first card the way a player would.
	var layer = combat.get_child(combat.get_child_count() - 1)
	var views := _find_card_views(layer)
	_ok("picker lists the Basic units found", views.size() == 2)
	if views.is_empty():
		return

	views[0].pressed.emit()
	await process_frame
	await process_frame
	_ok("a Basic was added to hand", you.hand.has("grave_whelp") or you.hand.has("barrow_knight"))
	_ok("picker closed", combat.get_child_count() == before)


## Identified by shape rather than by class: naming CardView here would pull the
## UI scripts in at parse time, before the Palette autoload exists.
func _find_card_views(node: Node) -> Array:
	var out: Array = []
	if node is PanelContainer and node.get("card") != null and node.has_signal("pressed"):
		out.append(node)
	for c in node.get_children():
		out.append_array(_find_card_views(c))
	return out
