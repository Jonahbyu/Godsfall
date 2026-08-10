extends SceneTree

## Headless tutorial WALKTHROUGH:
##   godot --headless --script res://scripts/core/TutorialWalkTest.gd
##
## Drives every battle lesson through the REAL Combat screen, performing what
## each step asks via the same entry points a player clicks, and fails if any
## step cannot be satisfied.
##
## This exists because `TutorialTest` could not have caught the bug that shipped:
## it asserted a lesson opened with *at least one* Basic, while `board` step 4
## asks for a *second* one — so the lesson was verifiably "valid" and completely
## unplayable. Content assertions check that a lesson is well formed; only
## walking it checks that it can be FINISHED.
##
## Deliberately separate from `TutorialTest`: this one instantiates scenes and
## awaits real timers, so it is slow and reports pass/fail per lesson rather than
## a counted assertion total.

## Walk EVERY battle lesson through the real Combat screen, performing what each
## step asks via the same entry points a player clicks. A step that cannot be
## satisfied is a soft-lock.

var _db = null

func _initialize() -> void:
	_db = root.get_node_or_null("CardDB")
	var T = root.get_node_or_null("Tutorial")
	T.use_sandbox_path("walk")
	var bad := []

	for lesson in TutorialData.lessons():
		if bool(lesson.get("builder", false)): continue
		var lid = String(lesson.get("id", ""))
		T.begin(lid)
		var combat = load("res://scenes/Combat.tscn").instantiate()
		root.add_child(combat)
		await process_frame
		var you = combat.gs.players[0]
		var stuck := ""

		while true:
			if T.step().is_empty(): break
			var s = T.step()
			var cond = String(s.get("advance", ""))
			if cond == "":
				if T.is_last_step(): break
				T.advance(); await process_frame; continue

			if not await _do(combat, you, T, cond):
				stuck = "%s (step %d: %s)" % [cond, T.step_index + 1, s.get("title","")]
				break
			if T.step_satisfied():
				if T.is_last_step(): break
				T.advance()
			else:
				stuck = "%s (step %d: %s)" % [cond, T.step_index + 1, s.get("title","")]
				break
			await process_frame

		if stuck != "":
			bad.append("%s -> %s" % [lid, stuck])
			print("  SOFT-LOCK  %-10s %s" % [lid, stuck])
		else:
			print("  ok         %-10s all %d steps completable" % [lid, T.step_count()])
		combat.queue_free(); await process_frame
		T.end()

	print("\nwalk: ", ("FAILED — " + str(bad)) if bad.size() else "clean — all 13 lessons completable")
	quit(1 if bad.size() else 0)


## Perform whatever the step is waiting for, through the UI paths a player uses.
func _do(combat, you, T, cond: String) -> bool:
	if cond.begins_with("unit_count"):
		return await _deploy_basic(combat, you)
	if cond == "played_energy":
		for i in you.hand.size():
			var c = _db.get_card(you.hand[i])
			if c != null and c.is_energy():
				combat._on_hand_pressed(i, c)
				await process_frame
				return true
		return false
	if cond == "selected_my_unit":
		var us = you.all_units()
		if us.is_empty(): return false
		combat._select_unit(us[0]); await process_frame; return true
	if cond.begins_with("attached"):
		var us2 = you.all_units()
		if us2.is_empty(): return false
		if you.pool <= 0: you.pool = 5
		combat._do_charge(you, us2[0], 2); await process_frame; return true
	if cond.begins_with("queued"):
		for u in you.all_units():
			for atk in u.card.attack_lines():
				if you.pool < u.pool_needed(atk): you.pool = 20
				if combat.gs.queue_attack(you, u, atk):
					await process_frame; return true
		return false
	if cond.begins_with("stage"):
		for i in you.hand.size():
			var c = _db.get_card(you.hand[i])
			if c == null or not c.is_unit() or c.evolves_from == "": continue
			for u in you.all_units():
				if u.card.id == c.evolves_from:
					combat._selected_hand = i
					combat._evolve_into(u)
					await process_frame
					return true
		return false
	if cond == "hand_has_retreated":
		for u in you.all_units():
			if u.attached < u.retreat_cost(): u.attached = u.retreat_cost() + 1
			if combat.gs.retreat(you, u):
				await process_frame; return true
		return false
	if cond == "unit_healed":
		for i in you.hand.size():
			var c = _db.get_card(you.hand[i])
			if c == null or not c.is_support_like(): continue
			var us3 = you.all_units()
			if us3.is_empty(): return false
			us3[0].take_damage(20)
			you.pool = 10
			combat._on_hand_pressed(i, c)
			await process_frame
			if combat._pending_support != null:
				combat._pick_support_target(us3[0])
				await process_frame
			if T.step_satisfied(): return true
		return false
	if cond == "playing" or cond.begins_with("round"):
		combat._on_end_turn()
		var t0 = Time.get_ticks_msec()
		while Time.get_ticks_msec() - t0 < 3000 and not T.step_satisfied():
			await process_frame
		return true
	return false


func _deploy_basic(combat, you) -> bool:
	for i in you.hand.size():
		var c = _db.get_card(you.hand[i])
		if c == null or not c.is_unit() or c.stage != CardData.Stage.BASIC: continue
		for bi in 2:
			for si in 2:
				if you.boards[bi].unit_at(si) == null:
					combat._selected_hand = i
					combat._deploy_to(bi, si)
					await process_frame
					return true
	return false
