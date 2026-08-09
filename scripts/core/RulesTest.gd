extends SceneTree

## Total assertions this harness is expected to run; see the check at
## the end of the run. Update deliberately when assertions change.
const EXPECTED_ASSERTIONS := 126

## Headless rules harness:
##   godot --headless --script res://scripts/core/RulesTest.gd
##
## Exercises the economy and combat rules from CLAUDE.md, then plays a full
## AI-vs-AI game to make sure nothing crashes or stalls.

var _pass := 0
var _fail := 0


func _initialize() -> void:
	## Under --script the autoloads are still created, but _ready() has not run
	## for them yet at this point. Grab the real CardDB node and load it once,
	## so game code (which calls the CardDB singleton) sees the same instance.
	var db = root.get_node_or_null("CardDB")
	if db == null:
		db = load("res://scripts/core/CardDB.gd").new()
		db.name = "CardDB"
		root.add_child(db)
	if db._cards.is_empty():
		db._load()

	_run(db)
	quit(1 if _fail > 0 else 0)


## A two-player game with empty decks, already past setup.
##
## These tests place units directly and call the rules API, and every main-phase entry
## point is gated on the setup phase — so a game left in Phase.SETUP would have each
## call silently return false and each assertion fail on an unchanged board. Setup
## itself is covered by `_test_setup` and by the full AI game.
func _game(GS):
	var gs = GS.new([], [])
	gs.skip_setup()
	return gs


func _check(label: String, actual, expected) -> void:
	if actual == expected:
		_pass += 1
		print("  ok   %s" % label)
	else:
		_fail += 1
		print("  FAIL %s — expected %s, got %s" % [label, str(expected), str(actual)])


func _run(db) -> void:
	print("\n=== Godsfall rules harness ===\n")
	_test_decay(db)
	_test_energy_scaling(db)
	_test_toll(db)
	_test_attach_and_queue(db)
	_test_targeting(db)
	_test_tower_fire(db)
	_test_retribution(db)
	_test_evolution_carries_energy(db)
	_test_rise(db)
	_test_abilities(db)
	_test_attack_lock(db)
	_test_setup(db)
	_test_structure_growth(db)
	_test_full_game(db)
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


# ---- pool decay: 20%, min 1, rounded down
func _test_decay(_db) -> void:
	print("Pool decay (20%, min 1, floor):")
	var p = load("res://scripts/core/Player.gd").new("T", false)
	p.pool = 10; p.apply_decay(); _check("10 -> 8", p.pool, 8)
	p.pool = 15; p.apply_decay(); _check("15 -> 12", p.pool, 12)
	p.pool = 4;  p.apply_decay(); _check("4 -> 3", p.pool, 3)
	p.pool = 1;  p.apply_decay(); _check("1 -> 0", p.pool, 0)
	p.pool = 0;  p.apply_decay(); _check("0 stays 0", p.pool, 0)


# ---- energy card on turn t gives t + 1
func _test_energy_scaling(_db) -> void:
	print("Energy income (turn t -> t+1):")
	var p = load("res://scripts/core/Player.gd").new("T", false)
	p.pool = 0
	_check("turn 1 -> +2", p.play_energy(1), 2)
	p.energy_played_this_turn = false
	_check("turn 5 -> +6", p.play_energy(5), 6)
	p.energy_played_this_turn = false
	_check("turn 9 -> +10", p.play_energy(9), 10)


# ---- Toll = printed value; pays into pool on death
func _test_toll(db) -> void:
	print("Toll (printed, pays pool, attached lost):")
	var UnitC = load("res://scripts/core/Unit.gd")
	var whelp = UnitC.new(db.get_card("grave_whelp"))
	_check("Grave Whelp 40 HP tolls 1", whelp.toll(), 1)
	var colossus = UnitC.new(db.get_card("charnel_colossus"))
	_check("Charnel Colossus 90 HP tolls 3", colossus.toll(), 3)
	var queen = UnitC.new(db.get_card("hel_queen"))
	_check("Queen has no Toll", queen.toll(), 0)

	## damage never changes Toll
	whelp.take_damage(35)
	_check("damaged Whelp still tolls 1", whelp.toll(), 1)

	var gs = load("res://scripts/core/GameState.gd").new(["grave_whelp"], ["grave_whelp"])
	gs.skip_setup()
	var p = gs.players[0]
	var u = UnitC.new(db.get_card("bonepicker"))
	u.attached = 4
	p.boards[0].place(u, 0)
	p.pool = 0
	u.hp = 0
	gs._cleanup_dead(p)
	_check("Bonepicker death -> pool 2 (Toll)", p.pool, 2)
	_check("slot left empty (no compacting)", p.boards[0].slots[0], null)


# ---- queueing pulls exactly the shortfall from the pool
func _test_attach_and_queue(db) -> void:
	print("Attach / queue economy:")
	var gs = load("res://scripts/core/GameState.gd").new(["grave_whelp"], ["grave_whelp"])
	gs.skip_setup()
	var p = gs.players[0]
	var UnitC = load("res://scripts/core/Unit.gd")
	var u = UnitC.new(db.get_card("grave_whelp"))
	p.boards[0].place(u, 0)

	p.pool = 20
	var gnaw = u.card.attacks[0]
	gs.queue_attack(p, u, gnaw)
	_check("1-cost attack pulls exactly 1 from a 20 pool", p.pool, 19)
	_check("1 energy now attached", u.attached, 1)

	## attached energy makes the attack free next time
	u.clear_queue()
	gs.queue_attack(p, u, gnaw)
	_check("re-queue costs nothing (already attached)", p.pool, 19)


# ---- across -> leftmost living unit -> tower -> throne
func _test_targeting(db) -> void:
	print("Targeting (across -> leftmost survivor -> tower -> throne):")
	var GS = load("res://scripts/core/GameState.gd")
	var UnitC = load("res://scripts/core/Unit.gd")

	## 1) hits the unit across
	var gs = _game(GS)
	var me = gs.players[0]
	var foe = gs.players[1]
	var att = UnitC.new(db.get_card("barrow_knight"))     ## Cleave 25
	me.boards[0].place(att, 0)
	var def = UnitC.new(db.get_card("thornshade"))        ## 50 HP, Retribution 10
	foe.boards[0].place(def, 0)
	me.pool = 5
	gs.queue_attack(me, att, att.card.attacks[0])
	gs._resolve_attacks(me)
	_check("defender took 25", def.hp, 25)

	## 2) empty slot across -> tower
	var gs2 = _game(GS)
	var me2 = gs2.players[0]
	var foe2 = gs2.players[1]
	var att2 = UnitC.new(db.get_card("barrow_knight"))
	me2.boards[0].place(att2, 0)
	me2.pool = 5
	gs2.queue_attack(me2, att2, att2.card.attacks[0])
	gs2._resolve_attacks(me2)
	_check("empty slot -> tower takes 25", foe2.boards[0].tower_hp, 25)

	## 3) dead tower -> throne
	var gs3 = _game(GS)
	var me3 = gs3.players[0]
	var foe3 = gs3.players[1]
	foe3.boards[0].tower_hp = 0
	var att3 = UnitC.new(db.get_card("barrow_knight"))
	me3.boards[0].place(att3, 0)
	me3.pool = 5
	gs3.queue_attack(me3, att3, att3.card.attacks[0])
	gs3._resolve_attacks(me3)
	_check("dead tower -> throne takes 25", foe3.throne_hp, 75)

	## 4) empty slot across, but a unit lives elsewhere on that board ->
	## redirect to the leftmost survivor, NOT the tower.
	var gs4 = _game(GS)
	var me4 = gs4.players[0]
	var foe4 = gs4.players[1]
	var att4 = UnitC.new(db.get_card("barrow_knight"))
	me4.boards[0].place(att4, 1)                          ## attacks slot 1
	var surv = UnitC.new(db.get_card("grave_whelp"))      ## 40 HP
	foe4.boards[0].place(surv, 0)                         ## but the survivor is in slot 0
	me4.pool = 5
	gs4.queue_attack(me4, att4, att4.card.attacks[0])
	gs4._resolve_attacks(me4)
	_check("redirects to the leftmost survivor", surv.hp, 15)
	_check("tower was shielded", foe4.boards[0].tower_hp, 50)

	## 5) shielding never crosses boards: a crowded board 1 does not protect
	## board 0's tower.
	var gs5 = _game(GS)
	var me5 = gs5.players[0]
	var foe5 = gs5.players[1]
	var att5 = UnitC.new(db.get_card("barrow_knight"))
	me5.boards[0].place(att5, 0)
	foe5.boards[1].place(UnitC.new(db.get_card("grave_whelp")), 0)   ## other board
	me5.pool = 5
	gs5.queue_attack(me5, att5, att5.card.attacks[0])
	gs5._resolve_attacks(me5)
	_check("other board shields nothing", foe5.boards[0].tower_hp, 25)

	## 6) no overkill: two attacks, the first kills, the second must redirect
	## to the other living unit rather than hitting the corpse or the tower.
	var gs6 = _game(GS)
	var me6 = gs6.players[0]
	var foe6 = gs6.players[1]
	var a6a = UnitC.new(db.get_card("barrow_knight"))     ## slot 0, Cleave 25
	var a6b = UnitC.new(db.get_card("barrow_knight"))     ## slot 1, Cleave 25
	me6.boards[0].place(a6a, 0)
	me6.boards[0].place(a6b, 1)
	var victim = UnitC.new(db.get_card("grave_whelp"))    ## 40 HP
	victim.hp = 20                                        ## dies to the first hit
	var other = UnitC.new(db.get_card("grave_whelp"))     ## 40 HP
	foe6.boards[0].place(victim, 0)
	foe6.boards[0].place(other, 1)
	me6.pool = 10
	gs6.queue_attack(me6, a6a, a6a.card.attacks[0])
	gs6.queue_attack(me6, a6b, a6b.card.attacks[0])
	gs6._resolve_attacks(me6)
	_check("first attack killed its target", victim.is_alive(), false)
	_check("no overkill — corpse took no extra damage", victim.hp <= 0, true)
	_check("second attack hit the other unit", other.hp, 15)
	_check("tower still shielded by the survivor", foe6.boards[0].tower_hp, 50)

	## 7) clearing the board opens it *within the same resolution*: the enemy
	## board holds one nearly-dead unit and my board 0 has two attackers, so
	## the first kills it and the second — with the board now clear — reaches
	## the tower. This is the sequencing rule the docs describe.
	var gs7 = _game(GS)
	var me7 = gs7.players[0]
	var foe7 = gs7.players[1]
	var a7a = UnitC.new(db.get_card("barrow_knight"))    ## slot 0, resolves first
	var a7b = UnitC.new(db.get_card("barrow_knight"))    ## slot 1, resolves second
	me7.boards[0].place(a7a, 0)
	me7.boards[0].place(a7b, 1)
	var lone = UnitC.new(db.get_card("grave_whelp"))
	lone.hp = 20                                          ## dies to the first Cleave
	foe7.boards[0].place(lone, 0)
	me7.pool = 10
	gs7.queue_attack(me7, a7a, a7a.card.attacks[0])
	gs7.queue_attack(me7, a7b, a7b.card.attacks[0])
	gs7._resolve_attacks(me7)
	_check("the lone defender died", lone.is_alive(), false)
	_check("board now clear -> second attack reached the tower", foe7.boards[0].tower_hp, 25)


# ---- towers: silent in round 1, then full damage to units and half to structures
func _test_tower_fire(db) -> void:
	print("Tower fire (silent round 1, full to units, 1/2 to structures):")
	var GS = load("res://scripts/core/GameState.gd")
	var UnitC = load("res://scripts/core/Unit.gd")

	## 0) the damage schedule itself: 0, 5, 8, 11, ... — silent through round 1,
	## then a flat 5 and +3 a round.
	var sched = _game(GS)
	var want := {1: 0, 2: 5, 3: 8, 4: 11, 5: 14, 8: 23, 12: 35}
	for r in want:
		sched.turn = r
		_check("round %d tower damage" % r, sched.tower_damage(), want[r])

	## 1) a unit in front eats the full shot and the structures behind take nothing.
	var gs = _game(GS)
	gs.turn = 4                                            ## tower deals 11
	var me = gs.players[0]
	var foe = gs.players[1]
	var wall = UnitC.new(db.get_card("charnel_colossus"))  ## 90 HP
	foe.boards[0].place(wall, 0)
	## Silence board 1 on both sides so only the board-0 pairing is under test.
	## My board-0 tower must stay ALIVE — it is the one doing the shooting.
	me.boards[1].tower_hp = 0
	foe.boards[1].tower_hp = 0
	gs._resolve_towers(me)
	_check("unit took the full 11", wall.hp, 79)
	_check("shielded enemy tower untouched", foe.boards[0].tower_hp, 50)
	_check("shielded throne untouched", foe.throne_hp, 100)

	## 2) empty board, enemy tower alive -> half into that tower.
	var gs2 = _game(GS)
	gs2.turn = 4                                           ## 11 -> chip 5
	var me2 = gs2.players[0]
	var foe2 = gs2.players[1]
	me2.boards[1].tower_hp = 0
	foe2.boards[1].tower_hp = 0
	gs2._resolve_towers(me2)
	_check("empty board -> tower chipped for 5", foe2.boards[0].tower_hp, 45)
	_check("throne still shielded by the live tower", foe2.throne_hp, 100)

	## 3) empty board and a dead tower -> half into the throne.
	var gs3 = _game(GS)
	gs3.turn = 8                                           ## 23 -> chip 11
	var me3 = gs3.players[0]
	var foe3 = gs3.players[1]
	me3.boards[1].tower_hp = 0
	foe3.boards[0].tower_hp = 0        ## the target tower is dead -> throne exposed
	foe3.boards[1].tower_hp = 0
	gs3._resolve_towers(me3)
	_check("empty board + dead tower -> throne chipped for 11", foe3.throne_hp, 89)

	## 4) round 1 is silent — towers deal nothing at all, to units or structures.
	## This is the grace round, not a floored-to-zero chip: nothing is touched.
	var gs4 = _game(GS)
	gs4.turn = 1
	var me4 = gs4.players[0]
	var foe4 = gs4.players[1]
	var early = UnitC.new(db.get_card("charnel_colossus"))
	foe4.boards[1].place(early, 0)     ## a unit to shoot at, on the other board
	me4.boards[1].tower_hp = 0
	gs4._resolve_towers(me4)
	_check("round 1: enemy tower untouched", foe4.boards[0].tower_hp, 50)
	_check("round 1: enemy unit untouched", early.hp, 90)
	_check("round 1: enemy throne untouched", foe4.throne_hp, 100)

	## 4b) the min-1 floor still applies to any odd damage that halves below 1.
	## Crossfire is the smallest source in the game: a single Murder Holes fires 5,
	## which halves to 2 — so drive the floor directly through _tower_strike.
	var gs4b = _game(GS)
	gs4b.turn = 5
	var foe4b = gs4b.players[1]
	foe4b.boards[1].tower_hp = 0
	gs4b._tower_strike(gs4b.players[0], foe4b, 1, 1, "floor probe")
	_check("a 1-damage strike floors at 1 against a structure", foe4b.throne_hp, 99)

	## 5) a unit anywhere on the board shields it, not just the facing slot.
	var gs5 = _game(GS)
	gs5.turn = 4
	var me5 = gs5.players[0]
	var foe5 = gs5.players[1]
	me5.boards[1].tower_hp = 0
	foe5.boards[1].tower_hp = 0
	var off = UnitC.new(db.get_card("charnel_colossus"))
	foe5.boards[0].place(off, 1)                           ## NOT the facing slot
	gs5._resolve_towers(me5)
	_check("leftmost survivor took the full 11", off.hp, 79)
	_check("tower shielded by an off-slot unit", foe5.boards[0].tower_hp, 50)


# ---- Retribution hits back at the attacker
func _test_retribution(db) -> void:
	print("Retribution:")
	var GS = load("res://scripts/core/GameState.gd")
	var UnitC = load("res://scripts/core/Unit.gd")
	var gs = _game(GS)
	var me = gs.players[0]
	var foe = gs.players[1]
	var att = UnitC.new(db.get_card("barrow_knight"))     ## 50 HP
	me.boards[0].place(att, 0)
	var def = UnitC.new(db.get_card("thornshade"))        ## Retribution 10
	foe.boards[0].place(def, 0)
	me.pool = 5
	gs.queue_attack(me, att, att.card.attacks[0])
	gs._resolve_attacks(me)
	_check("attacker took 10 back", att.hp, 40)


# ---- evolution carries attached energy
func _test_evolution_carries_energy(db) -> void:
	print("Evolution:")
	var GS = load("res://scripts/core/GameState.gd")
	var UnitC = load("res://scripts/core/Unit.gd")
	var gs = _game(GS)
	var p = gs.players[0]
	var u = UnitC.new(db.get_card("grave_whelp"))
	u.attached = 6
	p.boards[0].place(u, 0)
	p.hand = ["gravebound_reaper"]
	var ok = gs.evolve(p, 0, u)
	_check("evolve succeeded", ok, true)
	_check("now Gravebound Reaper", u.card.id, "gravebound_reaper")
	_check("attached energy carried", u.attached, 6)
	_check("HP is the new card's", u.hp, db.get_card("gravebound_reaper").max_hp)
	## The base card stays *under* the unit as its evolution path rather than
	## going to the discard, because retreat returns the whole path to hand.
	## It reaches the discard when the unit dies instead.
	_check("base card not discarded on evolve", p.discard.has("grave_whelp"), false)
	_check("base card is in the evolution path", u.evolution_path, ["grave_whelp"])
	_check("retreat would return both cards", u.retreat_cards(), ["grave_whelp", "gravebound_reaper"])

	## ...and dying sends the whole stack to the discard.
	u.hp = 0
	gs._cleanup_dead(p)
	_check("base card discarded on death", p.discard.has("grave_whelp"), true)
	_check("evolved card discarded on death", p.discard.has("gravebound_reaper"), true)

	## wrong base should be rejected
	var u2 = UnitC.new(db.get_card("bonepicker"))
	p.boards[0].place(u2, 1)
	p.hand = ["gravebound_reaper"]
	_check("cannot evolve off the wrong base", gs.evolve(p, 0, u2), false)


# ---- Rise returns at half HP without Rise, no attached energy
func _test_rise(db) -> void:
	print("Rise:")
	var GS = load("res://scripts/core/GameState.gd")
	var UnitC = load("res://scripts/core/Unit.gd")
	var gs = _game(GS)
	var p = gs.players[0]
	var u = UnitC.new(db.get_card("hollow_servant"))   ## 55 HP, Toll 2, Rise
	u.attached = 5
	p.boards[0].place(u, 0)
	p.pool = 0
	u.hp = 0
	gs._cleanup_dead(p)
	_check("Toll paid on first death", p.pool, 2)
	_check("queued to Rise", p.pending_rise.size(), 1)

	gs._begin_turn_for(p)
	var risen = p.boards[0].units()[0]
	_check("returned at half HP", risen.hp, 27)
	_check("returned without attached energy", risen.attached, 0)
	_check("Rise is spent", risen.has_rise(), false)
	_check("Toll survives the trip", risen.toll(), 2)

	## second death pays again, then it's gone for good
	p.pool = 0
	risen.hp = 0
	gs._cleanup_dead(p)
	_check("Toll paid a second time", p.pool, 2)
	_check("no third Rise", p.pending_rise.size(), 0)
	_check("now in discard", p.discard.has("hollow_servant"), true)


# ---- abilities: free, immediate, once per turn, pool untouched
func _test_abilities(db) -> void:
	print("Abilities (free, immediate, once per turn):")
	var GS = load("res://scripts/core/GameState.gd")
	var UnitC = load("res://scripts/core/Unit.gd")

	## Charnel Colossus' Consume the Fallen is a free ability.
	var gs = _game(GS)
	var p = gs.players[0]
	var colossus = UnitC.new(db.get_card("charnel_colossus"))
	p.boards[0].place(colossus, 0)
	var donor = UnitC.new(db.get_card("grave_whelp"))
	donor.attached = 5
	p.boards[0].place(donor, 1)

	var devour = colossus.card.ability_lines()[0]
	_check("Consume the Fallen is an ability", devour.is_ability, true)
	_check("it is free", devour.total_cost(), 0)
	_check("it is not in attack_lines", colossus.card.attack_lines().has(devour), false)

	## An ability must never *charge* the pool. The devoured Grave Whelp has
	## Toll 1, so the pool rises by exactly that refund and nothing else — the
	## ability itself took nothing.
	p.pool = 9
	gs.use_ability(p, colossus, devour, donor)
	_check("ability spent nothing from the pool (only the victim's Toll 1 paid in)",
		p.pool, 9 + donor.toll())
	_check("energy moved to the colossus", colossus.attached, 5)
	_check("donor was destroyed", donor.is_alive(), false)

	## Once per turn, per unit.
	_check("ability marked used", colossus.has_used_ability(devour), true)
	_check("second use in the same turn refused", gs.use_ability(p, colossus, devour), false)
	colossus.clear_abilities_used()
	_check("usable again after the reset", colossus.can_use_ability(devour), true)

	## An ability may never be queued as an attack.
	_check("queue_attack refuses an ability", gs.queue_attack(p, colossus, devour), false)

	## Consume: paid from attached energy, and destroyed rather than refunded.
	var gs2 = _game(GS)
	var p2 = gs2.players[0]
	var chorus = UnitC.new(db.get_card("hels_chorus"))
	p2.boards[0].place(chorus, 0)
	var dirge = chorus.card.ability_lines()[0]
	_check("Dirge consumes 1", dirge.consume_cost(), 1)

	chorus.attached = 0
	p2.pool = 20
	_check("cannot Consume with nothing attached, even on a full pool",
		chorus.can_use_ability(dirge), false)

	chorus.attached = 3
	gs2.use_ability(p2, chorus, dirge)
	_check("Consume burned 1 attached", chorus.attached, 2)
	_check("burned energy did not return to the pool", p2.pool, 20)
	_check("the ability still resolved", p2.eot_multiplier, 2)


# ---- attack lock: re-queues last turn's attack at the start of your turn
func _test_attack_lock(db) -> void:
	print("Attack lock:")
	var GS = load("res://scripts/core/GameState.gd")
	var UnitC = load("res://scripts/core/Unit.gd")

	var gs = _game(GS)
	var p = gs.players[0]
	var u = UnitC.new(db.get_card("grave_whelp"))
	p.boards[0].place(u, 0)
	var gnaw = u.card.attack_lines()[0]

	## Queueing is what arms the lock.
	p.pool = 10
	_check("no attack remembered yet", u.last_attack, null)
	gs.queue_attack(p, u, gnaw)
	_check("queueing records the attack", u.last_attack, gnaw)

	## With the lock off, nothing re-fires.
	u.clear_queue()
	p.auto_lock_attacks = false
	gs._fire_locked_attacks(p)
	_check("nothing re-queued while unlocked", u.queued_attack, null)

	## Global lock on: it re-fires.
	p.auto_lock_attacks = true
	gs._fire_locked_attacks(p)
	_check("global lock re-queues it", u.queued_attack, gnaw)

	## A per-unit override must beat the global setting.
	u.clear_queue()
	u.lock_mode = UnitC.LOCK_OFF
	gs._fire_locked_attacks(p)
	_check("per-unit unlock overrides the global lock", u.queued_attack, null)

	## ...and in the other direction.
	p.auto_lock_attacks = false
	u.lock_mode = UnitC.LOCK_ON
	gs._fire_locked_attacks(p)
	_check("per-unit lock overrides the global unlock", u.queued_attack, gnaw)

	## The lock never queues an attack the player cannot afford.
	u.clear_queue()
	u.attached = 0
	p.pool = 0
	gs._fire_locked_attacks(p)
	_check("unaffordable attack is skipped", u.queued_attack, null)

	## Evolution retires the remembered attack — it belonged to the old card.
	u.attached = 5
	p.pool = 5
	gs.queue_attack(p, u, gnaw)
	u.evolve_into(db.get_card("gravebound_reaper"))
	_check("evolution clears the remembered attack", u.last_attack, null)
	_check("but keeps the player's lock setting", u.lock_mode, UnitC.LOCK_ON)
	gs._fire_locked_attacks(p)
	_check("nothing re-fires until a new attack is chosen", u.queued_attack, null)


# ---- setup: guaranteed Basic, mulligan, and free Basic deployment
func _test_setup(db) -> void:
	print("Setup (guaranteed Basic, mulligan, free deployment):")
	var GS = load("res://scripts/core/GameState.gd")
	var store = load("res://scripts/core/DeckStore.gd").new()
	store.use_sandbox_path("rules_setup")
	store.seed_samples()

	## 1) the opening deal guarantees a Basic, on BOTH sides. Run it over every
	## sample deck rather than one, since the guarantee is a property of the deal
	## and must not depend on which list happens to be first.
	var deals_ok := true
	for i in store.deck_count():
		var g = GS.new(store.list_at(i), store.list_at(i))
		for pi in 2:
			var p = g.players[pi]
			if p.hand.size() != 6 or not p.has_basic_in_hand():
				deals_ok = false
	_check("every sample deck opens 6 with a Basic, both seats", deals_ok, true)

	## 2) a game starts in setup, and main-phase actions are illegal there.
	var gs = GS.new(store.list_at(0), store.list_at(0))
	_check("a new game starts in setup", gs.in_setup(), true)
	var p0 = gs.players[0]
	p0.pool = 10
	_check("no energy during setup", gs.play_energy(p0, 0), false)
	_check("end_turn is inert during setup", gs.turn, 1)
	gs.end_turn()
	_check("end_turn did not advance the round", gs.turn, 1)
	_check("end_turn did not leave setup", gs.in_setup(), true)

	## 3) the mulligan replaces the hand, once, and only before deploying.
	var before: Array = p0.hand.duplicate()
	_check("mulligan is available", gs.mulligan(p0), true)
	_check("hand is still 6", p0.hand.size(), 6)
	_check("still guaranteed a Basic", p0.has_basic_in_hand(), true)
	_check("mulligan is spent", p0.mulligan_used, true)
	_check("a second mulligan is refused", gs.mulligan(p0), false)
	## The old hand went back to the deck rather than to the discard — a mulligan
	## must not cost cards.
	_check("nothing was discarded by the mulligan", p0.discard.size(), 0)
	_check("deck + hand is conserved", p0.deck.size() + p0.hand.size(),
		before.size() + p0.deck.size())

	## 4) deploying a Basic during setup is free and needs no energy.
	var basic_i := -1
	for i in p0.hand.size():
		var c = db.get_card(p0.hand[i])
		if c != null and c.is_unit() and c.stage == 0:
			basic_i = i
			break
	_check("a Basic is in hand to place", basic_i >= 0, true)
	_check("setup deploy succeeds", gs.setup_deploy(p0, basic_i, 0, 0), true)
	_check("the unit is on the board", p0.boards[0].unit_at(0) != null, true)
	_check("deploying cost no energy", p0.pool, 10)

	## 5) once a unit is down the mulligan is gone even if unused — the decision is
	## meant to be made on the hand alone.
	var gs2 = GS.new(store.list_at(0), store.list_at(0))
	var q = gs2.players[0]
	var bi := -1
	for i in q.hand.size():
		var c = db.get_card(q.hand[i])
		if c != null and c.is_unit() and c.stage == 0:
			bi = i
			break
	gs2.setup_deploy(q, bi, 0, 0)
	_check("no mulligan after deploying", gs2.mulligan(q), false)

	## 6) round 1 begins only once BOTH players are ready.
	gs.finish_setup(gs.players[0])
	_check("one side ready is not enough", gs.in_setup(), true)
	gs.finish_setup(gs.players[1])
	_check("both ready -> play begins", gs.in_setup(), false)
	_check("play opens on round 1", gs.turn, 1)
	_check("play opens with P1 active", gs.active, 0)
	## The turn-start hook ran, so P1 has drawn for round 1.
	_check("P1 drew for round 1", gs.players[0].hand.size() > 0, true)


# ---- structures grow +5 once per ROUND, not once per player turn
func _test_structure_growth(_db) -> void:
	print("Structure growth (+5 per round, not per turn):")
	var GS = load("res://scripts/core/GameState.gd")
	var gs = _game(GS)
	var p0 = gs.players[0]
	var p1 = gs.players[1]

	_check("throne starts at 100", p0.throne_max_hp, 100)
	_check("tower starts at 50", p0.boards[0].tower_max_hp, 50)

	## P1 ends their turn: the round is not complete, so nothing grows.
	gs.active = 0
	gs.end_turn()
	_check("no growth after the first player's turn", p0.throne_max_hp, 100)
	_check("tower likewise ungrown", p0.boards[0].tower_max_hp, 50)

	## P2 ends theirs: the round is complete and BOTH players' structures grow once.
	gs.end_turn()
	_check("throne +5 after a full round", p0.throne_max_hp, 105)
	_check("both players grow together", p1.throne_max_hp, 105)
	_check("tower +5 after a full round", p0.boards[0].tower_max_hp, 55)

	## A second full round adds exactly 5 more, not 10.
	gs.end_turn()
	gs.end_turn()
	_check("two rounds is +10 total, not +20", p0.throne_max_hp, 110)
	_check("tower after two rounds", p0.boards[0].tower_max_hp, 60)


# ---- full AI vs AI game
func _test_full_game(db) -> void:
	print("Full AI vs AI game:")
	var GS = load("res://scripts/core/GameState.gd")
	var AI = load("res://scripts/core/AIPlayer.gd")

	## Both sides draw a RANDOM sample deck rather than mirroring one list.
	## A mirror only ever measures the AI against itself with identical draws,
	## so it can never surface a matchup problem — which is the thing worth
	## sampling. A same-deck pairing is allowed to come up by chance; the draw
	## is uniform and forcing distinctness would bias it.
	var store = load("res://scripts/core/DeckStore.gd").new()
	store.use_sandbox_path("rulesfullgame")
	store.seed_samples()          ## _ready() never runs for a bare .new()
	var a := _random_sample(store)
	var b := _random_sample(store)

	var gs = GS.new(store.list_at(a), store.list_at(b))
	gs.deck_names = [store.name_at(a), store.name_at(b)]
	print("  matchup: %s vs %s" % [gs.deck_names[0], gs.deck_names[1]])
	gs.players[0].is_ai = true
	var bot = AI.new(gs)

	## Setup: both sides mulligan and place Basics before round 1. The game will not
	## leave Phase.SETUP until both have finished, and `end_turn()` is a no-op there,
	## so skipping this would spin the loop to the guard without a single turn passing.
	bot.take_setup(gs.players[0])
	bot.take_setup(gs.players[1])

	var guard := 0
	while not gs.finished and guard < 300:
		guard += 1
		bot.take_turn()
		gs.end_turn()

	## NOTE: this assertion is currently flaky, and the flake is a real signal.
	## Since the Stage 2 buff to 100-175 (2026-08-08) roughly 1 run in 14 hits the
	## 300-round guard without finishing, because the throne's unconditional +5/turn
	## outgrows the damage either side can land. Do not "fix" it by raising the guard
	## or deleting the check -- see Open Questions in CLAUDE.md.
	_check("game reached a conclusion", gs.finished, true)
	if gs.finished:
		print("  -> winner: %s (%s) on round %d" % [
			gs.deck_names[gs.winner], gs.players[gs.winner].display_name, gs.turn])
	else:
		print("  -> stalled after %d turns (throne HP %d / %d)" % [guard, gs.players[0].throne_hp, gs.players[1].throne_hp])

	## Append the full record — decks, structures, per-card damage — so balance
	## can be read across many runs instead of off one console scroll.
	load("res://scripts/core/BattleLog.gd").record(gs, "RulesTest")


## A random legal sample deck index. Falls back to 0 so the harness still runs
## if every sample were somehow illegal — a broken deck should fail the
## DeckStore assertions, not silently skip the game.
func _random_sample(store) -> int:
	var legal: Array[int] = []
	for i in store.deck_count():
		if store.is_legal_at(i):
			legal.append(i)
	if legal.is_empty():
		return 0
	return legal[randi() % legal.size()]
