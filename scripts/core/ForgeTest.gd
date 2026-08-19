extends SceneTree

## Forge harness — Stoke, Scrap, and the payoff ops.
## Run: godot --headless --path <project> --script res://scripts/core/ForgeTest.gd

## Total assertions this harness is expected to run. Checked at the end, because
## a crash mid-test produces "0 failed" and exit 0 — the assertions after the
## crash simply never run, and silence reads identically to success.
## 139 = the original 91 (6 sanctuary + 3 resist + 8 basics + 5 lethal-toll
## + 3 clear + 2 afford + 10 scrap + 9 payoff-damage + 5 free-attack
## + 6 heal-back + 6 cleave + 5 ignore-shield + 10 parsing + 9 card-data
## + 4 ops) plus 48 for the expansion's ten payoff ops: 5 unpreventable
## + 5 sweep + 4 both-boards + 4 also-tower + 6 extra-attack + 4 immediate
## + 4 cost-reduction + 6 no-decay + 2 draw + 6 stoke-twice + 5 grants-expire,
## and 4 more from `begin_turn()` in grants-expire drawing a fresh hand.
## Reconciled against a real run rather than estimated -- an estimate here is
## the guard measuring nothing.
const EXPECTED_ASSERTIONS := 143

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


## `_initialize()` rather than `_init()`, and CardDB registered by hand: under
## `--script` the autoloads are not in the tree, and without this `Player.new()`
## inside `GameState._init` resolves to a bare GDScript and returns null — every
## `gs.players[0]` then errors to stderr while the pass counter never increments.
func _initialize() -> void:
	var db = root.get_node_or_null("CardDB")
	if db == null:
		db = load("res://scripts/core/CardDB.gd").new()
		db.name = "CardDB"
		root.add_child(db)
	if db._cards.is_empty():
		db._load()

	## The unpreventability tests run FIRST, deliberately. They are the two rules
	## most likely to be got wrong by routing Stoke through the ordinary damage
	## path out of habit, and they are the entire reason the keyword exists in the
	## shape it does.
	_test_stoke_ignores_sanctuary()
	_test_stoke_ignores_resist()
	_test_stoke_basics()
	_test_stoke_lethal_fires_toll()
	_test_stoke_clears_each_turn()
	_test_stoke_affordability()
	_test_scrap()
	_test_payoff_damage()
	_test_payoff_free_attack()
	_test_payoff_heal_back()
	_test_payoff_cleave()
	_test_payoff_ignore_shield()
	## The expansion's ten payoff ops, each driven through the real pipeline.
	_test_payoff_unpreventable()
	_test_payoff_sweep()
	_test_payoff_both_boards()
	_test_payoff_also_tower()
	_test_payoff_extra_attack()
	_test_payoff_immediate()
	_test_payoff_cost_reduction()
	_test_payoff_no_decay()
	_test_payoff_draw()
	_test_payoff_stoke_twice()
	_test_grants_expire()
	_test_ability_cost_parsing()
	_test_card_data()
	_test_set_effect_ops()

	if _pass + _fail != EXPECTED_ASSERTIONS:
		print("FAIL: expected %d assertions, ran %d — a test crashed before finishing."
			% [EXPECTED_ASSERTIONS, _pass + _fail])
		_fail += 1

	print("\nForgeTest: %d passed, %d failed" % [_pass, _fail])
	quit(1 if _fail > 0 else 0)


# ------------------------------------------------------------------ helpers

func _new_game():
	return load("res://scripts/core/GameState.gd").new([], [])


func _place(gs, side: int, bi: int, si: int, u: Unit) -> void:
	gs.players[side].boards[bi].slots[si] = u


func _make_card(id: String, hp: int, kws: Dictionary, lines: Array = []) -> CardData:
	var kw_list: Array = []
	for k in kws:
		kw_list.append({"kw": k, "n": kws[k]})
	return CardData.from_dict({
		"id": id, "name": id, "type": "unit", "faction": "forge",
		"hp": hp, "keywords": kw_list, "attacks": lines,
	})


## A free once-per-turn Stoke ability.
func _stoke_line(n: int, effects: Array = []) -> Dictionary:
	return {"id": "stoke", "name": "Stoke", "damage": 0, "ability": true,
			"stoke": n, "effects": effects}


func _attack_line(dmg: int, effects: Array = [], cost: Dictionary = {}) -> Dictionary:
	return {"id": "swing", "name": "Swing", "damage": dmg,
			"cost": cost, "effects": effects}


# ------------------------------------------------- unpreventability (first)

## Stoke is a COST, not an incoming damage event. If it went through the damage
## path a shielded body would Stoke for free and the faction's central cost would
## be optional in exactly the matchups where it has to be real.
func _test_stoke_ignores_sanctuary() -> void:
	var c := _make_card("t_sanct", 100, {"sanctuary": 80}, [_stoke_line(20)])
	var u := Unit.new(c)
	_ok("sanctuary armed", u.sanctuary_active)
	_check("sanctuary pool full", u.sanctuary_pool, 80)

	var spent := u.pay_stoke(20)
	_check("stoke spent in full", spent, 20)
	_check("hp actually dropped", u.hp, 80)
	_check("sanctuary pool untouched", u.sanctuary_pool, 80)
	_ok("sanctuary still armed", u.sanctuary_active)
	_check("flag records the amount", u.stoked_this_turn, 20)


## Same reasoning for Resist: a Resist 10 body must not pay 10 less every time.
func _test_stoke_ignores_resist() -> void:
	var c := _make_card("t_resist", 100, {"resist": 10}, [_stoke_line(20)])
	var u := Unit.new(c)
	_check("resist is printed", u.resist(), 10)

	u.pay_stoke(20)
	_check("resist did not reduce the cost", u.hp, 80)
	_check("full amount recorded", u.stoked_this_turn, 20)


# ------------------------------------------------------------------- basics

func _test_stoke_basics() -> void:
	var u := Unit.new(_make_card("t_basic", 90, {}, [_stoke_line(20)]))
	_check("starts unstoked", u.stoked_this_turn, 0)
	_ok("has_stoked false", not u.has_stoked())

	u.pay_stoke(20)
	_check("hp paid", u.hp, 70)
	_ok("has_stoked true", u.has_stoked())

	## Amounts accumulate — a card may let a unit stoke twice.
	u.pay_stoke(30)
	_check("amount accumulates", u.stoked_this_turn, 50)
	_check("hp paid again", u.hp, 40)

	## Hold the Slot floors the unit at 1 HP. Stoke honours it: that card says
	## this body does not die this turn, and a voluntary cost must not route
	## around it either.
	var pr := Unit.new(_make_card("t_prot", 40, {}, [_stoke_line(50)]))
	pr.protected_this_turn = true
	var spent := pr.pay_stoke(50)
	_check("protected unit stops at 1 hp", pr.hp, 1)
	_check("only the payable amount counts", spent, 39)

	## A dead unit cannot stoke.
	var dead := Unit.new(_make_card("t_dead", 40, {}, [_stoke_line(10)]))
	dead.hp = 0
	_check("dead unit pays nothing", dead.pay_stoke(10), 0)


## Stoke may kill, and the death is an ORDINARY one — Forge gets no private kind
## of death, so Toll still refunds.
func _test_stoke_lethal_fires_toll() -> void:
	var gs = _new_game()
	var p = gs.players[0]
	gs.phase = gs.Phase.PLAYING

	var card := _make_card("t_lethal", 40, {"toll": 2}, [_stoke_line(40)])
	var u := Unit.new(card)
	_place(gs, 0, 0, 0, u)

	var pool_before: int = p.pool
	var ab: AttackData = u.card.ability_lines()[0]
	_ok("ability is usable", u.can_use_ability(ab))
	_ok("use_ability succeeds", gs.use_ability(p, u, ab))

	_check("unit died to its own stoke", u.is_alive(), false)
	_check("slot cleared", p.boards[0].slots[0], null)
	_check("toll refunded on a stoke death", p.pool, pool_before + 2)
	_ok("death was recorded", p.unit_died_this_turn)


func _test_stoke_clears_each_turn() -> void:
	var gs = _new_game()
	var p = gs.players[0]
	var u := Unit.new(_make_card("t_clear", 90, {}, [_stoke_line(20)]))
	_place(gs, 0, 0, 0, u)

	u.pay_stoke(20)
	_check("stoked this turn", u.stoked_this_turn, 20)

	p.begin_turn()
	_check("flag cleared next turn", u.stoked_this_turn, 0)
	_ok("has_stoked false again", not u.has_stoked())


## A unit may Stoke itself to death, but only when the HP is really there — a
## partial payment is not a thing, the same way an unaffordable attack is simply
## illegal rather than partly paid.
func _test_stoke_affordability() -> void:
	var u := Unit.new(_make_card("t_afford", 30, {}, [_stoke_line(40)]))
	var ab: AttackData = u.card.ability_lines()[0]
	_ok("cannot stoke more hp than it has", not u.can_use_ability(ab))

	var big := Unit.new(_make_card("t_afford2", 40, {}, [_stoke_line(40)]))
	var ab2: AttackData = big.card.ability_lines()[0]
	_ok("exactly lethal stoke is legal", big.can_use_ability(ab2))


# -------------------------------------------------------------------- scrap

func _test_scrap() -> void:
	var gs = _new_game()
	var p = gs.players[0]
	gs.phase = gs.Phase.PLAYING

	var scrapper := Unit.new(_make_card("t_scrapper", 90, {},
		[{"id": "eat", "name": "Eat", "damage": 0, "ability": true, "scrap": true}]))
	var fodder := Unit.new(_make_card("t_fodder", 40, {"toll": 1}, []))
	var big := Unit.new(_make_card("t_big", 120, {}, []))
	_place(gs, 0, 0, 0, scrapper)
	_place(gs, 0, 0, 1, fodder)
	_place(gs, 0, 1, 0, big)

	var pool_before: int = p.pool
	var ab: AttackData = scrapper.card.ability_lines()[0]
	_ok("scrap ability usable", scrapper.can_use_ability(ab))
	_ok("scrap resolves", gs.use_ability(p, scrapper, ab))

	## With no explicit target the weakest body is taken — what a player scrapping
	## for value would pick, and what lets the AI use the line without a UI.
	_check("weakest unit was scrapped", fodder.is_alive(), false)
	_check("the scrapper itself survived", scrapper.is_alive(), true)
	_check("the big unit was not touched", big.is_alive(), true)
	_check("scrap fires Toll", p.pool, pool_before + 1)

	## Never itself: a lone unit has no legal Scrap target, so the line is illegal
	## and costs nothing.
	var gs2 = _new_game()
	var p2 = gs2.players[0]
	gs2.phase = gs2.Phase.PLAYING
	var lone := Unit.new(_make_card("t_lone", 90, {},
		[{"id": "eat", "name": "Eat", "damage": 0, "ability": true, "scrap": true}]))
	_place(gs2, 0, 0, 0, lone)
	var ab2: AttackData = lone.card.ability_lines()[0]
	_check("scrap with no other unit is refused", gs2.use_ability(p2, lone, ab2), false)
	_ok("lone unit survived", lone.is_alive())
	_ok("ability was not marked used", not lone.has_used_ability(ab2))

	## An explicit target is honoured.
	var gs3 = _new_game()
	var p3 = gs3.players[0]
	gs3.phase = gs3.Phase.PLAYING
	var s3 := Unit.new(_make_card("t_s3", 90, {},
		[{"id": "eat", "name": "Eat", "damage": 0, "ability": true, "scrap": true}]))
	var small := Unit.new(_make_card("t_small", 40, {}, []))
	var chosen := Unit.new(_make_card("t_chosen", 120, {}, []))
	_place(gs3, 0, 0, 0, s3)
	_place(gs3, 0, 0, 1, small)
	_place(gs3, 0, 0, 2, chosen)
	_ok("explicit scrap resolves", gs3.use_ability(p3, s3, s3.card.ability_lines()[0], chosen))
	_check("named target died", chosen.is_alive(), false)
	_check("the weaker body was spared", small.is_alive(), true)


# ------------------------------------------------------------------ payoffs

func _test_payoff_damage() -> void:
	## Flat bonus.
	var gs = _new_game()
	var p = gs.players[0]
	var enemy = gs.players[1]
	gs.phase = gs.Phase.PLAYING

	var card := _make_card("t_pay", 90, {}, [
		_stoke_line(20),
		_attack_line(30, [{"op": "stoked_bonus_damage", "n": 10}]),
	])
	var u := Unit.new(card)
	_place(gs, 0, 0, 0, u)
	var target := Unit.new(_make_card("t_target", 200, {}, []))
	_place(gs, 1, 0, 0, target)

	var atk: AttackData = u.card.attack_lines()[0]
	gs._resolve_line_effects(p, enemy, u, atk, null, 0, 0)
	_check("unstoked attack deals base", target.hp, 170)

	u.pay_stoke(20)
	gs._resolve_line_effects(p, enemy, u, atk, null, 0, 0)
	_check("stoked attack adds the bonus", target.hp, 130)

	## Scaling with the amount — this is what makes a large printed Stoke worth
	## having. Without it every deck runs the cheapest body that sets the flag.
	var gs2 = _new_game()
	var p2 = gs2.players[0]
	var e2 = gs2.players[1]
	gs2.phase = gs2.Phase.PLAYING
	var u2 := Unit.new(_make_card("t_scale", 120, {}, [
		_stoke_line(40),
		_attack_line(20, [{"op": "stoked_scale_damage", "n": 2}]),
	]))
	_place(gs2, 0, 0, 0, u2)
	var t2 := Unit.new(_make_card("t_t2", 200, {}, []))
	_place(gs2, 1, 0, 0, t2)

	u2.pay_stoke(40)
	gs2._resolve_line_effects(p2, e2, u2, u2.card.attack_lines()[0], null, 0, 0)
	_check("40 stoked at 1-per-2 adds 20", t2.hp, 160)

	## A bigger stoke is genuinely better, which is the point of the op.
	u2.stoked_this_turn = 60
	gs2._resolve_line_effects(p2, e2, u2, u2.card.attack_lines()[0], null, 0, 0)
	_check("60 stoked adds 30", t2.hp, 110)

	## Threshold: only a body that commits real HP unlocks the big payoffs.
	var gs3 = _new_game()
	var p3 = gs3.players[0]
	var e3 = gs3.players[1]
	gs3.phase = gs3.Phase.PLAYING
	var u3 := Unit.new(_make_card("t_thresh", 150, {}, [
		_stoke_line(20),
		_attack_line(20, [
			{"op": "stoked_threshold", "n": 40},
			{"op": "stoked_threshold_damage", "n": 40},
		]),
	]))
	_place(gs3, 0, 0, 0, u3)
	var t3 := Unit.new(_make_card("t_t3", 300, {}, []))
	_place(gs3, 1, 0, 0, t3)

	u3.pay_stoke(20)
	gs3._resolve_line_effects(p3, e3, u3, u3.card.attack_lines()[0], null, 0, 0)
	_check("under the threshold pays base only", t3.hp, 280)

	u3.stoked_this_turn = 40
	gs3._resolve_line_effects(p3, e3, u3, u3.card.attack_lines()[0], null, 0, 0)
	_check("at the threshold the payoff fires", t3.hp, 220)

	## Doubling reads last, so it doubles everything above it.
	var gs4 = _new_game()
	var p4 = gs4.players[0]
	var e4 = gs4.players[1]
	gs4.phase = gs4.Phase.PLAYING
	var u4 := Unit.new(_make_card("t_dbl", 150, {}, [
		_stoke_line(20),
		_attack_line(25, [
			{"op": "stoked_bonus_damage", "n": 5},
			{"op": "stoked_double", "n": 1},
		]),
	]))
	_place(gs4, 0, 0, 0, u4)
	var t4 := Unit.new(_make_card("t_t4", 300, {}, []))
	_place(gs4, 1, 0, 0, t4)
	u4.pay_stoke(20)
	gs4._resolve_line_effects(p4, e4, u4, u4.card.attack_lines()[0], null, 0, 0)
	_check("double applies after the flat bonus", t4.hp, 240)


## The discount expires with the flag, so unlike attached energy it buys nothing
## permanent — which is why it is the safe form of the economy payoff.
func _test_payoff_free_attack() -> void:
	var gs = _new_game()
	var p = gs.players[0]
	gs.phase = gs.Phase.PLAYING

	var u := Unit.new(_make_card("t_free", 90, {}, [
		_stoke_line(20),
		_attack_line(30, [{"op": "stoked_free_attack", "n": 1}], {"forge": 4}),
	]))
	_place(gs, 0, 0, 0, u)
	var atk: AttackData = u.card.attack_lines()[0]
	_check("the attack really costs 4", atk.total_cost(), 4)

	p.pool = 0
	_check("unstoked and broke: refused", gs.queue_attack(p, u, atk), false)

	u.pay_stoke(20)
	_ok("stoked: queues for free", gs.queue_attack(p, u, atk))
	_check("pool untouched", p.pool, 0)
	_check("nothing attached", u.attached, 0)


## The heal is NOT a cost eraser: the unit still counts as having stoked, so
## every other payoff on the board stays on. That separation is the whole reason
## the flag is independent of what it paid for.
func _test_payoff_heal_back() -> void:
	var gs = _new_game()
	var p = gs.players[0]
	gs.phase = gs.Phase.PLAYING

	var u := Unit.new(_make_card("t_heal", 120, {}, [
		_stoke_line(40, [{"op": "stoked_heal_back", "n": 100}]),
	]))
	_place(gs, 0, 0, 0, u)

	var ab: AttackData = u.card.ability_lines()[0]
	_ok("heal-back ability resolves", gs.use_ability(p, u, ab))
	_check("hp restored in full", u.hp, 120)
	_check("STILL counts as stoked", u.stoked_this_turn, 40)
	_ok("has_stoked stays true", u.has_stoked())

	## A partial refund heals less but the flag is unchanged.
	var gs2 = _new_game()
	var p2 = gs2.players[0]
	gs2.phase = gs2.Phase.PLAYING
	var u2 := Unit.new(_make_card("t_heal2", 120, {}, [
		_stoke_line(40, [{"op": "stoked_heal_back", "n": 50}]),
	]))
	_place(gs2, 0, 0, 0, u2)
	gs2.use_ability(p2, u2, u2.card.ability_lines()[0])
	_check("half refunded", u2.hp, 100)
	_check("flag still full", u2.stoked_this_turn, 40)


## Stoke as the weapon itself. Obeys the shielding chain like every other damage
## source, because it reuses `_deal_lane_damage` rather than reimplementing it.
func _test_payoff_cleave() -> void:
	var gs = _new_game()
	var p = gs.players[0]
	var enemy = gs.players[1]
	gs.phase = gs.Phase.PLAYING

	var u := Unit.new(_make_card("t_cleave", 120, {}, [
		_stoke_line(40, [{"op": "stoked_cleave", "n": 100}]),
	]))
	_place(gs, 0, 0, 0, u)
	var victim := Unit.new(_make_card("t_victim", 100, {}, []))
	_place(gs, 1, 0, 0, victim)

	gs.use_ability(p, u, u.card.ability_lines()[0])
	_check("cleave splashed the full amount", victim.hp, 60)
	_check("the stoker still paid", u.hp, 80)

	## The splash is ordinary damage, so a shield DOES stop it — only the cost
	## itself is unpreventable.
	var gs2 = _new_game()
	var p2 = gs2.players[0]
	gs2.phase = gs2.Phase.PLAYING
	var u2 := Unit.new(_make_card("t_cleave2", 120, {}, [
		_stoke_line(40, [{"op": "stoked_cleave", "n": 100}]),
	]))
	_place(gs2, 0, 0, 0, u2)
	var shielded := Unit.new(_make_card("t_shield", 100, {"sanctuary": 80}, []))
	_place(gs2, 1, 0, 0, shielded)
	gs2.use_ability(p2, u2, u2.card.ability_lines()[0])
	_check("sanctuary absorbed the splash", shielded.hp, 100)
	_check("but the shield paid for it", shielded.sanctuary_pool, 40)
	_check("the stoker still paid its own cost", u2.hp, 80)


## The deliberate rule-break: gated on having spent real HP, so it is a reward
## for commitment rather than a free bypass.
func _test_payoff_ignore_shield() -> void:
	var gs = _new_game()
	var p = gs.players[0]
	var enemy = gs.players[1]
	gs.phase = gs.Phase.PLAYING

	var u := Unit.new(_make_card("t_pierce", 150, {}, [
		_stoke_line(40),
		_attack_line(30, [
			{"op": "stoked_threshold", "n": 40},
			{"op": "stoked_ignore_shield", "n": 1},
		]),
	]))
	_place(gs, 0, 0, 0, u)
	var wall := Unit.new(_make_card("t_wall", 200, {}, []))
	_place(gs, 1, 0, 0, wall)

	var tower_before: int = enemy.boards[0].tower_hp
	var atk: AttackData = u.card.attack_lines()[0]

	## Under the threshold it is an ordinary attack and the wall shields.
	u.pay_stoke(20)
	gs._resolve_line_effects(p, enemy, u, atk, null, 0, 0)
	_check("unstoked enough: the wall took it", wall.hp, 170)
	_check("tower shielded", enemy.boards[0].tower_hp, tower_before)

	## At the threshold it burns past.
	u.stoked_this_turn = 40
	gs._resolve_line_effects(p, enemy, u, atk, null, 0, 0)
	_check("wall untouched by the piercing hit", wall.hp, 170)
	_check("tower took it instead", enemy.boards[0].tower_hp, tower_before - 30)


# ------------------------------------------------------------- data parsing

func _test_ability_cost_parsing() -> void:
	## An ability's `cost` block is ignored — a card cannot price an ability by
	## filling in the wrong field.
	var a := AttackData.from_dict({
		"id": "x", "name": "X", "ability": true,
		"cost": {"forge": 5}, "stoke": 20,
	})
	_check("ability ignores its cost block", a.total_cost(), 0)
	_check("stoke parsed", a.stoke, 20)
	_ok("has a printed cost", a.has_printed_cost())
	_check("cost string names Stoke", a.cost_string(), "Stoke 20")

	var b := AttackData.from_dict({"id": "y", "name": "Y", "ability": true, "scrap": true})
	_ok("scrap parsed", b.scrap)
	_check("cost string names Scrap", b.cost_string(), "Scrap")

	var c := AttackData.from_dict({"id": "z", "name": "Z", "ability": true})
	_ok("a bare ability has no printed cost", not c.has_printed_cost())
	_check("and reads as free", c.cost_string(), "Free")

	## All three non-energy costs may coexist on one line.
	var d := AttackData.from_dict({
		"id": "w", "name": "W", "ability": true,
		"consume": 1, "stoke": 20, "scrap": true,
	})
	_check("combined cost string", d.cost_string(), "Consume 1, Stoke 20, Scrap")

	## An attack still prices normally.
	var e := AttackData.from_dict({"id": "v", "name": "V", "cost": {"forge": 3, "colorless": 2}})
	_check("attack total cost", e.total_cost(), 5)
	_check("attack colour recorded", e.cost_color, "forge")


# --------------------------------------------------------------- card data

func _test_card_data() -> void:
	var db = root.get_node_or_null("CardDB")
	var forge: Array = []
	for cid in db.all_ids():
		var c: CardData = db.get_card(cid)
		if c != null and c.faction == "forge":
			forge.append(c)

	## A census, not an invariant — this catches a card failing to LOAD, and is
	## expected to move whenever the roster does.
	_ok("forge cards exist", forge.size() > 0)

	var units: Array = []
	var energy: Array = []
	for c in forge:
		if c.type == CardData.Type.UNIT:
			units.append(c)
		elif c.type == CardData.Type.ENERGY:
			energy.append(c)
	_check("exactly one forge energy card", energy.size(), 1)
	_ok("forge has units", units.size() > 0)

	## Invariants — these must hold whatever the roster size.
	var bands := {
		CardData.Stage.BASIC: [40, 90],
		CardData.Stage.STAGE1: [80, 120],
		CardData.Stage.STAGE2: [110, 175],
	}
	var hp_ok := true
	var lines_ok := true
	var retreat_ok := true
	var stoke_is_ability := true
	var stoke_affordable := true
	for c in units:
		var band: Array = bands.get(c.stage, [1, 999])
		if c.max_hp < band[0] or c.max_hp > band[1]:
			hp_ok = false
			print("  HP band: %s (%s) %d not in %s" % [c.name, c.stage, c.max_hp, band])
		if c.attacks.size() > 2:
			lines_ok = false
			print("  two-line rule: %s has %d lines" % [c.name, c.attacks.size()])
		if c.retreat != int(c.max_hp / 40.0):
			retreat_ok = false
			print("  retreat: %s prints %d, formula gives %d" % [c.name, c.retreat, int(c.max_hp / 40.0)])
		for ln in c.attacks:
			if ln.stoke > 0:
				if not ln.is_ability:
					stoke_is_ability = false
					print("  stoke on an attack: %s / %s" % [c.name, ln.name])
				## A unit must be able to pay its own printed Stoke.
				if ln.stoke > c.max_hp:
					stoke_affordable = false
					print("  unpayable stoke: %s stokes %d with %d hp" % [c.name, ln.stoke, c.max_hp])
	_ok("every unit is inside its HP band", hp_ok)
	_ok("two-line rule holds", lines_ok)
	_ok("retreat is HP/40 everywhere", retreat_ok)
	_ok("Stoke only ever appears on an ability", stoke_is_ability)
	_ok("every unit can pay its own Stoke", stoke_affordable)

	## Forge supports are faction-locked; that restriction is what they pay with.
	var supports: Array = []
	for c in forge:
		if c.type in [CardData.Type.SUPPORT, CardData.Type.TOOL,
				CardData.Type.TOWER_SUPPORT]:
			supports.append(c)
	_ok("forge prints its own supports", supports.size() > 0)


## Every op a Forge card names must be one the engine actually handles. An
## unknown op parses fine and silently does nothing — the exact shape of the
## dropped-`effects` bug already in the decision log.
func _test_set_effect_ops() -> void:
	var db = root.get_node_or_null("CardDB")
	var implemented := [
		## Shipped with the faction.
		"stoked_bonus_damage", "stoked_scale_damage", "stoked_threshold",
		"stoked_threshold_damage", "stoked_double", "stoked_free_attack",
		"stoked_heal_back", "stoked_cleave", "stoked_ignore_shield",
		## Built for the expansion, one per new chain's identity.
		"stoked_extra_attack", "stoked_immediate", "stoked_cost_reduction",
		"stoked_no_decay", "stoked_sweep", "stoked_both_boards",
		"stoked_also_tower", "stoked_unpreventable", "stoked_draw",
		"stoked_twice",
	]
	var src: String = FileAccess.get_file_as_string("res://scripts/core/GameState.gd")
	var all_ok := true
	for op in implemented:
		if not src.contains('"%s"' % op):
			all_ok = false
			print("  op not found in GameState: %s" % op)
	_ok("every documented Stoke op is implemented", all_ok)

	## And no Forge card names an op outside the implemented set.
	var unknown := true
	for cid in db.all_ids():
		var c: CardData = db.get_card(cid)
		if c == null or c.faction != "forge":
			continue
		for ln in c.attacks:
			for e in ln.effects:
				var op: String = e.get("op", "")
				if op.begins_with("stoked_") and not implemented.has(op):
					unknown = false
					print("  unknown stoke op on %s: %s" % [c.name, op])
	_ok("no forge card names an unimplemented stoke op", unknown)


# ------------------------------------------- expansion payoffs (2026-08-16)
#
# One test per new op, every one driven through the REAL pipeline
# (`_resolve_line_effects` / `_deal_lane_damage` / `queue_attack` / `end_turn`)
# rather than by simulating the rule inline. A test that reimplements the rule
# it checks proves nothing about the engine — the same discipline the Heaven and
# Gaia harnesses follow.
#
# Each was verified by putting the bug back: an op that silently does nothing
# passes every structural assertion, which is the failure shape the decision log
# already carries three times.


## `stoked_unpreventable` — the printed answer to shield decks, and the reason
## Forge/Heaven has a reason to exist now that Stoke itself ignores Sanctuary.
func _test_payoff_unpreventable() -> void:
	var gs = _new_game()
	var p = gs.players[0]
	var enemy = gs.players[1]
	gs.phase = gs.Phase.PLAYING

	var u := Unit.new(_make_card("t_unprev", 120, {}, [
		_stoke_line(20),
		_attack_line(40, [{"op": "stoked_unpreventable", "n": 1}]),
	]))
	_place(gs, 0, 0, 0, u)

	## A defender holding BOTH prevention mechanics, so one test covers both.
	var wall := Unit.new(_make_card("t_shield", 200, {"sanctuary": 80, "resist": 10}, []))
	_place(gs, 1, 0, 0, wall)
	var atk: AttackData = u.card.attack_lines()[0]

	## Unstoked it is an ordinary attack: Sanctuary absorbs it whole.
	gs._resolve_line_effects(p, enemy, u, atk, null, 0, 0)
	_check("unstoked: sanctuary ate it", wall.hp, 200)
	_check("sanctuary paid for it", wall.sanctuary_pool, 40)

	## Stoked it ignores the shield and the reduction alike.
	u.pay_stoke(20)
	gs._resolve_line_effects(p, enemy, u, atk, null, 0, 0)
	_check("stoked: full damage landed", wall.hp, 160)
	_check("sanctuary untouched", wall.sanctuary_pool, 40)
	_ok("sanctuary still armed", wall.sanctuary_active)


## `stoked_sweep` — hits every living unit on the target board. Structures are
## deliberately untouched: a sweep is a WIDE weapon, not a second shielding break.
func _test_payoff_sweep() -> void:
	var gs = _new_game()
	var p = gs.players[0]
	var enemy = gs.players[1]
	gs.phase = gs.Phase.PLAYING

	var u := Unit.new(_make_card("t_sweep", 140, {}, [
		_stoke_line(30),
		_attack_line(25, [
			{"op": "stoked_threshold", "n": 25},
			{"op": "stoked_sweep", "n": 1},
		]),
	]))
	_place(gs, 0, 0, 0, u)
	var a := Unit.new(_make_card("t_a", 100, {}, []))
	var b := Unit.new(_make_card("t_b", 100, {}, []))
	_place(gs, 1, 0, 0, a)
	_place(gs, 1, 0, 1, b)
	var atk: AttackData = u.card.attack_lines()[0]

	## Below the threshold only the unit across is hit.
	u.pay_stoke(20)
	gs._resolve_line_effects(p, enemy, u, atk, null, 0, 0)
	_check("under threshold: front hit", a.hp, 75)
	_check("under threshold: back untouched", b.hp, 100)

	## Over it, the whole rank takes it.
	u.stoked_this_turn = 30
	var tower_before: int = enemy.boards[0].tower_hp
	gs._resolve_line_effects(p, enemy, u, atk, null, 0, 0)
	_check("sweep hit the front", a.hp, 50)
	_check("sweep hit the back too", b.hp, 75)
	_check("sweep left the tower alone", enemy.boards[0].tower_hp, tower_before)


## `stoked_both_boards` — breaks the per-board rule that makes the two lanes
## independent fights. Each board still resolves its own shielding chain.
func _test_payoff_both_boards() -> void:
	var gs = _new_game()
	var p = gs.players[0]
	var enemy = gs.players[1]
	gs.phase = gs.Phase.PLAYING

	var u := Unit.new(_make_card("t_both", 170, {}, [
		_stoke_line(45),
		_attack_line(30, [
			{"op": "stoked_threshold", "n": 45},
			{"op": "stoked_both_boards", "n": 1},
		]),
	]))
	_place(gs, 0, 0, 0, u)
	var near := Unit.new(_make_card("t_near", 100, {}, []))
	var far := Unit.new(_make_card("t_far", 100, {}, []))
	_place(gs, 1, 0, 0, near)
	_place(gs, 1, 1, 0, far)
	var atk: AttackData = u.card.attack_lines()[0]

	## Under the threshold it never crosses.
	u.pay_stoke(30)
	gs._resolve_line_effects(p, enemy, u, atk, null, 0, 0)
	_check("under threshold: near board hit", near.hp, 70)
	_check("under threshold: far board safe", far.hp, 100)

	u.stoked_this_turn = 45
	gs._resolve_line_effects(p, enemy, u, atk, null, 0, 0)
	_check("both boards: near hit again", near.hp, 40)
	_check("both boards: far board reached", far.hp, 70)


## `stoked_also_tower` — the SOFT reach payoff. It never redirects the attack,
## so a defended board still costs the attacker its main damage.
func _test_payoff_also_tower() -> void:
	var gs = _new_game()
	var p = gs.players[0]
	var enemy = gs.players[1]
	gs.phase = gs.Phase.PLAYING

	var u := Unit.new(_make_card("t_splash", 120, {}, [
		_stoke_line(20),
		_attack_line(30, [{"op": "stoked_also_tower", "n": 15}]),
	]))
	_place(gs, 0, 0, 0, u)
	var wall := Unit.new(_make_card("t_w", 200, {}, []))
	_place(gs, 1, 0, 0, wall)
	var atk: AttackData = u.card.attack_lines()[0]
	var tower_before: int = enemy.boards[0].tower_hp

	gs._resolve_line_effects(p, enemy, u, atk, null, 0, 0)
	_check("unstoked: no splash", enemy.boards[0].tower_hp, tower_before)
	_check("unstoked: wall took it", wall.hp, 170)

	u.pay_stoke(20)
	gs._resolve_line_effects(p, enemy, u, atk, null, 0, 0)
	_check("stoked: the wall STILL takes the main hit", wall.hp, 140)
	_check("stoked: tower splashed too", enemy.boards[0].tower_hp, tower_before - 15)


## `stoked_extra_attack` — conditional Windfury. The grant is checked through
## `queue_attack`, which is the entry point a player actually clicks.
func _test_payoff_extra_attack() -> void:
	var gs = _new_game()
	var p = gs.players[0]
	var enemy = gs.players[1]
	gs.phase = gs.Phase.PLAYING
	p.pool = 20

	var u := Unit.new(_make_card("t_twice", 140, {}, [
		_stoke_line(25, [{"op": "stoked_extra_attack", "n": 1}]),
		_attack_line(20, [], {"forge": 2}),
	]))
	_place(gs, 0, 0, 0, u)
	var wall := Unit.new(_make_card("t_w2", 200, {}, []))
	_place(gs, 1, 0, 0, wall)

	var ab: AttackData = u.card.ability_lines()[0]
	var atk: AttackData = u.card.attack_lines()[0]

	## Without the grant, a second queue is refused outright.
	_ok("first queue accepted", gs.queue_attack(p, u, atk))
	_ok("second queue refused without the grant", not gs.queue_attack(p, u, atk))

	u.clear_queue()
	gs.use_ability(p, u, ab)
	_ok("stoke granted the extra slot", u.extra_attack_allowed)
	_ok("first queue accepted again", gs.queue_attack(p, u, atk))
	_ok("second queue now accepted", gs.queue_attack(p, u, atk))

	## Both resolve, in order, through the real end-of-turn volley.
	gs._resolve_attacks(p)
	_check("both attacks landed", wall.hp, 160)


## `stoked_immediate` — resolves at queue time rather than end of turn, which is
## what lets it kill a blocker before the rest of the volley.
func _test_payoff_immediate() -> void:
	var gs = _new_game()
	var p = gs.players[0]
	var enemy = gs.players[1]
	gs.phase = gs.Phase.PLAYING
	p.pool = 20

	var u := Unit.new(_make_card("t_now", 120, {}, [
		_stoke_line(20),
		_attack_line(30, [{"op": "stoked_immediate", "n": 1}], {"forge": 2}),
	]))
	_place(gs, 0, 0, 0, u)
	var wall := Unit.new(_make_card("t_w3", 200, {}, []))
	_place(gs, 1, 0, 0, wall)
	var atk: AttackData = u.card.attack_lines()[0]

	## Unstoked it queues normally and waits for end of turn.
	gs.queue_attack(p, u, atk)
	_check("unstoked: nothing has happened yet", wall.hp, 200)
	_ok("unstoked: it is sitting in the queue", u.queued_attack != null)
	u.clear_queue()

	u.pay_stoke(20)
	gs.queue_attack(p, u, atk)
	_check("stoked: it resolved on the spot", wall.hp, 170)
	_ok("stoked: nothing was left queued", u.queued_attack == null)


## `stoked_cost_reduction` — stacks, and floors at 0 rather than paying the
## player. Read through `attack_cost`, the one authority on a live cost.
func _test_payoff_cost_reduction() -> void:
	var gs = _new_game()
	var p = gs.players[0]
	gs.phase = gs.Phase.PLAYING
	p.pool = 20

	var u := Unit.new(_make_card("t_cheap", 120, {}, [
		_stoke_line(20, [{"op": "stoked_cost_reduction", "n": 1}]),
		_attack_line(30, [], {"forge": 3}),
	]))
	_place(gs, 0, 0, 0, u)
	var ab: AttackData = u.card.ability_lines()[0]
	var atk: AttackData = u.card.attack_lines()[0]

	_check("printed cost", u.attack_cost(atk), 3)
	gs.use_ability(p, u, ab)
	_check("stoked: one cheaper", u.attack_cost(atk), 2)

	## Stacking: a second grant takes another point off.
	u.cost_reduction_this_turn += 1
	_check("stacks", u.attack_cost(atk), 1)

	## And it floors at 0 — an attack may become free, never negative.
	u.cost_reduction_this_turn += 10
	_check("floors at zero", u.attack_cost(atk), 0)


## `stoked_no_decay` — the rule-break on the game's central tax. Spent on read,
## so it never survives the turn that granted it.
func _test_payoff_no_decay() -> void:
	var gs = _new_game()
	var p = gs.players[0]
	gs.phase = gs.Phase.PLAYING
	p.pool = 10

	var u := Unit.new(_make_card("t_bank", 120, {}, [
		_stoke_line(25, [{"op": "stoked_no_decay", "n": 1}]),
		_attack_line(20, [], {"forge": 2}),
	]))
	_place(gs, 0, 0, 0, u)

	## Baseline: 20% of 10 is 2.
	_check("decay normally bites", p.apply_decay(), 2)

	p.pool = 10
	gs.use_ability(p, u, u.card.ability_lines()[0])
	_ok("grant is set", p.decay_suspended)
	_check("no decay this turn", p.apply_decay(), 0)
	_check("pool intact", p.pool, 10)
	_ok("the grant was spent on read", not p.decay_suspended)
	_check("and decay resumes next turn", p.apply_decay(), 2)


## `stoked_draw` — Forge burns through hand, so card flow is a payoff class.
func _test_payoff_draw() -> void:
	var gs = _new_game()
	var p = gs.players[0]
	gs.phase = gs.Phase.PLAYING
	p.deck = ["forge_energy", "forge_energy", "forge_energy"]
	p.hand = []

	var u := Unit.new(_make_card("t_draw", 120, {}, [
		_stoke_line(20, [{"op": "stoked_draw", "n": 2}]),
		_attack_line(20, [], {"forge": 2}),
	]))
	_place(gs, 0, 0, 0, u)

	gs.use_ability(p, u, u.card.ability_lines()[0])
	_check("stoked: drew 2", p.hand.size(), 2)
	_check("off the deck", p.deck.size(), 1)


## `stoked_twice` — breaks the once-per-turn ability limit for Stoke lines only,
## and for exactly one extra use. Both halves matter: without the second the
## grant would make Stoke unlimited, which is what the limit exists to prevent.
func _test_payoff_stoke_twice() -> void:
	var gs = _new_game()
	var p = gs.players[0]
	gs.phase = gs.Phase.PLAYING

	var u := Unit.new(_make_card("t_relight", 150, {}, [
		_stoke_line(20, [{"op": "stoked_twice", "n": 1}]),
		_attack_line(20, [], {"forge": 2}),
	]))
	_place(gs, 0, 0, 0, u)
	var ab: AttackData = u.card.ability_lines()[0]

	_ok("first stoke accepted", gs.use_ability(p, u, ab))
	_check("paid once", u.stoked_this_turn, 20)
	_ok("granted a second use", u.extra_stoke_allowed)

	_ok("second stoke accepted", gs.use_ability(p, u, ab))
	_check("paid twice — the scaling payoffs double", u.stoked_this_turn, 40)

	## A THIRD is refused: the grant bought one extra use, not a free ability.
	_ok("third stoke refused", not gs.use_ability(p, u, ab))
	_check("no third payment", u.stoked_this_turn, 40)


## Every grant expires with the flag that bought it. An extra attack slot or a
## discount carried into next turn would be permanent multi-attack and permanent
## ramp respectively — the two things the payoffs are explicitly bounded against.
func _test_grants_expire() -> void:
	var gs = _new_game()
	var p = gs.players[0]
	gs.phase = gs.Phase.PLAYING

	var u := Unit.new(_make_card("t_expire", 150, {}, [
		_stoke_line(20, [
			{"op": "stoked_extra_attack", "n": 1},
			{"op": "stoked_twice", "n": 1},
			{"op": "stoked_cost_reduction", "n": 1},
		]),
		_attack_line(20, [], {"forge": 2}),
	]))
	_place(gs, 0, 0, 0, u)
	gs.use_ability(p, u, u.card.ability_lines()[0])
	_ok("granted this turn", u.extra_attack_allowed and u.cost_reduction_this_turn > 0)

	## `begin_turn()`, not `start_turn()` — the latter does not exist, and calling
	## it made every assertion below pass vacuously against a no-op. Caught by
	## sabotaging the reset and watching this test NOT fail.
	p.begin_turn()
	_ok("extra attack expired", not u.extra_attack_allowed)
	_ok("extra stoke expired", not u.extra_stoke_allowed)
	_check("discount expired", u.cost_reduction_this_turn, 0)
	_check("and so did the flag", u.stoked_this_turn, 0)
