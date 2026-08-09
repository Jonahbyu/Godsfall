extends SceneTree

## Drives the real Combat screen the way a player would: select a hand card,
## deploy it, charge, queue an attack, end turn, let the AI respond.
## Catches interaction bugs the rules harness cannot see.
##   godot --headless --script res://scripts/core/PlaythroughTest.gd

var _fail := 0


func _initialize() -> void:
	var db = root.get_node_or_null("CardDB")
	if db != null and db._cards.is_empty():
		db._load()
	var ds = root.get_node_or_null("DeckStore")
	if ds != null:
		## Never write the player's real save file from a test run.
		ds.use_sandbox_path("playthrough")
		if ds.deck.is_empty():
			ds.deck = ds.default_deck()

	print("\n=== Playthrough (driving the real UI) ===\n")

	var combat = load("res://scenes/Combat.tscn").instantiate()
	## This harness ends turns, which can trigger the hand-limit discard prompt.
	## That prompt blocks end_turn() until it is answered, and there is no pointer
	## here to answer it with, so let the screen resolve choices for us.
	combat.auto_resolve_choices = true
	root.add_child(combat)
	await process_frame
	await process_frame

	var gs = combat.gs
	if gs == null:
		print("  FAIL combat screen never built a GameState")
		quit(1)
		return

	var you = gs.players[0]
	print("  opening hand: %d cards, deck %d" % [you.hand.size(), you.deck.size()])

	## Leave setup the way a player would — Ready. The AI committed its own board in
	## _start_game, so this starts round 1 and makes the main phase legal.
	_ok("opening hand holds a Basic", you.has_basic_in_hand())
	_ok("combat opens in setup", gs.in_setup())
	combat._on_end_turn()
	await process_frame
	_ok("Ready starts round 1", not gs.in_setup() and gs.turn == 1)

	## --- play an energy card through the UI path
	var e_idx := _find_energy_in_hand(you)
	if e_idx >= 0:
		combat._on_hand_pressed(e_idx, _db().get_card(you.hand[e_idx]))
		await process_frame
		_ok("played energy via UI, pool = %d" % you.pool, you.pool > 0)
	else:
		print("  (no energy card in opening hand — skipping)")

	## --- deploy a basic unit through the UI path
	var u_idx := _find_basic_in_hand(you)
	if u_idx >= 0:
		combat._selected_hand = u_idx
		combat._deploy_to(0, 0)
		await process_frame
		_ok("deployed a unit to board 0 slot 0", you.boards[0].unit_at(0) != null)
	else:
		print("  (no basic unit in opening hand — skipping)")

	## --- charge and queue an attack
	var unit = you.boards[0].unit_at(0)
	if unit != null and you.pool > 0:
		var atk = unit.card.attacks[0]
		var before: int = you.pool
		gs.queue_attack(you, unit, atk)
		await process_frame
		_ok("queued %s (pool %d -> %d, attached %d)" % [atk.name, before, you.pool, unit.attached],
			unit.queued_attack != null)

	## --- run several full turns through the UI's end-turn path
	var rounds := 0
	while rounds < 12 and not gs.finished:
		rounds += 1
		await combat._on_end_turn()
		await process_frame

	_ok("survived %d end-turn cycles without crashing" % rounds, true)
	print("  state after %d rounds: your throne %d, enemy throne %d, round %d"
		% [rounds, you.throne_hp, gs.players[1].throne_hp, gs.turn])
	print("  your board: %d units, pool %d, hand %d"
		% [you.all_units().size(), you.pool, you.hand.size()])

	if gs.finished:
		print("  game ended — winner: %s" % gs.players[gs.winner].display_name)

	print("\n%s\n" % ("playthrough clean" if _fail == 0 else "%d check(s) failed" % _fail))
	quit(1 if _fail > 0 else 0)


func _db():
	return root.get_node_or_null("CardDB")


func _ok(label: String, cond: bool) -> void:
	if cond:
		print("  ok   %s" % label)
	else:
		_fail += 1
		print("  FAIL %s" % label)


## Ask for the type by name. This used to be a `want_unit` bool, where "not a
## unit" meant energy — that stopped being true the moment support cards existed,
## and the energy check started intermittently picking up a support card instead.
func _find_energy_in_hand(p) -> int:
	for i in p.hand.size():
		var c = _db().get_card(p.hand[i])
		if c != null and c.is_energy():
			return i
	return -1


func _find_basic_in_hand(p) -> int:
	for i in p.hand.size():
		var c = _db().get_card(p.hand[i])
		if c != null and c.is_unit() and c.stage == 0:   ## 0 == Stage.BASIC
			return i
	return -1
