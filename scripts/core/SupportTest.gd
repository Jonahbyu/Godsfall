extends SceneTree

## Total assertions this harness is expected to run; see the check at
## the end of the run. Update deliberately when assertions change.
## 158 -> 169: eleven for Reposition, repurposed from swapping two of your own
## units to shoving an enemy unit within its own board.
const EXPECTED_ASSERTIONS := 169

## Headless support/retreat harness:
##   godot --headless --script res://scripts/core/SupportTest.gd
##
## Covers the card types added alongside the neutral support file: support,
## Tool, and tower support resolution, the retreat action and its hand lock,
## and the end-of-turn hand limit. RulesTest still owns the core economy.

var _pass := 0
var _fail := 0

var GS
var UnitC
var PlayerC


func _initialize() -> void:
	var db = root.get_node_or_null("CardDB")
	if db == null:
		db = load("res://scripts/core/CardDB.gd").new()
		db.name = "CardDB"
		root.add_child(db)

	## Redirect saves before any game code can write them.
	var ds = root.get_node_or_null("DeckStore")
	if ds != null:
		ds.use_sandbox_path("support")

	GS = load("res://scripts/core/GameState.gd")
	UnitC = load("res://scripts/core/Unit.gd")
	PlayerC = load("res://scripts/core/Player.gd")

	_run(db)
	quit(1 if _fail > 0 else 0)


func _check(label: String, actual, expected) -> void:
	if actual == expected:
		_pass += 1
		print("  ok   %s" % label)
	else:
		_fail += 1
		print("  FAIL %s — expected %s, got %s" % [label, str(expected), str(actual)])


func _run(db) -> void:
	print("\n=== Godsfall support harness ===\n")
	_test_card_data(db)
	_test_deck_limits(db)
	_test_draw_and_energy(db)
	_test_healing(db)
	_test_damage_and_removal(db)
	_test_tools(db)
	_test_tower_support(db)
	_test_retreat(db)
	_test_retreat_supports(db)
	_test_reposition(db)
	_test_hand_limit(db)
	_test_full_game_with_supports(db)
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


## A game with a unit already on the board, so supports have something to target.
func _fresh() -> Array:
	var gs = GS.new([], [])
	## Units are placed directly and the rules API is called straight away; every
	## main-phase entry point is gated on the setup phase, which the full-game test
	## at the end of this file exercises properly.
	gs.skip_setup()
	return [gs, gs.players[0], gs.players[1]]


func _place(db, p, card_id: String, bi: int, si: int):
	var u = UnitC.new(db.get_card(card_id))
	p.boards[bi].place(u, si)
	return u


# ---- the card data itself loads with the right types
func _test_card_data(db) -> void:
	print("Card data:")
	var CD = load("res://scripts/core/CardData.gd")
	var ledger = db.get_card("gravekeepers_ledger")
	_check("Ledger is a support", ledger.type, CD.Type.SUPPORT)
	_check("Ledger is support-like", ledger.is_support_like(), true)
	_check("Ledger is not a unit", ledger.is_unit(), false)
	_check("Ledger is not energy", ledger.is_energy(), false)
	_check("Ledger draws 3", ledger.effect_value("draw", 0), 3)

	_check("Bone Splint is a Tool", db.get_card("bone_splint").is_tool(), true)
	_check("Reinforced Base is tower support", db.get_card("reinforced_base").is_tower_support(), true)
	_check("Reinforced Base is permanent", db.get_card("reinforced_base").permanent, true)
	_check("Rebuild is not permanent", db.get_card("rebuild").permanent, false)

	## Every support-like card must carry rules text and at least one effect,
	## or it would be an unplayable blank.
	var blanks := 0
	for id in db.all_ids():
		var c = db.get_card(id)
		if c.is_support_like() and (c.text == "" or c.effects.is_empty()):
			blanks += 1
			print("     blank: %s" % id)
	_check("no support has blank text or effects", blanks, 0)

	## Scoped to `neutral` on purpose: this asserts the size of the *neutral* support
	## pool from support.md, and a faction adding its own Tool must not break it.
	## Counting the whole database made every new faction card a test failure.
	var counts := { "support": 0, "tool": 0, "tower": 0 }
	for id in db.all_ids():
		var c = db.get_card(id)
		if c.faction != "neutral": continue
		if c.is_tool(): counts["tool"] += 1
		elif c.is_tower_support(): counts["tower"] += 1
		elif c.is_support_like(): counts["support"] += 1
	_check("31 neutral one-shot supports", counts["support"], 31)
	_check("6 neutral Tools", counts["tool"], 6)
	_check("6 neutral tower support", counts["tower"], 6)

	## Priced supports: cost is 0-3, and only plain supports may carry one.
	## Tools and tower support are off-limits by rule — they're already discounted
	## for paying out over time / being self-limiting. See CLAUDE.md.
	## The cost-range and no-priced-Tools rules are checked across the WHOLE
	## database, because they are game-wide invariants that any new faction must
	## also obey. The *count* is scoped to neutral cards only — a global count
	## breaks every time a faction ships a priced support, which makes it a
	## changelog rather than a test.
	var priced_neutral := 0
	var bad_cost := 0
	for id in db.all_ids():
		var c = db.get_card(id)
		if not c.is_support_like():
			continue
		if c.cost < 0 or c.cost > 3:
			bad_cost += 1
			print("     cost out of range: %s (%d)" % [id, c.cost])
		if c.cost > 0:
			if c.faction == "neutral":
				priced_neutral += 1
			if c.is_tool() or c.is_tower_support():
				bad_cost += 1
				print("     priced Tool/tower support: %s" % id)
	_check("no support cost outside 0-3, any faction", bad_cost, 0)
	_check("4 priced neutral supports", priced_neutral, 4)
	_check("Field Surgery costs 1", db.get_card("field_surgery").cost, 1)
	_check("Closing Ranks costs 2", db.get_card("closing_ranks").cost, 2)
	_check("Vigil costs 2", db.get_card("vigil").cost, 2)
	_check("Grave Warden's Oath costs 3", db.get_card("grave_wardens_oath").cost, 3)
	_check("free heals still cost 0", db.get_card("shore_up").cost, 0)

	## No card may restore a unit to full HP. A heal that scales with the target's
	## printed HP is unboundable on a big body, so every heal is a flat number (or
	## a flat rate, in Vigil's case). This guard is the rule, enforced.
	var full_heals := 0
	for id in db.all_ids():
		var c = db.get_card(id)
		if c.is_support_like() and c.has_effect("heal_full"):
			full_heals += 1
			print("     full heal: %s" % id)
	_check("no card fully heals a unit", full_heals, 0)
	_check("base heal is 20", db.get_card("shore_up").effect_value("heal", 0), 20)
	_check("1 energy buys +30", db.get_card("field_surgery").effect_value("heal", 0), 50)
	_check("Oath is a flat 100", db.get_card("grave_wardens_oath").effect_value("heal", 0), 100)
	_check("Last Breath is a flat 50", db.get_card("last_breath").effect_value("heal_conditional", 0), 50)


# ---- supports obey the 4-copy limit; only energy is exempt
func _test_deck_limits(_db) -> void:
	print("Deckbuilding limits:")
	## A bare `.new()` starts with save_path pointing at the *real* decks.json, and
	## every add() below calls save_decks(). Left unsandboxed this test wrote its
	## own fixture over the player's collection — a deck named "T" holding 4
	## Gravekeeper's Ledger, which is exactly what one bug report looked like.
	var store = load("res://scripts/core/DeckStore.gd").new()
	store.use_sandbox_path("supportlimits")
	store.decks = [store._new_entry("T", {})]
	store.active_index = 0
	_check("support is not treated as energy", store.is_energy("gravekeepers_ledger"), false)
	_check("support caps at 4 copies", store.max_copies_of("gravekeepers_ledger"), 4)
	_check("Tool caps at 4 copies", store.max_copies_of("bone_splint"), 4)
	_check("energy is still exempt", store.max_copies_of("hel_energy"), 99)

	for i in 4:
		store.add("gravekeepers_ledger")
	_check("4 copies added", store.count_of("gravekeepers_ledger"), 4)
	_check("a 5th copy is rejected", store.add("gravekeepers_ledger"), false)
	_check("supports don't count as energy", store.energy_count(), 0)
	_check("support_count sees them", store.support_count(), 4)


# ---- draw and energy supports
func _test_draw_and_energy(db) -> void:
	print("Draw & energy supports:")
	var f = _fresh()
	var gs = f[0]
	var p = f[1]

	p.deck = ["grave_whelp", "grave_whelp", "grave_whelp", "barrow_knight"]
	p.hand = ["gravekeepers_ledger"]
	_check("Ledger plays", gs.play_support(p, 0, null), true)
	_check("drew 3", p.hand.size(), 3)
	_check("deck went down by 3", p.deck.size(), 1)
	_check("Ledger went to the discard", p.discard.has("gravekeepers_ledger"), true)

	## Offering is pool energy, so it is exposed to decay and is not an energy card.
	p.hand = ["offering"]
	p.pool = 0
	p.energy_played_this_turn = false
	_check("Offering plays", gs.play_support(p, 0, null), true)
	_check("pool gained 3", p.pool, 3)
	_check("Offering is not an energy card play", p.energy_played_this_turn, false)

	## Sift the Ashes is dead when nothing died, and pays out after a bad turn.
	p.hand = ["sift_the_ashes"]
	p.pool = 0
	p.units_died_this_turn = 0
	gs.play_support(p, 0, null)
	_check("Sift pays nothing with no deaths", p.pool, 0)

	p.hand = ["sift_the_ashes"]
	p.units_died_this_turn = 6
	gs.play_support(p, 0, null)
	_check("Sift caps at 4", p.pool, 4)

	## Tithe consolidates two half-charged units into one.
	var a = _place(db, p, "grave_whelp", 0, 0)
	var b = _place(db, p, "barrow_knight", 0, 1)
	a.attached = 5
	b.attached = 2
	p.hand = ["tithe"]
	_check("Tithe plays on two units", gs.play_support(p, 0, [a, b]), true)
	_check("source is emptied", a.attached, 0)
	_check("destination holds both", b.attached, 7)


# ---- healing, capped at printed max HP
func _test_healing(db) -> void:
	print("Healing:")
	var f = _fresh()
	var gs = f[0]
	var p = f[1]

	var u = _place(db, p, "barrow_knight", 0, 0)   ## 50 HP
	u.hp = 10
	p.hand = ["shore_up"]
	_check("Shore Up plays", gs.play_support(p, 0, u), true)
	_check("healed 20 — the baseline", u.hp, 30)

	## Healing never goes above printed HP.
	u.hp = 45
	p.hand = ["shore_up"]
	gs.play_support(p, 0, u)
	_check("capped at printed max", u.hp, 50)

	## A full-HP unit is not a legal heal target, so the card is held.
	p.hand = ["shore_up"]
	_check("no legal target at full HP", gs.support_has_any_target(p, db.get_card("shore_up")), false)

	## Last Breath needs the unit at or below half, and heals a FLAT 50 — no card
	## in the game restores a unit to full, because a heal that scales with the
	## target's printed HP is unboundable on a big body.
	u.hp = 30
	_check("Last Breath illegal above half", gs.support_has_any_target(p, db.get_card("last_breath")), false)
	u.hp = 25
	_check("Last Breath legal at exactly half", gs.support_has_any_target(p, db.get_card("last_breath")), true)
	p.hand = ["last_breath"]
	gs.play_support(p, 0, u)
	_check("healed 50, capped by the small body", u.hp, 50)

	## On a body big enough to show it, Last Breath is 50 and not a reset.
	var big = _place(db, p, "hel_queen", 1, 0)     ## 110 HP
	big.hp = 20
	p.hand = ["last_breath"]
	gs.play_support(p, 0, big)
	_check("Last Breath is a flat 50, not a full heal", big.hp, 70)

	## Hold the Slot floors the unit at 1 HP for the turn — and it does not Toll,
	## because it did not die.
	u.hp = 20
	p.hand = ["hold_the_slot"]
	gs.play_support(p, 0, u)
	var pool_before = p.pool
	u.take_damage(500)
	_check("cannot be reduced below 1", u.hp, 1)
	_check("still alive", u.is_alive(), true)
	_check("no Toll paid — it did not die", p.pool, pool_before)

	## ---- the heal ladder. Base heal is 20 and each energy buys ~30 more, so:
	## Shore Up 20 (free) -> Field Surgery 50 (1) -> Grave Warden's Oath 100 (3).
	## Cost is printed but NOT yet charged, so these resolve for free; the pool
	## assertions below pin that so the day it changes, the tests say so.
	u.hp = 10
	p.hand = ["mend"]
	gs.play_support(p, 0, u)
	_check("Mend heals 10", u.hp, 20)

	big.hp = 20
	p.hand = ["field_surgery"]
	p.pool = 7
	_check("Field Surgery plays", gs.play_support(p, 0, big), true)
	_check("1 energy buys 50 — base 20 plus 30", big.hp, 70)
	_check("cost not charged yet", p.pool, 7)

	## Grave Warden's Oath is a flat 100 — big enough to top up almost any body,
	## but it is NOT a full heal and it overflows away on anything smaller.
	big.hp = 5
	p.hand = ["grave_wardens_oath"]
	gs.play_support(p, 0, big)
	_check("Oath heals 100", big.hp, 105)

	## Overflow: heal from a point where 100 would exceed max HP, so the excess
	## has somewhere to be wasted. Derived from the card's own max rather than a
	## literal, so tuning a body's HP never silently turns this test into a no-op.
	big.hp = big.max_hp() - 40
	p.hand = ["grave_wardens_oath"]
	gs.play_support(p, 0, big)
	_check("Oath overflow is wasted, not banked", big.hp, big.max_hp())

	## The Oath has no HP condition, unlike Last Breath — that is what it buys.
	## Both units must sit above half for this to test the condition and not the
	## other body: support_has_any_target scans the whole board.
	big.hp = 100
	u.hp = 45
	_check("Last Breath illegal with every unit above half",
		gs.support_has_any_target(p, db.get_card("last_breath")), false)
	_check("Oath legal at any damage", gs.support_has_any_target(p, db.get_card("grave_wardens_oath")), true)

	## Vigil scales with the round number and is capped at printed HP like
	## everything else.
	u.hp = 5
	gs.turn = 2
	p.hand = ["vigil"]
	gs.play_support(p, 0, u)
	_check("Vigil heals 15 x round 2", u.hp, 35)

	u.hp = 5
	gs.turn = 9
	p.hand = ["vigil"]
	gs.play_support(p, 0, u)
	_check("Vigil overflow capped at printed max", u.hp, 50)

	## Closing Ranks heals the whole board, not one unit — which is what makes it
	## worth 2 rather than 1: on four bodies it is 80 HP off a single card.
	var u2 = _place(db, p, "barrow_knight", 0, 1)
	u.hp = 10
	u2.hp = 10
	big.hp = 10
	p.hand = ["closing_ranks"]
	gs.play_support(p, 0, null)
	_check("Closing Ranks heals unit 1", u.hp, 30)
	_check("Closing Ranks heals unit 2", u2.hp, 30)
	_check("Closing Ranks reaches the other board too", big.hp, 30)


# ---- damage, energy destruction, tower damage
func _test_damage_and_removal(db) -> void:
	print("Damage & removal:")
	var f = _fresh()
	var gs = f[0]
	var p = f[1]
	var foe = f[2]

	var charged = _place(db, foe, "barrow_knight", 0, 0)
	charged.attached = 3
	var bare = _place(db, foe, "grave_whelp", 0, 1)

	## Collapse only ever hits an uncharged unit.
	var candidates = gs._support_unit_candidates(p, db.get_card("collapse"))
	_check("Collapse cannot target a charged unit", candidates.has(charged), false)
	_check("Collapse can target an uncharged unit", candidates.has(bare), true)

	p.hand = ["collapse"]
	_check("Collapse plays on the bare unit", gs.play_support(p, 0, bare), true)
	_check("dealt 20", bare.hp, 20)

	## Sever attacks the investment rather than the body.
	p.hand = ["sever"]
	_check("Sever plays", gs.play_support(p, 0, charged), true)
	_check("destroyed 2 attached", charged.attached, 1)
	_check("body untouched", charged.hp, 50)

	## Toppling Blow reaches the tower and only the tower.
	p.hand = ["toppling_blow"]
	_check("Toppling Blow plays", gs.play_support(p, 0, 0), true)
	_check("tower took 25", foe.boards[0].tower_hp, 50)
	_check("throne untouched", foe.throne_hp, 150)


# ---- Tools: one per unit, carried through evolution, lost on death and retreat
func _test_tools(db) -> void:
	print("Tools:")
	var f = _fresh()
	var gs = f[0]
	var p = f[1]

	var u = _place(db, p, "grave_whelp", 0, 0)
	p.hand = ["bone_splint"]
	_check("Tool attaches", gs.play_support(p, 0, u), true)
	_check("unit holds the Tool", u.tool.id, "bone_splint")

	## One Tool per unit.
	p.hand = ["weighted_chain"]
	_check("second Tool is rejected", gs.play_support(p, 0, u), false)
	_check("first Tool still attached", u.tool.id, "bone_splint")

	## Bone Splint heals at end of turn, capped at printed HP.
	u.hp = 20
	gs._resolve_tool_effects(p)
	_check("Bone Splint heals 5", u.hp, 25)

	## A Tool carries through evolution, like attached energy.
	p.hand = ["gravebound_reaper"]
	gs.evolve(p, 0, u)
	_check("Tool survives evolution", u.tool.id, "bone_splint")

	## Weighted Chain adds damage; Deadweight taxes attacks.
	var w = _place(db, p, "barrow_knight", 0, 1)
	w.tool = db.get_card("weighted_chain")
	_check("Weighted Chain adds 5", w.tool_damage_bonus(), 5)
	var atk = w.card.attacks[0]
	var base_cost = atk.total_cost()
	w.tool = db.get_card("deadweight")
	_check("Deadweight taxes the attack by 1", w.attack_cost(atk), base_cost + 1)

	## Iron Standard stacks with printed Retribution. These two only exercise
	## stat math, so they don't need a board slot — there are only 4 while the
	## towers are alive.
	var bell = UnitC.new(db.get_card("mourning_bell"))
	var printed = bell.retribution()
	bell.tool = db.get_card("iron_standard")
	_check("Iron Standard stacks", bell.total_retribution(), printed + 5)

	## Grave Anchor lowers the payable retreat cost without moving the printed one.
	var big = UnitC.new(db.get_card("hel_queen"))
	var printed_retreat = big.card.retreat
	big.tool = db.get_card("grave_anchor")
	_check("printed retreat is unchanged", big.card.retreat, printed_retreat)
	_check("payable retreat is 2 lower", big.retreat_cost(), max(0, printed_retreat - 2))

	## A Tool goes to the discard with the body it was on.
	## Slot 2 is the tower slot while the tower lives, so use a free lane slot.
	var doomed = _place(db, p, "grave_whelp", 1, 1)
	doomed.tool = db.get_card("ration_pack")
	doomed.hp = 0
	gs._cleanup_dead(p)
	_check("Tool discarded on death", p.discard.has("ration_pack"), true)


# ---- tower support: permanents stack without limit, lost when the tower dies
func _test_tower_support(db) -> void:
	print("Tower support:")
	var f = _fresh()
	var gs = f[0]
	var p = f[1]
	var foe = f[2]

	## Reinforced Base raises the ceiling rather than healing.
	p.hand = ["reinforced_base"]
	_check("tower support plays on your tower", gs.play_support(p, 0, 0), true)
	_check("max HP raised", p.boards[0].tower_max_hp, 95)
	_check("current HP raised too", p.boards[0].tower_hp, 95)
	_check("mod recorded", p.boards[0].tower_mods[0].id, "reinforced_base")

	## Permanents stack: a tower takes any number, including repeats.
	p.hand = ["murder_holes"]
	_check("a second permanent is accepted", gs.play_support(p, 0, 0), true)
	_check("both mods held", p.boards[0].tower_mods.size(), 2)
	_check("damage bonus applied", p.boards[0].tower_damage_bonus, 5)

	## A repeat of the same card stacks its effect again.
	p.hand = ["reinforced_base"]
	_check("a duplicate is accepted", gs.play_support(p, 0, 0), true)
	_check("max HP raised twice", p.boards[0].tower_max_hp, 115)
	_check("three mods held", p.boards[0].tower_mods.size(), 3)

	## The other tower is independent.
	p.hand = ["murder_holes"]
	_check("other tower takes its own", gs.play_support(p, 0, 1), true)
	_check("bonus is per tower", p.boards[1].tower_damage_bonus, 5)

	## One-shots don't take the slot, and cannot heal above max.
	p.boards[0].tower_hp = 30
	p.hand = ["rebuild"]
	_check("Rebuild plays alongside a permanent", gs.play_support(p, 0, 0), true)
	_check("repaired 25", p.boards[0].tower_hp, 55)
	_check("permanents untouched by a one-shot", p.boards[0].tower_mods.size(), 3)
	p.boards[0].tower_hp = 110
	p.hand = ["rebuild"]
	gs.play_support(p, 0, 0)
	_check("cannot heal above max", p.boards[0].tower_hp, 115)

	## A tower support must name a tower you control — a dead tower is no target.
	p.boards[0].tower_take_damage(999)
	_check("modifications lost with the tower", p.boards[0].tower_mods.size(), 0)
	p.hand = ["reinforced_base"]
	_check("cannot target a dead tower", gs.play_support(p, 0, 0), false)

	## Spite Engine turns a lost tower into one last swing.
	var f2 = _fresh()
	var gs2 = f2[0]
	var p2 = f2[1]
	var foe2 = f2[2]
	p2.hand = ["spite_engine"]
	gs2.play_support(p2, 0, 0)
	## The slot a tower faces is the enemy's own tower slot, which only holds a
	## unit once their tower is dead — so kill it first to open that slot.
	foe2.boards[0].tower_take_damage(999)
	var victim = _place(db, foe2, "barrow_knight", 0, 2)
	_check("facing slot is occupied", foe2.boards[0].unit_at(2), victim)
	p2.boards[0].tower_hp = 10
	gs2._destroy_tower(p2, 0)
	_check("Spite Engine hits the facing unit for 20", victim.hp, 30)

	## Open the Gate destroys your own tower and opens the slot immediately.
	var f3 = _fresh()
	var gs3 = f3[0]
	var p3 = f3[1]
	p3.deck = ["grave_whelp", "grave_whelp", "barrow_knight"]
	p3.hand = ["open_the_gate"]
	_check("Open the Gate plays", gs3.play_support(p3, 0, 1), true)
	_check("your tower is destroyed", p3.boards[1].tower_alive(), false)
	_check("drew 2", p3.hand.size(), 2)
	_check("the tower slot is now usable", p3.boards[1].is_slot_playable(2), true)


# ---- retreat
func _test_retreat(db) -> void:
	print("Retreat:")
	var f = _fresh()
	var gs = f[0]
	var p = f[1]

	## An uncharged unit is stuck on the board.
	var stuck = _place(db, p, "barrow_knight", 0, 0)
	var stuck_cost: int = stuck.retreat_cost()            ## printed, derived from HP
	_check("uncharged unit cannot retreat", stuck.can_retreat(), false)
	_check("retreat is refused", gs.retreat(p, stuck), false)
	_check("still on the board", p.boards[0].unit_at(0), stuck)

	## Pay from attached energy; leftover goes back to the pool.
	stuck.attached = 5
	stuck.hp = 10
	p.pool = 0
	_check("retreat succeeds once charged", gs.retreat(p, stuck), true)
	_check("slot is empty", p.boards[0].unit_at(0), null)
	_check("cost was spent, remainder refunded", p.pool, 5 - stuck_cost)
	_check("card returned to hand", p.hand.has("barrow_knight"), true)
	_check("locked for the turn", p.is_locked("barrow_knight"), true)
	_check("cannot be replayed while locked", gs.play_unit(p, p.hand.find("barrow_knight"), 0, 0), false)
	_check("did not go to the discard", p.discard.has("barrow_knight"), false)

	## The lock lifts next turn, and the card returns healed to full.
	p.begin_turn()
	_check("unlocked next turn", p.is_locked("barrow_knight"), false)
	var idx = p.hand.find("barrow_knight")
	_check("replayable next turn", gs.play_unit(p, idx, 0, 0), true)
	_check("returned healed to full", p.boards[0].unit_at(0).hp, 50)

	## Retreat does not trigger Toll — the unit did not die.
	var f2 = _fresh()
	var gs2 = f2[0]
	var p2 = f2[1]
	var toller = _place(db, p2, "grave_whelp", 0, 0)      ## Toll 1, retreat 1
	toller.attached = 1
	p2.pool = 0
	gs2.retreat(p2, toller)
	_check("no Toll refund on retreat", p2.pool, 0)

	## An evolved unit brings its whole path back, all locked.
	var f3 = _fresh()
	var gs3 = f3[0]
	var p3 = f3[1]
	var base = _place(db, p3, "grave_whelp", 0, 0)
	p3.hand = ["gravebound_reaper"]
	gs3.evolve(p3, 0, base)
	base.attached = 4
	_check("evolved unit retreats", gs3.retreat(p3, base), true)
	_check("Basic came back", p3.hand.has("grave_whelp"), true)
	_check("Stage 1 came back", p3.hand.has("gravebound_reaper"), true)
	_check("both locked", p3.is_locked("grave_whelp") and p3.is_locked("gravebound_reaper"), true)

	## Retreat discards the Tool — it saves the body, not the equipment.
	var f4 = _fresh()
	var gs4 = f4[0]
	var p4 = f4[1]
	var geared = _place(db, p4, "barrow_knight", 0, 0)
	geared.tool = db.get_card("bone_splint")
	geared.attached = 2
	gs4.retreat(p4, geared)
	_check("Tool discarded on retreat", p4.discard.has("bone_splint"), true)
	_check("Tool did not return to hand", p4.hand.has("bone_splint"), false)


# ---- the four retreat supports
func _test_retreat_supports(db) -> void:
	print("Retreat supports:")

	## Escape Route: cost 0, but the leftover attached energy still refunds.
	var f = _fresh()
	var gs = f[0]
	var p = f[1]
	var big = _place(db, p, "hel_queen", 0, 0)
	big.attached = 20
	p.pool = 0
	p.hand = ["escape_route"]
	_check("Escape Route plays", gs.play_support(p, 0, big), true)
	_check("all 20 energy returned to pool", p.pool, 20)
	_check("unit is off the board", p.boards[0].unit_at(0), null)

	## Withdraw pays from the pool — the only case where that is legal.
	var f2 = _fresh()
	var gs2 = f2[0]
	var p2 = f2[1]
	var bare = _place(db, p2, "barrow_knight", 0, 0)      ## no attached energy
	var bare_cost: int = bare.retreat_cost()             ## printed, derived from HP
	p2.pool = 5
	_check("normally stuck", bare.can_retreat(), false)
	p2.hand = ["withdraw"]
	_check("Withdraw plays", gs2.play_support(p2, 0, bare), true)
	_check("cost came out of the pool", p2.pool, 5 - bare_cost)
	_check("unit returned to hand", p2.hand.has("barrow_knight"), true)

	## Ground Give: no cost, no refund — the energy is written off.
	var f3 = _fresh()
	var gs3 = f3[0]
	var p3 = f3[1]
	var doomed = _place(db, p3, "barrow_knight", 0, 0)
	doomed.attached = 6
	p3.pool = 0
	p3.hand = ["ground_give"]
	_check("Ground Give plays", gs3.play_support(p3, 0, doomed), true)
	_check("attached energy is lost, not refunded", p3.pool, 0)
	_check("card came back to hand", p3.hand.has("barrow_knight"), true)
	_check("still locked", p3.is_locked("barrow_knight"), true)

	## Rally the Line lifts the lock so a retreated unit can be replayed at once.
	var f4 = _fresh()
	var gs4 = f4[0]
	var p4 = f4[1]
	var moving = _place(db, p4, "barrow_knight", 0, 0)
	moving.attached = 2
	gs4.retreat(p4, moving)
	_check("locked after retreat", p4.is_locked("barrow_knight"), true)
	p4.hand.append("rally_the_line")
	gs4.play_support(p4, p4.hand.find("rally_the_line"), null)
	_check("lock lifted", p4.is_locked("barrow_knight"), false)
	_check("can be replayed this turn", gs4.play_unit(p4, p4.hand.find("barrow_knight"), 0, 1), true)


# ---- Reposition: shoves an ENEMY unit within its own board
## Repurposed 2026-08-15. Free unit movement made the old "swap two of your own
## units" redundant, so the card points at the enemy instead — the one lever the
## player otherwise has none of. The assertions that matter are the two
## restrictions: the unit never leaves its own board, and it never changes owner.
func _test_reposition(db) -> void:
	print("Reposition:")

	var card = db.get_card("reposition")
	_check("reposition still exists", card != null, true)
	_check("moves an enemy unit", card.has_effect("move_enemy"), true)
	_check("no longer swaps your own units", card.has_effect("swap_slots"), false)

	var f = _fresh()
	var gs = f[0]
	var p = f[1]
	var foe = f[2]

	## Slot 2 is the tower slot on a fresh board, so the only empty usable slot
	## on board 0 is slot 1 — which is where the shove has to land.
	var shoved = _place(db, foe, "barrow_knight", 0, 0)
	shoved.attached = 3
	p.hand = ["reposition"]
	_check("Reposition plays on an enemy unit", gs.play_support(p, 0, shoved), true)
	_check("left its original slot", foe.boards[0].unit_at(0), null)
	_check("landed on the same board", foe.boards[0].unit_at(1), shoved)
	_check("never crossed to the enemy's other board", foe.boards[1].units().size(), 0)
	_check("never came to your side", p.all_units().size(), 0)
	_check("attached energy rides along", shoved.attached, 3)

	## A board with no empty usable slot fizzles: the unit stays put and nothing
	## raises. Slot 2 holds the living tower, so filling 0 and 1 is a full board.
	var f2 = _fresh()
	var gs2 = f2[0]
	var p2 = f2[1]
	var foe2 = f2[2]
	var stuck = _place(db, foe2, "barrow_knight", 0, 0)
	_place(db, foe2, "grave_whelp", 0, 1)
	p2.hand = ["reposition"]
	_check("plays even with nowhere to go", gs2.play_support(p2, 0, stuck), true)
	_check("stayed where it was", foe2.boards[0].unit_at(0), stuck)


# ---- hand limit, checked at end of turn
func _test_hand_limit(db) -> void:
	print("Hand limit:")
	var f = _fresh()
	var gs = f[0]
	var p = f[1]

	_check("limit is 10", PlayerC.MAX_HAND, 10)

	p.hand = []
	for i in 13:
		p.hand.append("grave_whelp")
	_check("over by 3", p.over_hand_limit(), 3)

	## No listener is connected, so the engine auto-discards the excess.
	gs.active = 0
	gs.end_turn()
	_check("discarded down to 10", gs.players[0].hand.size(), 10)

	## A draw support played into a full hand still draws its full amount —
	## the limit is checked at end of turn, not continuously.
	var f2 = _fresh()
	var gs2 = f2[0]
	var p2 = f2[1]
	p2.hand = []
	for i in 9:
		p2.hand.append("grave_whelp")
	p2.deck = ["barrow_knight", "barrow_knight", "barrow_knight"]
	p2.hand.append("gravekeepers_ledger")
	_check("Ledger plays from a full hand", gs2.play_support(p2, p2.hand.size() - 1, null), true)
	_check("all 3 cards drawn", p2.hand.size(), 12)


# ---- a full AI-vs-AI game with supports in the deck
func _test_full_game_with_supports(_db) -> void:
	print("Full AI vs AI game with supports:")
	var AI = load("res://scripts/core/AIPlayer.gd")

	## Both sides draw a RANDOM sample deck rather than mirroring a hand-built
	## mix. Every sample runs 15-21 support cards — draw, healing, Tools, tower
	## support, retreat — so the support paths are still exercised, and the
	## "cards were spent" assertion below keeps that honest. The advantage over
	## the old fixed mix is that this samples real matchups, which is what the
	## balance numbers in the docs actually need.
	var store = load("res://scripts/core/DeckStore.gd").new()
	store.use_sandbox_path("supportfullgame")
	store.seed_samples()          ## _ready() never runs for a bare .new()
	var a := _random_sample(store)
	var b := _random_sample(store)

	var gs = GS.new(store.list_at(a), store.list_at(b))
	gs.deck_names = [store.name_at(a), store.name_at(b)]
	print("  matchup: %s vs %s" % [gs.deck_names[0], gs.deck_names[1]])
	gs.players[0].is_ai = true
	var bot = AI.new(gs)

	## Both sides run setup before round 1 — see the note in RulesTest's mirror.
	bot.take_setup(gs.players[0])
	bot.take_setup(gs.players[1])

	var guard := 0
	while not gs.finished and guard < 300:
		guard += 1
		bot.take_turn()
		gs.end_turn()

	## NOTE: flaky, and the flake is a real signal — roughly 1 run in 10 hits the
	## round guard without finishing, because the throne's unconditional +5/turn
	## eventually outgrows the damage either side can land. `RulesTest.gd` carries
	## the same assertion and the same caveat. Do not "fix" this by raising the
	## guard or deleting the check — see Open Questions in CLAUDE.md.
	_check("game reached a conclusion", gs.finished, true)
	## The whole point of the run: supports were actually played, not held.
	var played: int = gs.players[0].discard.size() + gs.players[1].discard.size()
	_check("cards were spent during the game", played > 0, true)
	if gs.finished:
		print("  -> winner: %s (%s) on round %d" % [
			gs.deck_names[gs.winner], gs.players[gs.winner].display_name, gs.turn])
	else:
		print("  -> stalled after %d turns" % guard)

	## Nobody should end the game holding more than the hand limit.
	_check("P1 within the hand limit", gs.players[0].hand.size() <= PlayerC.MAX_HAND, true)
	_check("P2 within the hand limit", gs.players[1].hand.size() <= PlayerC.MAX_HAND, true)

	load("res://scripts/core/BattleLog.gd").record(gs, "SupportTest")


## A random legal sample deck index. Mirrors the helper in `RulesTest.gd`.
func _random_sample(store) -> int:
	var legal: Array[int] = []
	for i in store.deck_count():
		if store.is_legal_at(i):
			legal.append(i)
	if legal.is_empty():
		return 0
	return legal[randi() % legal.size()]
