extends SceneTree

## Total assertions this harness is expected to run; see the check at
## the end of the run. Update deliberately when assertions change.
const EXPECTED_ASSERTIONS := 61

## Headless Heaven harness:
##   godot --headless --script res://scripts/core/HeavenTest.gd
##
## Covers both halves of Judgment, the Heaven mirror ordering, Sanctuary pool
## depletion and terminal overflow, Sanctuary against non-attack damage sources,
## the reset cards, and the batched-death guarantee.
##
## The pipeline tests drive the real GameState rather than simulating the rules
## inline — a test that reimplements the ordering it is checking proves nothing.

var _pass := 0
var _fail := 0


func _initialize() -> void:
	## Under --script the autoloads exist but their _ready() has not run. Grab the
	## real CardDB node and load it once so game code sees the same instance.
	var db = root.get_node_or_null("CardDB")
	if db == null:
		db = load("res://scripts/core/CardDB.gd").new()
		db.name = "CardDB"
		root.add_child(db)
	if db._cards.is_empty():
		db._load()

	_run(db)
	quit(1 if _fail > 0 else 0)


func _check(label: String, actual, expected) -> void:
	if actual == expected:
		_pass += 1
		print("  ok   %s" % label)
	else:
		_fail += 1
		print("  FAIL %s — expected %s, got %s" % [label, str(expected), str(actual)])


func _unit(db, id: String) -> Unit:
	return Unit.new(db.get_card(id))


## A two-player game with empty decks, for driving real attacks. Units are placed
## into slots directly — these tests exercise the damage pipeline, not deployment.
##
## Loaded by path rather than by class name: under --script the CardDB autoload is
## not resolvable as an identifier at compile time, so a typed `GameState` return
## fails to compile. RulesTest.gd uses the same workaround.
func _game(_db):
	var gs = load("res://scripts/core/GameState.gd").new([], [])
	## These tests place units directly and call the rules API, which is gated on the
	## setup phase. Setup itself is covered in RulesTest.
	gs.skip_setup()
	return gs


func _run(db) -> void:
	print("\n=== Godsfall Heaven harness ===\n")
	_test_card_data(db)
	_test_sanctuary_pool(db)
	_test_sanctuary_overflow(db)
	_test_judgment_defensive_live(db)
	_test_judgment_offensive_live(db)
	_test_judgment_mirror_live(db)
	_test_judgment_no_double_dip(db)
	_test_sanctuary_blocks_attack_live(db)
	_test_restore_own_judgment(db)
	_test_restore_board_judgment(db)
	_test_rise_restores_keywords(db)
	_test_evolution_restores_keywords(db)
	_test_spent_keywords_disappear(db)
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


# ---- every Heaven card loads with the printed values from heaven.md
func _test_card_data(db) -> void:
	print("Heaven card data:")
	var acolyte := _unit(db, "lantern_acolyte")
	_check("Lantern Acolyte HP", acolyte.max_hp(), 40)
	_check("Lantern Acolyte Judgment", acolyte.judgment(), 10)
	var bastion := _unit(db, "radiant_bastion")
	_check("Radiant Bastion Sanctuary pool", bastion.sanctuary_pool, 60)
	_check("Radiant Bastion Sanctuary live", bastion.sanctuary_active, true)
	var warden := _unit(db, "warden_of_the_lamp")
	_check("plain Sanctuary is live at pool 0", warden.sanctuary_active, true)
	_check("plain Sanctuary pool is 0", warden.sanctuary_pool, 0)
	_check("Warden has no Judgment", warden.has_judgment(), false)
	var court := _unit(db, "court_of_bells")
	_check("Court of Bells carries no printed Judgment", court.card.has_kw("judgment"), false)
	_check("Heaven energy card exists", db.energy_card_of("heaven") != null, true)


# ---- pool depletes; small hits are inefficient against it
func _test_sanctuary_pool(db) -> void:
	print("Sanctuary N depletion:")
	var u := _unit(db, "radiant_bastion")
	_check("30 into pool 60 -> 0 through", u.absorb(30), 0)
	_check("pool now 30", u.sanctuary_pool, 30)
	_check("still live", u.sanctuary_active, true)
	_check("20 more -> 0 through", u.absorb(20), 0)
	_check("pool now 10", u.sanctuary_pool, 10)


# ---- overflow: a pool that cannot cover a hit drains exactly and the rest lands
#
# `Sanctuary N` used to absorb the WHOLE instance when its pool could not cover it,
# which made every shielded body worth `pool + one arbitrarily large hit`. A deck
# of thirty such bodies could not be killed (Sealed Light, 88-91% over 3M games).
# The pool now drains exactly. PLAIN Sanctuary keeps the full absorb, because it
# has no pool and draining it exactly would delete the keyword.
func _test_sanctuary_overflow(db) -> void:
	print("Sanctuary overflow:")
	var u := _unit(db, "radiant_bastion")
	_check("110 into pool 60 -> 50 through", u.absorb(110), 50)
	_check("shield spent", u.sanctuary_active, false)
	_check("pool emptied", u.sanctuary_pool, 0)
	_check("next hit passes fully", u.absorb(25), 25)

	var w := _unit(db, "warden_of_the_lamp")
	_check("plain Sanctuary eats a 75 hit", w.absorb(75), 0)
	_check("plain Sanctuary now spent", w.sanctuary_active, false)


# ---- defensive half, through the real damage pipeline
func _test_judgment_defensive_live(db) -> void:
	print("Judgment defensive half (live pipeline):")
	var gs = _game(db)
	var p = gs.players[0]
	var e = gs.players[1]

	var attacker := _unit(db, "radiant_bastion")            ## no Judgment
	var defender := _unit(db, "arbiter_of_the_third_seal")  ## Judgment 30
	p.boards[0].slots[0] = attacker
	e.boards[0].slots[0] = defender

	## A hit that leaves the body at 5 is survivable, so defensive Judgment must NOT
	## fire — the charge is only spent when the unit would actually die. Damage is
	## derived from the defender's HP so tuning the body never turns this into a
	## lethal hit (which would test the opposite rule) or an above-threshold one.
	var survivable: int = defender.max_hp() - 5
	gs._deal_lane_damage(p, e, attacker, 0, 0, survivable, attacker.card.attacks[0])
	_check("non-lethal hit leaves it at 5", defender.hp, 5)
	_check("charge untouched", defender.has_judgment(), true)

	## A second hit is lethal — now the defensive half fires.
	gs._deal_lane_damage(p, e, attacker, 0, 0, 65, attacker.card.attacks[0])
	_check("lethal hit -> survives at 30", defender.hp, 30)
	_check("charge spent", defender.has_judgment(), false)
	_check("printed value unchanged", defender.judgment(), 30)
	_check("still alive, still shielding", defender.is_alive(), true)

	## With the charge gone, the next lethal hit actually kills.
	gs._deal_lane_damage(p, e, attacker, 0, 0, 65, attacker.card.attacks[0])
	_check("no second reprieve", defender.is_alive(), false)


# ---- offensive half: a survivor at or below N is executed
func _test_judgment_offensive_live(db) -> void:
	print("Judgment offensive half (live pipeline):")
	var gs = _game(db)
	var p = gs.players[0]
	var e = gs.players[1]

	var attacker := _unit(db, "arbiter_of_the_third_seal")   ## Judgment 30
	var defender := _unit(db, "hollow_servant")              ## 55 HP Hel body
	p.boards[0].slots[0] = attacker
	e.boards[0].slots[0] = defender

	## 25 damage leaves 30 — exactly at the threshold, so the execute fires.
	gs._deal_lane_damage(p, e, attacker, 0, 0, 25, attacker.card.attacks[0])
	_check("defender executed at the threshold", defender.is_alive(), false)
	_check("attacker charge spent", attacker.has_judgment(), false)

	## A spent attacker no longer executes.
	var d2 := _unit(db, "hollow_servant")
	e.boards[0].slots[1] = d2
	gs._deal_lane_damage(p, e, attacker, 0, 1, 25, attacker.card.attacks[0])
	_check("spent Judgment does not execute", d2.is_alive(), true)
	_check("it just took the damage", d2.hp, 30)


# ---- the mirror: both charges spend, the defender lives at its own N
func _test_judgment_mirror_live(db) -> void:
	print("Judgment mirror (live pipeline):")
	var gs = _game(db)
	var p = gs.players[0]
	var e = gs.players[1]

	var attacker := _unit(db, "arbiter_of_the_third_seal")   ## Judgment 30
	var defender := _unit(db, "lantern_acolyte")             ## 40 HP, Judgment 10
	p.boards[0].slots[0] = attacker
	e.boards[0].slots[0] = defender

	## A lethal hit: defensive Judgment fires first (step 4), so the defender
	## survives at 10 and the offensive half is NOT re-checked on it.
	gs._deal_lane_damage(p, e, attacker, 0, 0, 40, attacker.card.attacks[0])
	_check("defender survives at its own N", defender.hp, 10)
	_check("defender charge spent", defender.has_judgment(), false)
	_check("attacker charge NOT spent (step 4 won)", attacker.has_judgment(), true)

	## Now the defender is at 10 with no charge. The attacker's execute fires on
	## the next hit, since 10 is inside its Judgment 30 threshold.
	gs._deal_lane_damage(p, e, attacker, 0, 0, 1, attacker.card.attacks[0])
	_check("survivor inside range is executed", defender.is_alive(), false)
	_check("attacker charge now spent", attacker.has_judgment(), false)


# ---- a unit saved by its own Judgment is not immediately executed by the same hit
func _test_judgment_no_double_dip(db) -> void:
	print("Judgment save is not re-executed by the same attack:")
	var gs = _game(db)
	var p = gs.players[0]
	var e = gs.players[1]

	## Seraph has Judgment 50; the defender survives at 30, which is inside 50.
	## Without the elif in step 5 this would delete the save it just made.
	var attacker := _unit(db, "seraph_of_the_final_ledger")
	var defender := _unit(db, "arbiter_of_the_third_seal")
	p.boards[0].slots[0] = attacker
	e.boards[0].slots[0] = defender

	gs._deal_lane_damage(p, e, attacker, 0, 0, 200, attacker.card.attacks[1])
	_check("saved at 30, not executed", defender.hp, 30)
	_check("defender charge spent", defender.has_judgment(), false)
	_check("attacker charge NOT spent", attacker.has_judgment(), true)


# ---- Sanctuary absorbs an attack before Judgment is ever consulted
func _test_sanctuary_blocks_attack_live(db) -> void:
	print("Sanctuary precedes Judgment (live pipeline):")
	var gs = _game(db)
	var p = gs.players[0]
	var e = gs.players[1]

	var attacker := _unit(db, "radiant_bastion")
	var defender := _unit(db, "empyrean_sentinel")   ## plain Sanctuary
	var full := defender.max_hp()
	p.boards[0].slots[0] = attacker
	e.boards[0].slots[0] = defender

	gs._deal_lane_damage(p, e, attacker, 0, 0, 65, attacker.card.attacks[0])
	_check("shield ate the whole hit", defender.hp, full)
	_check("shield now spent", defender.sanctuary_active, false)

	gs._deal_lane_damage(p, e, attacker, 0, 0, 65, attacker.card.attacks[0])
	_check("second hit lands", defender.hp, full - 65)


# ---- Bellringer recharges itself through the real effect path
func _test_restore_own_judgment(db) -> void:
	print("Recall the Verdict:")
	var gs = _game(db)
	var p = gs.players[0]
	var e = gs.players[1]

	var bell := _unit(db, "bellringer_of_the_court")
	bell.judgment_spent = true
	p.boards[0].slots[0] = bell
	e.boards[0].slots[0] = _unit(db, "hollow_servant")

	_check("starts spent", bell.has_judgment(), false)
	gs._resolve_line_effects(p, e, bell, bell.card.attacks[0], null, 0, 0)
	_check("recalled by its own attack", bell.has_judgment(), true)


# ---- Court of Bells resets printed Judgment only
func _test_restore_board_judgment(db) -> void:
	print("Ring the Court Bell:")
	var gs = _game(db)
	var p = gs.players[0]
	var e = gs.players[1]

	var court := _unit(db, "court_of_bells")
	var a := _unit(db, "arbiter_of_the_third_seal")
	var b := _unit(db, "censer_bearer")
	var granted := _unit(db, "warden_of_the_lamp")   ## no printed Judgment
	a.judgment_spent = true
	b.judgment_spent = true
	granted.judgment_spent = true                    ## nonsense state, but proves the filter

	p.boards[0].slots[0] = court
	p.boards[0].slots[1] = a
	p.boards[1].slots[0] = b
	p.boards[1].slots[1] = granted

	gs._resolve_line_effects(p, e, court, court.card.attacks[0], null, -1, -1)
	_check("Arbiter restored", a.has_judgment(), true)
	_check("Censer Bearer restored", b.has_judgment(), true)
	_check("unit without printed Judgment untouched", granted.card.has_kw("judgment"), false)


# ---- Rise returns a fresh body with its printed keywords restored
func _test_rise_restores_keywords(db) -> void:
	print("Rise restores Judgment:")
	var u := _unit(db, "throne_of_the_risen_court")
	u.judgment_spent = true
	var risen := u.make_risen()
	_check("returns at half HP", risen.hp, int(u.card.max_hp / 2.0))
	_check("Judgment restored", risen.has_judgment(), true)
	_check("Rise is spent", risen.has_rise(), false)
	_check("no attached energy", risen.attached, 0)


# ---- evolution is a new printed card, so both keywords re-arm
func _test_evolution_restores_keywords(db) -> void:
	print("Evolution re-arms keywords:")
	var u := _unit(db, "warden_of_the_lamp")
	u.absorb(999)                                     ## burn the shield
	_check("shield spent before evolving", u.sanctuary_active, false)
	u.evolve_into(db.get_card("radiant_bastion"))
	_check("evolved body has the new pool", u.sanctuary_pool, 60)
	_check("evolved body is shielded", u.sanctuary_active, true)


# ---- a spent keyword must visibly disappear from the board
#
# The rules worked from the start, but `CardData.keyword_line()` reads the *printed*
# card, so a unit that had spent its Judgment still displayed "Judgment 30" on the
# board. On a keyword whose whole design is "one charge, spend it wisely", being
# unable to see which units still hold a charge makes the decision unplayable — the
# mechanic was correct and invisible, which reads to a player as broken.
func _test_spent_keywords_disappear(db) -> void:
	print("Spent keywords leave the board display:")
	var CV = load("res://scripts/ui/CardView.gd")

	var arb := _unit(db, "arbiter_of_the_third_seal")
	var v1 = CV.new(arb.card, arb, 1)
	_check("fresh shows Judgment", v1._live_keyword_line(), "Judgment 30")
	arb.judgment_spent = true
	var v2 = CV.new(arb.card, arb, 1)
	_check("spent Judgment is gone", v2._live_keyword_line(), "")
	_check("printed card is untouched", arb.card.keyword_line(), "Judgment 30")
	v1.free()
	v2.free()

	## Sanctuary N shows what is *left*, since a depleted pool is the state that
	## decides whether attacking into it is worthwhile.
	var bas := _unit(db, "radiant_bastion")
	bas.absorb(20)
	var v3 = CV.new(bas.card, bas, 1)
	_check("pool shows remaining, not printed", v3._live_keyword_line(), "Sanctuary 40")
	bas.absorb(9999)
	var v4 = CV.new(bas.card, bas, 1)
	_check("blown shield is gone", v4._live_keyword_line(), "")
	v3.free()
	v4.free()

	## Partial spend: one keyword drops, the other stays.
	var thr := _unit(db, "throne_of_the_risen_court")
	thr.judgment_spent = true
	var v5 = CV.new(thr.card, thr, 1)
	_check("Rise survives a spent Judgment", v5._live_keyword_line(), "Rise")
	v5.free()

	## Hel is unaffected — Toll is permanent, Rise still strips as it always did.
	var hs := _unit(db, "hollow_servant")
	hs.lost_rise = true
	var v6 = CV.new(hs.card, hs, 1)
	_check("Toll stays, Rise strips", v6._live_keyword_line(), "Toll 2")
	v6.free()
