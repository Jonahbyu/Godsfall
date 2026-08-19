extends SceneTree

## Tempest harness — `Charge` (a per-unit banked counter that grows when the unit
## DEALS damage) and `Storm` (a global damage ramp both players read).
## See docs/specs/2026-08-17-tempest-faction-design.md.
##
## Run: godot --headless --path <project> --script res://scripts/core/TempestTest.gd

## Total assertions this harness is expected to run. Checked at the end, because
## a crash mid-file produces "0 failed" and exit 0 — the assertions after the
## crash simply never run, and silence reads identically to success.
const EXPECTED_ASSERTIONS := 46

const CardDataS = preload("res://scripts/core/CardData.gd")
const UnitS = preload("res://scripts/core/Unit.gd")

var _pass := 0
var _fail := 0


func _check(label: String, got, want) -> void:
	if got == want:
		_pass += 1
	else:
		_fail += 1
		print("FAIL: %s — got %s, want %s" % [label, got, want])


func _ok(label: String, cond: bool) -> void:
	_check(label, cond, true)


## A bare unit from an inline card dict, so these tests do not depend on
## data/cards.json having been regenerated yet.
func _unit(d: Dictionary) -> Unit:
	return UnitS.new(CardDataS.from_dict(d))


func _charger(n: int) -> Dictionary:
	return {
		"id": "t_a", "name": "Testsile", "type": "unit", "faction": "tempest",
		"stage": "basic", "hp": 50, "keywords": [{"kw": "charge", "n": n}],
		"attacks": [],
	}


## `_initialize()` rather than `_init()`, and CardDB registered by hand: under
## `--script` the autoloads are not in the tree, and without this `Player.new()`
## inside `GameState._init` resolves to a bare GDScript and returns null.
func _initialize() -> void:
	var db = root.get_node_or_null("CardDB")
	if db == null:
		db = load("res://scripts/core/CardDB.gd").new()
		db.name = "CardDB"
		root.add_child(db)
	if db._cards.is_empty():
		db._load()

	_test_charge_counter()
	_test_charge_persistence()
	_test_storm_counter()
	_test_storm_instance()
	_test_charge_growth()
	_test_charge_kill_vs_judgment()
	_test_discharge()
	_test_storm_ops()

	print("%d passed, %d failed" % [_pass, _fail])
	if _pass + _fail != EXPECTED_ASSERTIONS:
		print("FAIL: expected %d assertions, ran %d" % [EXPECTED_ASSERTIONS, _pass + _fail])
		_fail += 1
	quit(1 if _fail > 0 else 0)


func _test_charge_counter() -> void:
	var u := _unit(_charger(3))
	_check("charge starts at 0", u.charge, 0)
	u.add_charge(3)
	_check("add_charge raises it", u.charge, 3)
	u.add_charge(3)
	_check("charge accumulates", u.charge, 6)
	_check("spend_charge returns the whole counter", u.spend_charge(), 6)


func _test_charge_persistence() -> void:
	var evolved := CardDataS.from_dict({
		"id": "t_a2", "name": "Testgale", "type": "unit", "faction": "tempest",
		"stage": "stage1", "hp": 96, "keywords": [{"kw": "charge", "n": 8}],
		"attacks": [],
	})

	## Evolution CARRIES the value and CHANGES the rate. The exception to
	## "new printed card, new everything", and the whole reason Tempest can evolve.
	var u := _unit(_charger(3))
	u.add_charge(21)
	_check("basic banks at its printed rate", u.charge_rate(), 3)
	u.evolve_into(evolved)
	_check("charge SURVIVES evolution", u.charge, 21)
	_check("but the rate is the new card's", u.charge_rate(), 8)

	## Rise restores the card, not the history — the rule grown Earth follows.
	var r := _unit(_charger(3))
	r.add_charge(30)
	_check("Rise returns the unit with no charge", r.make_risen().charge, 0)

	## kw_mods clear on evolution, so a raised rate does not ride along.
	var m := _unit(_charger(3))
	m.add_kw_mod("charge", 5)
	_check("a raised Charge rate reads modified", m.charge_rate(), 8)
	m.evolve_into(evolved)
	_check("the modifier cleared - this is the new print", m.charge_rate(), 8)


# ------------------------------------------------------------------ helpers

## A game already past SETUP. use_ability() and queue_attack() are both gated on
## the phase, and a fresh GameState starts in SETUP -- so a harness that skips
## this silently gets "false" back from every ability and reads as a broken op.
func _new_game():
	var gs = load("res://scripts/core/GameState.gd").new([], [])
	gs.skip_setup()
	return gs


func _place(gs, side: int, bi: int, si: int, u: Unit) -> void:
	gs.players[side].boards[bi].slots[si] = u


## A unit of any faction, with arbitrary keywords and lines.
func _make(id: String, faction: String, hp: int, kws: Dictionary,
		lines: Array = []) -> Unit:
	var kw_list: Array = []
	for k in kws:
		kw_list.append({"kw": k, "n": kws[k]})
	return UnitS.new(CardDataS.from_dict({
		"id": id, "name": id, "type": "unit", "faction": faction,
		"stage": "basic", "hp": hp, "keywords": kw_list, "attacks": lines,
	}))


func _attack_line(dmg: int, effects: Array = []) -> Dictionary:
	return {"id": "swing", "name": "Swing", "damage": dmg, "effects": effects}


func _test_storm_counter() -> void:
	var gs = _new_game()
	_check("Storm starts at 0", gs.storm, 0)
	gs.raise_storm(2)
	_check("raise_storm raises it", gs.storm, 2)
	gs.raise_storm(3)
	_check("Storm accumulates and never falls", gs.storm, 5)
	## Symmetric: one number, not one per player. Unlike the Gap.
	_check("a non-Tempest attacker gets N", gs.storm_damage_for(null), 5)


## Drive ONE real attack through the engine and return the HP the defender lost.
## Calls _deal_lane_damage via _deliver_attack_damage rather than simulating the
## rule: a test that reimplements what it checks proves nothing about the engine.
func _attack_for(gs, faction: String, dmg: int, resist: int = 0,
		scale: int = 0) -> int:
	var fx: Array = []
	if scale > 0:
		fx.append({"op": "storm_scale_damage", "n": scale})
	var atk_dict := _attack_line(dmg, fx)
	var a := _make("atk", faction, 100, {}, [atk_dict])
	var dkw := {}
	if resist > 0:
		dkw["resist"] = resist
	var d := _make("def", "hel", 500, dkw, [])
	_place(gs, 0, 0, 0, a)
	_place(gs, 1, 0, 0, d)
	var before: int = d.hp
	var atk = a.card.attacks[0]
	gs._deliver_attack_damage(gs.players[0], gs.players[1], a, 0, 0, dmg, atk)
	return before - d.hp


func _test_storm_instance() -> void:
	## A 20-damage attack at Storm 3 from a NON-Tempest unit deals 20 + 3.
	var gs = _new_game()
	gs.raise_storm(3)
	_check("Storm adds one instance of N", _attack_for(gs, "hel", 20), 23)

	## A Tempest attacker's Storm instance is doubled.
	var gs2 = _new_game()
	gs2.raise_storm(3)
	_check("a Tempest unit's Storm instance is 2N", _attack_for(gs2, "tempest", 20), 26)

	## ONE instance, not N: against Resist 10, Storm 3 is fully blunted rather
	## than becoming three 1-damage ticks that pierce armour.
	var gs3 = _new_game()
	gs3.raise_storm(3)
	_check("Resist blunts the Storm instance normally", _attack_for(gs3, "hel", 20, 10), 11)

	## Storm 0 changes nothing at all.
	var gs4 = _new_game()
	_check("no Storm, no extra instance", _attack_for(gs4, "hel", 20), 20)
	_check("and the counter stays 0", gs4.storm, 0)


## Place a Tempest attacker whose attack banks `n` Charge per instance dealt.
func _place_charger(gs, n: int, on_kill: int = 0, dmg: int = 20) -> Unit:
	var fx: Array = [{"op": "charge_on_damage", "n": n}]
	if on_kill > 0:
		fx.append({"op": "charge_on_kill", "n": on_kill})
	var a := _make("chg", "tempest", 100, {"charge": n}, [_attack_line(dmg, fx)])
	_place(gs, 0, 0, 0, a)
	return a


## Swing the unit at slot 0's attack into whatever is across from it.
func _swing(gs, a: Unit) -> void:
	var atk = a.card.attacks[0]
	gs._deliver_attack_damage(gs.players[0], gs.players[1], a, 0, 0, atk.damage, atk)


func _place_defender(gs, hp: int = 500) -> Unit:
	var d := _make("def", "hel", hp, {}, [])
	_place(gs, 1, 0, 0, d)
	return d


func _test_charge_growth() -> void:
	## Grows on damage DEALT. One instance per attack with no Storm up.
	var gs = _new_game()
	var a := _place_charger(gs, 5)
	_place_defender(gs)
	_swing(gs, a)
	_check("one instance dealt grows the counter once", a.charge, 5)

	## With Storm up an attack is TWO instances: the attack, then Storm's.
	gs.raise_storm(2)
	_swing(gs, a)
	_check("with Storm up, an attack is two instances", a.charge, 15)

	## NEVER on damage taken. The counterplay must not be "stop attacking".
	var gs2 = _new_game()
	var b := _place_charger(gs2, 5)
	var atkr := _make("enemy", "hel", 100, {}, [_attack_line(10)])
	_place(gs2, 1, 0, 0, atkr)
	gs2._deliver_attack_damage(gs2.players[1], gs2.players[0], atkr, 0, 0, 10,
		atkr.card.attacks[0])
	_check("taking damage never grows the counter", b.charge, 0)

	## A unit with no charge_on_damage line banks nothing.
	var gs3 = _new_game()
	var c := _make("plain", "tempest", 100, {}, [_attack_line(20)])
	_place(gs3, 0, 0, 0, c)
	_place_defender(gs3)
	_swing(gs3, c)
	_check("a unit with no Charge line banks nothing", c.charge, 0)

	## charge_on_kill pays an EXTRA bonus when the damage kills.
	var gs4 = _new_game()
	var k := _place_charger(gs4, 3, 6, 40)
	_place_defender(gs4, 30)
	_swing(gs4, k)
	_check("a kill pays the on-damage AND the on-kill bonus", k.charge, 9)

	## storm_charge_bonus banks extra per point of Storm.
	var gs5 = _new_game()
	gs5.raise_storm(3)
	var t := _make("tool", "tempest", 100, {"charge": 4}, [_attack_line(20, [
		{"op": "charge_on_damage", "n": 4},
		{"op": "storm_charge_bonus", "n": 2}])])
	_place(gs5, 0, 0, 0, t)
	_place_defender(gs5)
	_swing(gs5, t)
	## Two instances (attack + Storm), each banking 4 + 2*3 = 10.
	_check("storm_charge_bonus banks extra per point of Storm", t.charge, 20)


## `charge_on_kill` reads `defender.hp <= 0`, and defensive Judgment rescues a
## unit AFTER that check. A Judgment save is not a kill, so the bonus must not
## pay -- this is the ordering trap the Heaven mirror already documents.
func _test_charge_kill_vs_judgment() -> void:
	var gs = _new_game()
	var k := _place_charger(gs, 3, 6, 40)
	var j := _make("judge", "heaven", 30, {"judgment": 20}, [])
	_place(gs, 1, 0, 0, j)
	_swing(gs, k)
	_check("Judgment saved the body, so it lives", j.hp, 20)
	_check("a Judgment save is not a kill - no bonus", k.charge, 3)


## A Tempest unit with a banking attack AND a discharge ability.
func _place_discharger(gs, rate: int, mode: String, n: int = 1,
		dmg: int = 20, extra: Array = []) -> Unit:
	var fx: Array = [{"op": mode}]
	if n > 1:
		fx = [{"op": mode, "n": n}]
	for e in extra:
		fx.append(e)
	var lines: Array = [
		_attack_line(dmg, [{"op": "charge_on_damage", "n": rate}]),
		{"id": "disc", "name": "Discharge", "damage": 0, "ability": true,
		 "effects": fx},
	]
	var a := _make("dis", "tempest", 100, {"charge": rate}, lines)
	_place(gs, 0, 0, 0, a)
	return a


func _discharge(gs, a: Unit, target = null) -> bool:
	return gs.use_ability(gs.players[0], a, a.card.attacks[1], target)


func _test_discharge() -> void:
	## The baseline: the next attack carries the counter AND strikes a second
	## unit on that board for the counter.
	var gs = _new_game()
	var a := _place_discharger(gs, 5, "discharge")
	a.add_charge(20)
	var d1 := _place_defender(gs, 500)
	var d2 := _make("def2", "hel", 500, {}, [])
	_place(gs, 1, 0, 1, d2)
	_discharge(gs, a)
	_check("discharge spends the whole counter", a.charge, 0)
	_check("and arms the next attack with it", a.pending_discharge, 20)
	_swing(gs, a)
	_check("the armed attack carries the counter", 500 - d1.hp, 40)
	_check("and a second unit is struck for it", 500 - d2.hp, 20)
	## Discharge damage NEVER grows Charge -- a spend is a spend. The swing banks
	## its own two instances (main + second target) at rate 5.
	_check("the discharge itself never refunds the counter", a.charge, 10)
	_check("and the arming is cleared", a.pending_discharge, 0)

	## discharge_single multiplies into one target and does NOT hit a second.
	var gs2 = _new_game()
	var b := _place_discharger(gs2, 5, "discharge_single", 2)
	b.add_charge(15)
	var e1 := _place_defender(gs2, 500)
	var e2 := _make("e2", "hel", 500, {}, [])
	_place(gs2, 1, 0, 1, e2)
	_discharge(gs2, b)
	_swing(gs2, b)
	_check("discharge_single deals 2x the counter", 500 - e1.hp, 50)
	_check("and never touches a second unit", e2.hp, 500)

	## discharge_heal spends the counter as healing.
	var gs3 = _new_game()
	var h := _place_discharger(gs3, 5, "discharge_heal")
	h.add_charge(25)
	var ally := _make("ally", "tempest", 96, {}, [])
	ally.hp = 40
	_place(gs3, 0, 0, 1, ally)
	_discharge(gs3, h, ally)
	_check("discharge_heal restores the counter as HP", ally.hp, 65)
	_check("and still spends it", h.charge, 0)

	## charge_transfer moves the counter to another body.
	var gs4 = _new_game()
	var sx := _place_discharger(gs4, 4, "charge_transfer")
	sx.add_charge(18)
	var heir := _make("heir", "tempest", 96, {"charge": 4}, [])
	_place(gs4, 0, 0, 1, heir)
	_discharge(gs4, sx, heir)
	_check("transfer empties the source", sx.charge, 0)
	_check("and fills the destination", heir.charge, 18)


func _enemy_tower_hp(gs) -> int:
	return gs.players[1].boards[0].tower_hp


func _test_storm_ops() -> void:
	## storm_scale_damage adds N per point of Storm to the attack itself, on top
	## of Storm's own instance.
	var gs = _new_game()
	gs.raise_storm(4)
	## base 20 + (3 x 4 scale) = 32, plus a 4-point Storm instance = 36
	_check("storm_scale_damage scales the attack", _attack_for(gs, "hel", 20, 0, 3), 36)

	## discharge_sweep splits the counter across every living unit on the board.
	var gs2 = _new_game()
	var w := _place_discharger(gs2, 5, "discharge_sweep")
	w.add_charge(30)
	var f1 := _place_defender(gs2, 500)
	var f2 := _make("f2", "hel", 500, {}, [])
	var f3 := _make("f3", "hel", 500, {}, [])
	_place(gs2, 1, 0, 1, f2)
	_place(gs2, 1, 0, 2, f3)
	_discharge(gs2, w)
	_swing(gs2, w)
	## 30 split three ways = 10 each; the base attack lands on the first as well.
	_check("sweep reaches the second unit", 500 - f2.hp, 10)
	_check("and the third", 500 - f3.hp, 10)

	## discharge_structures reaches the tower PAST a living blocker.
	var gs3 = _new_game()
	## The rider sits on the ATTACK, not on the ability: _deal_lane_damage reads
	## the attack that is resolving, and the ability only arms the counter.
	var d3 := _make("brk", "tempest", 100, {"charge": 5}, [
		_attack_line(20, [{"op": "charge_on_damage", "n": 5},
						  {"op": "discharge_structures"}]),
		{"id": "disc", "name": "Discharge", "damage": 0, "ability": true,
		 "effects": [{"op": "discharge_single", "n": 2}]},
	])
	_place(gs3, 0, 0, 0, d3)
	var d := d3
	d.add_charge(30)
	_place_defender(gs3, 500)
	var t_before := _enemy_tower_hp(gs3)
	_discharge(gs3, d)
	_swing(gs3, d)
	_ok("discharge_structures reaches the tower past a wall",
		_enemy_tower_hp(gs3) < t_before)

	## ...and the base keyword does NOT.
	var gs4 = _new_game()
	var e := _place_discharger(gs4, 5, "discharge")
	e.add_charge(30)
	var blocker := _place_defender(gs4, 500)
	var t4 := _enemy_tower_hp(gs4)
	_discharge(gs4, e)
	_swing(gs4, e)
	_check("a plain discharge never reaches a shielded tower", _enemy_tower_hp(gs4), t4)
	_ok("it hit the blocker instead", blocker.hp < 500)

	## storm_raise on an ability raises the global counter.
	var gs5 = _new_game()
	var f := _make("caller", "tempest", 60, {}, [
		{"id": "raise", "name": "Rising Air", "damage": 0, "ability": true,
		 "effects": [{"op": "storm_raise", "n": 2}]}])
	_place(gs5, 0, 0, 0, f)
	gs5.use_ability(gs5.players[0], f, f.card.attacks[0])
	_check("storm_raise raises the global counter", gs5.storm, 2)
