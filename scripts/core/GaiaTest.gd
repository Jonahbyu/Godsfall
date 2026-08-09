extends SceneTree

## Gaia harness — Earth aura, Essence, Resist, Makeshift Tower.
## Run: godot --headless --path <project> --script res://scripts/core/GaiaTest.gd

## Total assertions this harness is expected to run. Checked at the end, because
## a crash mid-test produces "0 failed" and exit 0 — the assertions after the
## crash simply never run, and silence reads identically to success.
const EXPECTED_ASSERTIONS := 146

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

## `_initialize()` rather than `_init()`: `_new_game()` loads GameState.gd, which
## references the `CardDB` autoload. Autoloads aren't in the tree yet during
## `_init()` (object construction), only by `_initialize()` (tree ready) — the
## same reason VoidTest.gd defers its run to `_initialize()`. `_test_printed_keywords`
## alone would have worked under `_init()` since it never touches GameState, but
## `_test_earth_sum` needs the tree.
func _initialize() -> void:
	## Register CardDB the way VoidTest/HeavenTest do. Under `--script` the
	## autoloads are NOT in the tree, and without this `Player.new()` inside
	## GameState._init resolves to a bare GDScript and returns null — leaving
	## `players` empty so every `gs.players[0]` errors to stderr while the pass
	## counter silently never increments.
	var db = root.get_node_or_null("CardDB")
	if db == null:
		db = load("res://scripts/core/CardDB.gd").new()
		db.name = "CardDB"
		root.add_child(db)
	if db._cards.is_empty():
		db._load()

	_test_printed_keywords()
	_test_earth_sum()
	_test_aura_healing_and_clamp()
	_test_support_heal_reaches_aura()
	_test_aura_damage()
	_test_resist()
	_test_resist_on_retribution()
	_test_tower_aura()
	_test_essence()
	_test_earth_resets()
	_test_derived_earth_and_rate()
	_test_makeshift_tower()
	_test_card_data()
	_test_full_set()
	_test_set_effect_ops()

	## A harness that errors out mid-test still reports "0 failed", because an
	## assertion that never RUNS cannot fail. Pin the expected total so a crash
	## that skips whole test functions is a failure rather than a clean exit.
	if _pass + _fail != EXPECTED_ASSERTIONS:
		print("FAIL: expected %d assertions, ran %d — a test crashed before finishing."
			% [EXPECTED_ASSERTIONS, _pass + _fail])
		_fail += 1

	print("\nGaiaTest: %d passed, %d failed" % [_pass, _fail])
	quit(1 if _fail > 0 else 0)


func _make_card(id: String, hp: int, kws: Dictionary) -> CardData:
	var kw_list: Array = []
	for k in kws:
		kw_list.append({"kw": k, "n": kws[k]})
	return CardData.from_dict({
		"id": id, "name": id, "type": "unit", "faction": "gaia",
		"hp": hp, "keywords": kw_list,
	})


func _test_printed_keywords() -> void:
	var u := Unit.new(_make_card("t_earth", 60, {"earth": 3, "essence": 2, "resist": 5}))
	_check("earth is printed", u.earth(), 3)
	_check("essence is printed", u.essence(), 2)
	_check("resist is printed", u.resist(), 5)
	_ok("has_essence", u.has_essence())

	var bare := Unit.new(_make_card("t_bare", 50, {}))
	_check("no earth is 0", bare.earth(), 0)
	_check("no resist is 0", bare.resist(), 0)
	_ok("no essence", not bare.has_essence())


## Build a real two-player GameState with empty decks. Deck contents don't matter
## for aura tests — units are placed directly onto boards.
##
## GameState's constructor is `_init(deck_p1: Array, deck_p2: Array)` and it is
## loaded rather than referenced by class_name, matching VoidTest.gd:55.
func _new_game():
	return load("res://scripts/core/GameState.gd").new([], [])


func _place(gs, side: int, bi: int, si: int, u: Unit) -> void:
	gs.players[side].boards[bi].slots[si] = u


func _test_earth_sum() -> void:
	var gs = _new_game()
	var p = gs.players[0]

	_check("empty board is 0 Earth", gs.earth_for(p), 0)

	var a := Unit.new(_make_card("e_a", 60, {"earth": 3}))
	var b := Unit.new(_make_card("e_b", 60, {"earth": 2}))
	_place(gs, 0, 0, 0, a)
	_place(gs, 0, 1, 0, b)
	_check("Earth sums across both boards", gs.earth_for(p), 5)

	## Grown Earth counts toward the aura.
	a.earth_grown = 4
	_check("grown Earth counts", gs.earth_for(p), 9)
	a.earth_grown = 0

	## Dead-but-not-cleaned units are excluded, exactly like the Gap. Within a
	## volley a corpse still sits on the board for Retribution, but its Earth is
	## already gone or the aura would outlive the body holding it.
	a.hp = 0
	_check("dead units excluded", gs.earth_for(p), 2)
	a.hp = 60

	## The aura is strictly per-player.
	_check("enemy Earth is separate", gs.earth_for(gs.players[1]), 0)

	## effective_max_hp adds the aura on top of the PRINTED max.
	_check("effective max includes aura", gs.effective_max_hp(p, a), 65)
	_check("printed max is untouched", a.max_hp(), 60)
	_check("default rate is 1", gs.earth_rate(p), 1)


func _test_aura_healing_and_clamp() -> void:
	var gs = _new_game()
	var p = gs.players[0]

	var big := Unit.new(_make_card("h_big", 60, {"earth": 5}))
	_place(gs, 0, 0, 0, big)

	## 60 printed + 5 Earth = 65 effective.
	_check("effective max includes aura", gs.effective_max_hp(p, big), 65)

	big.hp = 55
	_check("heals into aura HP", gs.heal_unit(p, big, 10), 10)
	_check("hp reached effective max", big.hp, 65)

	## Healing still stops at the effective ceiling, never above it.
	_check("no overheal", gs.heal_unit(p, big, 10), 0)
	_check("hp unchanged", big.hp, 65)

	## Aura grows: a second Earth body raises the ceiling for everyone.
	var feeder := Unit.new(_make_card("h_feed", 40, {"earth": 3}))
	_place(gs, 0, 0, 1, feeder)
	_check("aura grew", gs.effective_max_hp(p, big), 68)
	gs.heal_unit(p, big, 5)
	_check("healed into the bigger aura", big.hp, 68)

	## Aura shrinks: the feeder dies, the ceiling drops, and the unit sitting
	## above it is clamped down.
	feeder.hp = 0
	gs.clamp_to_aura(p)
	_check("clamped when aura shrank", big.hp, 65)

	## Clamping never kills. A unit at 1 HP stays alive no matter what.
	var frail := Unit.new(_make_card("h_frail", 40, {}))
	frail.hp = 1
	_place(gs, 0, 1, 0, frail)
	gs.clamp_to_aura(p)
	_ok("clamp never kills", frail.is_alive())

	## Dead units are not resurrected or touched by clamping.
	_ok("dead stays dead", not feeder.is_alive())


## A support heal must reach the aura's HP, not stop at the printed max.
func _test_support_heal_reaches_aura() -> void:
	var gs = _new_game()
	var p = gs.players[0]
	var u := Unit.new(_make_card("sh_u", 60, {"earth": 5}))
	_place(gs, 0, 0, 0, u)
	u.hp = 50
	## 60 printed + 5 Earth = 65 effective. A 20-point heal must reach 65, not 60.
	_check("heal reaches aura ceiling", gs.heal_unit(p, u, 20), 15)
	_check("hp at effective max", u.hp, 65)


## Earth adds to outgoing attack damage, at the attacker's rate, read at
## resolution — driven through the real `_resolve_line_effects` pipeline
## (not `_deal_lane_damage` directly), which is the single place an
## attack's damage is assembled.
func _test_aura_damage() -> void:
	var gs = _new_game()
	var p = gs.players[0]
	var foe = gs.players[1]

	var atk := AttackData.from_dict({
		"id": "a_swing", "name": "Swing", "damage": 10, "cost": {"gaia": 1},
	})
	var attacker := Unit.new(_make_card("d_att", 60, {"earth": 4}))
	_place(gs, 0, 0, 0, attacker)

	var target := Unit.new(_make_card("d_tgt", 100, {}))
	_place(gs, 1, 0, 0, target)

	## 10 printed + 4 Earth = 14. Driven through the REAL resolution path.
	gs._resolve_line_effects(p, foe, attacker, atk, null, 0, 0)
	_check("aura adds to attack damage", target.hp, 86)

	## The aura is the ATTACKER's. A defender's own Earth must not reduce damage.
	var shielded := Unit.new(_make_card("d_shield", 100, {"earth": 9}))
	_place(gs, 1, 0, 1, shielded)
	target.hp = 0
	gs._resolve_line_effects(p, foe, attacker, atk, null, 0, 1)
	_check("defender Earth does not reduce damage", shielded.hp, 86)

	## Zero Earth must leave damage exactly as printed — the no-regression case
	## that every existing card in the game depends on.
	var gs2 = _new_game()
	var p2 = gs2.players[0]
	var foe2 = gs2.players[1]
	var plain := Unit.new(_make_card("d_plain", 60, {}))
	var victim := Unit.new(_make_card("d_vic", 100, {}))
	_place(gs2, 0, 0, 0, plain)
	_place(gs2, 1, 0, 0, victim)
	gs2._resolve_line_effects(p2, foe2, plain, atk, null, 0, 0)
	_check("no Earth is printed damage", victim.hp, 90)


func _test_resist() -> void:
	var gs = _new_game()
	var p = gs.players[0]
	var foe = gs.players[1]

	var atk := AttackData.from_dict({
		"id": "r_swing", "name": "Swing", "damage": 20, "cost": {"gaia": 1},
	})
	var attacker := Unit.new(_make_card("r_att", 60, {}))
	_place(gs, 0, 0, 0, attacker)

	var wall := Unit.new(_make_card("r_wall", 100, {"resist": 5}))
	_place(gs, 1, 0, 0, wall)

	## 20 damage - Resist 5 = 15 through, on the real attack path.
	gs._resolve_line_effects(p, foe, attacker, atk, null, 0, 0)
	_check("resist reduces each instance", wall.hp, 85)

	## The floor: Resist can never fully negate. Decay 5 into Resist 99 lands 1.
	var tank := Unit.new(_make_card("r_tank", 100, {"resist": 99}))
	_place(gs, 1, 1, 0, tank)
	_check("minimum 1 always lands", gs._damage_unit(tank, 5, "decay"), 1)
	_check("tank took exactly 1", tank.hp, 99)

	## A unit with no Resist is completely unaffected.
	var plain := Unit.new(_make_card("r_plain", 100, {}))
	_place(gs, 1, 1, 1, plain)
	_check("no resist is full damage", gs._damage_unit(plain, 20, "decay"), 20)

	## Sanctuary is prevention and runs FIRST: it must see the full amount, and
	## Resist only ever blunts what got through.
	var both := Unit.new(_make_card("r_both", 100, {"resist": 5, "sanctuary": 60}))
	_place(gs, 1, 1, 2, both)
	_check("sanctuary absorbs before resist", gs._damage_unit(both, 30, "attack"), 0)
	_check("sanctuary pool saw the FULL 30", both.sanctuary_pool, 30)
	_check("no damage reached hp", both.hp, 100)


## Retribution recoil is an instance of damage, so `Resist` blunts it.
##
## Sanctuary is deliberately NOT asserted here: the recoil site has always
## bypassed `absorb()`, which contradicts CLAUDE.md but predates Gaia and would
## change Heaven's behaviour to fix. Recorded in gaia.md Open Questions.
func _test_resist_on_retribution() -> void:
	var gs = _new_game()
	var p = gs.players[0]
	var foe = gs.players[1]

	var atk := AttackData.from_dict({
		"id": "rr_swing", "name": "Swing", "damage": 10, "cost": {"gaia": 1},
	})
	## The attacker has Resist 4 and will eat the recoil.
	var attacker := Unit.new(_make_card("rr_att", 100, {"resist": 4}))
	_place(gs, 0, 0, 0, attacker)
	## The defender punches back for 10.
	var thorns := Unit.new(_make_card("rr_def", 100, {"retribution": 10}))
	_place(gs, 1, 0, 0, thorns)

	gs._resolve_line_effects(p, foe, attacker, atk, null, 0, 0)
	_check("recoil is resisted", attacker.hp, 94)
	_check("defender still took the hit", thorns.hp, 90)

	## The floor holds on recoil too: Resist 99 still eats 1.
	var gs2 = _new_game()
	var p2 = gs2.players[0]
	var foe2 = gs2.players[1]
	var tanky := Unit.new(_make_card("rr_tank", 100, {"resist": 99}))
	_place(gs2, 0, 0, 0, tanky)
	var thorns2 := Unit.new(_make_card("rr_d2", 100, {"retribution": 10}))
	_place(gs2, 1, 0, 0, thorns2)
	gs2._resolve_line_effects(p2, foe2, tanky, atk, null, 0, 0)
	_check("recoil floors at 1", tanky.hp, 99)


## The aura grants tower max HP and tower damage. Tower max HP is STORED state,
## unlike a unit's, so the aura's share is tracked on the Board and re-applied
## rather than recomputed — the sync has to be idempotent or it would compound.
func _test_tower_aura() -> void:
	var gs = _new_game()
	var p = gs.players[0]
	var b = p.boards[0]

	_check("tower starts at printed max", b.tower_max_hp, 50)

	var e := Unit.new(_make_card("t_e", 60, {"earth": 6}))
	_place(gs, 0, 0, 0, e)
	gs.sync_tower_aura(p)
	_check("tower max HP gains the aura", b.tower_max_hp, 56)
	_check("current HP rises with it", b.tower_hp, 56)

	## Idempotent — syncing repeatedly must not compound.
	gs.sync_tower_aura(p)
	gs.sync_tower_aura(p)
	_check("sync is idempotent", b.tower_max_hp, 56)
	_check("current HP not compounded", b.tower_hp, 56)

	## Both towers receive it, not just the board the Earth unit stands on.
	_check("the other tower gains it too", p.boards[1].tower_max_hp, 56)

	## The aura shrinks when the Earth body dies.
	e.hp = 0
	gs.sync_tower_aura(p)
	_check("tower max HP falls back", b.tower_max_hp, 50)
	_check("current HP clamped down", b.tower_hp, 50)

	## Shrinking must never kill a tower — it floors at 1.
	e.hp = 60
	gs.sync_tower_aura(p)
	b.tower_hp = 1
	e.hp = 0
	gs.sync_tower_aura(p)
	_ok("aura shrinking never kills a tower", b.tower_alive())

	## The aura is added to the tower's outgoing damage.
	##
	## Driven through `_tower_strike` — the function that resolves ONE shot —
	## rather than `_resolve_towers`, which loops over both players and fires
	## four towers. Return fire from the other side perturbs whatever number this
	## is trying to read; `RulesTest` already covers `_resolve_towers`' own
	## scheduling, so what is left to prove here is only that the aura reaches the
	## damage figure and obeys the half-rate rule behind it.
	var gs2 = _new_game()
	var p2 = gs2.players[0]
	var foe2 = gs2.players[1]
	gs2.turn = 4                        ## past round-1 silence: 5 + 3*(4-2) = 11
	_place(gs2, 0, 0, 0, Unit.new(_make_card("t_dmg", 60, {"earth": 5})))

	## Reproduce what `_resolve_towers` hands to the strike: base + mods + aura.
	var aura: int = gs2.earth_for(p2) * gs2.earth_rate(p2)
	_check("aura reaches tower damage", aura, 5)
	var shot: int = gs2.tower_damage() + gs2.players[0].boards[0].tower_damage_bonus + aura
	_check("tower shot is base plus aura", shot, 16)

	## Full damage to a living unit.
	var victim := Unit.new(_make_card("t_vic", 200, {}))
	_place(gs2, 1, 0, 0, victim)
	gs2._tower_strike(p2, foe2, 0, shot, "tower fire")
	_check("full damage to a unit", 200 - victim.hp, 16)

	## Half, floored, to a structure once that board is clear — the aura raises
	## the number the half is taken FROM, never the rate itself.
	victim.hp = 0
	var eb = foe2.boards[0]
	var tower_before: int = eb.tower_hp
	gs2._tower_strike(p2, foe2, 0, shot, "tower fire")
	_check("half-rate chip uses the buffed number", tower_before - eb.tower_hp, 8)


## `Essence N` — pay N from the pool on death to move the dying unit's Earth and
## attached energy to the nearest living friendly unit on the SAME board.
##
## Driven through the real `_cleanup_dead`, which is the only path a unit ever
## leaves the board by. The harness has no picker attached, so `_choose_from`
## auto-resolves to the first option (pay) — see `_try_essence`.
func _test_essence() -> void:
	var gs = _new_game()
	var p = gs.players[0]

	## Dying unit in slot 0, heir in slot 1, same board.
	var dying := Unit.new(_make_card("es_dying", 60, {"essence": 2, "earth": 3}))
	dying.attached = 4
	var heir := Unit.new(_make_card("es_heir", 80, {}))
	_place(gs, 0, 0, 0, dying)
	_place(gs, 0, 0, 1, heir)

	p.pool = 5
	dying.hp = 0
	gs._cleanup_dead(p)

	_check("pool paid the essence cost", p.pool, 3)
	_check("attached energy carried forward", heir.attached, 4)
	_check("earth carried forward", heir.earth_grown, 3)
	_check("the aura survives the death", gs.earth_for(p), 3)

	## Cannot afford: the unit dies normally and everything is lost.
	var gs2 = _new_game()
	var p2 = gs2.players[0]
	var poor := Unit.new(_make_card("es_poor", 60, {"essence": 3, "earth": 2}))
	poor.attached = 5
	var heir2 := Unit.new(_make_card("es_h2", 80, {}))
	_place(gs2, 0, 0, 0, poor)
	_place(gs2, 0, 0, 1, heir2)
	p2.pool = 1
	poor.hp = 0
	gs2._cleanup_dead(p2)
	_check("unaffordable essence pays nothing", p2.pool, 1)
	_check("energy lost as normal", heir2.attached, 0)
	_check("earth lost as normal", heir2.earth_grown, 0)

	## Never crosses boards — an heir on the OTHER board is not eligible.
	var gs3 = _new_game()
	var p3 = gs3.players[0]
	var alone := Unit.new(_make_card("es_alone", 60, {"essence": 1, "earth": 2}))
	alone.attached = 3
	var other_board := Unit.new(_make_card("es_ob", 80, {}))
	_place(gs3, 0, 0, 0, alone)
	_place(gs3, 0, 1, 0, other_board)
	p3.pool = 5
	alone.hp = 0
	gs3._cleanup_dead(p3)
	_check("never crosses boards", other_board.attached, 0)
	_check("fizzle costs nothing", p3.pool, 5)

	## Only to a SURVIVOR: an heir dying in the same batch is skipped, and the
	## transfer goes to the living one further away.
	var gs4 = _new_game()
	var p4 = gs4.players[0]
	var d4 := Unit.new(_make_card("es_d4", 60, {"essence": 1, "earth": 5}))
	d4.attached = 2
	var dead_heir := Unit.new(_make_card("es_dh", 60, {}))
	var live_heir := Unit.new(_make_card("es_lh", 60, {}))
	_place(gs4, 0, 0, 0, d4)
	_place(gs4, 0, 0, 1, dead_heir)
	_place(gs4, 0, 0, 2, live_heir)
	p4.pool = 5
	d4.hp = 0
	dead_heir.hp = 0
	gs4._cleanup_dead(p4)
	_check("skips a dying heir", dead_heir.attached, 0)
	_check("transfers to the survivor", live_heir.attached, 2)
	_check("earth to the survivor", live_heir.earth_grown, 5)

	## Nearest wins, and ties go LEFT — the same tiebreak the targeting chain uses.
	var gs5 = _new_game()
	var p5 = gs5.players[0]
	var mid := Unit.new(_make_card("es_mid", 60, {"essence": 1, "earth": 4}))
	mid.attached = 6
	var left := Unit.new(_make_card("es_left", 60, {}))
	var right := Unit.new(_make_card("es_right", 60, {}))
	_place(gs5, 0, 0, 0, left)
	_place(gs5, 0, 0, 1, mid)
	_place(gs5, 0, 0, 2, right)
	p5.pool = 5
	mid.hp = 0
	gs5._cleanup_dead(p5)
	_check("ties go left", left.attached, 6)
	_check("the right neighbour gets nothing", right.attached, 0)

	## A unit with no Essence keyword transfers nothing, whatever the pool holds.
	var gs6 = _new_game()
	var p6 = gs6.players[0]
	var plain := Unit.new(_make_card("es_plain", 60, {"earth": 3}))
	plain.attached = 4
	var h6 := Unit.new(_make_card("es_h6", 60, {}))
	_place(gs6, 0, 0, 0, plain)
	_place(gs6, 0, 0, 1, h6)
	p6.pool = 9
	plain.hp = 0
	gs6._cleanup_dead(p6)
	_check("no essence keyword, no transfer", h6.attached, 0)
	_check("pool untouched without the keyword", p6.pool, 9)


## `Rise` restores the card, not the history: grown Earth is lost with the body,
## exactly as attached energy is. Evolution is likewise a NEW printed card.
func _test_earth_resets() -> void:
	var u := Unit.new(_make_card("rz_a", 60, {"earth": 2, "rise": 0}))
	u.earth_grown = 7
	_check("grown earth counts before death", u.earth(), 9)

	var risen := u.make_risen()
	_check("risen keeps printed earth", risen.earth(), 2)
	_check("risen loses grown earth", risen.earth_grown, 0)

	## Evolution takes the new card's printed Earth and drops what was grown.
	var evo := Unit.new(_make_card("rz_b", 60, {"earth": 1}))
	evo.earth_grown = 5
	_check("grown earth counts before evolving", evo.earth(), 6)
	evo.evolve_into(_make_card("rz_c", 100, {"earth": 3}))
	_check("evolved uses the new printed earth", evo.earth(), 3)
	_check("evolved loses grown earth", evo.earth_grown, 0)

	## Essence-carried Earth lands in `earth_grown`, so it is subject to the same
	## rule — a unit that inherited a funeral and then evolves does not keep it.
	var heir := Unit.new(_make_card("rz_h", 60, {"earth": 1}))
	heir.earth_grown += 4
	_check("inherited earth counts", heir.earth(), 5)
	heir.evolve_into(_make_card("rz_h2", 100, {"earth": 2}))
	_check("evolving drops inherited earth", heir.earth(), 2)


## Earth derived live from attached energy, and the additive rate-breaker.
func _test_derived_earth_and_rate() -> void:
	var gs = _new_game()
	var p = gs.players[0]

	var conduit_card := CardData.from_dict({
		"id": "gaia_living_conduit", "name": "Living Conduit", "type": "unit",
		"faction": "gaia", "hp": 70, "retreat": 1,
		"effects": [{"op": "earth_from_attached", "n": 1}],
	})
	var conduit := Unit.new(conduit_card)
	_place(gs, 0, 0, 0, conduit)
	_check("no energy is no Earth", gs.earth_for(p), 0)

	conduit.attached = 4
	_check("Earth tracks attached energy", gs.earth_for(p), 4)
	conduit.attached = 1
	_check("Earth falls with the energy", gs.earth_for(p), 1)
	conduit.attached = 0
	_check("spent to nothing is nothing", gs.earth_for(p), 0)

	## The rate-breaker: ADDITIVE, never multiplicative. The aura applies to four
	## units and two towers, so a multiplier on the total is exponential across
	## six things (CLAUDE.md decision log).
	conduit.attached = 1
	var breaker_card := CardData.from_dict({
		"id": "gaia_deep_roots", "name": "Deep Roots", "type": "unit",
		"faction": "gaia", "hp": 110, "retreat": 2,
		"keywords": [{"kw": "earth", "n": 2}],
		"effects": [{"op": "earth_rate", "n": 1}],
	})
	_place(gs, 0, 0, 1, Unit.new(breaker_card))
	_check("Earth total", gs.earth_for(p), 3)
	_check("rate raised to 2", gs.earth_rate(p), 2)

	## 70 printed + (3 Earth x rate 2) = 76.
	_check("aura uses the raised rate", gs.effective_max_hp(p, conduit), 76)

	## Two rate-breakers ADD rather than compound: 1 + 1 + 1 = 3, not 4.
	_place(gs, 0, 1, 0, Unit.new(breaker_card))
	_check("two breakers add", gs.earth_rate(p), 3)

	## A dead rate-breaker stops contributing, exactly like Earth itself.
	gs.players[0].boards[1].slots[0].hp = 0
	_check("dead breaker stops counting", gs.earth_rate(p), 2)

	## Units read `effects` at all — the parser used to drop the list for units.
	_ok("units parse their effects", conduit_card.has_effect("earth_from_attached"))


## Makeshift Tower: a unit that auto-fires at end of turn for free, and grows
## +5 max HP a round like a real tower. Its whole cost is that it is a UNIT — an
## enemy attack may name it, which a real tower is immune to until the board is
## cleared.
func _test_makeshift_tower() -> void:
	var gs = _new_game()
	var p = gs.players[0]
	var foe = gs.players[1]

	var mt_card := CardData.from_dict({
		"id": "gaia_makeshift_tower", "name": "Makeshift Tower", "type": "unit",
		"faction": "gaia", "hp": 50, "retreat": 1,
		"keywords": [{"kw": "earth", "n": 1}],
		"effects": [{"op": "auto_fire", "n": 10}, {"op": "tower_growth", "n": 5}],
	})
	_ok("unit effects survive parsing", mt_card.has_effect("auto_fire"))

	var mt := Unit.new(mt_card)
	_place(gs, 0, 0, 0, mt)
	var victim := Unit.new(_make_card("mt_v", 100, {}))
	_place(gs, 1, 0, 0, victim)

	## 10 printed + 1 own Earth = 11. It pays nothing to fire.
	gs.resolve_auto_fire(p, foe)
	_check("auto-fires without energy", victim.hp, 89)
	_check("spent no energy", mt.attached, 0)

	## It grows like a tower, and current HP rises with the max.
	_check("starts at printed max", mt.max_hp(), 50)
	gs.grow_auto_towers(p)
	_check("gains 5 max HP a round", mt.max_hp(), 55)
	_check("current HP grows too", mt.hp, 55)
	gs.grow_auto_towers(p)
	_check("growth accumulates", mt.max_hp(), 60)

	## Growth is history, so Rise drops it — the same rule as grown Earth.
	var risen := mt.make_risen()
	_check("risen returns at printed size", risen.max_hp(), 50)
	_check("risen keeps no grown HP", risen.hp_grown, 0)

	## A unit with no auto_fire effect never fires, whatever else it has.
	var gs2 = _new_game()
	var p2 = gs2.players[0]
	var foe2 = gs2.players[1]
	_place(gs2, 0, 0, 0, Unit.new(_make_card("mt_plain", 60, {"earth": 3})))
	var safe := Unit.new(_make_card("mt_safe", 100, {}))
	_place(gs2, 1, 0, 0, safe)
	gs2.resolve_auto_fire(p2, foe2)
	_check("no auto_fire, no shot", safe.hp, 100)

	## Auto-fire obeys the shielding chain: it cannot reach a tower past a living
	## unit, and it hits the leftmost survivor when nothing faces it.
	var gs3 = _new_game()
	var p3 = gs3.players[0]
	var foe3 = gs3.players[1]
	_place(gs3, 0, 0, 1, Unit.new(mt_card))       ## fires from slot 1
	var shield := Unit.new(_make_card("mt_shield", 100, {}))
	_place(gs3, 1, 0, 0, shield)                  ## only living body, slot 0
	var tower_hp_before: int = foe3.boards[0].tower_hp
	gs3.resolve_auto_fire(p3, foe3)
	_check("redirects to the leftmost survivor", shield.hp, 89)
	_check("cannot reach the tower past a unit", foe3.boards[0].tower_hp, tower_hp_before)


## The Gaia cards as they actually sit in `data/cards.json`, loaded through
## CardDB. The tests above build their fixtures inline, which proves the ENGINE
## works but says nothing about whether the shipped card data is right — this is
## the check that the printed numbers survive the parser.
func _test_card_data() -> void:
	var db = root.get_node_or_null("CardDB")

	var energy = db.get_card("gaia_energy")
	_ok("gaia energy exists", energy != null)
	_check("gaia energy is an energy card", energy.type, CardData.Type.ENERGY)
	_check("gaia energy is gaia", energy.faction, "gaia")

	var mt = db.get_card("gaia_makeshift_tower")
	_ok("makeshift tower exists", mt != null)
	_check("makeshift tower HP", mt.max_hp, 50)
	_check("makeshift tower Earth", mt.kw("earth"), 1)
	_ok("makeshift tower auto-fires", mt.has_effect("auto_fire"))
	_check("auto-fire damage", mt.effect_value("auto_fire", 0), 10)
	_ok("makeshift tower grows", mt.has_effect("tower_growth"))
	## Retreat is HP / 40 floored: 50 / 40 = 1.
	_check("makeshift tower retreat", mt.retreat, 1)

	var lc = db.get_card("gaia_living_conduit")
	_ok("living conduit exists", lc != null)
	_check("living conduit HP", lc.max_hp, 70)
	_ok("earth from attached", lc.has_effect("earth_from_attached"))
	_check("living conduit essence", lc.kw("essence"), 1)
	_check("living conduit retreat", lc.retreat, 1)

	var dr = db.get_card("gaia_deep_roots")
	_ok("deep roots exists", dr != null)
	_check("deep roots HP", dr.max_hp, 110)
	_check("deep roots evolves from the conduit", dr.evolves_from, "gaia_living_conduit")
	_ok("deep roots breaks the rate", dr.has_effect("earth_rate"))
	_check("rate breaker is additive by 1", dr.effect_value("earth_rate", 0), 1)
	## HP 110 / 40 = 2.
	_check("deep roots retreat", dr.retreat, 2)

	## Attack costs must parse in the card's OWN colour. Heaven shipped with every
	## attack costing 0 because the parser only read `cost.hel` — the exact bug
	## CLAUDE.md's decision log records, so Gaia asserts against it directly.
	_check("conduit attack cost", lc.attacks[0].total_cost(), 2)
	_check("deep roots attack cost", dr.attacks[0].total_cost(), 3)
	_check("conduit attack damage", lc.attacks[0].damage, 18)
	_check("deep roots attack damage", dr.attacks[0].damage, 26)


## The full Gaia card set as authored in `data/cards.json`: five evolution chains,
## the supports, the Tool. Checks the printed numbers survive the parser and that
## the chains actually link — an evolution whose Basic is missing is the trap a
## themed set invites (CLAUDE.md).
func _test_full_set() -> void:
	var db = root.get_node_or_null("CardDB")
	var ids := [
		"gaia_makeshift_tower", "gaia_bulwark_of_stone", "gaia_the_standing_stone",
		"gaia_living_conduit", "gaia_deep_roots", "gaia_heartwood_ancient",
		"gaia_sapling_warden", "gaia_grovekeeper", "gaia_elder_of_the_grove",
		"gaia_mossback_tortoise", "gaia_granite_colossus",
		"gaia_seedbearer", "gaia_vernal_rite",
		"gaia_bedrock", "gaia_deep_communion", "gaia_terraform",
		"gaia_cairn", "gaia_verdant_anchor", "gaia_energy",
	]
	var missing := 0
	for cid in ids:
		if db.get_card(cid) == null:
			missing += 1
			print("  missing card: %s" % cid)
	_check("every Gaia card loads", missing, 0)

	## Every evolution names a card that exists, and names its own chain's parent.
	var chain_ok := true
	for pair in [
		["gaia_bulwark_of_stone", "gaia_makeshift_tower"],
		["gaia_the_standing_stone", "gaia_bulwark_of_stone"],
		["gaia_deep_roots", "gaia_living_conduit"],
		["gaia_heartwood_ancient", "gaia_deep_roots"],
		["gaia_grovekeeper", "gaia_sapling_warden"],
		["gaia_elder_of_the_grove", "gaia_grovekeeper"],
		["gaia_granite_colossus", "gaia_mossback_tortoise"],
		["gaia_vernal_rite", "gaia_seedbearer"],
	]:
		var child = db.get_card(pair[0])
		if child == null or child.evolves_from != pair[1]:
			chain_ok = false
			print("  broken chain: %s should evolve from %s" % [pair[0], pair[1]])
	_ok("all five chains link", chain_ok)

	## Retreat is HP / 40 floored, for every unit in the set.
	var retreat_ok := true
	for cid in ids:
		var c = db.get_card(cid)
		if c == null or not c.is_unit():
			continue
		if c.retreat != int(c.max_hp / 40.0):
			retreat_ok = false
			print("  retreat mismatch: %s hp%d printed %d" % [c.name, c.max_hp, c.retreat])
	_ok("retreat follows HP / 40", retreat_ok)

	## `Resist` lives on the stone chain and nowhere else — it is per-card flavour,
	## not part of Gaia's identity (CLAUDE.md: shared keywords are chosen per card).
	_check("bulwark resists", db.get_card("gaia_bulwark_of_stone").kw("resist"), 5)
	_check("standing stone resists", db.get_card("gaia_the_standing_stone").kw("resist"), 10)
	_check("the grove does not resist", db.get_card("gaia_elder_of_the_grove").kw("resist"), 0)

	## Exactly ONE rate-breaker in the base set, per gaia.md's open question.
	var breakers := 0
	for cid2 in db.all_ids():
		var c2 = db.get_card(cid2)
		if c2 != null and c2.faction == "gaia" and c2.has_effect("earth_rate"):
			breakers += 1
	_check("exactly one rate-breaker", breakers, 1)


## The three effect ops the card set introduced: growing a unit's own Earth,
## moving grown Earth between units, and a Tool granting Earth.
func _test_set_effect_ops() -> void:
	var db = root.get_node_or_null("CardDB")
	var gs = _new_game()
	## Abilities are gated on the main phase — a fresh GameState starts in
	## Phase.SETUP, exactly as VoidTest.gd does before driving the rules API.
	gs.skip_setup()
	var p = gs.players[0]

	## `grow_earth` — Grovekeeper's Tend, a free once-per-turn ability.
	var keeper := Unit.new(db.get_card("gaia_grovekeeper"))
	_place(gs, 0, 0, 0, keeper)
	_check("grovekeeper starts at printed Earth", keeper.earth(), 2)
	var tend: AttackData = null
	for a in keeper.card.ability_lines():
		if a.has_effect("grow_earth"):
			tend = a
	_ok("Tend is an ability", tend != null and tend.is_ability)
	_check("Tend is free", tend.total_cost(), 0)
	gs.use_ability(p, keeper, tend)
	_check("Tend grows Earth", keeper.earth(), 3)
	_check("growth is permanent, in earth_grown", keeper.earth_grown, 1)
	## Once per turn per unit — a global rule, not a per-card clause.
	gs.use_ability(p, keeper, tend)
	_check("Tend is once per turn", keeper.earth(), 3)

	## `move_earth` — Vernal Rite's Gather consolidates grown Earth onto itself.
	var rite := Unit.new(db.get_card("gaia_vernal_rite"))
	_place(gs, 0, 0, 1, rite)
	var before_total: int = gs.earth_for(p)
	var gather: AttackData = null
	for a in rite.card.ability_lines():
		if a.has_effect("move_earth"):
			gather = a
	_ok("Gather is an ability", gather != null and gather.is_ability)
	gs.use_ability(p, rite, gather, keeper)
	_check("grown Earth left the source", keeper.earth_grown, 0)
	_check("grown Earth arrived", rite.earth_grown, 1)
	_check("printed Earth did not move", keeper.earth(), 2)
	_check("board total is unchanged by a move", gs.earth_for(p), before_total)

	## `grant_earth` — Verdant Anchor, a Tool, the same shape as Event Horizon.
	var anchor = db.get_card("gaia_verdant_anchor")
	var plain := Unit.new(_make_card("va_u", 60, {"earth": 1}))
	_check("before the Tool", plain.earth(), 1)
	plain.tool = anchor
	_check("Tool grants Earth", plain.earth(), 3)

	## `grow_earth_target` — Bedrock, a free support.
	var gs2 = _new_game()
	gs2.skip_setup()
	var p2 = gs2.players[0]
	var t := Unit.new(_make_card("bd_u", 60, {"earth": 1}))
	_place(gs2, 0, 0, 0, t)
	gs2._resolve_support_effects(p2, db.get_card("gaia_bedrock"), t)
	_check("Bedrock grows the target", t.earth(), 3)
	_check("Bedrock growth is grown, not printed", t.earth_grown, 2)
