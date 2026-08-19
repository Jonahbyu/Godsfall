class_name AIPlayer
extends RefCounted

## A deliberately simple opponent. Heuristics only — enough to pressure the
## player and exercise the energy economy, not enough to be good.
##
## Priority: play energy -> evolve -> deploy -> supports -> abilities -> queue
## attacks (cheapest first, favouring kills) -> charge leftovers into the biggest
## body.
##
## Abilities run before attacks because they resolve immediately: Consume the
## Fallen can move energy onto a body that then affords a bigger attack in the
## same turn.

var gs: GameState

## Heuristic generation. "v1" is the original behaviour, preserved byte-for-byte
## so balance samples taken before this change remain comparable; "v2" adds
## saving-toward-attacks, focus fire, and volley ordering.
##
## The variant exists because the AI is the measuring instrument for every
## balance number in the design docs. Changing it silently would invalidate the
## existing readings without anyone noticing which ones.
var variant: String = "v1"


func _init(state: GameState) -> void:
	gs = state


func set_variant(v: String) -> void:
	variant = v


func _v2() -> bool:
	return variant == "v2"


## Setup: mulligan if the opening hand is unplayable, then put Basics down.
##
## Takes the player explicitly rather than reading `gs.me()`, because setup is not
## turn-based — both sides commit their board independently, and the AI may run its
## setup while `active` still points at the human.
func take_setup(p: Player) -> void:
	if not p.is_ai or not gs.in_setup():
		return

	if _should_mulligan(p):
		gs.mulligan(p)

	_deploy(p)
	gs.finish_setup(p)


## Mulligan on an opening hand that cannot function, not on one that is merely
## mediocre — a second hand is a fresh roll, not a better one, so the bar is
## "this hand loses the early game by itself".
##
## Two conditions, both about the first few turns rather than the whole deck:
##   - no energy card at all, so the pool never starts and no attack is ever queued
##   - only one Basic, which is a board that a single trade empties
##
## The guaranteed-Basic deal means "no units whatsoever" cannot occur, so the
## unplayable-hand case a mulligan classically exists for is already gone. What is
## left is the hand that functions but starts too slowly.
func _should_mulligan(p: Player) -> bool:
	var basics := 0
	var energy := 0
	for id in p.hand:
		var c: CardData = CardDB.get_card(id)
		if c == null:
			continue
		if c.is_unit():
			if c.stage == CardData.Stage.BASIC:
				basics += 1
		elif not c.is_support_like():
			energy += 1
	return energy == 0 or basics <= 1


func take_turn() -> void:
	var p: Player = gs.me()
	if not p.is_ai:
		return

	_play_energy(p)
	_evolve(p)
	_deploy(p)
	_play_supports(p)
	_use_abilities(p)
	_queue_attacks(p)
	_dump_leftover_energy(p)


## Activated abilities. They are free (or burn attached energy), resolve on the
## spot, and are capped at once per turn per unit, so there is no cost to weigh —
## the only judgement is whether a Consume is worth the energy it destroys.
func _use_abilities(p: Player) -> void:
	for unit_any in p.all_units():
		var u: Unit = unit_any
		for ab in u.card.ability_lines():
			if not u.can_use_ability(ab):
				continue
			if not _ability_worth_it(p, u, ab):
				continue
			gs.use_ability(p, u, ab)


## Whether Stoking is worth the HP right now.
##
## Three things have to be true, and the first is the one a naive "free abilities
## are always taken" rule gets wrong: **Stoke pays nothing by itself.** It sets a
## flag that a LATER line reads, so stoking on a body with no payoff is pure
## self-harm.
func _stoke_worth_it(p: Player, u: Unit, ab: AttackData) -> bool:
	## 1. Something on this unit has to actually read the flag. The flag is
	##    per-unit, so another unit's payoff is no reason to burn this one.
	var has_payoff := false
	for ln in u.card.attacks:
		if ln == ab:
			continue
		for e in ln.effects:
			if String(e.get("op", "")).begins_with("stoked_"):
				has_payoff = true
				break

	## The expansion put several payoffs on the STOKE LINE ITSELF rather than on
	## a later attack — draw, the decay skip, the extra attack slot, the second
	## Stoke, the discount. Those pay out the moment the ability resolves, so the
	## loop above (which deliberately skips `ab`) cannot see them and the AI would
	## refuse to use a card whose whole point is the ability. `stoked_heal_back`
	## is NOT in this list: it refunds the cost and pays nothing on its own, which
	## is exactly the no-op case rule 1 exists to catch.
	if not has_payoff:
		for op in ["stoked_draw", "stoked_no_decay", "stoked_extra_attack",
				"stoked_twice", "stoked_cost_reduction", "stoked_cleave"]:
			if ab.has_effect(op):
				has_payoff = true
				break
	## A self-refunding Stoke (heal-back) is worth taking on its own terms only
	## when something else reads the flag — otherwise it is a no-op that costs a
	## once-per-turn activation.
	if not has_payoff:
		return false

	## 2. Survive it. The AI does not model racing, so it never stokes itself to
	##    death — a body that dies to its own cost has bought nothing unless the
	##    payoff already resolved, which it has not at this point in the turn.
	var refunds: bool = ab.has_effect("stoked_heal_back")
	if not refunds and u.hp <= ab.stoke:
		return false

	## 3. Do not stoke a body already too hurt to take a hit afterwards. Half the
	##    printed max is a rough line, and it is skipped when the cost refunds.
	if not refunds and u.hp - ab.stoke < u.max_hp() / 4:
		return false
	return true


## Free abilities are always taken. A Consume has to justify the energy it
## destroys, so it is only used when there is something to gain.
func _ability_worth_it(p: Player, u: Unit, ab: AttackData) -> bool:
	## Checked ahead of the free/Consume split, because a Siphon or Void ability
	## with nothing to take is a wasted activation whether or not it charges —
	## once per turn per unit is itself a cost.
	if ab.has_effect("siphon") or ab.has_effect("void_energy"):
		var foe_energy: Player = gs.opponent_of(gs.active)
		for other in foe_energy.all_units():
			if other.is_alive() and other.attached > 0:
				return true
		return false

	## ------------------------------------------------------------ Forge
	##
	## Stoke and Scrap are FREE in the pool sense but expensive in HP and bodies,
	## so the "free abilities are always taken" default is actively harmful here:
	## it would burn the board down every turn whether or not a payoff follows.
	## These checks run ahead of the free/Consume split for the same reason the
	## Siphon one does — once per turn per unit is itself a cost.
	if ab.stoke > 0:
		return _stoke_worth_it(p, u, ab)
	if ab.scrap:
		## Never scrap the last body: a thin board is a board whose tower is
		## about to be exposed, and shielding is what keeps a structure alive.
		var living := 0
		for other in p.all_units():
			if other.is_alive():
				living += 1
		if living <= 2:
			return false
		return _stoke_worth_it(p, u, ab) if ab.stoke > 0 else true

	if ab.consume <= 0:
		## Consume the Fallen destroys a friendly body — only worth it when
		## another unit is actually holding energy to rescue.
		if ab.has_effect("devour_friendly"):
			for other in p.all_units():
				if other != u and other.attached > 0:
					return true
			return false
		return true

	## Dirge doubles end-of-turn effects — pointless without a Decay unit out.
	if ab.has_effect("eot_multiplier"):
		for other in p.all_units():
			if other.decay() > 0:
				return true
		return false

	## Claim the Fallen needs both a body in the discard and a slot to put it in.
	if ab.has_effect("reanimate"):
		return p.empty_slots_total() > 0 and gs._last_unit_in_discard(p) >= 0

	## Pool destruction is percentage-based with a floor, so it is only worth a
	## Consume once the opponent has actually banked something. Against a spent
	## pool it takes the minimum and wastes the charge.
	if ab.has_effect("void_pool_pct"):
		return gs.opponent_of(gs.active).pool >= 8

	return true


func _play_energy(p: Player) -> void:
	for i in p.hand.size():
		var c: CardData = CardDB.get_card(p.hand[i])
		if c != null and c.is_energy():
			gs.play_energy(p, i)
			return


func _evolve(p: Player) -> void:
	## Evolve anything we can — evolution is a free board upgrade.
	var changed := true
	while changed:
		changed = false
		for i in p.hand.size():
			var c: CardData = CardDB.get_card(p.hand[i])
			if c == null or not c.is_unit() or c.evolves_from == "":
				continue
			if p.is_locked(c.id):
				continue
			for u in p.all_units():
				if u.card.id == c.evolves_from:
					gs.evolve(p, i, u)
					changed = true
					break
			if changed:
				break


func _deploy(p: Player) -> void:
	## Fill empty slots with the biggest basic in hand.
	var guard := 0
	while guard < 10:
		guard += 1
		var slot_info := _best_empty_slot(p)
		if slot_info[0] < 0:
			return
		var best_i := -1
		var best_hp := -1
		for i in p.hand.size():
			var c: CardData = CardDB.get_card(p.hand[i])
			if c == null or not c.is_unit() or c.stage != CardData.Stage.BASIC:
				continue
			if p.is_locked(c.id):
				continue
			if c.max_hp > best_hp:
				best_hp = c.max_hp
				best_i = i
		if best_i < 0:
			return
		gs.play_unit(p, best_i, slot_info[0], slot_info[1])


func _best_empty_slot(p: Player) -> Array:
	## Prefer the slot facing an enemy unit, so attacks connect.
	##
	## The opponent is derived from `p` rather than from `gs.active`: during setup
	## both players place independently, so the AI can be deploying while `active`
	## still points at the human, and reading `active` there would have the AI
	## comparing its own board against itself.
	var enemy: Player = gs.players[1] if p == gs.players[0] else gs.players[0]
	var fallback := [-1, -1]
	for bi in p.boards.size():
		var b: Board = p.boards[bi]
		for si in b.usable_slots():
			if b.slots[si] != null:
				continue
			var across: Unit = enemy.boards[bi].unit_at(si)
			if across != null:
				return [bi, si]
			if fallback[0] < 0:
				fallback = [bi, si]
	return fallback


# ---------------------------------------------------------------- supports

## Supports are free and unlimited, so the AI plays anything it can use well.
## The ordering below is a priority list, not a solver — it exists so AI decks
## containing supports still exercise the rules rather than sitting on dead cards.
func _play_supports(p: Player) -> void:
	var guard := 0
	while guard < 12:
		guard += 1
		var choice := _best_support(p)
		if choice.is_empty():
			return
		if not gs.play_support(p, choice["index"], choice["target"]):
			return


## Returns { index, target } for the best support to play now, or {} for none.
func _best_support(p: Player) -> Dictionary:
	var best: Dictionary = {}
	var best_score := 0.0

	for i in p.hand.size():
		var c: CardData = CardDB.get_card(p.hand[i])
		if c == null or not c.is_support_like() or p.is_locked(c.id):
			continue
		var pick := _score_support(p, c)
		if pick.is_empty() or pick["score"] <= best_score:
			continue
		best_score = pick["score"]
		best = { "index": i, "target": pick["target"] }

	return best


## Higher is better. Cards the AI has no good use for score 0 and are held.
func _score_support(p: Player, c: CardData) -> Dictionary:
	var foe_p: Player = gs.opponent_of(gs.active)

	## ---- Tools: bet on the healthiest body, since Tools only pay while it lives.
	if c.is_tool():
		var owner: Player = foe_p if c.has_effect("attach_enemy") else p
		var best: Unit = null
		for u in owner.all_units():
			if u.is_alive() and not u.has_tool() and (best == null or u.hp > best.hp):
				best = u
		if best == null:
			return {}
		return { "score": 3.0, "target": best }

	## ---- tower support: only while a tower is alive to carry it.
	if c.is_tower_support():
		for bi in p.boards.size():
			if not gs.can_play_support(p, c, bi):
				continue
			## Don't blow up your own tower unless the slot is genuinely wanted.
			if c.has_effect("destroy_own_tower"):
				if p.empty_slots_total() > 0:
					continue
				return { "score": 2.0, "target": bi }
			## Only repair a tower that has actually taken damage.
			if c.has_effect("tower_heal"):
				var b: Board = p.boards[bi]
				if b.tower_hp >= b.tower_max_hp:
					continue
				return { "score": 5.0, "target": bi }
			return { "score": 4.0, "target": bi }
		return {}

	## ---- one-shots that need no target
	if c.has_effect("draw") or c.has_effect("dig_take") or c.has_effect("discard_then_draw"):
		## Don't draw into the hand limit.
		return { "score": 8.0, "target": null } if p.hand.size() <= Player.MAX_HAND - 2 else {}

	if c.has_effect("shuffle_hand_draw_plus"):
		return { "score": 1.0, "target": null } if p.hand.size() <= 3 else {}

	if c.has_effect("search_basic"):
		return { "score": 7.0, "target": null } if p.empty_slots_total() > 0 else {}

	if c.has_effect("search_random_evolved") or c.has_effect("search_any_to_top") \
		or c.has_effect("random_from_discard") or c.has_effect("dig_for_tower_support"):
		return { "score": 6.0, "target": null }

	if c.has_effect("gain_energy"):
		return { "score": 7.5, "target": null }

	if c.has_effect("gain_per_death"):
		return { "score": 9.0, "target": null } if p.units_died_this_turn > 0 else {}

	if c.has_effect("clear_locks"):
		return { "score": 1.0, "target": null } if not p.locked.is_empty() else {}

	## ---- targeted one-shots: take the best legal target the engine offers.
	var candidates: Array = gs._support_unit_candidates(p, c)
	if candidates.is_empty():
		return {}

	if c.has_effect("damage_uncharged"):
		## Prefer a target it actually kills.
		var n := c.effect_value("damage_uncharged", 0)
		for u in candidates:
			if u.hp <= n:
				return { "score": 12.0, "target": u }
		return { "score": 5.0, "target": candidates[0] }

	## ---- Void: theft and destruction both want the *most charged* enemy body.
	##
	## Taking 1 off a unit holding 8 denies far more than emptying one holding 1,
	## and the biggest stack is also the one most likely to be feeding an
	## expensive attack. The candidate lists are already filtered to units that
	## hold energy, so this only ever ranks live options.
	if c.has_effect("siphon_support") or c.has_effect("void_all"):
		var richest: Unit = null
		for u in candidates:
			if richest == null or u.attached > richest.attached:
				richest = u
		if richest == null or richest.attached <= 0:
			return {}
		## Unwrite destroys everything, so its value scales with the whole stack;
		## Siphon caps at what it can carry. Score accordingly rather than
		## treating "deny 1" and "deny 8" as the same play.
		var denied: float
		if c.has_effect("void_all"):
			denied = float(richest.attached)
		else:
			denied = float(min(c.effect_value("siphon_support", 1), richest.attached))
		return { "score": 4.0 + denied, "target": richest }

	## Gap damage is reach, so it is worth playing only when the Gap is real, and
	## it is worth most when it finishes something.
	if c.has_effect("gap_damage"):
		var amt: int = min(
			c.effect_value("gap_damage_max", 30),
			c.effect_value("gap_damage", 0) * gs.gap_for(p))
		if amt <= 0:
			return {}
		for u in candidates:
			if u.hp <= amt:
				return { "score": 13.0, "target": u }
		return { "score": 2.0 + amt / 10.0, "target": candidates[0] }

	if c.has_effect("destroy_energy"):
		var richest: Unit = null
		for u in candidates:
			if richest == null or u.attached > richest.attached:
				richest = u
		return { "score": 6.0, "target": richest }

	if c.has_effect("damage_tower"):
		for bi in foe_p.boards.size():
			if foe_p.boards[bi].tower_alive():
				return { "score": 7.0, "target": bi }
		return {}

	if c.has_effect("heal") or c.has_effect("heal_conditional") \
			or c.has_effect("heal_undo_decay") or c.has_effect("heal_per_round"):
		## Heal the most-damaged unit, and only if it's actually hurt.
		var hurt: Unit = null
		for u in candidates:
			if hurt == null or (u.max_hp() - u.hp) > (hurt.max_hp() - hurt.hp):
				hurt = u
		if hurt == null or hurt.hp >= hurt.max_hp():
			return {}
		return { "score": 6.0, "target": hurt }

	if c.has_effect("heal_all"):
		for u in p.all_units():
			if u.hp < u.max_hp():
				return { "score": 5.0, "target": null }
		return {}

	if c.has_effect("protect"):
		var weakest: Unit = null
		for u in candidates:
			if weakest == null or u.hp < weakest.hp:
				weakest = u
		return { "score": 4.0, "target": weakest }

	## Gaia: growing Earth buffs every unit AND both towers, so it is worth more
	## the more board there is to buff. Put it on the unit most likely to live —
	## grown Earth dies with its holder, so the toughest body is the safest bank.
	if c.has_effect("grow_earth_target"):
		var toughest: Unit = null
		for u in candidates:
			if toughest == null or u.hp > toughest.hp:
				toughest = u
		if toughest == null:
			return {}
		## Scales with board size: +1 Earth on a full board is six stat lines.
		var board_size: int = p.all_units().size()
		return { "score": 4.0 + float(board_size), "target": toughest }

	## Retreat and repositioning are board decisions this AI isn't equipped to
	## make well; leaving them unplayed is better than playing them badly.
	return {}


func _queue_attacks(p: Player) -> void:
	var enemy: Player = gs.opponent_of(gs.active)

	## Cheapest affordable attack first, so we get the most activations per turn.
	var candidates: Array = []
	for bi in p.boards.size():
		var b: Board = p.boards[bi]
		for si in Board.SLOT_COUNT:
			var u: Unit = b.slots[si]
			if u == null or not u.is_alive():
				continue
			## Abilities are not queued — they resolve immediately, so they are
			## handled by _use_abilities() rather than scored against attacks.
			for atk in u.card.attack_lines():
				candidates.append({ "u": u, "atk": atk, "bi": bi, "si": si })

	candidates.sort_custom(func(a, b): return _score(a, enemy) > _score(b, enemy))

	## v2 tracks projected damage per enemy unit across the whole volley, so
	## attacks can be aimed rather than each one scored against the board as it
	## stands. Without this the AI spreads damage by default and never converts a
	## volley into a kill — which makes *clearing a board* look far harder than
	## the rules make it, and clearing a board is the gate on reaching a tower.
	var projected: Dictionary = {}      ## Unit -> damage already aimed at it

	for c in candidates:
		var u: Unit = c["u"]
		## One queued attack per unit — EXCEPT when a Forge `stoked_extra_attack`
		## payoff granted a second slot this turn. Without this exception the AI
		## could never use the grant at all: it would stoke, pay the HP, and then
		## skip the unit here because it already had something queued. Found by
		## probing which ops actually fire in AI games rather than by reading.
		if u.queued_attack != null and not u.can_queue_extra():
			continue
		var atk: AttackData = c["atk"]
		## Skip the 20-cost bomb unless it's actually reachable.
		if u.pool_needed(atk) > p.pool:
			continue
		if _v2():
			var pick: Unit = _focus_target(p, enemy, u, atk, c["bi"], c["si"], projected)
			if pick != null:
				var dmg: int = atk.damage + _bonus_damage(u, atk, pick)
				projected[pick] = int(projected.get(pick, 0)) + dmg
			gs.queue_attack(p, u, atk, pick)
		else:
			gs.queue_attack(p, u, atk)


## v2 focus fire: name the enemy unit this attack should hit.
##
## Returns null to leave the attack untargeted (the v1 behaviour: slot across,
## then leftmost survivor), which is correct whenever no named target is better
## than the default.
##
## The rule is "finish what the volley has already committed to killing, else
## start on the target we are most likely to finish". Damage already aimed at a
## unit earlier in this volley is counted, so three attacks converge instead of
## each independently picking the same healthiest body and overkilling it.
##
## Targeting is deliberately conservative about *structures*: a named target must
## be a living unit, and once a board is projected clear the attack is left
## untargeted so it falls through the chain to the tower on its own.
func _focus_target(p: Player, enemy: Player, u: Unit, atk: AttackData,
		bi: int, si: int, projected: Dictionary) -> Unit:
	var eb: Board = enemy.boards[bi]
	var living: Array = []
	for slot in Board.SLOT_COUNT:
		var d: Unit = eb.unit_at(slot)
		if d != null and d.is_alive():
			living.append(d)
	if living.is_empty():
		return null

	## If everything on this board is already projected dead, don't name a target
	## — the attack should fall through to the tower.
	var all_dead := true
	for d in living:
		if int(projected.get(d, 0)) < d.hp:
			all_dead = false
			break
	if all_dead:
		return null

	var best: Unit = null
	var best_score := -1.0
	for d in living:
		var already: int = int(projected.get(d, 0))
		var remaining: int = d.hp - already
		if remaining <= 0:
			continue                     ## already dead in projection; don't overkill
		var dmg: float = float(atk.damage + _bonus_damage(u, atk, d))
		var score: float
		if dmg >= float(remaining):
			## A kill, and the cheaper the overkill the better — spending a 50
			## on a 12 HP body wastes the volley's concentration.
			score = 1000.0 - float(dmg - remaining)
		else:
			## No kill available: chip whatever we come closest to finishing, so
			## the *next* attack in the volley has a kill to take.
			score = 100.0 - float(remaining - dmg)
		if score > best_score:
			best_score = score
			best = d

	## Leaving it untargeted is equivalent when the pick is the default anyway.
	if best != null and best == eb.unit_at(si):
		return null
	return best


## Higher is better: prefer lethal-on-defender, then damage per energy.
##
## The target has to be resolved through the real chain, not read out of the slot
## across: living units shield their board, so an empty slot means "redirect to
## the leftmost survivor", not "free hit on the tower". Scoring the slot directly
## would both miss real kills and chase structures that cannot be reached.
##
## This is a first-order read only. It does not model the volley killing a unit
## and opening the board for a later attack — the AI scores each attack against
## the board as it stands now.
func _score(entry: Dictionary, enemy: Player) -> float:
	var u: Unit = entry["u"]
	var atk: AttackData = entry["atk"]
	var need := u.pool_needed(atk)
	var eb: Board = enemy.boards[entry["bi"]]

	var defender: Unit = eb.unit_at(entry["si"])
	if defender == null or not defender.is_alive():
		defender = eb.leftmost_living_unit()

	## Effective damage, not printed damage. A Rift unit hits for its printed
	## number plus N per point of Gap, and a Void rider pays per energy it
	## destroys — scoring the printed value would make the AI systematically
	## undervalue exactly the attacks Void is built around.
	var dmg: float = float(atk.damage) + float(_bonus_damage(u, atk, defender))

	var score: float = dmg / max(1.0, float(need + 1))
	if defender != null and dmg >= float(defender.hp):
		score += 50.0                    ## kills are worth a lot
	if defender == null:
		score += 10.0                    ## board is clear — the structures are open
	if atk.has_effect("last_toll"):
		score += 100.0                   ## always take the win if affordable

	## Silence Eternal deals no lane damage at all — its whole output is throne
	## damage scaled by the Gap, so the generic path scores it at zero and the AI
	## would never fire the faction's win condition.
	if atk.has_effect("gap_throne_damage"):
		var throne_dmg: int = min(
			atk.effect_value("gap_throne_max", 100),
			atk.effect_value("gap_throne_damage", 0) * gs.gap_for(gs.players[gs.active]))
		score = float(throne_dmg) / max(1.0, float(need + 1))
		if throne_dmg >= enemy.throne_hp:
			score += 100.0               ## lethal on the throne is the game
	return score


## Damage an attack adds beyond its printed number, for scoring purposes.
## Mirrors GameState's resolution order but never mutates anything.
func _bonus_damage(u: Unit, atk: AttackData, defender: Unit) -> int:
	var bonus: int = 0
	if u.has_rift():
		bonus += u.rift() * gs.gap_for(gs.players[gs.active])
	## The per-energy-destroyed rider only pays if the defender actually holds
	## energy — which is the property that makes those cards conditional.
	if atk.has_effect("damage_per_voided") and defender != null:
		var can_void: int = min(atk.effect_value("void_energy", 0), defender.attached)
		bonus += atk.effect_value("damage_per_voided", 0) * can_void
	return bonus


func _dump_leftover_energy(p: Player) -> void:
	if p.pool <= 0:
		return
	if _v2():
		_bank_leftover_energy_v2(p)
		return
	## Bank the rest on the toughest unit so decay can't eat it.
	var best: Unit = null
	for u in p.all_units():
		if best == null or u.hp > best.hp:
			best = u
	if best != null:
		gs.charge(p, best, p.pool)


## v2 banking: charge toward the cheapest attack the board cannot yet afford,
## and only bank the surplus that decay would actually take.
##
## v1 dumped the entire pool onto the single toughest body every turn. That is
## not a neutral simplification for measurement purposes — it has three effects
## that all bias the numbers this simulation exists to produce:
##
##   - The pool is empty at every decision point, so an expensive attack is
##     never reachable and reads as unplayable whatever its printed cost.
##   - Energy piles onto one unit far past what its own attacks cost, and dies
##     with it, inflating how punishing unit death looks.
##   - For Void specifically it maximises the Gap by accident, which the design
##     docs already flag as having produced a bad tuning decision.
##
## Decay is 20% floored, so a pool at or under 4 loses exactly 1 whether it holds
## 1 or 4. Holding a small pool is therefore nearly free, and holding a large one
## is taxed — so the rule is: fund the next attack, then keep a small float, then
## bank whatever is left rather than letting decay eat it.
func _bank_leftover_energy_v2(p: Player) -> void:
	## 1. Put energy where it completes a real attack. Cheapest gap first, so the
	##    board converts pool into activations as fast as possible.
	var guard := 0
	while p.pool > 0 and guard < 12:
		guard += 1
		var target: Unit = null
		var gap := 999
		for u in p.all_units():
			if not u.is_alive():
				continue
			for atk in u.card.attack_lines():
				var need: int = u.pool_needed(atk)
				if need <= 0 or need > p.pool:
					continue
				if need < gap:
					gap = need
					target = u
		if target == null:
			break
		gs.charge(p, target, gap)

	if p.pool <= 0:
		return

	## 2. Keep a float that decay cannot meaningfully tax, so there is pool
	##    available next turn for a support or a newly-deployed body. Below the
	##    floor the 20% rule takes the same 1 energy regardless.
	const FLOAT_KEEP := 4
	if p.pool <= FLOAT_KEEP:
		return

	## 3. Bank the taxable surplus on the body most likely to survive to spend it.
	##    "Toughest" in v1 meant highest current HP; a unit's *attacks* matter
	##    too, since energy on a body with nothing expensive to buy is stranded.
	var best: Unit = null
	var best_score := -1.0
	for u in p.all_units():
		if not u.is_alive():
			continue
		var ceiling := 0
		for atk in u.card.attack_lines():
			ceiling = max(ceiling, u.attack_cost(atk))
		## Room left before this unit's own biggest attack is fully funded.
		var room: int = max(0, ceiling - u.attached)
		var score := float(u.hp) + 20.0 * float(min(room, p.pool))
		if score > best_score:
			best_score = score
			best = u
	if best != null:
		gs.charge(p, best, p.pool - FLOAT_KEEP)
