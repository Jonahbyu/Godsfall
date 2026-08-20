extends SceneTree

## Wilds harness — `Molt` (a one-shot full replacement on death) and
## `Ferocity N` (a per-unit stack counter fed by friendly deaths on its board).
## See wilds.md and docs/specs/2026-08-19-wilds-faction-design.md.
##
## Wilds shipped without a harness while every other faction had one, which is
## why this file exists: three unit-line ops (`self_molt`, `heal_spent_molt`,
## `ferocity_on_damage`) were added in the 2026-08-20 expansion, and an op wired
## into only one of the two effect dispatchers parses fine and silently does
## nothing — the dead-data trap this project's decision log already records
## three times. Every op below is driven through the REAL entry point
## (`use_ability`, `_deliver_attack_damage`, `_kill`) rather than simulated.
##
## Run: godot --headless --path <project> --script res://scripts/core/WildsTest.gd

## Total assertions this harness is expected to run. Checked at the end, because
## a crash mid-file produces "0 failed" and exit 0 — the assertions after the
## crash simply never run, and silence reads identically to success.
const EXPECTED_ASSERTIONS := 43

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


func _initialize() -> void:
	var db = root.get_node_or_null("CardDB")
	if db == null:
		db = load("res://scripts/core/CardDB.gd").new()
		db.name = "CardDB"
		root.add_child(db)
	if db._cards.is_empty():
		db._load()

	_test_molt_basics()
	_test_molt_replacement()
	_test_ferocity_counter()
	_test_ferocity_trigger()
	_test_ferocity_own_molt()
	_test_self_molt_op()
	_test_heal_spent_molt_op()
	_test_ferocity_on_damage_op()
	_test_granted_molt()
	_test_real_cards()

	print("%d passed, %d failed" % [_pass, _fail])
	if _pass + _fail != EXPECTED_ASSERTIONS:
		print("FAIL: expected %d assertions, ran %d" % [EXPECTED_ASSERTIONS, _pass + _fail])
		_fail += 1
	quit(1 if _fail > 0 else 0)


# ------------------------------------------------------------------ helpers

## A game already past SETUP. use_ability() and queue_attack() are both gated on
## the phase, and a fresh GameState starts in SETUP — so a harness that skips
## this silently gets "false" back from every ability and reads as ten broken ops.
func _new_game():
	var gs = load("res://scripts/core/GameState.gd").new([], [])
	gs.skip_setup()
	return gs


func _place(gs, side: int, bi: int, si: int, u: Unit) -> void:
	gs.players[side].boards[bi].slots[si] = u


func _make(id: String, hp: int, kws: Dictionary, lines: Array = [],
		stage: String = "basic") -> Unit:
	var kw_list: Array = []
	for k in kws:
		kw_list.append({"kw": k, "n": kws[k]})
	return UnitS.new(CardDataS.from_dict({
		"id": id, "name": id, "type": "unit", "faction": "wilds",
		"stage": stage, "hp": hp, "keywords": kw_list, "attacks": lines,
	}))


# ------------------------------------------------------------------ Molt

func _test_molt_basics() -> void:
	var u := _make("m1", 50, {"molt": 1})
	_ok("a printed Molt body has Molt", u.has_molt())
	_check("and has not spent it", u.lost_molt, false)

	var plain := _make("m2", 50, {})
	_ok("a body with no printed Molt has none", not plain.has_molt())


func _test_molt_replacement() -> void:
	## Molt inverts every axis of Rise at once. The four that matter most are
	## full HP, the SAME slot, retained attached energy, and the keyword spent.
	var u := _make("m3", 60, {"molt": 1})
	u.hp = 3
	u.attached = 7
	var c := u.make_molted()

	_check("the copy returns at FULL hp", c.hp, 60)
	_check("attached energy is RETAINED — the printed exception", c.attached, 7)
	_ok("the copy has spent its Molt", c.lost_molt)
	_ok("so it cannot Molt again", not c.has_molt())

	## Evolution is the one thing that restores it, which is what makes evolving
	## mechanically necessary for a Molt line rather than optional.
	var evo := CardDataS.from_dict({
		"id": "m3b", "name": "m3b", "type": "unit", "faction": "wilds",
		"stage": "stage1", "hp": 90, "keywords": [{"kw": "molt", "n": 1}],
		"attacks": [],
	})
	c.evolve_into(evo)
	_ok("evolving RESTORES Molt", c.has_molt())


# ------------------------------------------------------------------ Ferocity

func _test_ferocity_counter() -> void:
	var u := _make("f1", 50, {"ferocity": 2})
	_check("stacks start at 0", u.ferocity_stacks, 0)
	_check("the printed number is the RATE", u.ferocity_rate(), 2)

	u.add_ferocity(2)
	_check("stacks accumulate", u.ferocity_stacks, 2)
	_check("+2 max HP per stack", u.max_hp(), 54)
	_check("+1 damage per stack", u.ferocity_dmg_bonus(), 2)

	u.add_ferocity(3)
	_check("and keep accumulating", u.ferocity_stacks, 5)
	_check("HP bonus scales", u.max_hp(), 60)


func _test_ferocity_trigger() -> void:
	## The trigger is per-BOARD, matching every other per-board rule in the game
	## (shielding, Essence, targeting) — a death on your other board does not feed it.
	var gs = _new_game()
	var tracker := _make("f2", 60, {"ferocity": 2})
	var victim := _make("v1", 10, {})
	_place(gs, 0, 0, 0, tracker)
	_place(gs, 0, 0, 1, victim)

	gs._kill(gs.players[0], gs.players[0].boards[0], 1, victim)
	_check("a friendly death on this board feeds the tracker", tracker.ferocity_stacks, 2)

	## Now a death on the OTHER board, which must not count.
	var far := _make("v2", 10, {})
	_place(gs, 0, 1, 0, far)
	gs._kill(gs.players[0], gs.players[0].boards[1], 0, far)
	_check("a death on the OTHER board does not", tracker.ferocity_stacks, 2)


func _test_ferocity_own_molt() -> void:
	## Settled 2026-08-20: the trigger fires at the MOMENT OF DEATH regardless of
	## what happens to the body next, so a unit carrying both signatures feeds its
	## own counter from its own Molt. This is the deliberate combo point of the pair.
	var gs = _new_game()
	var both := _make("f3", 40, {"molt": 1, "ferocity": 1})
	_place(gs, 0, 0, 0, both)

	gs._kill(gs.players[0], gs.players[0].boards[0], 0, both)
	var back: Unit = gs.players[0].boards[0].slots[0]

	_ok("the body is still there — Molt replaced it", back != null)
	_ok("and it is a different object", back != both)
	_check("its own Molt fed its own counter", back.ferocity_stacks, 1)
	_check("stacks SURVIVE a Molt death — the printed exception", back.ferocity_stacks, 1)
	_ok("Molt is spent on the copy", back.lost_molt)

	## A tracker watching that same Molt-death is also fed by it.
	var gs2 = _new_game()
	var watcher := _make("f4", 60, {"ferocity": 3})
	var molter := _make("f5", 40, {"molt": 1})
	_place(gs2, 0, 0, 0, watcher)
	_place(gs2, 0, 0, 1, molter)
	gs2._kill(gs2.players[0], gs2.players[0].boards[0], 1, molter)
	_check("a nearby tracker is fed by a Molt-death too", watcher.ferocity_stacks, 3)


# ------------------------------------------------------------------ the new ops

func _test_self_molt_op() -> void:
	## `self_molt` routes through the SAME `_kill` path a combat death uses, which
	## is what makes it feed Ferocity exactly as a real death would. Driven through
	## the real `use_ability`, never by calling make_molted() directly.
	var gs = _new_game()
	var line := {"id": "sm", "name": "Shed", "damage": 0, "ability": true,
		"text": "", "effects": [{"op": "self_molt", "n": 1}]}
	var u := _make("s1", 50, {"molt": 1}, [line])
	var watcher := _make("s2", 60, {"ferocity": 2})
	_place(gs, 0, 0, 0, u)
	_place(gs, 0, 0, 1, watcher)
	u.hp = 5

	gs.use_ability(gs.players[0], u, u.card.ability_lines()[0], null)
	var back: Unit = gs.players[0].boards[0].slots[0]

	_ok("self_molt replaced the body", back != u)
	_check("the replacement is at full HP", back.hp, 50)
	_ok("and has spent its Molt", back.lost_molt)
	_check("it fed a nearby tracker, like any death", watcher.ferocity_stacks, 2)

	## Refused when there is nothing to spend, so it can never be a silent no-op
	## that eats the unit's once-per-turn.
	var gs2 = _new_game()
	var spent := _make("s3", 50, {}, [line])
	_place(gs2, 0, 0, 0, spent)
	gs2.use_ability(gs2.players[0], spent, spent.card.ability_lines()[0], null)
	_ok("a body with no Molt is not consumed", gs2.players[0].boards[0].slots[0] == spent)


func _test_heal_spent_molt_op() -> void:
	## Small while the reprieve is still held, double once it is gone — so the
	## ability reads the chain's own keyword instead of being a generic button.
	var gs = _new_game()
	var line := {"id": "hs", "name": "Shrug", "damage": 0, "ability": true,
		"text": "", "effects": [{"op": "heal_spent_molt", "n": 12}]}

	var fresh := _make("h1", 60, {"molt": 1}, [line])
	_place(gs, 0, 0, 0, fresh)
	fresh.hp = 10
	gs.use_ability(gs.players[0], fresh, fresh.card.ability_lines()[0], null)
	_check("heals the printed amount while Molt is held", fresh.hp, 22)

	var gs2 = _new_game()
	var used := _make("h2", 60, {"molt": 1}, [line])
	used.lost_molt = true
	_place(gs2, 0, 0, 0, used)
	used.hp = 10
	gs2.use_ability(gs2.players[0], used, used.card.ability_lines()[0], null)
	_check("heals DOUBLE once Molt is spent", used.hp, 34)


func _test_ferocity_on_damage_op() -> void:
	## The printed answer to the faction's structural weakness: a Ferocity deck
	## whose opponent refuses to trade has no other way to turn the counter on.
	## Driven through the real attack pipeline.
	var gs = _new_game()
	var atk := {"id": "fod", "name": "Slash", "damage": 20,
		"text": "", "cost": {"wilds": 2},
		"effects": [{"op": "ferocity_on_damage", "n": 1}]}
	var u := _make("d1", 50, {"ferocity": 1}, [atk])
	var enemy := _make("d2", 90, {})
	_place(gs, 0, 0, 0, u)
	_place(gs, 1, 0, 0, enemy)

	var line0: AttackData = u.card.attack_lines()[0]
	gs._resolve_line_effects(gs.players[0], gs.players[1], u, line0, null, 0, 0)
	_check("the attacker banked a stack from damage dealt", u.ferocity_stacks, 1)

	## A body with no Ferocity gains nothing — the op reads the keyword, it does
	## not grant it.
	var gs2 = _new_game()
	var plain := _make("d3", 50, {}, [atk])
	var e2 := _make("d4", 90, {})
	_place(gs2, 0, 0, 0, plain)
	_place(gs2, 1, 0, 0, e2)
	var line1: AttackData = plain.card.attack_lines()[0]
	gs2._resolve_line_effects(gs2.players[0], gs2.players[1], plain, line1, null, 0, 0)
	_check("a body without Ferocity banks nothing", plain.ferocity_stacks, 0)


func _test_granted_molt() -> void:
	## `Second Skin` grants Molt to a body that prints none. A separate field
	## because Molt is a PRESENCE keyword (has_kw), not a numeric one add_kw_mod
	## can raise — the same gap that made grant_sanctuary() necessary.
	var u := _make("g1", 50, {})
	_ok("no printed Molt to start", not u.has_molt())
	u.granted_molt = true
	_ok("granted Molt reads as Molt", u.has_molt())

	## And it must be VISIBLE. The board renderer walks the PRINTED keyword line,
	## so a granted keyword had no part to iterate over and showed nothing —
	## the spent-Judgment bug in its other direction, and it had shipped twice
	## (Second Skin's Molt, Aegis of the Choir's Sanctuary).
	## Loaded by PATH, not by class_name: under `--script` the test compiles
	## before autoloads register, and CardView.gd references the Palette
	## autoload — naming the class drags in an identifier that does not exist
	## yet and the whole compile fails. Same rule CardViewTest documents.
	var cv = load("res://scripts/ui/CardView.gd").new(u.card, u, 0)
	_ok("granted Molt appears on the board card",
		cv._live_keyword_line().to_lower().contains("molt"))
	cv.free()


# ------------------------------------------------------------------ shipped data

func _test_real_cards() -> void:
	## Checked against the SHIPPED card data rather than a fixture, so a
	## regenerated roster that breaks a rule fails here.
	var db = root.get_node("CardDB")
	var units: Array = []
	for c in db._cards.values():
		if c.faction == "wilds" and c.is_unit():
			units.append(c)

	## A census assertion, not an invariant — it exists to catch the roster
	## failing to load, not to freeze the card count.
	_ok("the Wilds roster loaded", units.size() >= 55)

	var molt := 0
	var fero := 0
	var bad_band := 0
	var bad_lines := 0
	var vanilla := 0
	for c in units:
		if c.has_kw("molt"):
			molt += 1
		if c.has_kw("ferocity"):
			fero += 1
		if c.keywords.is_empty():
			vanilla += 1
		## The two-line rule is a hard structural constraint on every card.
		if c.attacks.size() > 2:
			bad_lines += 1
		## Molt trades a smaller printed body for a guaranteed second life.
		if c.has_kw("molt"):
			var cap := {"Basic": 60, "Stage 1": 95, "Stage 2": 140}
			if c.max_hp > int(cap.get(c.stage_name(), 999)):
				bad_band += 1

	_ok("Molt is printed across the roster", molt >= 15)
	_ok("Ferocity is printed across the roster", fero >= 15)
	_check("no card breaks the two-line rule", bad_lines, 0)
	_check("no Molt body exceeds its reduced HP band", bad_band, 0)
	## Not every unit carries a signature — a faction where every card has the
	## keyword is the sameness failure the bestiary waves documented.
	_ok("some bodies print no keyword at all", vanilla > 0)

	## Ferocity N is pinned by stage, never banded.
	var want := {"Basic": 1, "Stage 1": 2, "Stage 2": 3}
	var bad_n := 0
	for c in units:
		if c.has_kw("ferocity") and c.kw("ferocity") != int(want.get(c.stage_name(), -1)):
			bad_n += 1
	_check("Ferocity N matches its stage everywhere", bad_n, 0)

	## Every effect the roster prints must be one the ENGINE handles. An unknown
	## op parses fine and silently does nothing.
	var known := ["self_molt", "heal_spent_molt", "ferocity_on_damage",
		"temp_retribution", "gain_stacks", "also_hit_tower", "heal"]
	var unknown_ops: Array = []
	for c in units:
		for a in c.attacks:
			for e in a.effects:
				var op := str(e.get("op", ""))
				if op != "" and not known.has(op) and not unknown_ops.has(op):
					unknown_ops.append(op)
	_check("no unit prints an op this harness does not know", unknown_ops, [])
