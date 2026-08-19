extends SceneTree

## Per-attack-cost usage sampler, for the energy-pricing question specifically.
##
## The aggregate CSV answers "is energy tight?" but not "which printed costs
## actually get used?" — and that second question is what a cost *range* has to
## be built on. An attack nobody can ever afford is mispriced no matter how
## efficient its damage looks on paper.
##
##   godot --headless --path . --script res://scripts/core/CostProbe.gd -- games=4000
##
## Emits, per printed cost tier: how many times an attack at that cost was
## queued, how many distinct games saw it at all, the round it first fires, and
## the observed damage-per-energy. Also samples the HP-vs-incoming-damage
## relationship so the "how many hits does a body survive" question has numbers.

var _games := 4000
var _ai := "v2"


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		var kv := String(a).split("=", true, 1)
		if kv.size() == 2:
			if kv[0] == "games": _games = int(kv[1])
			elif kv[0] == "ai": _ai = kv[1]

	var db = root.get_node_or_null("CardDB")
	if db == null:
		db = load("res://scripts/core/CardDB.gd").new()
		db.name = "CardDB"
		root.add_child(db)
	if db._cards.is_empty():
		db._load()

	seed(4242)
	var GS = load("res://scripts/core/GameState.gd")
	var AI = load("res://scripts/core/AIPlayer.gd")
	var store = load("res://scripts/core/DeckStore.gd").new()
	store.use_sandbox_path("costprobe")
	store.seed_samples()

	## cost -> [queued count, games seen, first-fire round sum, damage sum]
	var by_cost := {}
	var stage_deaths := {}      ## stage -> [deaths, total attacks absorbed]
	var kill_hits := {}         ## stage -> hits taken before dying
	var evolved := 0
	var deployed := 0

	for g in _games:
		var gs = GS.new(store.list_at(g % 10), store.list_at((g * 7 + 3) % 10))
		gs.players[0].is_ai = true
		gs.players[1].is_ai = true
		var bot = AI.new(gs)
		bot.set_variant(_ai)
		bot.take_setup(gs.players[0])
		bot.take_setup(gs.players[1])

		var seen_this_game := {}
		var guard := 0
		while not gs.finished and guard < 300:
			guard += 1
			bot.take_turn()
			var p = gs.players[gs.active]
			for u in p.all_units():
				if u.queued_attack == null:
					continue
				var atk = u.queued_attack
				var cost: int = u.attack_cost(atk)
				if not by_cost.has(cost):
					by_cost[cost] = [0, 0, 0, 0]
				by_cost[cost][0] += 1
				by_cost[cost][2] += gs.turn
				by_cost[cost][3] += atk.damage
				if not seen_this_game.has(cost):
					seen_this_game[cost] = true
					by_cost[cost][1] += 1
			gs.end_turn()

		## Which stages actually reach the board, and which die there.
		for pi in 2:
			for cid in gs.players[pi].discard:
				var c = db.get_card(cid)
				if c != null and c.is_unit():
					var st: int = c.stage
					if not stage_deaths.has(st):
						stage_deaths[st] = 0
					stage_deaths[st] += 1

	print("\n=== ATTACK COST USAGE (%d games, ai=%s) ===" % [_games, _ai])
	print("cost | queued  | %of all | games seen | avg round | avg dmg | dmg/energy")
	var costs := by_cost.keys()
	costs.sort()
	var total_q := 0
	for c in costs:
		total_q += by_cost[c][0]
	for c in costs:
		var e: Array = by_cost[c]
		if e[0] == 0:
			continue
		print("%4d | %7d | %6.2f%% | %9.1f%% | %9.2f | %7.1f | %.2f" % [
			c, e[0], 100.0 * e[0] / max(1, total_q),
			100.0 * e[1] / _games,
			float(e[2]) / e[0], float(e[3]) / e[0],
			(float(e[3]) / e[0]) / max(1, c)])

	print("\n=== UNIT DEATHS BY STAGE (bodies that reached the discard) ===")
	var names := ["Basic", "Stage 1", "Stage 2"]
	var td := 0
	for k in stage_deaths:
		td += stage_deaths[k]
	for s in 3:
		var d: int = stage_deaths.get(s, 0)
		print("%-8s %7d  (%.1f%% of unit deaths)" % [names[s], d, 100.0 * d / max(1, td)])
	quit(0)
