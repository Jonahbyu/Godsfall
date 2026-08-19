extends SceneTree

## Mass AI-vs-AI balance sampler. NOT a test harness — it asserts nothing and
## never fails. It plays many games and emits one CSV row per game plus a set of
## aggregate tables, so the balance numbers in the design docs can be read off a
## sample instead of off a single console scroll.
##
##   godot --headless --path . --script res://scripts/core/BalanceSim.gd -- \
##       games=10000 out=logs/sim/shard0.csv seed=1 [ai=v2] [pairs=all]
##
## Why this is separate from `RulesTest`'s single AI game:
##   - `BattleLog` is human-readable prose appended per game. At 100k games that
##     is a gigabyte of text nobody can aggregate. This writes CSV.
##   - The rules harnesses assert; a sampler that fails on a stall would hide the
##     stall rate, which is one of the numbers actually being measured.
##
## Every metric here is chosen to answer one of the three questions in the brief:
## energy cost balance, HP balance, damage balance. See `_row()` for what each
## column is for.

const GUARD := 300               ## rounds before a game is declared stalled

var _games := 10000
var _out := "logs/sim/sim.csv"
var _seed := 1
var _ai_variant := "v1"
var _pair_mode := "all"          ## "all" = every ordered deck pairing, "random"

var _rows: PackedStringArray = []


func _initialize() -> void:
	_parse_args()

	var db = root.get_node_or_null("CardDB")
	if db == null:
		db = load("res://scripts/core/CardDB.gd").new()
		db.name = "CardDB"
		root.add_child(db)
	if db._cards.is_empty():
		db._load()

	seed(_seed)

	var GS = load("res://scripts/core/GameState.gd")
	var AI = load("res://scripts/core/AIPlayer.gd")
	var store = load("res://scripts/core/DeckStore.gd").new()
	## Sandboxed: a sampler must never touch the player's real collection.
	store.use_sandbox_path("balancesim_%d" % _seed)
	store.seed_samples()

	var legal: Array[int] = []
	for i in store.deck_count():
		if store.is_legal_at(i):
			legal.append(i)

	var t0 := Time.get_ticks_msec()
	for g in _games:
		var pair := _pick_pair(legal, g)
		_play_one(GS, AI, store, pair[0], pair[1], g)

	var dt := Time.get_ticks_msec() - t0
	_write()
	print("BalanceSim: %d games, %d ms (%.2f ms/game) -> %s" % [
		_games, dt, float(dt) / max(1, _games), _out])
	quit(0)


func _parse_args() -> void:
	for a in OS.get_cmdline_user_args():
		var kv := String(a).split("=", true, 1)
		if kv.size() != 2:
			continue
		match kv[0]:
			"games": _games = int(kv[1])
			"out": _out = kv[1]
			"seed": _seed = int(kv[1])
			"ai": _ai_variant = kv[1]
			"pairs": _pair_mode = kv[1]


## Round-robin over every ordered pairing rather than uniform random.
##
## Uniform random leaves each of the 100 ordered pairings with a Poisson count,
## so a matchup table read off it carries sampling noise that has nothing to do
## with the decks. Cycling deterministically gives every pairing exactly the same
## number of games, which is what makes the win-rate matrix comparable cell to
## cell. Seating is part of the pairing (i vs j and j vs i are both played), so
## the first-player question in Open Questions can be read straight off it.
func _pick_pair(legal: Array[int], g: int) -> Array:
	if _pair_mode == "random":
		return [legal[randi() % legal.size()], legal[randi() % legal.size()]]
	var n := legal.size()
	var idx := g % (n * n)
	return [legal[idx / n], legal[idx % n]]


func _play_one(GS, AI, store, a: int, b: int, game_index: int) -> void:
	var gs = GS.new(store.list_at(a), store.list_at(b))
	gs.deck_names = [store.name_at(a), store.name_at(b)]
	## Both seats are AI-driven. P2 already defaults to is_ai; P1 is the "You"
	## seat and has to be flagged, or its turns are silently no-ops.
	gs.players[0].is_ai = true
	gs.players[1].is_ai = true

	## One bot per seat, so the two seats can run different heuristic variants.
	## `ai=v1xv2` pits v1 as P1 against v2 as P2, which is the only way to read
	## whether a heuristic change is an improvement rather than merely a
	## difference — aggregate economy stats can move without the AI playing better.
	var va := _ai_variant
	var vb := _ai_variant
	if _ai_variant.find("x") > 0:
		var parts := _ai_variant.split("x", true, 1)
		va = parts[0]
		vb = parts[1]

	var bot_a = AI.new(gs)
	var bot_b = AI.new(gs)
	if bot_a.has_method("set_variant"):
		bot_a.set_variant(va)
		bot_b.set_variant(vb)

	bot_a.take_setup(gs.players[0])
	bot_b.take_setup(gs.players[1])

	## Per-game economy accumulators. Sampled once per round per player, because
	## the questions being asked ("is energy tight?", "does damage keep up with
	## HP?") are about the typical board state, not the final one.
	var pool_sum := [0, 0]
	var attached_sum := [0, 0]
	var units_sum := [0, 0]
	var samples := 0
	var pool_peak := [0, 0]
	var idle_energy := [0, 0]     ## rounds ending with pool >= 4 and no attack queued
	var queued_total := [0, 0]
	var unaffordable := [0, 0]    ## affordable-attack-less unit-turns

	var guard := 0
	while not gs.finished and guard < GUARD:
		guard += 1
		## Drive whichever seat is active with that seat's own heuristics.
		if gs.active == 0:
			bot_a.take_turn()
		else:
			bot_b.take_turn()

		var act: int = gs.active
		var p = gs.players[act]
		pool_sum[act] += p.pool
		pool_peak[act] = max(pool_peak[act], p.pool)
		var att := 0
		var qn := 0
		var un := 0
		var cant := 0
		for u in p.all_units():
			att += u.attached
			un += 1
			if u.queued_attack != null:
				qn += 1
			else:
				cant += 1
		attached_sum[act] += att
		units_sum[act] += un
		queued_total[act] += qn
		unaffordable[act] += cant
		if p.pool >= 4 and qn == 0:
			idle_energy[act] += 1
		if act == 0:
			samples += 1

		gs.end_turn()

	_rows.append(_row(gs, store, a, b, guard, samples, pool_sum, attached_sum,
		units_sum, pool_peak, idle_energy, queued_total, unaffordable, game_index))


## One CSV row per game. Column choices, and what each is for:
##
##   winner/rounds        - the headline: who wins, how fast, and seat effects
##   stalled              - the rate the docs' stall worry actually occurs at
##   throne/tower HP      - how close the loss was, and whether structures held
##   *_dmg_unit/tower/throne - where damage went; the damage-vs-HP question
##   pool_avg/attached_avg   - is energy tight or abundant (energy cost balance)
##   idle_rounds          - rounds with energy banked and nothing queued: the
##                          direct signal that attacks are priced too high
##   unaffordable_share   - unit-turns with no queued attack: same question from
##                          the unit's side rather than the pool's
func _row(gs, store, a: int, b: int, guard: int, samples: int,
		pool_sum: Array, attached_sum: Array, units_sum: Array, pool_peak: Array,
		idle_energy: Array, queued_total: Array, unaffordable: Array,
		game_index: int) -> String:
	var stalled: bool = not gs.finished
	var p0 = gs.players[0]
	var p1 = gs.players[1]

	var d0: Dictionary = gs.damage_by_card[0]
	var d1: Dictionary = gs.damage_by_card[1]

	var f := PackedStringArray()
	f.append(str(game_index))
	f.append(store.name_at(a))
	f.append(store.name_at(b))
	f.append("-1" if stalled else str(gs.winner))
	f.append(str(gs.turn))
	f.append("1" if stalled else "0")
	f.append(str(p0.throne_hp)); f.append(str(p0.throne_max_hp))
	f.append(str(p1.throne_hp)); f.append(str(p1.throne_max_hp))
	f.append(str(p0.boards[0].tower_hp)); f.append(str(p0.boards[1].tower_hp))
	f.append(str(p1.boards[0].tower_hp)); f.append(str(p1.boards[1].tower_hp))
	f.append(str(gs.tower_damage_dealt[0])); f.append(str(gs.tower_damage_dealt[1]))
	f.append(str(_sum_kind(d0, "unit"))); f.append(str(_sum_kind(d0, "tower")))
	f.append(str(_sum_kind(d0, "throne")))
	f.append(str(_sum_kind(d1, "unit"))); f.append(str(_sum_kind(d1, "tower")))
	f.append(str(_sum_kind(d1, "throne")))
	var s: float = max(1.0, float(samples))
	f.append("%.2f" % (float(pool_sum[0]) / s))
	f.append("%.2f" % (float(pool_sum[1]) / s))
	f.append("%.2f" % (float(attached_sum[0]) / s))
	f.append("%.2f" % (float(attached_sum[1]) / s))
	f.append("%.2f" % (float(units_sum[0]) / s))
	f.append("%.2f" % (float(units_sum[1]) / s))
	f.append(str(pool_peak[0])); f.append(str(pool_peak[1]))
	f.append(str(idle_energy[0])); f.append(str(idle_energy[1]))
	f.append(str(queued_total[0])); f.append(str(queued_total[1]))
	f.append(str(unaffordable[0])); f.append(str(unaffordable[1]))
	return "|".join(f)


const HEADER := "game|deck_p1|deck_p2|winner|rounds|stalled|p0_throne|p0_throne_max|p1_throne|p1_throne_max|p0_tower0|p0_tower1|p1_tower0|p1_tower1|p0_towerfire|p1_towerfire|p0_dmg_unit|p0_dmg_tower|p0_dmg_throne|p1_dmg_unit|p1_dmg_tower|p1_dmg_throne|p0_pool_avg|p1_pool_avg|p0_att_avg|p1_att_avg|p0_units_avg|p1_units_avg|p0_pool_peak|p1_pool_peak|p0_idle|p1_idle|p0_queued|p1_queued|p0_unaff|p1_unaff"


func _sum_kind(d: Dictionary, kind: String) -> int:
	var t := 0
	for card_id in d:
		t += int(d[card_id].get(kind, 0))
	return t


func _write() -> void:
	var path := _out
	if path.begins_with("res://") or not path.begins_with("/"):
		path = ProjectSettings.globalize_path("res://" + path) if not path.begins_with("res://") \
			else ProjectSettings.globalize_path(path)
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		push_error("BalanceSim: cannot write %s" % path)
		return
	f.store_line(HEADER)
	for r in _rows:
		f.store_line(r)
	f.close()
