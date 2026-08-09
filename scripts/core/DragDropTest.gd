extends SceneTree

## Total assertions this harness is expected to run; see the check at
## the end of the run. Update deliberately when assertions change.
const EXPECTED_ASSERTIONS := 27

## Drives the drag-and-drop paths on the real Combat screen: payload
## resolution, deploy-by-drop, evolve-by-drop, energy-onto-unit, and the
## guards that must reject an illegal drop.
##   godot --headless --script res://scripts/core/DragDropTest.gd

var _passed := 0
var _failed := 0


func _initialize() -> void:
	var db = root.get_node_or_null("CardDB")
	if db != null and db._cards.is_empty():
		db._load()
	var ds = root.get_node_or_null("DeckStore")
	if ds != null:
		## Never write the player's real save file from a test run.
		ds.use_sandbox_path("dragdrop")
		if ds.deck.is_empty():
			ds.deck = ds.default_deck()

	print("\n=== Drag & drop test ===\n")

	var combat = load("res://scenes/Combat.tscn").instantiate()
	root.add_child(combat)
	await process_frame

	var gs = combat.gs
	var you = gs.players[0]

	## The game opens in setup, where only Basic deployment is legal. Leave it the way
	## a player would — the AI has already committed its board in _start_game, so
	## pressing Ready is what starts round 1.
	_ok("combat opens in setup", gs.in_setup())
	combat._on_end_turn()
	await process_frame
	_ok("Ready leaves setup", not gs.in_setup())

	await _payloads(combat, gs, you)
	await _deploy(combat, gs, you)
	await _evolve(combat, gs, you)
	await _energy_onto_unit(combat, gs, you)
	await _guards(combat, gs, you)

	## A harness that errors out mid-run still reports "0 failed", because an
	## assertion that never RUNS cannot fail — that is how the Gaia harness passed
	## for several rounds while executing 7 of its 40 checks. Pinning the total
	## makes a crash that skips whole test functions a failure instead of silence.
	## Update this number deliberately when adding or removing assertions.
	if _passed + _failed != EXPECTED_ASSERTIONS:
		print("FAIL: expected %d assertions, ran %d — a test crashed before finishing."
			% [EXPECTED_ASSERTIONS, _passed + _failed])
		_failed += 1

	print("\n%d passed, %d failed" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)


func _ok(label: String, cond: bool) -> void:
	if cond:
		_passed += 1
		print("  ok   %s" % label)
	else:
		_failed += 1
		print("  FAIL %s" % label)


func _payload(hand_index: int, card_id: String) -> Dictionary:
	return { "kind": "hand_card", "hand_index": hand_index, "card_id": card_id }


## Put a known card at a known hand position so each case is deterministic.
func _give(you, card_id: String) -> int:
	you.hand.append(card_id)
	return you.hand.size() - 1


func _payloads(combat, _gs, you) -> void:
	print("Payload resolution:")
	## The opening hand is random, so the fallback case needs a card that is
	## certainly not already in it — otherwise find() legitimately returns the
	## other copy and the assertion is testing the shuffle, not the lookup.
	you.hand = you.hand.filter(func(id): return str(id) != "grave_whelp")
	var i: int = _give(you, "grave_whelp")

	_ok("resolves a well-formed payload", combat._payload_index(_payload(i, "grave_whelp")) == i)
	_ok("reads the card back", combat._payload_card(_payload(i, "grave_whelp")) != null)

	## The hand shifts when cards are played, so a stale index must still
	## resolve by card id rather than grabbing whatever moved into that slot.
	var stale := _payload(i + 5, "grave_whelp")
	_ok("stale index falls back to the card id", combat._payload_index(stale) == i)

	_ok("unknown card rejected", combat._payload_index(_payload(0, "not_a_card")) == -1)
	_ok("non-drag data rejected", combat._payload_index("garbage") == -1)
	_ok("wrong payload kind rejected", combat._payload_index({ "kind": "other" }) == -1)

	you.hand.remove_at(i)
	await process_frame


func _deploy(combat, _gs, you) -> void:
	print("Deploy by drop:")
	var i: int = _give(you, "grave_whelp")
	var before: int = you.hand.size()

	_ok("a Basic is a valid deploy payload", combat._is_basic_payload(_payload(i, "grave_whelp")))

	combat._deploy_from_drag(_payload(i, "grave_whelp"), 0, 1)
	await process_frame

	_ok("unit landed in the dropped slot", you.boards[0].unit_at(1) != null)
	_ok("card left the hand", you.hand.size() == before - 1)
	_ok("drag state cleared after the drop", combat._drag_card == null)


func _evolve(combat, _gs, you) -> void:
	print("Evolve by drop:")
	## Grave Whelp is in board 0 slot 1 from the previous case.
	var base = you.boards[0].unit_at(1)
	if base == null:
		print("  (no base unit — skipping)")
		return

	var db = root.get_node_or_null("CardDB")
	var evo_id := ""
	for c in db.units_of("hel"):
		if c.evolves_from == base.card.id:
			evo_id = c.id
			break
	if evo_id == "":
		print("  (no evolution for %s — skipping)" % base.card.name)
		return

	var i: int = _give(you, evo_id)
	base.attached = 2

	_ok("evolution accepted onto its base", combat._can_drop_on_unit(_payload(i, evo_id), base))

	## Target pre-lighting keys off the card actually in flight.
	combat._on_drag_started(i, db.get_card(evo_id))
	await process_frame
	_ok("pre-lights the matching base", combat._dragging_evolution_for(base))
	combat._end_drag()

	combat._drop_on_unit(_payload(i, evo_id), base)
	await process_frame

	var now = you.boards[0].unit_at(1)
	_ok("unit evolved in place", now != null and now.card.id == evo_id)
	_ok("attached energy carried through", now != null and now.attached == 2)


func _energy_onto_unit(combat, gs, you) -> void:
	print("Energy dropped on a unit:")
	var u = you.boards[0].unit_at(1)
	if u == null:
		print("  (no unit — skipping)")
		return

	you.energy_played_this_turn = false
	you.pool = 0
	var attached_before: int = u.attached
	var i: int = _give(you, "hel_energy")

	_ok("energy accepted onto a unit", combat._can_drop_on_unit(_payload(i, "hel_energy"), u))

	combat._drop_on_unit(_payload(i, "hel_energy"), u)
	await process_frame

	_ok("energy card was spent", you.energy_played_this_turn)
	_ok("the gain went onto the unit", u.attached > attached_before)
	_ok("pool not left holding it", you.pool == 0)

	## One energy card per turn still holds — the shortcut must not bypass it.
	var j: int = _give(you, "hel_energy")
	_ok("second energy drop rejected same turn",
		not combat._can_drop_on_unit(_payload(j, "hel_energy"), u))
	you.hand.remove_at(j)


func _guards(combat, gs, you) -> void:
	print("Illegal drops rejected:")
	var u = you.boards[0].unit_at(1)

	## A Basic is not an evolution of anything on the board.
	var i: int = _give(you, "grave_whelp")
	_ok("unrelated unit not accepted as an evolution",
		not combat._can_drop_on_unit(_payload(i, "grave_whelp"), u))

	## Occupied slots are not deploy targets.
	var before = you.boards[0].unit_at(1)
	combat._deploy_from_drag(_payload(i, "grave_whelp"), 0, 1)
	await process_frame
	_ok("occupied slot unchanged by a deploy drop", you.boards[0].unit_at(1) == before)

	## The tower slot (index 2) is blocked while the tower lives.
	you.boards[1].tower_hp = 50
	combat._deploy_from_drag(_payload(i, "grave_whelp"), 1, 2)
	await process_frame
	_ok("live tower slot rejects a deploy", you.boards[1].unit_at(2) == null)

	## Nothing is droppable on the opponent's turn.
	var was: int = gs.active
	gs.active = 1
	_ok("no deploys on the opponent's turn", not combat._is_basic_payload(_payload(i, "grave_whelp")))
	_ok("no unit drops on the opponent's turn", not combat._can_drop_on_unit(_payload(i, "grave_whelp"), u))
	gs.active = was

	## A dead unit is not a target.
	if u != null:
		var hp: int = u.hp
		u.hp = 0
		_ok("dead unit rejects drops", not combat._can_drop_on_unit(_payload(i, "grave_whelp"), u))
		u.hp = hp
