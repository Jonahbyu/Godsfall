extends SceneTree

## Total assertions this harness is expected to run; see the check at
## the end of the run. Update deliberately when assertions change.
const EXPECTED_ASSERTIONS := 69   ## +5 gap_is_relevant (2026-08-15)

## Headless Void harness:
##   godot --headless --script res://scripts/core/VoidTest.gd
##
## Covers the two Void signatures and the Gap:
##   * card data integrity and the printed damage budget
##   * Gap direction and its floor at 0
##   * Siphon MOVING energy (unit) vs. Siphon into the POOL (support)
##   * Void N destroying energy, and the damage-per-voided rider
##   * Rift scaling read at resolution, and Rift granted by a Tool
##   * the pool-destruction rule-breaker
##   * Silence Eternal converting Gap into throne damage
##   * Siphon obeying the shielding chain rather than reaching past it
##
## Like HeavenTest, the pipeline tests drive the real GameState rather than
## simulating the rules inline — a test that reimplements the rule it checks
## proves nothing about the engine.

var _pass := 0
var _fail := 0


func _initialize() -> void:
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


func _ok(label: String, cond: bool) -> void:
	_check(label, cond, true)


func _unit(db, id: String) -> Unit:
	return Unit.new(db.get_card(id))


func _game(_db):
	var gs = load("res://scripts/core/GameState.gd").new([], [])
	## Units are placed directly here; the rules API is gated on the setup phase.
	gs.skip_setup()
	return gs


func _run(db) -> void:
	print("\n=== Godsfall Void harness ===\n")
	_test_card_data(db)
	_test_damage_budget(db)
	_test_gap_basics(db)
	_test_siphon_unit(db)
	_test_siphon_support(db)
	_test_void_energy(db)
	_test_damage_per_voided(db)
	_test_rift_scaling(db)
	_test_rift_tool(db)
	_test_void_pool(db)
	_test_gap_throne(db)
	_test_siphon_shielding(db)
	_test_gap_excludes_dead(db)
	_test_gap_relevance(db)
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


# ---- the roster is present and legal
func _test_card_data(db) -> void:
	print("Void card data:")
	var units: Array = db.units_of("void")
	## Counts moved 15 -> 30 -> 60 across the two bestiary waves (2026-08-15). These are census assertions: they exist to catch a
	## card silently failing to load, not to freeze the roster size. The
	## invariants below — two-line rule, HP bands, retreat formula, damage
	## budget — are the ones that encode design rules and they did not move.
	_check("60 Void units", units.size(), 60)

	var basics := 0
	var s1 := 0
	var s2 := 0
	for c in units:
		match c.stage:
			CardData.Stage.BASIC: basics += 1
			CardData.Stage.STAGE1: s1 += 1
			CardData.Stage.STAGE2: s2 += 1
	_check("28 Basics", basics, 28)
	_check("24 Stage 1s", s1, 24)
	_check("8 Stage 2s", s2, 8)

	## Two-line rule, and the HP bands from CLAUDE.md.
	var bands := {
		CardData.Stage.BASIC: [40, 90],
		CardData.Stage.STAGE1: [80, 120],
		CardData.Stage.STAGE2: [110, 175],
	}
	var lines_ok := true
	var bands_ok := true
	var retreat_ok := true
	for c in units:
		if c.attacks.size() > 2:
			lines_ok = false
		var b: Array = bands[c.stage]
		if c.max_hp < b[0] or c.max_hp > b[1]:
			bands_ok = false
			print("    band violation: %s %d" % [c.name, c.max_hp])
		if c.retreat != int(c.max_hp / 40.0):
			retreat_ok = false
			print("    retreat violation: %s %d" % [c.name, c.retreat])
	_ok("every unit obeys the two-line rule", lines_ok)
	_ok("every unit sits inside its stage's HP band", bands_ok)
	_ok("retreat is HP / 40 on every unit", retreat_ok)

	_check("Void has an energy card", db.energy_card_of("void") != null, true)

	## Rift 2 must be a Stage 2. Rift is uncapped, so the multiplier is the only
	## thing bounding it — two points on a *cheap body* would scale past every
	## other card in the game, and it is the cheap body rather than the count
	## that the bound is actually about.
	##
	## Went 1 -> 3 -> 4 across the two bestiary waves (2026-08-15). The stage requirement is
	## what does the work and it is unchanged; both new Rift 2 cards are Stage 2s
	## printing 64 damage at cost 8, against the original's 80 at cost 10, so the
	## ceiling did not move. Watch this number: Rift 2 is the faction's most
	## dangerous printed value and three is where it should stop for now.
	var rift2: Array = []
	for c in units:
		if c.kw("rift") >= 2:
			rift2.append(c.name)
			_check("%s (Rift 2) is a Stage 2" % c.name, c.stage, CardData.Stage.STAGE2)
	_check("four Rift 2 cards", rift2.size(), 4)


# ---- printed damage sits at or under the budget
func _test_damage_budget(db) -> void:
	print("Damage budget:")
	## Void buys denial and scaling, so its raw damage sits below the standard
	## 12-per-energy curve — the same shape as Heaven's Judgment rate cut.
	##   Siphon line -> 10/e, minus 5 per Siphon point
	##   Rift line   -> 10/e, minus 8 per Rift point
	##   plain line  -> 12/e, the standard curve
	##
	## The Rift discount pays for the keyword *existing*, not for its unbounded
	## tail. It is deliberately NOT priced against a large Gap: a Void player
	## holding a 30+ Gap has staked 30 energy on bodies that all die at once, and
	## winning from there is the payoff working, not a bug.
	##
	## A cut to 11 was tried and reverted. A flat base-damage reduction is the
	## wrong lever for a scaling mechanic -- at Gap 30 it moved a Null Adept from
	## 42 to 39 damage (noise) while at Gap 0 it moved 12 to 9 (a 25% cut). It
	## taxed the early game, where Void is already weakest, and did nothing at the
	## Gaps that prompted it.
	var over: Array = []
	for c in db.units_of("void"):
		for a in c.attack_lines():
			var tc: int = a.total_cost()
			var sn: int = a.effect_value("siphon", 0)
			var rn: int = c.kw("rift")
			var budget: int
			if sn > 0:
				budget = 10 * tc - 5 * sn
			elif rn > 0:
				budget = 10 * tc - 8 * rn
			else:
				budget = 12 * tc
			if a.damage > budget:
				over.append("%s/%s %d > %d" % [c.name, a.name, a.damage, budget])
	if over.size() > 0:
		for o in over:
			print("    OVER BUDGET: %s" % o)
	_check("no Void attack exceeds its printed budget", over.size(), 0)


# ---- Gap direction and floor
func _test_gap_basics(db) -> void:
	print("The Gap:")
	var gs = _game(db)
	var p = gs.players[0]
	var e = gs.players[1]

	_check("empty boards -> Gap 0", gs.gap_for(p), 0)

	var mine := _unit(db, "null_adept")
	var theirs := _unit(db, "rust_crawler")
	p.boards[0].slots[0] = mine
	e.boards[0].slots[0] = theirs

	mine.attached = 6
	theirs.attached = 2
	_check("mine 6 vs theirs 2 -> Gap 4", gs.gap_for(p), 4)

	## The Gap is directional, and the opponent reads their own.
	_check("the same board is Gap 0 from the other side", gs.gap_for(e), 0)

	## Floors at 0 rather than going negative: a Rift card promises a bonus, so a
	## negative Gap must never quietly become a penalty.
	mine.attached = 1
	theirs.attached = 9
	_check("behind on attached -> Gap floors at 0", gs.gap_for(p), 0)
	_check("and the opponent's Gap is 8", gs.gap_for(e), 8)


# ---- Siphon on a unit MOVES energy onto that unit
func _test_siphon_unit(db) -> void:
	print("Siphon (unit line):")
	var gs = _game(db)
	var p = gs.players[0]
	var e = gs.players[1]

	var thief := _unit(db, "hollow_acolyte")     ## Draw Thin: 14 dmg, Siphon 1
	var victim := _unit(db, "rust_crawler")
	p.boards[0].slots[0] = thief
	e.boards[0].slots[0] = victim

	## Start ahead on attached so the swing is visible. The Gap floors at 0, so
	## measuring a swing from behind would read 0 -> 0 and prove nothing.
	thief.attached = 6
	victim.attached = 5

	var gap_before: int = gs.gap_for(p)
	_check("Gap starts at 1", gap_before, 1)
	gs._resolve_line_effects(p, e, thief, thief.card.attacks[0], null, 0, 0)

	_check("victim lost 1 energy", victim.attached, 4)
	_check("thief gained it", thief.attached, 7)
	_check("energy moved, none created", victim.attached + thief.attached, 11)
	_check("damage still landed", victim.hp, victim.max_hp() - thief.card.attacks[0].damage)

	## The double-swing is the whole reason Siphon feeds Rift: -1 there, +1 here.
	_check("Gap swung by 2", gs.gap_for(p) - gap_before, 2)

	## Siphon takes what is there and no more.
	victim.attached = 0
	var before: int = thief.attached
	gs._do_siphon(p, e, thief, 2, 0, 0)
	_check("siphoning an empty body takes nothing", thief.attached, before)


# ---- Siphon on a SUPPORT goes to the pool instead
func _test_siphon_support(db) -> void:
	print("Siphon (support card):")
	var gs = _game(db)
	var p = gs.players[0]
	var e = gs.players[1]

	var victim := _unit(db, "rust_crawler")
	e.boards[0].slots[0] = victim
	victim.attached = 4
	p.pool = 0
	p.hand = ["draw_down"]

	_check("Draw Down plays", gs.play_support(p, 0, victim), true)
	_check("victim lost 1", victim.attached, 3)
	_check("it landed in the POOL, not on a unit", p.pool, 1)

	## A support has no body, so its theft cannot feed the Gap — the Gap counts
	## attached energy only. This is what keeps units the centre of the faction.
	_check("support Siphon does not move the Gap", gs.gap_for(p), 0)

	## Exsanguinate is the priced variant: same effect, bigger number.
	var big := _unit(db, "hungering_maw")
	e.boards[0].slots[1] = big
	big.attached = 10
	p.hand = ["exsanguinate"]
	_check("Exsanguinate plays", gs.play_support(p, 0, big), true)
	_check("takes 3", big.attached, 7)
	_check("pool now 4", p.pool, 4)


# ---- Void N destroys rather than moves
func _test_void_energy(db) -> void:
	print("Void N (destruction):")
	var gs = _game(db)
	var p = gs.players[0]
	var e = gs.players[1]

	var u := _unit(db, "the_unwritten")     ## Blank the Page: Consume 1, Void 2
	var victim := _unit(db, "rust_crawler")
	p.boards[0].slots[0] = u
	e.boards[0].slots[0] = victim
	victim.attached = 5
	u.attached = 3

	var burned: int = gs._do_void_energy(p, e, u, 2, 0, 0)
	_check("2 energy destroyed", burned, 2)
	_check("victim is down to 3", victim.attached, 3)
	_check("the thief gained nothing — it was destroyed", u.attached, 3)

	## Unwrite, the support, takes the lot.
	p.hand = ["unwrite"]
	_check("Unwrite plays", gs.play_support(p, 0, victim), true)
	_check("all attached energy is gone", victim.attached, 0)


# ---- the rider that pays per energy destroyed
func _test_damage_per_voided(db) -> void:
	print("Damage per energy unmade:")
	var gs = _game(db)
	var p = gs.players[0]
	var e = gs.players[1]

	var u := _unit(db, "gnawing_absence")   ## Unmake: 10 dmg, Void 1, +15 per unmade
	p.boards[0].slots[0] = u

	## Against a charged body: 10 base + 15 for the one energy destroyed.
	var charged := _unit(db, "rust_crawler")
	e.boards[0].slots[0] = charged
	charged.attached = 3
	var base: int = u.card.attacks[0].damage
	var per_void: int = u.card.attacks[0].effect_value("damage_per_voided", 0)
	gs._resolve_line_effects(p, e, u, u.card.attacks[0], null, 0, 0)
	_check("charged victim takes base + the rider", charged.hp, charged.max_hp() - (base + per_void))
	_check("and loses an energy", charged.attached, 2)

	## Against an uncharged body the rider pays nothing. This is the whole reason
	## the card is fair: Void is efficient against the committed and weak against
	## an empty board.
	var bare := _unit(db, "hungering_maw")
	e.boards[0].slots[0] = bare
	bare.attached = 0
	gs._resolve_line_effects(p, e, u, u.card.attacks[0], null, 0, 0)
	_check("uncharged victim takes only the base", bare.hp, bare.max_hp() - base)


# ---- Rift scales with the Gap, read at resolution
func _test_rift_scaling(db) -> void:
	print("Rift scaling:")
	var gs = _game(db)
	var p = gs.players[0]
	var e = gs.players[1]

	var adept := _unit(db, "null_adept")    ## Rift 1, Widen: 12 damage
	var target := _unit(db, "hungering_maw")
	p.boards[0].slots[0] = adept
	e.boards[0].slots[0] = target

	## Gap 0 -> the printed number and nothing more.
	adept.attached = 0
	target.attached = 0
	gs._resolve_line_effects(p, e, adept, adept.card.attacks[0], null, 0, 0)
	var widen: int = adept.card.attacks[0].damage
	_check("Gap 0 -> printed damage only", target.hp, target.max_hp() - widen)

	## Gap 8 -> +8 at Rift 1.
	target.hp = target.max_hp()
	adept.attached = 8
	target.attached = 0
	_check("Gap is 8", gs.gap_for(p), 8)
	gs._resolve_line_effects(p, e, adept, adept.card.attacks[0], null, 0, 0)
	_check("Rift 1 at Gap 8 adds 8", target.hp, target.max_hp() - (widen + 8))

	## Rift 2 doubles it, and it is the only card that does. A fresh victim, since
	## the one above is already damaged — and its max is read before the attack so
	## the assertion cannot accidentally compare against the attacker's HP.
	## NOTE: the two ints passed to _resolve_line_effects are (board, slot), not
	## (slot, slot). Throat sits in board 0 slot 1, so it attacks board 0 slot 1.
	var throat := _unit(db, "throat_of_the_void")   ## Rift 2, Swallow: 44
	p.boards[0].slots[1] = throat
	throat.attached = 0
	var victim2 := _unit(db, "hungering_maw")
	e.boards[0].slots[1] = victim2
	var full2: int = victim2.max_hp()
	_check("Gap still 8", gs.gap_for(p), 8)
	gs._resolve_line_effects(p, e, throat, throat.card.attacks[0], null, 0, 1)
	var swallow: int = throat.card.attacks[0].damage
	_check("Rift 2 at Gap 8 adds 16", victim2.hp, full2 - (swallow + 16))


# ---- a Tool can grant Rift
func _test_rift_tool(db) -> void:
	print("Rift granted by a Tool:")
	var gs = _game(db)
	var p = gs.players[0]
	var e = gs.players[1]

	var plain := _unit(db, "rust_crawler")   ## no printed Rift
	p.boards[0].slots[0] = plain
	_check("no Rift printed", plain.has_rift(), false)

	p.hand = ["event_horizon"]
	_check("Event Horizon attaches", gs.play_support(p, 0, plain), true)
	_check("now has Rift 1", plain.rift(), 1)

	var target := _unit(db, "hungering_maw")
	e.boards[0].slots[0] = target
	plain.attached = 5
	_check("Gap is 5", gs.gap_for(p), 5)
	gs._resolve_line_effects(p, e, plain, plain.card.attacks[0], null, 0, 0)
	var corrode: int = plain.card.attacks[0].damage
	_check("Corrode + Rift 5", target.hp, target.max_hp() - (corrode + 5))


# ---- the pool-destruction rule-breaker
func _test_void_pool(db) -> void:
	print("Pool destruction (the printed exception):")
	var gs = _game(db)
	var p = gs.players[0]
	var e = gs.players[1]

	var u := _unit(db, "unmaker_of_thrones")
	p.boards[0].slots[0] = u
	u.attached = 4

	## 20% of a hoarded pool, mirroring the end-of-turn decay rule it models.
	e.pool = 30
	gs._do_void_pool(p, e, 20)
	_check("20% of 30 is 6", e.pool, 24)

	## Minimum 2, so it is never entirely blank — but against a small pool that
	## floor is most of what it does, which is the intended shape: worthless
	## early, devastating against a hoarder.
	e.pool = 5
	gs._do_void_pool(p, e, 20)
	_check("floors at 2", e.pool, 3)

	## Never takes more than is there.
	e.pool = 1
	gs._do_void_pool(p, e, 20)
	_check("cannot go negative", e.pool, 0)


# ---- Silence Eternal converts the Gap into throne damage
func _test_gap_throne(db) -> void:
	print("Gap to throne damage:")
	var gs = _game(db)
	var p = gs.players[0]
	var e = gs.players[1]

	var closer := _unit(db, "silence_eternal")
	p.boards[0].slots[0] = closer
	var throne_before: int = e.throne_hp

	## No Gap, no effect.
	closer.attached = 0
	gs._resolve_line_effects(p, e, closer, closer.card.attacks[0], null, 0, 0)
	_check("Gap 0 -> throne untouched", e.throne_hp, throne_before)

	## Gap 6 at 10 per point.
	closer.attached = 6
	_check("Gap is 6", gs.gap_for(p), 6)
	gs._resolve_line_effects(p, e, closer, closer.card.attacks[0], null, 0, 0)
	_check("60 to the throne", e.throne_hp, throne_before - 60)

	## Capped at 100 however large the Gap grows, so it can never be a one-card
	## kill on a throne that has been growing all game.
	e.throne_hp = 300
	closer.attached = 40
	gs._resolve_line_effects(p, e, closer, closer.card.attacks[0], null, 0, 0)
	_check("capped at 100", e.throne_hp, 200)


# ---- Siphon obeys shielding rather than reaching past it
func _test_siphon_shielding(db) -> void:
	print("Siphon obeys the targeting chain:")
	var gs = _game(db)
	var p = gs.players[0]
	var e = gs.players[1]

	var thief := _unit(db, "hollow_acolyte")
	p.boards[0].slots[0] = thief
	thief.attached = 0

	## Slot 0 across is empty; a charged unit sits in slot 1. Siphon must redirect
	## to the leftmost living unit, exactly as damage does — energy denial can
	## never reach somewhere an attack could not.
	var shielded := _unit(db, "rust_crawler")
	e.boards[0].slots[1] = shielded
	shielded.attached = 4
	gs._do_siphon(p, e, thief, 1, 0, 0)
	_check("redirects to the leftmost living unit", shielded.attached, 3)
	_check("thief holds the stolen energy", thief.attached, 1)

	## An empty enemy board has nothing to take from, and no structure to fall
	## through to — towers and thrones hold no attached energy.
	e.boards[0].slots[1] = null
	var before: int = thief.attached
	gs._do_siphon(p, e, thief, 2, 0, 0)
	_check("empty board -> nothing taken", thief.attached, before)


# ---- a dead body's energy is already forfeit
func _test_gap_excludes_dead(db) -> void:
	print("The Gap ignores the dead:")
	var gs = _game(db)
	var p = gs.players[0]
	var e = gs.players[1]

	var mine := _unit(db, "null_adept")
	var theirs := _unit(db, "rust_crawler")
	p.boards[0].slots[0] = mine
	e.boards[0].slots[0] = theirs
	mine.attached = 10
	theirs.attached = 4
	_check("Gap is 6", gs.gap_for(p), 6)

	## Within a volley a unit marked dead stays on the board so it can still deal
	## Retribution — but its attached energy is already lost, so counting it would
	## let a corpse inflate the Gap for the rest of the resolution.
	theirs.hp = 0
	_check("their corpse stops subtracting", gs.gap_for(p), 10)
	mine.hp = 0
	_check("and mine stops adding", gs.gap_for(p), 0)


# ---- the Gap readout is conditional on Void being in the game
#
# These are INVARIANT assertions, not a census: they check the *property* that a
# Void card anywhere makes the Gap relevant and its absence makes it irrelevant,
# so they stay correct as the roster changes. The Void card id is looked up from
# CardDB rather than hardcoded for the same reason — a hardcoded id would break on
# a roster change while proving nothing about the rule.
func _test_gap_relevance(db) -> void:
	print("
Gap relevance:")

	## Any Void card and any non-Void one, taken from the data.
	var void_id := ""
	var plain_id := ""
	for cid in db.all_ids():
		## Deliberately untyped. A `: CardData` annotation here forces the compiler
		## to resolve the CardDB autoload at compile time, which is not available
		## under `--script` and fails the whole file — the trap CLAUDE.md records
		## for CardViewTest. Every other CardData use in this harness is a bare
		## constant lookup, which is why the file gets away with those.
		var c = db.get_card(cid)
		if c == null:
			continue
		if void_id == "" and c.faction == "void":
			void_id = cid
		elif plain_id == "" and c.faction != "void":
			plain_id = cid
		if void_id != "" and plain_id != "":
			break
	_ok("found a Void card and a non-Void card to test with",
		void_id != "" and plain_id != "")
	if void_id == "" or plain_id == "":
		return

	## Players are reached by bare index, never as `GameState.P1`. Naming the
	## GameState class here would force it to compile eagerly, and its own typed
	## `var card: CardData = CardDB...` lines then fail to resolve the autoload
	## under `--script` — taking the whole harness down. Every other test in this
	## file uses [0]/[1] for the same reason.
	var you := 0
	var foe := 1

	## No Void card anywhere.
	var gs = _game(db)
	gs.players[you].deck = [plain_id, plain_id]
	gs.players[foe].deck = [plain_id]
	_check("no Void card anywhere is not relevant", gs.gap_is_relevant(), false)

	## In YOUR deck.
	gs.players[you].deck = [plain_id, void_id]
	_check("a Void card in your deck is relevant", gs.gap_is_relevant(), true)

	## In THEIR deck. Their Rift unit reads their Gap against you, so an
	## opponent's Void deck makes the number just as load-bearing as your own.
	gs.players[you].deck = [plain_id]
	gs.players[foe].deck = [void_id]
	_check("a Void card in their deck is relevant", gs.gap_is_relevant(), true)

	## In hand — the readout must not wait for the card to be played.
	gs.players[foe].deck = [plain_id]
	gs.players[you].hand = [void_id]
	_check("a Void card in hand is relevant", gs.gap_is_relevant(), true)
