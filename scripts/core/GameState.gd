class_name GameState
extends RefCounted

## Authoritative game rules. No UI code here — the combat screen reads this and
## renders it. All rules from CLAUDE.md live in this file.

signal log_line(text: String)
signal state_changed()
signal game_over(winner_index: int)

## A support needs the player to pick something the engine can't choose for
## them (a card from the deck, a card to discard to the hand limit). The combat
## screen listens and opens a picker; headless callers use the auto-resolvers.
##   choices: Array[String] card ids   on_pick: func(index: int) -> void
signal choice_required(p, prompt: String, choices: Array, on_pick: Callable)

const P1 := 0
const P2 := 1

## Setup runs before round 1: mulligan, then both players deploy Basics for free.
## Nothing else is legal in it — see `setup_deploy`.
enum Phase { SETUP, PLAYING }

var players: Array = []          ## Array[Player], [P1, P2]
var turn: int = 1                ## round number; both players act each round
var active: int = P1
var finished: bool = false
var winner: int = -1

var phase: Phase = Phase.SETUP

## Set once each player has committed their setup board. Both must be true before
## round 1 begins. Indexed like `players`.
var setup_done: Array = [false, false]

## Deck names for the battle record. Purely informational — the rules never read
## them — but a damage table is unreadable without knowing which decks played.
var deck_names: Array = ["You", "Opponent"]

## Damage attribution, for post-game balance analysis. Keyed by card id:
##   { "barrow_knight": { "unit": 120, "tower": 25, "throne": 0, "hits": 6 } }
## One dictionary per player, indexed the same way as `players`.
##
## Recorded only where the *source card* is known — attacks and card-driven
## damage. Tower fire is attributed to the structure, not to a card, because no
## card dealt it. That is the honest reading of "which cards did the most
## damage" and it keeps the table free of an entry no deck decision can affect.
var damage_by_card: Array = [{}, {}]

## Tower fire is worth counting even though it belongs to no card — it is a large
## fraction of the damage in a long game and the quarter-rate rule made it a
## throne threat. Kept separate so it never pollutes the per-card table.
var tower_damage_dealt: Array = [0, 0]


## `shuffled = false` is the TUTORIAL's entry point for a reproducible deal — a
## lesson must present the same hand every run or its scripted steps cannot name a
## card. It also skips the guaranteed-Basic re-deal below, since re-dealing would
## reshuffle the very order the caller asked to preserve.
##
## `hand_p1` is how a lesson STATES the hand its steps require, rather than
## inferring it from deck order. A lesson that asks for a second Basic must be able
## to guarantee a second Basic; anything less soft-locks at that step.
func _init(deck_p1: Array, deck_p2: Array, shuffled: bool = true,
		hand_p1: Array = []) -> void:
	players = [Player.new("You", false), Player.new("Opponent", true)]
	players[P1].load_deck(deck_p1, shuffled)
	players[P2].load_deck(deck_p2, shuffled)

	if not shuffled:
		if hand_p1.is_empty():
			players[P1].draw(Player.HAND_SIZE_START)
		else:
			players[P1].deal_exact_hand(hand_p1)
		players[P2].draw(Player.HAND_SIZE_START)
		return

	## Both sides get the guaranteed-Basic deal. Symmetric on purpose: an asymmetric
	## opening would mean the AI-vs-AI harnesses are no longer measuring the same game
	## on both seats, which is most of what they are for.
	players[P1].deal_opening_hand()
	players[P2].deal_opening_hand()


## Record damage against the card that caused it. `who` is a Player; `kind` is
## "unit", "tower", or "throne".
##
## Silently ignores zero and negative amounts so callers can hand it the result
## of a capped `take_damage` without checking first — an attack that hit a
## 5 HP tower for 40 should record the 5 that actually landed, and an attack
## fully absorbed by Sanctuary should record nothing at all.
func _record_damage(who: Player, card_id: String, kind: String, amount: int) -> void:
	if amount <= 0 or card_id == "":
		return
	var idx: int = 0 if who == players[P1] else 1
	var table: Dictionary = damage_by_card[idx]
	if not table.has(card_id):
		table[card_id] = {"unit": 0, "tower": 0, "throne": 0, "hits": 0}
	table[card_id][kind] += amount
	table[card_id]["hits"] += 1


## ------------------------------------------------------------------- the Gap
##
## Void's board-wide state value: **my total attached energy minus theirs**.
## Read by `Rift N` and by the Gap support cards. Positive means I have more
## committed to bodies than the opponent does.
##
## The direction is not arbitrary — it falls out of the arithmetic. `Siphon`
## MOVES energy from an enemy unit onto one of mine, so it lowers their total and
## raises mine: it swings this number by 2N in my favor. Defining the Gap the
## other way round would make Void's own primary keyword turn off its own payoff
## cards, which is the one shape the faction must not have.
##
## Floors at 0. A negative Gap would mean Rift units get *worse* than printed,
## which reads as a hidden penalty on a card whose text only promises a bonus.
func gap_for(p: Player) -> int:
	var idx: int = 0 if p == players[P1] else 1
	return max(0, _attached_total(players[idx]) - _attached_total(players[1 - idx]))


## Total energy attached to a player's living units. Dead-but-not-yet-cleaned
## units are excluded: within a volley a unit marked dead still sits on the board
## for Retribution, but its energy is already forfeit, so counting it would let a
## corpse inflate the Gap for the rest of the resolution.
func _attached_total(p: Player) -> int:
	var n: int = 0
	for b in p.boards:
		for u in b.units():
			if u != null and u.is_alive():
				n += u.attached
	return n


## ------------------------------------------------------------------ Gaia Earth
##
## A player's total Earth: the sum across every LIVING unit they control, both
## boards. This is the aura, and it is deliberately computed on demand rather than
## cached — that is what makes it live, so a unit dying shrinks it with no
## invalidation logic anywhere.
##
## Living units only, for the same reason the Gap counts only the living: within a
## volley a unit marked dead stays on the board so it can deal Retribution, but
## counting its Earth would let a corpse hold the aura up for the rest of the
## resolution.
func earth_for(p: Player) -> int:
	var n: int = 0
	for b in p.boards:
		for u in b.units():
			if u != null and u.is_alive():
				n += u.earth()
	return n


## A unit's max HP including its owner's Earth aura. `Unit.max_hp()` stays the
## PRINTED value — a Unit has no owner reference, and giving it one would force an
## owner through every construction site in the game and the harnesses.
func effective_max_hp(p: Player, u: Unit) -> int:
	return u.max_hp() + earth_for(p) * earth_rate(p)


## Stat points each point of Earth grants, to units and towers alike. 1 by default.
## Rate-breaker cards raise it ADDITIVELY and never multiply the total: the aura
## already applies to four units and two towers, so a multiplier on the sum is
## exponential across six things (CLAUDE.md decision log).
func earth_rate(p: Player) -> int:
	var rate: int = 1
	for b in p.boards:
		for u in b.units():
			if u != null and u.is_alive() and u.card.has_effect("earth_rate"):
				rate += u.card.effect_value("earth_rate", 1)
	return rate


## Heal `u`, capped at its AURA-ADJUSTED max rather than the printed one. Callers
## that heal a unit must use this instead of Unit.heal(), or a Gaia unit can never
## be healed into the HP its own aura granted it.
func heal_unit(p: Player, u: Unit, amount: int) -> int:
	if amount <= 0 or not u.is_alive():
		return 0
	var healed: int = min(amount, effective_max_hp(p, u) - u.hp)
	if healed <= 0:
		return 0
	u.hp += healed
	return healed


## Clamp every unit down to its current effective max. Called after anything that
## can shrink the aura — a death, a retreat, an evolution.
##
## It NEVER kills: a unit floors at 1 HP. A body dying because a different unit
## died two boards away is a feel-bad with no counterplay, and it would make Gaia's
## own aura a liability against its own board (gaia.md).
func clamp_to_aura(p: Player) -> void:
	for b in p.boards:
		for u in b.units():
			if u != null and u.is_alive():
				var ceiling: int = effective_max_hp(p, u)
				if u.hp > ceiling:
					u.hp = max(1, ceiling)


## Re-apply the Earth aura to both of a player's towers. Idempotent: it removes
## the bonus it granted last time before granting the new one, so it may be called
## after any board change without compounding.
##
## Unlike a unit's max HP — computed on demand by `effective_max_hp` — a tower's
## max HP is STORED state, so the aura's share of it has to be tracked explicitly
## in `Board.earth_max_hp_bonus`.
##
## Growing the aura raises current HP too: a tower that gains 6 max HP from a new
## Earth body should actually be 6 tougher, not merely have a higher ceiling.
## Shrinking clamps current HP down but NEVER kills — the tower floors at 1, for
## the same reason `clamp_to_aura` never kills a unit (gaia.md).
func sync_tower_aura(p: Player) -> void:
	var bonus: int = earth_for(p) * earth_rate(p)
	for b in p.boards:
		if not b.tower_alive():
			## A dead tower keeps no aura. Its mods are already gone.
			b.earth_max_hp_bonus = 0
			continue
		var delta: int = bonus - b.earth_max_hp_bonus
		if delta == 0:
			continue
		b.tower_max_hp += delta
		b.earth_max_hp_bonus = bonus
		if delta > 0:
			b.tower_hp += delta
		elif b.tower_hp > b.tower_max_hp:
			b.tower_hp = max(1, b.tower_max_hp)


## Both aura fix-ups in one call, for the many sites that change the living-unit
## set. Cheap and idempotent, so calling it defensively is correct.
func refresh_aura(p: Player) -> void:
	sync_tower_aura(p)
	clamp_to_aura(p)


## Units that fire on their own at end of turn — Makeshift Tower.
##
## Free, no energy, no queueing: the card is a deliberate rule-breaker on *energy
## only buys attacks*, and it pays for that by being an ordinary targetable unit
## rather than a structure. A real tower is only reachable once a board has been
## cleared; this one can be named by any attack the turn it lands (gaia.md).
##
## It resolves through `_deal_lane_damage`, the same chain every other attack
## uses, so it respects shielding and cannot reach past a living board.
func resolve_auto_fire(p: Player, enemy: Player) -> void:
	var bonus: int = earth_for(p) * earth_rate(p)
	for bi in p.boards.size():
		var b: Board = p.boards[bi]
		for si in Board.SLOT_COUNT:
			var u: Unit = b.slots[si]
			if u == null or not u.is_alive():
				continue
			if not u.card.has_effect("auto_fire"):
				continue
			var dmg: int = u.card.effect_value("auto_fire", 0) + bonus
			if dmg <= 0:
				continue
			var atk := AttackData.from_dict({
				"id": "auto_fire", "name": "Auto-fire", "damage": dmg,
			})
			_deal_lane_damage(p, enemy, u, bi, si, dmg, atk)
			if finished:
				return
	_cleanup_dead(enemy)


## +5 max HP a round for auto-fire units, matching a real tower's growth. Current
## HP rises with the max, so the growth is real toughness rather than a ceiling.
func grow_auto_towers(p: Player) -> void:
	for b in p.boards:
		for u in b.units():
			if u == null or not u.is_alive():
				continue
			if not u.card.has_effect("tower_growth"):
				continue
			var n: int = u.card.effect_value("tower_growth", 5)
			u.hp_grown += n
			u.hp += n


func me() -> Player:
	return players[active]


func foe() -> Player:
	return players[1 - active]


func opponent_of(idx: int) -> Player:
	return players[1 - idx]


func _log(text: String) -> void:
	log_line.emit(text)


# ---------------------------------------------------------------- main phase

func play_unit(p: Player, hand_index: int, board_index: int, slot: int) -> bool:
	if finished or hand_index < 0 or hand_index >= p.hand.size():
		return false
	var card: CardData = CardDB.get_card(p.hand[hand_index])
	if card == null or not card.is_unit():
		return false
	if card.stage != CardData.Stage.BASIC:
		return false                       ## non-basics only enter play by evolving
	if p.is_locked(card.id):
		return false                       ## returned by retreat this turn
	var b: Board = p.boards[board_index]
	if not b.is_slot_playable(slot):
		return false

	## No lock to retire: is_locked() guaranteed an unlocked copy, and the copy
	## played is that one. The remaining locked copies keep their locks.
	p.hand.remove_at(hand_index)
	b.place(Unit.new(card), slot)
	_log("%s plays %s." % [p.display_name, card.name])
	## A new body can carry Earth, which grows the aura for towers and units alike.
	refresh_aura(p)
	state_changed.emit()
	return true


func play_energy(p: Player, hand_index: int) -> bool:
	if finished or in_setup() or p.energy_played_this_turn:
		return false
	if hand_index < 0 or hand_index >= p.hand.size():
		return false
	var card: CardData = CardDB.get_card(p.hand[hand_index])
	if card == null or card.is_unit():
		return false

	p.hand.remove_at(hand_index)
	p.discard.append(card.id)
	var gain := p.play_energy(turn)
	_log("%s plays Energy: +%d (pool %d)." % [p.display_name, gain, p.pool])
	state_changed.emit()
	return true


func evolve(p: Player, hand_index: int, target: Unit) -> bool:
	if finished or in_setup() or hand_index < 0 or hand_index >= p.hand.size():
		return false
	var card: CardData = CardDB.get_card(p.hand[hand_index])
	if card == null or not card.is_unit():
		return false
	if card.evolves_from != target.card.id:
		return false
	if p.is_locked(card.id):
		return false                       ## returned by retreat this turn

	p.hand.remove_at(hand_index)
	var old_name := target.card.name
	## The base card is not discarded — it stays under the unit as part of the
	## evolution path, and retreat returns the whole stack to hand.
	target.evolve_into(card)
	_log("%s evolves %s into %s (%d energy carried)." % [p.display_name, old_name, card.name, target.attached])
	## The evolved card prints its own Earth, which may be higher or lower than
	## the stage underneath — the aura moves either way.
	refresh_aura(p)
	state_changed.emit()
	return true


# ---------------------------------------------------------------- retreat

## Pull a unit off the board and back into hand.
##
##   1. pay the retreat cost from the unit's *own* attached energy
##   2. that energy is spent, not banked
##   3. leftover attached energy returns to the pool
##   4. the whole evolution path returns to hand, healed, locked for one turn
##   5. the slot is left empty and does not compact
##
## Retreat is not death: no Toll, no Rise, nothing to the discard except the
## Tool, which retreat does not save.
##
## `free` is Escape Route (cost reduced to 0); `from_pool` is Withdraw (the cost
## is paid from the pool instead, the only case where that is legal).
func retreat(p: Player, u: Unit, free: bool = false, from_pool: bool = false) -> bool:
	if finished or in_setup():
		return false
	var loc := p.find_unit(u)
	if loc[0] < 0:
		return false

	var cost: int = 0 if free else u.retreat_cost()

	if from_pool:
		if p.pool < cost:
			return false
		p.pool -= cost
	else:
		if u.attached < cost:
			return false                   ## an uncharged unit is stuck
		u.attached -= cost

	## Leftover attached energy returns to the pool — the only non-death way
	## energy ever comes back off a unit.
	var refund: int = u.attached
	p.pool += refund
	u.attached = 0

	_remove_and_return_to_hand(p, u, loc[0], loc[1])
	_log("%s retreats %s (cost %d, %d energy returned to pool)." % [
		p.display_name, u.card.name, cost, refund
	])
	state_changed.emit()
	return true


## Shared by retreat and Ground Give: take the unit off the board, discard its
## Tool, and push its whole evolution path to hand, locked and healed.
func _remove_and_return_to_hand(p: Player, u: Unit, bi: int, si: int) -> void:
	p.boards[bi].slots[si] = null

	## Retreat saves the body, not the equipment.
	if u.tool != null:
		p.discard.append(u.tool.id)
		_log("  %s is discarded — retreat does not save Tools." % u.tool.name)
		u.tool = null

	## The card returns healed to full simply by being a card again; a Stage 2
	## brings its Basic and Stage 1 back as separate cards, all locked.
	for cid in u.retreat_cards():
		p.hand.append(cid)
		p.lock_card(cid)

	## Pulling a body off the board shrinks the aura exactly as a death does.
	## Placed here rather than in `retreat()` so Ground Give gets it too — this
	## is the one function both removal paths share.
	refresh_aura(p)


## Free action, unlimited per turn.
func charge(p: Player, u: Unit, n: int) -> bool:
	if finished or in_setup() or n <= 0 or p.pool <= 0:
		return false
	var moved := p.charge(u, n)
	if moved <= 0:
		return false
	_log("%s charges %d onto %s (attached %d)." % [p.display_name, moved, u.card.name, u.attached])
	state_changed.emit()
	return true


## Queue an attack. Pulls exactly the shortfall from the pool onto the unit.
##
## Abilities are rejected outright: they are not queued and do not resolve at end
## of turn. Route them through use_ability() instead.
func queue_attack(p: Player, u: Unit, atk: AttackData, target = null) -> bool:
	if finished or in_setup() or atk.is_ability:
		return false
	var need := u.pool_needed(atk)
	if need > p.pool:
		return false

	if need > 0:
		p.pool -= need
		u.attached += need

	u.queued_attack = atk
	u.queued_target = target
	u.last_attack = atk               ## what the attack lock will re-fire
	_log("%s queues %s on %s." % [p.display_name, atk.name, u.card.name])
	state_changed.emit()
	return true


func cancel_attack(u: Unit) -> void:
	u.clear_queue()
	state_changed.emit()


# ---------------------------------------------------------------- abilities

## Activate an ability. Unlike an attack this resolves **immediately** during the
## main phase, is limited to once per turn per unit, and is **free** — the only
## energy it may cost is `Consume N`, which destroys N *attached* energy.
##
## Nothing here draws from the pool. That is the whole distinction: attacks buy
## an effect with pool energy that then stays attached, abilities either cost
## nothing or burn energy already committed to the body.
func use_ability(p: Player, u: Unit, ab: AttackData, target = null) -> bool:
	if finished or in_setup() or not ab.is_ability:
		return false
	if not u.can_use_ability(ab):
		return false

	var burned := ab.consume_cost()
	u.spend_ability(ab)

	if burned > 0:
		_log("%s uses %s (Consume %d — %d attached left)." % [
			u.card.name, ab.name, burned, u.attached
		])
	else:
		_log("%s uses %s." % [u.card.name, ab.name])

	## Void's Siphon/Void abilities need a lane position, because they pick their
	## victim with the same slot-across-then-leftmost chain damage uses. Abilities
	## historically passed -1 for "no lane", which is still right for every other
	## ability — none of them reach across the board — so the position is looked
	## up rather than the signature being changed for all callers.
	var pos: Array = _find_unit_position(p, u)
	_resolve_line_effects(p, opponent_of(players.find(p)), u, ab, target, pos[0], pos[1])
	_cleanup_dead(p)
	_cleanup_dead(opponent_of(players.find(p)))
	state_changed.emit()
	return true


## Where a unit is standing: [board_index, slot_index], or [-1, -1] if it is not
## on the board (which can happen for a unit resolving as it leaves play).
func _find_unit_position(p: Player, u: Unit) -> Array:
	for bi in p.boards.size():
		for si in p.boards[bi].slots.size():
			if p.boards[bi].slots[si] == u:
				return [bi, si]
	return [-1, -1]


## True when this unit has any ability it could activate right now. Used by the
## UI to decide whether to show the ability section at all.
func has_usable_ability(u: Unit) -> bool:
	for ab in u.card.ability_lines():
		if u.can_use_ability(ab):
			return true
	return false


# ---------------------------------------------------------------- support

## Play a support, Tool, or tower support card. Free, and unlimited per turn —
## hand size is the only cost.
##
## `target` is whatever the card needs, or null:
##   Tool                     -> Unit (friendly, or enemy for Deadweight)
##   tower support            -> Array [board_index] naming a tower you control
##   unit-targeted support    -> Unit
##   two-unit support         -> Array [Unit, Unit] (Tithe, Reposition)
func play_support(p: Player, hand_index: int, target = null) -> bool:
	if finished or in_setup() or hand_index < 0 or hand_index >= p.hand.size():
		return false
	var card: CardData = CardDB.get_card(p.hand[hand_index])
	if card == null or not card.is_support_like():
		return false
	if p.is_locked(card.id):
		return false
	if not can_play_support(p, card, target):
		return false

	p.hand.remove_at(hand_index)
	_log("%s plays %s." % [p.display_name, card.name])

	match card.type:
		CardData.Type.TOOL:
			_attach_tool(p, card, target)
		CardData.Type.TOWER_SUPPORT:
			_resolve_tower_support(p, card, target)
		_:
			p.discard.append(card.id)      ## one-shot: play, resolve, discard
			_resolve_support_effects(p, card, target)

	state_changed.emit()
	return true


## Legality check, shared by the UI (to grey out cards) and play_support.
func can_play_support(p: Player, card: CardData, target = null) -> bool:
	match card.type:
		CardData.Type.TOOL:
			if not (target is Unit) or not target.is_alive():
				return false
			return not target.has_tool()   ## one Tool per unit
		CardData.Type.TOWER_SUPPORT:
			var bi := _tower_index(target)
			if bi < 0 or bi >= p.boards.size():
				return false
			var b: Board = p.boards[bi]
			if not b.tower_alive():
				return false                ## must name a tower you control
			return b.can_take_tower_mod() if card.permanent else true
		_:
			return _support_target_ok(p, card, target)


## Does this card have a legal target at all right now? Used to grey out cards
## in hand that would fizzle.
func support_has_any_target(p: Player, card: CardData) -> bool:
	match card.type:
		CardData.Type.TOOL:
			for u in _tool_candidates(p, card):
				return true
			return false
		CardData.Type.TOWER_SUPPORT:
			for bi in p.boards.size():
				if can_play_support(p, card, bi):
					return true
			return false
		_:
			if not _support_needs_target(card):
				return true
			for u in _support_unit_candidates(p, card):
				return true
			return false


## Deadweight attaches to an enemy unit; every other Tool goes on your own.
func _tool_candidates(p: Player, card: CardData) -> Array:
	var owner: Player = opponent_of(players.find(p)) if card.has_effect("attach_enemy") else p
	var out: Array = []
	for u in owner.all_units():
		if u.is_alive() and not u.has_tool():
			out.append(u)
	return out


func _tower_index(target) -> int:
	if target is int:
		return target
	if target is Array and target.size() > 0:
		return int(target[0])
	return -1


## Cards whose effect list names a unit target.
const UNIT_TARGET_OPS := [
	"heal", "heal_conditional", "heal_undo_decay", "heal_per_round",
	"protect",
	"damage_uncharged", "destroy_energy", "retreat_unit", "retreat_free",
	"retreat_from_pool", "return_to_hand",
	## Void — all three point at an enemy unit.
	"siphon_support", "void_all", "gap_damage",
]

const TWO_UNIT_OPS := ["move_energy", "swap_slots"]


func _support_needs_target(card: CardData) -> bool:
	for op in UNIT_TARGET_OPS + TWO_UNIT_OPS:
		if card.has_effect(op):
			return true
	return false


## Legal single-unit targets for a support, respecting each card's condition.
func _support_unit_candidates(p: Player, card: CardData) -> Array:
	var mine: Player = p
	var foe_p: Player = opponent_of(players.find(p))
	var out: Array = []

	if card.has_effect("damage_uncharged"):
		for u in foe_p.all_units():
			if u.is_alive() and u.attached == 0:
				out.append(u)
		return out

	if card.has_effect("destroy_energy"):
		for u in foe_p.all_units():
			if u.is_alive() and u.attached > 0:
				out.append(u)
		return out

	## Void's theft and destruction supports want an enemy body actually holding
	## something. A charged-only filter means the card is illegal rather than a
	## wasted play when the board is empty of energy — same treatment
	## `destroy_energy` already gets.
	if card.has_effect("siphon_support") or card.has_effect("void_all"):
		for u in foe_p.all_units():
			if u.is_alive() and u.attached > 0:
				out.append(u)
		return out

	## Gap damage hits any living enemy body — it reads the board state, not the
	## target's energy, so an uncharged unit is a perfectly good target.
	if card.has_effect("gap_damage"):
		for u in foe_p.all_units():
			if u.is_alive():
				out.append(u)
		return out

	if card.has_effect("heal_conditional"):
		for u in mine.all_units():
			if u.is_alive() and u.hp * 2 <= u.max_hp():
				out.append(u)
		return out

	if card.has_effect("retreat_unit"):
		for u in mine.all_units():
			if u.is_alive() and u.can_retreat():
				out.append(u)
		return out

	if card.has_effect("retreat_from_pool"):
		for u in mine.all_units():
			if u.is_alive() and mine.pool >= u.retreat_cost():
				out.append(u)
		return out

	## Every unconditional heal wants the same filter: alive and actually hurt.
	if card.has_effect("heal") or card.has_effect("heal_per_round"):
		for u in mine.all_units():
			if u.is_alive() and u.hp < u.max_hp():
				out.append(u)
		return out

	for u in mine.all_units():
		if u.is_alive():
			out.append(u)
	return out


func _support_target_ok(p: Player, card: CardData, target) -> bool:
	if not _support_needs_target(card):
		return true

	for op in TWO_UNIT_OPS:
		if card.has_effect(op):
			if not (target is Array) or target.size() < 2:
				return false
			return target[0] is Unit and target[1] is Unit and target[0] != target[1]

	if not (target is Unit):
		return false
	return _support_unit_candidates(p, card).has(target)


# ------------------------------------------------------------ tools & towers

func _attach_tool(p: Player, card: CardData, target) -> void:
	var u: Unit = target
	u.tool = card
	_log("  %s is attached to %s." % [card.name, u.card.name])

	## Aegis of the Choir — grants plain Sanctuary, or restores an existing one so the
	## Tool is never dead on the body it most wants to protect. Granted Sanctuary is
	## deliberately not *printed*, so Court of Bells cannot refresh it.
	if card.has_effect("grant_sanctuary"):
		if u.card.has_kw("sanctuary"):
			u.restore_sanctuary()
			_log("  %s restores %s's Sanctuary." % [card.name, u.card.name])
		else:
			u.grant_sanctuary()
			_log("  %s grants %s Sanctuary." % [card.name, u.card.name])


func _resolve_tower_support(p: Player, card: CardData, target) -> void:
	var bi := _tower_index(target)
	var b: Board = p.boards[bi]

	if card.permanent:
		b.tower_mods.append(card)
		if card.has_effect("tower_max_hp"):
			var n := card.effect_value("tower_max_hp", 0)
			b.tower_max_hp += n
			b.tower_hp += n
			_log("  Tower %d gains +%d max HP (now %d/%d)." % [bi + 1, n, b.tower_hp, b.tower_max_hp])
		if card.has_effect("tower_damage"):
			b.tower_damage_bonus += card.effect_value("tower_damage", 0)
			_log("  Tower %d now deals +%d damage." % [bi + 1, b.tower_damage_bonus])
		if card.has_effect("tower_crossfire"):
			_log("  Tower %d gains Crossfire." % [bi + 1])
		if card.has_effect("tower_death_damage"):
			_log("  Tower %d gains Spite Engine." % [bi + 1])
		return

	## One-shots resolve and go to the discard without taking the slot.
	p.discard.append(card.id)
	if card.has_effect("tower_heal"):
		var healed := b.tower_heal(card.effect_value("tower_heal", 0))
		_log("  Tower %d repaired for %d (now %d/%d)." % [bi + 1, healed, b.tower_hp, b.tower_max_hp])
	if card.has_effect("destroy_own_tower"):
		_log("  %s destroys their own tower %d." % [p.display_name, bi + 1])
		_destroy_tower(p, bi)
		var n := card.effect_value("draw", 0)
		if n > 0:
			p.draw(n)
			_log("  Draws %d." % n)


## Killing a tower opens its slot immediately and fires Spite Engine if the
## tower carried it.
func _destroy_tower(p: Player, bi: int) -> void:
	var b: Board = p.boards[bi]
	if not b.tower_alive():
		return
	## Copied, not referenced: tower_take_damage clears the list in place.
	var mods: Array = b.tower_mods.duplicate()
	b.tower_take_damage(b.tower_hp)
	_fire_spite_engine(p, bi, mods)


## `mods` is the tower's permanent list captured *before* the damage that killed
## it, because tower_take_damage clears the list. Every Spite Engine on the tower
## fires — permanents stack, so two of them hit twice.
func _fire_spite_engine(p: Player, bi: int, mods: Array) -> void:
	var enemy: Player = opponent_of(players.find(p))
	for mod in mods:
		if mod == null or not mod.has_effect("tower_death_damage"):
			continue
		var victim: Unit = enemy.boards[bi].unit_at(Board.TOWER_SLOT)
		## Re-read each time: an earlier Spite Engine may have killed the victim.
		if victim == null or not victim.is_alive():
			return
		var n: int = mod.effect_value("tower_death_damage", 0)
		var dealt: int = _damage_unit(victim, n, "Spite Engine")
		_log("  Spite Engine: %d to %s as the tower falls." % [dealt, victim.card.name])
		_cleanup_dead(enemy)


# ------------------------------------------------------ one-shot resolution

## Every one-shot support effect. Each card carries one entry (the one-effect
## rule), so these are handled independently rather than as a match.
func _resolve_support_effects(p: Player, card: CardData, target) -> void:
	var enemy: Player = opponent_of(players.find(p))

	## ---- draw & selection
	if card.has_effect("draw"):
		var n := card.effect_value("draw", 0)
		var got := p.draw(n)
		_log("  Draws %d." % got.size())

	if card.has_effect("dig_take"):
		_do_dig_take(p, card)

	if card.has_effect("shuffle_hand_draw_plus"):
		_do_second_thoughts(p, card)

	if card.has_effect("discard_then_draw"):
		_do_last_rites(p, card)

	## ---- search
	if card.has_effect("search_basic"):
		_do_search_basic(p, card.effect_value("search_basic", 1))

	if card.has_effect("search_random_evolved"):
		_do_search_random_evolved(p)

	if card.has_effect("search_any_to_top"):
		_do_search_any_to_top(p)

	if card.has_effect("random_from_discard"):
		_do_random_from_discard(p)

	if card.has_effect("dig_for_tower_support"):
		_do_dig_for_tower_support(p)

	## ---- energy
	if card.has_effect("gain_energy"):
		var g := card.effect_value("gain_energy", 0)
		p.gain_energy(g)
		_log("  +%d energy to pool (now %d)." % [g, p.pool])

	if card.has_effect("gain_per_death"):
		var cap := card.effect_value("gain_per_death", 4)
		var g2: int = min(p.units_died_this_turn, cap)
		if g2 > 0:
			p.gain_energy(g2)
			_log("  %d unit(s) died this turn — +%d energy (pool %d)." % [p.units_died_this_turn, g2, p.pool])
		else:
			_log("  No friendly unit died this turn — no energy gained.")

	if card.has_effect("move_energy"):
		_do_move_energy(target)

	## ---- retreat
	if card.has_effect("retreat_free"):
		retreat(p, target, true, false)

	if card.has_effect("retreat_from_pool"):
		retreat(p, target, false, true)

	if card.has_effect("return_to_hand"):
		_do_ground_give(p, target)

	if card.has_effect("clear_locks"):
		p.clear_locks()
		_log("  Cards returned this turn are no longer locked.")

	## ---- board
	if card.has_effect("swap_slots"):
		_do_swap_slots(p, target)

	## ---- healing
	if card.has_effect("heal"):
		var ht: Unit = target
		var healed: int = heal_unit(p, ht, card.effect_value("heal", 0))
		_log("  Heals %s for %d (%d/%d)." % [ht.card.name, healed, ht.hp, effective_max_hp(p, ht)])

	if card.has_effect("heal_all"):
		var n3 := card.effect_value("heal_all", 0)
		for unit_any in p.all_units():
			var hu: Unit = unit_any
			var h: int = heal_unit(p, hu, n3)
			if h > 0:
				_log("  Heals %s for %d." % [hu.card.name, h])

	## Last Breath — a flat heal gated on the unit being at or below half HP.
	## Deliberately NOT a full heal: no card in the game restores to max, because
	## a heal that scales with the target's HP is unboundable on a big body.
	if card.has_effect("heal_conditional"):
		var hc: Unit = target
		var got2: int = heal_unit(p, hc, card.effect_value("heal_conditional", 0))
		_log("  Heals %s for %d (%d/%d)." % [hc.card.name, got2, hc.hp, effective_max_hp(p, hc)])

	## Vigil — scales with the round, so it outruns the tower clock instead of
	## losing to it. The HP cap in heal_unit() is the only brake — the effective
	## max, so a Gaia aura raises the ceiling but never removes it.
	if card.has_effect("heal_per_round"):
		var hr: Unit = target
		var amount: int = card.effect_value("heal_per_round", 0) * turn
		var got: int = heal_unit(p, hr, amount)
		_log("  Heals %s for %d (round %d x %d, %d/%d)." % [
			hr.card.name, got, turn, card.effect_value("heal_per_round", 0), hr.hp, effective_max_hp(p, hr)])

	if card.has_effect("heal_undo_decay"):
		var hd: Unit = target
		var h2: int = heal_unit(p, hd, card.effect_value("heal_undo_decay", 0))
		var undone: int = heal_unit(p, hd, hd.decay_taken_this_turn)
		hd.decay_taken_this_turn = 0
		_log("  Heals %s for %d and undoes %d Decay damage." % [hd.card.name, h2, undone])

	if card.has_effect("protect"):
		var pr: Unit = target
		pr.protected_this_turn = true
		_log("  %s cannot be reduced below 1 HP this turn." % pr.card.name)

	## Gaia: grow a target unit's Earth permanently (Bedrock, Deep Communion,
	## Terraform). Lands in `earth_grown`, so it dies with the body and is reset
	## by Rise and evolution — a support cannot buy Earth that outlives its holder.
	if card.has_effect("grow_earth_target"):
		var ge: Unit = target
		if ge != null and ge.is_alive():
			var n: int = card.effect_value("grow_earth_target", 1)
			ge.earth_grown += n
			_log("  %s gains +%d Earth (now %d, board %d)." % [
				ge.card.name, n, ge.earth(), earth_for(p)])
			refresh_aura(p)

	## ---- damage & removal
	if card.has_effect("damage_uncharged"):
		var dt: Unit = target
		var d: int = _damage_unit(dt, card.effect_value("damage_uncharged", 0), card.name)
		_log("  %d to %s (%d HP left)." % [d, dt.card.name, max(0, dt.hp)])
		_cleanup_dead(enemy)

	if card.has_effect("destroy_energy"):
		var et: Unit = target
		var n4 := card.effect_value("destroy_energy", 0)
		var removed: int = min(n4, et.attached)
		et.attached -= removed
		_log("  Destroys %d attached energy on %s (%d left)." % [removed, et.card.name, et.attached])

	if card.has_effect("damage_tower"):
		_do_damage_tower(p, enemy, card.effect_value("damage_tower", 0), target)

	## ---- Void
	##
	## A support has no body to carry stolen energy, so `Siphon` on a card puts it
	## in the POOL rather than on a unit. That is a real difference from the unit
	## keyword and it cuts both ways: pool energy is safe from unit death but
	## exposed to the 20% decay, and it does NOT feed the Gap (which counts only
	## attached energy). Support Siphon is therefore ramp, while unit Siphon is
	## ramp *and* Gap — which is what keeps the units the centre of the faction.
	if card.has_effect("siphon_support"):
		var st: Unit = target
		var want: int = card.effect_value("siphon_support", 0)
		var got3: int = min(want, st.attached)
		st.attached -= got3
		p.pool += got3
		_log("  Siphon %d: takes %d from %s into the pool (%d left on it)." % [
			want, got3, st.card.name, st.attached])

	## Unwrite — destroys the lot. Takes nothing back, which is why it is priced
	## below theft despite being the harsher effect for the opponent.
	if card.has_effect("void_all"):
		var vt: Unit = target
		var wiped: int = vt.attached
		vt.attached = 0
		_log("  Unwrites all %d attached energy on %s." % [wiped, vt.card.name])

	## Reach on a card, capped so a large Gap can never make it the whole plan.
	if card.has_effect("gap_damage"):
		var gt: Unit = target
		var per2: int = card.effect_value("gap_damage", 0)
		var cap2: int = card.effect_value("gap_damage_max", 30)
		var amt: int = min(cap2, per2 * gap_for(p))
		if amt <= 0:
			_log("  No Gap — no damage.")
		else:
			var dealt4: int = _damage_unit(gt, amt, card.name)
			_log("  %d to %s (Gap %d, %d HP left)." % [dealt4, gt.card.name, gap_for(p), max(0, gt.hp)])
			_cleanup_dead(enemy)


## Ask the player to pick `count` cards out of `choices`, then run `done` with
## the picked ids. If nobody is listening for choice_required — a headless
## harness, or an AI player — the first `count` are taken automatically so the
## card still resolves rather than hanging.
func _choose_from(p: Player, prompt: String, choices: Array, count: int, done: Callable) -> void:
	var n: int = clampi(count, 0, choices.size())
	if n <= 0:
		done.call([])
		return

	if p.is_ai or choice_required.get_connections().is_empty():
		done.call(choices.slice(0, n))
		return

	var picked: Array = []
	var remaining: Array = choices.duplicate()

	## Emitted once per pick so the picker can be a simple one-of-N list.
	var step: Callable = func(_step_self: Callable) -> void:
		if picked.size() >= n or remaining.is_empty():
			done.call(picked)
			return
		choice_required.emit(p, "%s (%d of %d)" % [prompt, picked.size() + 1, n],
			remaining.duplicate(),
			func(idx: int) -> void:
				if idx < 0 or idx >= remaining.size():
					done.call(picked)      ## cancelled — resolve with what we have
					return
				picked.append(remaining[idx])
				remaining.remove_at(idx)
				_step_self.call(_step_self)
		)
	step.call(step)


func _do_dig_take(p: Player, card: CardData) -> void:
	## Scavenger's Instinct: look at the top 5, take 2, discard the rest.
	var look := card.effect_value("dig_look", 5)
	var take := card.effect_value("dig_take", 2)
	var seen: Array = []
	for i in look:
		if p.deck.is_empty():
			break
		seen.append(p.deck.pop_back())
	if seen.is_empty():
		_log("  Deck is empty — nothing to look at.")
		return

	_choose_from(p, "Take %d — the rest are discarded" % take, seen, take,
		func(picked: Array):
			for cid in picked:
				p.hand.append(cid)
			for cid in seen:
				if not picked.has(cid):
					p.discard.append(cid)
			_log("  Takes %d, discards %d." % [picked.size(), seen.size() - picked.size()])
			state_changed.emit()
	)


func _do_second_thoughts(p: Player, card: CardData) -> void:
	var n := p.hand.size()
	for cid in p.hand:
		p.deck.append(cid)
	p.hand.clear()
	p.clear_locks()                     ## the locked cards were shuffled away
	p.deck.shuffle()
	var bonus := card.effect_value("shuffle_hand_draw_plus", 1)
	p.draw(n + bonus)
	_log("  Shuffles %d cards back and draws %d." % [n, n + bonus])


func _do_last_rites(p: Player, card: CardData) -> void:
	var cost := card.effect_value("discard_then_draw", 2)
	var n := card.effect_value("draw_after_discard", 4)
	if p.hand.is_empty():
		p.draw(n)
		_log("  No cards to discard — draws %d." % n)
		return

	var pool_ids: Array = p.hand.duplicate()
	_choose_from(p, "Discard %d" % cost, pool_ids, min(cost, p.hand.size()),
		func(picked: Array):
			for cid in picked:
				var idx: int = p.hand.find(cid)
				if idx >= 0:
					p.discard_from_hand(idx)
			p.draw(n)
			_log("  Discards %d, draws %d." % [picked.size(), n])
			state_changed.emit()
	)


func _do_search_basic(p: Player, count: int) -> void:
	var basics: Array = []
	for cid in p.deck:
		var c: CardData = CardDB.get_card(cid)
		if c != null and c.is_unit() and c.stage == CardData.Stage.BASIC:
			basics.append(cid)
	if basics.is_empty():
		_log("  No Basic unit in the deck.")
		return

	_choose_from(p, "Choose up to %d Basic unit(s)" % count, basics, min(count, basics.size()),
		func(picked: Array):
			for cid in picked:
				var idx: int = p.deck.find(cid)
				if idx >= 0:
					p.deck.remove_at(idx)
					p.hand.append(cid)
					_log("  Finds %s." % CardDB.get_card(cid).name)
			p.deck.shuffle()
			state_changed.emit()
	)


func _do_search_random_evolved(p: Player) -> void:
	var pool_ids: Array = []
	for cid in p.deck:
		var c: CardData = CardDB.get_card(cid)
		if c != null and c.is_unit() and c.stage != CardData.Stage.BASIC:
			pool_ids.append(cid)
	if pool_ids.is_empty():
		_log("  No evolved unit in the deck.")
		return
	var pick: String = pool_ids[randi() % pool_ids.size()]
	p.deck.remove_at(p.deck.find(pick))
	p.hand.append(pick)
	p.deck.shuffle()
	_log("  Reveals %s at random." % CardDB.get_card(pick).name)


func _do_search_any_to_top(p: Player) -> void:
	if p.deck.is_empty():
		_log("  Deck is empty.")
		return
	p.deck.shuffle()
	var choices: Array = p.deck.duplicate()
	_choose_from(p, "Choose a card to put on top of your deck", choices, 1,
		func(picked: Array):
			if picked.is_empty():
				return
			var cid: String = picked[0]
			var idx: int = p.deck.find(cid)
			if idx >= 0:
				p.deck.remove_at(idx)
				p.deck.append(cid)      ## top of deck — drawn next turn
				_log("  Puts %s on top of the deck." % CardDB.get_card(cid).name)
			state_changed.emit()
	)


func _do_random_from_discard(p: Player) -> void:
	if p.discard.is_empty():
		_log("  Discard pile is empty.")
		return
	var i := randi() % p.discard.size()
	var cid: String = p.discard[i]
	p.discard.remove_at(i)
	p.hand.append(cid)
	_log("  Returns %s from the discard at random." % CardDB.get_card(cid).name)


func _do_dig_for_tower_support(p: Player) -> void:
	## Reveal until a tower support turns up; everything else shuffles back, so
	## a deck with none mills nothing.
	var skipped: Array = []
	var found := ""
	while not p.deck.is_empty():
		var cid: String = p.deck.pop_back()
		var c: CardData = CardDB.get_card(cid)
		if c != null and c.is_tower_support():
			found = cid
			break
		skipped.append(cid)
	for cid in skipped:
		p.deck.append(cid)
	p.deck.shuffle()
	if found == "":
		_log("  No tower support card in the deck.")
		return
	p.hand.append(found)
	_log("  Finds %s." % CardDB.get_card(found).name)


func _do_move_energy(target) -> void:
	var from: Unit = target[0]
	var to: Unit = target[1]
	var moved: int = from.attached
	from.attached = 0
	to.attached += moved
	_log("  Moves %d energy from %s to %s." % [moved, from.card.name, to.card.name])


func _do_ground_give(p: Player, u: Unit) -> void:
	var loc := p.find_unit(u)
	if loc[0] < 0:
		return
	var lost: int = u.attached
	u.attached = 0                       ## written off, not refunded
	_remove_and_return_to_hand(p, u, loc[0], loc[1])
	_log("  %s returns to hand. %d attached energy lost." % [u.card.name, lost])


func _do_swap_slots(p: Player, target) -> void:
	var a: Unit = target[0]
	var b: Unit = target[1]
	var la := p.find_unit(a)
	var lb := p.find_unit(b)
	if la[0] < 0 or lb[0] < 0:
		return
	p.boards[la[0]].slots[la[1]] = b
	p.boards[lb[0]].slots[lb[1]] = a
	_log("  Swaps %s and %s. Attached energy stays with each unit." % [a.card.name, b.card.name])


## Toppling Blow. Restricted to towers so it can never become a throne-burn
## plan — throne damage must come from units.
func _do_damage_tower(p: Player, enemy: Player, n: int, target) -> void:
	var bi := _tower_index(target)
	if bi < 0:
		## No explicit target: hit the first living enemy tower.
		for i in enemy.boards.size():
			if enemy.boards[i].tower_alive():
				bi = i
				break
	if bi < 0 or bi >= enemy.boards.size():
		_log("  No enemy tower to hit.")
		return
	var b: Board = enemy.boards[bi]
	if not b.tower_alive():
		_log("  That tower is already destroyed.")
		return
	var mods: Array = b.tower_mods.duplicate()
	var dealt := b.tower_take_damage(n)
	_log("  %d to the enemy tower (%d HP left)." % [dealt, b.tower_hp])
	if not b.tower_alive():
		_fire_spite_engine(enemy, bi, mods)


# ---------------------------------------------------------- end of turn

## Resolution order from CLAUDE.md:
##   1. queued attacks resolve left to right, board by board
##   2. end-of-turn effects (Decay, Tools)
##   3. towers fire
##   4. towers and thrones gain +5 max HP
##   5. pool decays 20%
##   6. discard down to the hand limit
func end_turn() -> void:
	if finished or in_setup():
		return
	var p: Player = me()
	_log("--- %s ends turn %d ---" % [p.display_name, turn])

	_resolve_attacks(p)
	if finished: return

	## Auto-firing units (Makeshift Tower) resolve WITH the volley at step 1 —
	## they are attacks, just ones that were never queued. After the queued
	## attacks, so a player's own sequencing still decides what is left standing.
	resolve_auto_fire(p, opponent_of(active))
	if finished: return

	_resolve_eot_effects(p)
	if finished: return

	_resolve_towers(p)
	if finished: return

	## Structures grow +5 ONCE PER ROUND, not once per player turn. `end_turn()` runs
	## twice a round, so calling this unconditionally here — as it did until 2026-08-09 —
	## granted +10 a round while every rule doc and balance note assumed +5. The round is
	## complete when the *second* player ends their turn, which is the non-active seat
	## relative to P1: active == P2 here means P1 has already gone.
	if active == P2:
		players[P1].grow_structures()
		players[P2].grow_structures()
		## Makeshift Tower grows on the same per-round clock as a real tower, and
		## for the same reason — putting it in the per-turn path would double it.
		grow_auto_towers(players[P1])
		grow_auto_towers(players[P2])

	var lost := p.apply_decay()
	if lost > 0:
		_log("Pool decays %d (now %d)." % [lost, p.pool])

	_enforce_hand_limit(p)


## Step 6: discard down to 10, choosing which cards to pitch. Checked here
## rather than continuously so a draw support played from a near-full hand
## still draws its full amount.
##
## The turn only advances once this resolves, because the discard prompt is
## asynchronous when a human is choosing.
func _enforce_hand_limit(p: Player) -> void:
	var over := p.over_hand_limit()
	if over <= 0:
		_advance_turn()
		return

	_log("%s is over the hand limit by %d." % [p.display_name, over])
	_choose_from(p, "Discard down to %d" % Player.MAX_HAND, p.hand.duplicate(), over,
		func(picked: Array):
			for cid in picked:
				var idx: int = p.hand.find(cid)
				if idx >= 0:
					p.discard_from_hand(idx)
			_log("  Discards %d to the hand limit." % picked.size())
			_advance_turn()
	)


func _resolve_attacks(p: Player) -> void:
	var enemy: Player = opponent_of(active)
	for bi in p.boards.size():
		var b: Board = p.boards[bi]
		for si in Board.SLOT_COUNT:
			var u: Unit = b.slots[si]
			if u == null or u.queued_attack == null or not u.is_alive():
				continue
			_execute_attack(p, enemy, u, bi, si)
			if finished:
				return
	_cleanup_dead(p)
	_cleanup_dead(enemy)


func _execute_attack(p: Player, enemy: Player, u: Unit, bi: int, si: int) -> void:
	var atk: AttackData = u.queued_attack
	u.clear_queue()

	## An attack's cost stays attached, but Consume destroys it on resolution.
	var burned := atk.consume_cost()
	if burned > 0:
		u.attached = max(0, u.attached - burned)
		_log("%s consumes %d energy (%d attached left)." % [u.card.name, burned, u.attached])

	_resolve_line_effects(p, enemy, u, atk, u.queued_target, bi, si)


## Everything a line does once it resolves, shared by attacks and abilities.
##
## `bi`/`si` are the unit's board and slot, needed for anything that fires down
## the lane. Abilities pass -1: they are activated in the main phase and none of
## them deal lane damage, so the board-position path is simply skipped for them.
func _resolve_line_effects(p: Player, enemy: Player, u: Unit, atk: AttackData,
		target = null, bi: int = -1, si: int = -1) -> void:
	## Non-damage / special lines
	if atk.has_effect("last_toll"):
		_do_last_toll(p, enemy, atk)
		return
	if atk.has_effect("reanimate"):
		_do_reanimate(p, atk)
		return
	if atk.has_effect("devour_friendly"):
		_do_devour(p, u, atk, target)
		return

	## Gaia: grow this unit's OWN Earth permanently. The aura is a live sum, so
	## this raises max HP and damage across the whole board — and it lands in
	## `earth_grown`, which Rise and evolution both reset (CLAUDE.md: Rise
	## restores the card, not the history).
	if atk.has_effect("grow_earth"):
		var n: int = atk.effect_value("grow_earth", 1)
		u.earth_grown += n
		_log("%s grows: Earth +%d (now %d, board %d)." % [
			u.card.name, n, u.earth(), earth_for(p)
		])
		refresh_aura(p)
		return

	## Gaia: consolidate a friendly unit's Earth onto another. Essence without the
	## death — it is how a board banks its grown Earth onto one survivor before a
	## wipe, which is the counterplay to the aura being killable.
	if atk.has_effect("move_earth"):
		_do_move_earth(p, u, target)
		return
	if atk.has_effect("eot_multiplier"):
		p.eot_multiplier = max(p.eot_multiplier, atk.effect_value("eot_multiplier", 1))
		_log("%s uses %s — end-of-turn effects trigger %dx." % [u.card.name, atk.name, p.eot_multiplier])

	## Void lines that move or destroy energy. These resolve BEFORE damage, so a
	## Siphon attack's own theft counts toward the Gap that its Rift then reads —
	## the two signatures compound within a single attack, which is the whole
	## point of printing them on the same card (`The Absence`).
	if atk.has_effect("siphon"):
		_do_siphon(p, enemy, u, atk.effect_value("siphon", 0), bi, si)
	var voided: int = 0
	if atk.has_effect("void_energy"):
		voided = _do_void_energy(p, enemy, u, atk.effect_value("void_energy", 0), bi, si)
	if atk.has_effect("void_pool_pct"):
		_do_void_pool(p, enemy, atk.effect_value("void_pool_pct", 20))
	if atk.has_effect("gap_throne_damage"):
		_do_gap_throne(p, enemy, u, atk)
		return

	## Damage, if any: hits the slot directly across. A Tool may add to it.
	## Only a queued attack has a lane position; abilities never reach this.
	if atk.damage > 0 and bi >= 0:
		var dmg: int = atk.damage + u.tool_damage_bonus()

		## Earth: the attacker's board-wide aura adds +1 damage per point (at the
		## current rate). Read at resolution like Rift, and for the same reason —
		## the board can change between queueing and resolving, and both players
		## can see it.
		var earth_bonus: int = earth_for(p) * earth_rate(p)
		if earth_bonus > 0:
			dmg += earth_bonus
			_log("  Earth %d: +%d damage." % [earth_for(p), earth_bonus])

		## Rift N: +N damage per point of Gap. Read at resolution rather than at
		## queue time, so the number the player sees when they commit can move —
		## which is correct, because the Gap is public and both players act on it.
		if u.has_rift():
			var bonus: int = u.rift() * gap_for(p)
			if bonus > 0:
				dmg += bonus
				_log("  Rift %d: +%d damage (Gap %d)." % [u.rift(), bonus, gap_for(p)])

		## A rider that pays per energy destroyed. Zero against an uncharged
		## body, which is what makes Void efficient against the committed and
		## weak against the empty board.
		if voided > 0 and atk.has_effect("damage_per_voided"):
			var per: int = atk.effect_value("damage_per_voided", 0)
			dmg += per * voided
			_log("  %d energy unmade: +%d damage." % [voided, per * voided])

		_deal_lane_damage(p, enemy, u, bi, si, dmg, atk)

	## Rider effects
	if atk.has_effect("also_hit_tower") and bi >= 0:
		var eb: Board = enemy.boards[bi]
		var n := atk.effect_value("also_hit_tower", 0)
		if eb.tower_alive():
			var mods: Array = eb.tower_mods.duplicate()
			var dealt := eb.tower_take_damage(n)
			_log("  %s hits the enemy tower for %d (tower %d)." % [atk.name, dealt, eb.tower_hp])
			if not eb.tower_alive():
				_fire_spite_engine(enemy, bi, mods)
		else:
			var dealt2 := enemy.throne_take_damage(n)
			_log("  %s hits the enemy throne for %d (throne %d)." % [atk.name, dealt2, enemy.throne_hp])
			_check_throne(enemy)

	if atk.has_effect("gain_energy"):
		var g := atk.effect_value("gain_energy", 0)
		p.gain_energy(g)
		_log("  %s refunds %d energy (pool %d)." % [atk.name, g, p.pool])

	if atk.has_effect("gain_if_death") and p.unit_died_this_turn:
		var g2 := atk.effect_value("gain_if_death", 0)
		p.gain_energy(g2)
		_log("  A friendly unit died — %s gains %d energy." % [atk.name, g2])

	if atk.has_effect("return_from_discard"):
		_return_unit_from_discard(p, atk.effect_value("return_from_discard", 1))

	if atk.has_effect("self_destruct"):
		u.dies_at_eot = true
		_log("  %s will die at end of turn." % u.card.name)

	## ---- Heaven ----------------------------------------------------------

	## The Ledger Closes — damage every enemy unit on one board. It does not kill on
	## its own; it pushes a whole board *into Judgment execute range* at once, which
	## is what the Seraph's attack then cashes in.
	if atk.has_effect("damage_enemy_board"):
		var n3: int = atk.effect_value("damage_enemy_board", 15)
		var tb: int = 0
		if target is int:
			tb = clampi(int(target), 0, enemy.boards.size() - 1)
		elif bi >= 0:
			tb = bi
		var eboard: Board = enemy.boards[tb]
		for si2 in Board.SLOT_COUNT:
			var v: Unit = eboard.slots[si2]
			if v != null and v.is_alive():
				var d3: int = _damage_unit(v, n3, atk.name)
				_log("  %s: %d to %s (%d HP left)." % [atk.name, d3, v.card.name, max(0, v.hp)])
		_cleanup_dead(enemy)

	## The Gate Opens — throne damage proportional to enemy units killed this turn.
	## Deliberately breaks the shielding rule (CLAUDE.md: living units shield the
	## structures behind them), but only in proportion to bodies actually cleared, so
	## it is a *reward for clearing* rather than a bypass. This is Heaven's pressure
	## valve — without it the faction never converts durability into a win.
	if atk.has_effect("throne_per_kill"):
		var per: int = atk.effect_value("throne_per_kill", 15)
		var kills: int = enemy.units_died_this_turn
		if kills > 0:
			var total: int = per * kills
			enemy.throne_take_damage(total)
			_log("*** The Gate Opens: %d kill(s) x %d = %d to the enemy THRONE (%d HP left)." % [kills, per, total, enemy.throne_hp])
			_check_throne(enemy)
		else:
			_log("  The Gate Opens: no enemy unit died this turn — no throne damage.")

	## Recall the Verdict — the Bellringer recharges itself. One attack line doing two
	## jobs is the brake: it can never execute and recharge in the same turn.
	if atk.has_effect("restore_own_judgment"):
		u.judgment_spent = false
		_log("  %s recalls its Judgment." % u.card.name)

	## Ring the Court Bell — board-wide reset. Reads *printed* keywords only, so a unit
	## granted Judgment by a Tool or support card is deliberately not refreshed;
	## otherwise granting widely and resetting board-wide is an uncapped loop.
	if atk.has_effect("restore_board_judgment"):
		var n_restored: int = 0
		for v2 in p.all_units():
			if v2.card.has_kw("judgment") and v2.judgment_spent:
				v2.judgment_spent = false
				n_restored += 1
		_log("  The Court rings: Judgment restored to %d unit(s)." % n_restored)


## Apply a defender's Resist to one instance of incoming damage.
##
## The minimum of 1 is not optional: without it a Resist 5 body makes Hel's
## Decay 5 do literally nothing, permanently, and no amount of stacking fixes it
## (CLAUDE.md). Resist runs AFTER Sanctuary — Sanctuary is prevention and absorbs
## whole instances, so it must see the full amount.
func _apply_resist(target: Unit, amount: int) -> int:
	if amount <= 0:
		return amount
	var r: int = target.resist()
	if r <= 0:
		return amount
	return max(1, amount - r)


## Apply damage to a unit through its Sanctuary. Every non-attack damage source
## routes through here so the shield genuinely blocks all sources, per CLAUDE.md.
## Returns damage actually dealt to HP (0 if fully absorbed).
func _damage_unit(target: Unit, amount: int, source_label: String) -> int:
	if amount <= 0:
		return 0
	var had: bool = target.sanctuary_active
	var through: int = target.absorb(amount)
	if had and through < amount:
		_log("  Sanctuary absorbs %d from %s on %s." % [amount, source_label, target.card.name])
		return 0
	return target.take_damage(_apply_resist(target, through))


## The targeting rule: slot across -> leftmost living unit -> tower -> throne.
##
## Living units shield the structures behind them: while anything on the enemy
## board is alive, this attack can only hit a unit. The redirect is deterministic
## (leftmost, no choice) so the rule adds durability without adding free
## targeting, which placement-as-targeting forbids.
##
## Shielding never crosses boards — everything here reads `enemy.boards[bi]`.
func _deal_lane_damage(p: Player, enemy: Player, u: Unit, bi: int, si: int, dmg: int, atk: AttackData) -> void:
	var eb: Board = enemy.boards[bi]

	## 1. The slot directly across, if someone living is standing in it.
	var defender: Unit = eb.unit_at(si)
	if defender == null or not defender.is_alive():
		## 2. Otherwise redirect to the leftmost survivor. A unit killed earlier
		## in this same resolution is not alive, so it is skipped — that is the
		## no-overkill rule, and it needs no separate bookkeeping.
		defender = eb.leftmost_living_unit()
		if defender != null:
			_log("  No unit across — %s redirects to %s." % [atk.name, defender.card.name])

	if defender != null:
		## --- Step 2: Sanctuary absorbs before anything lands. Prevention has to come
		## first or a unit could die, be saved by Judgment, and only then discover it
		## held a shield that would have stopped the hit outright.
		var incoming: int = dmg
		var had_sanctuary: bool = defender.sanctuary_active
		var through: int = defender.absorb(incoming)
		if had_sanctuary and through < incoming:
			if defender.sanctuary_active:
				_log("  Sanctuary absorbs %d (%d pool left on %s)." % [incoming, defender.sanctuary_pool, defender.card.name])
			else:
				_log("  Sanctuary absorbs %d and is spent on %s." % [incoming, defender.card.name])

		## --- Step 3a: Resist blunts what Sanctuary let through, floored at 1.
		var dealt := defender.take_damage(_apply_resist(defender, through))
		_record_damage(p, u.card.id, "unit", dealt)
		_log("%s uses %s: %d to %s (%d HP left)." % [u.card.name, atk.name, dealt, defender.card.name, max(0, defender.hp)])

		## --- Step 4: defensive Judgment. A unit that would die survives at N instead.
		## Checked before the offensive half so the Heaven mirror resolves by ordering
		## rather than by a special-case tiebreak rule.
		if defender.hp <= 0 and defender.has_judgment():
			defender.hp = defender.judgment()
			defender.judgment_spent = true
			_log("  Judgment: %s survives at %d HP. Its charge is spent." % [defender.card.name, defender.hp])

		## --- Step 5: offensive Judgment. Anything left standing at or below the
		## attacker's N is executed.
		##
		## `elif` matters: a unit whose Judgment just saved it at step 4 sits at exactly
		## N, which would otherwise satisfy this check for any attacker with an equal or
		## larger N and immediately delete the save it just made.
		elif defender.hp > 0 and u.has_judgment() and defender.hp <= u.judgment():
			_log("  Judgment: %s executes %s at %d HP." % [u.card.name, defender.card.name, defender.hp])
			defender.hp = 0
			u.judgment_spent = true
			## The execute is itself a death, so the defender's own Judgment may still
			## save it — both charges spend and the body lives at N.
			if defender.has_judgment():
				defender.hp = defender.judgment()
				defender.judgment_spent = true
				_log("  Judgment: %s survives the execute at %d HP. Both charges spent." % [defender.card.name, defender.hp])

		## --- Step 6: Retribution fires back at the attacker. Iron Standard stacks with
		## the defender's printed value. A unit marked dead still deals its recoil —
		## nothing leaves the board until _cleanup_dead runs after the whole volley.
		## `Resist X` reads "reduce each incoming instance of damage" — recoil is an
		## instance, so it is resisted. Sanctuary is deliberately NOT applied here:
		## this line has always bypassed it, `CLAUDE.md` says it should not, and
		## changing it would alter Heaven's behaviour. Recorded in gaia.md instead.
		var retr: int = defender.total_retribution()
		if retr > 0:
			var r := u.take_damage(_apply_resist(u, retr))
			_log("  Retribution: %s takes %d back (%d HP left)." % [u.card.name, r, max(0, u.hp)])
		return

	## 3./4. The board is clear, so the structures are reachable.
	if eb.tower_alive():
		var mods: Array = eb.tower_mods.duplicate()
		var dealt2 := eb.tower_take_damage(dmg)
		_record_damage(p, u.card.id, "tower", dealt2)
		_log("%s uses %s: %d to the enemy tower (%d HP left)." % [u.card.name, atk.name, dealt2, eb.tower_hp])
		if not eb.tower_alive():
			_fire_spite_engine(enemy, bi, mods)
		return

	var dealt3 := enemy.throne_take_damage(dmg)
	_record_damage(p, u.card.id, "throne", dealt3)
	_log("%s uses %s: %d to the enemy THRONE (%d HP left)." % [u.card.name, atk.name, dealt3, enemy.throne_hp])
	_check_throne(enemy)


func _resolve_eot_effects(p: Player) -> void:
	var enemy: Player = opponent_of(active)
	var mult: int = p.eot_multiplier
	if mult > 1:
		_log("End-of-turn effects trigger %dx." % mult)

	for rep in mult:
		for bi in p.boards.size():
			var b: Board = p.boards[bi]
			for si in Board.SLOT_COUNT:
				var u: Unit = b.slots[si]
				if u == null or not u.is_alive() or u.decay() <= 0:
					continue
				_deal_decay(p, enemy, u, bi, si)
				if finished:
					return

	## End-of-turn *triggered* abilities. Distinct from activated abilities: these
	## fire automatically and are not subject to the once-per-turn activation limit,
	## because the turn boundary is itself the limit. Currently only Rekindle.
	for u in p.all_units():
		if not u.is_alive():
			continue
		for ab in u.card.ability_lines():
			if ab.has_effect("eot_restore_sanctuary"):
				u.restore_sanctuary()
				_log("%s rekindles its Sanctuary." % u.card.name)

	_resolve_tool_effects(p)

	## Final Verdict self-kills
	for u in p.all_units():
		if u.dies_at_eot:
			u.hp = 0
			_log("%s dies to its own attack." % u.card.name)

	_cleanup_dead(p)
	_cleanup_dead(enemy)


## Tools that pay out at end of turn: Bone Splint heals, Ration Pack moves one
## energy off the decaying pool onto the body carrying it.
func _resolve_tool_effects(p: Player) -> void:
	for unit_any in p.all_units():
		var u: Unit = unit_any
		if u.tool == null or not u.is_alive():
			continue
		if u.tool.has_effect("heal_eot"):
			var h: int = heal_unit(p, u, u.tool.effect_value("heal_eot", 0))
			if h > 0:
				_log("%s heals %s for %d." % [u.tool.name, u.card.name, h])
		if u.tool.has_effect("pool_to_unit_eot"):
			var n: int = min(u.tool.effect_value("pool_to_unit_eot", 1), p.pool)
			if n > 0:
				p.pool -= n
				u.attached += n
				_log("%s moves %d energy onto %s (attached %d)." % [u.tool.name, n, u.card.name, u.attached])


## Decay is lane damage and follows the same targeting chain as an attack:
## across -> leftmost living unit -> tower -> throne. Living units shield the
## structures from it too, so a Decay board cannot chip a throne past a wall.
func _deal_decay(p: Player, enemy: Player, u: Unit, bi: int, si: int) -> void:
	var n := u.decay()
	var eb: Board = enemy.boards[bi]

	var defender: Unit = eb.unit_at(si)
	if defender == null or not defender.is_alive():
		defender = eb.leftmost_living_unit()

	if defender != null:
		var dealt := _damage_unit(defender, n, "Decay")
		defender.decay_taken_this_turn += dealt    ## Reconsecrate undoes this
		_log("Decay %d: %s -> %s (%d HP left)." % [n, u.card.name, defender.card.name, max(0, defender.hp)])
	elif eb.tower_alive():
		eb.tower_take_damage(n)
		_log("Decay %d: %s -> enemy tower (%d HP left)." % [n, u.card.name, eb.tower_hp])
	else:
		enemy.throne_take_damage(n)
		_log("Decay %d: %s -> enemy THRONE (%d HP left)." % [n, u.card.name, enemy.throne_hp])
		_check_throne(enemy)


## Towers fire at the unit directly in front, falling back to the leftmost living
## unit. Against a board with nothing alive on it they chip that board's
## structures at a QUARTER rate — see `_tower_strike`.
func _resolve_towers(p: Player) -> void:
	var base := tower_damage()
	for side in [active, 1 - active]:
		var owner: Player = players[side]
		var enemy: Player = players[1 - side]
		for bi in owner.boards.size():
			var b: Board = owner.boards[bi]
			if not b.tower_alive():
				continue
			## The Earth aura buffs the tower's main shot. It flows through
			## `_tower_strike`'s half-rate rule like any other damage, so it raises
			## the number the half is taken FROM and never the rate itself —
			## CLAUDE.md's hard line on tower support is untouched.
			var aura: int = earth_for(owner) * earth_rate(owner)
			_tower_strike(owner, enemy, bi, base + b.tower_damage_bonus + aura, "tower fire")

			## Crossfire reaches the *other* enemy board. Stacked copies each
			## fire, so the total is summed into one strike rather than several
			## log lines. It follows the same chain as the main shot, structures
			## included — the quarter rate is what makes that safe.
			var cross: int = b.mod_total("tower_crossfire", 5)
			if cross > 0:
				_tower_strike(owner, enemy, 1 - bi, cross, "tower crossfire")
	_cleanup_dead(players[P1])
	_cleanup_dead(players[P2])


## One tower shot against enemy board `bi`, resolved through the standard
## targeting chain: facing slot -> leftmost living unit -> tower -> throne.
##
## Units take the full amount. STRUCTURES TAKE HALF (floor, min 1), which is the
## whole reason a tower is allowed to reach them at all — full-rate tower fire is
## the two-structures-racing case the rules exist to prevent. The halving is taken
## after `tower_damage_bonus` is folded in, so a Murder Holes stack scales the chip
## too, at half of its printed value.
func _tower_strike(owner: Player, enemy: Player, bi: int, dmg: int, label: String) -> void:
	if dmg <= 0:
		return
	var eb: Board = enemy.boards[bi]

	var target: Unit = eb.unit_at(Board.TOWER_SLOT)
	if target == null or not target.is_alive():
		target = eb.leftmost_living_unit()
	var owner_idx: int = 0 if owner == players[P1] else 1
	if target != null:
		var dealt := _damage_unit(target, dmg, label)
		tower_damage_dealt[owner_idx] += dealt
		_log("%s's %s: %d to %s (%d HP left)." % [owner.display_name, label, dealt, target.card.name, max(0, target.hp)])
		return

	## Nothing alive on that board — chip the structures behind it.
	var chip: int = max(1, dmg / 2)
	if eb.tower_alive():
		tower_damage_dealt[owner_idx] += eb.tower_take_damage(chip)
		_log("%s's %s: %d to the enemy tower on board %d (%d HP left)." % [owner.display_name, label, chip, bi + 1, eb.tower_hp])
	else:
		tower_damage_dealt[owner_idx] += enemy.throne_take_damage(chip)
		_log("%s's %s: %d to the enemy THRONE (%d HP left)." % [owner.display_name, label, chip, enemy.throne_hp])
		_check_throne(enemy)


## Towers are silent through round 1, fire 5 at the end of round 2, and gain 3 a round
## after that: 0, 5, 8, 11, 14, ...
##
## The grace round exists because both players open with an empty board — under the old
## `5 * turn` a tower fired before anyone had deployed, into a board the half-rate rule
## then chipped, and it landed hardest on whoever presented a board first. The first shot
## is a flat 5 rather than the curve's own value at round 2, so the tower's opening number
## is legible and pairs with the 55 HP it has grown to by then.
func tower_damage() -> int:
	if turn < 2:
		return 0
	return 5 + 3 * (turn - 2)


# ---------------------------------------------------------------- deaths

func _cleanup_dead(p: Player) -> void:
	var any_died: bool = false
	for bi in p.boards.size():
		var b: Board = p.boards[bi]
		for si in Board.SLOT_COUNT:
			var u: Unit = b.slots[si]
			if u == null or u.is_alive():
				continue
			_kill(p, b, si, u)
			any_died = true
	## A death shrinks the Earth aura, so towers give back their share and any
	## unit now sitting above its lowered ceiling is clamped. Only when something
	## actually died — this runs constantly and the aura is otherwise unchanged.
	if any_died:
		refresh_aura(p)


## The nearest living friendly unit to slot `si` on board `b`, or null.
##
## Nearest is by slot distance, ties going LEFT — the same leftmost-wins tiebreak
## the targeting chain uses, so there is one rule for "which unit" in the game.
## Strictly per-board: no rule in this game crosses boards, and crossing would
## make Essence best at exactly the moment it should fail, when the board it
## defended has been cleared (gaia.md).
func _nearest_living_on_board(b: Board, si: int) -> Unit:
	var best: Unit = null
	var best_d: int = 99
	for i in Board.SLOT_COUNT:
		if i == si:
			continue
		var u: Unit = b.slots[i]
		## `is_alive()` is what implements "only to a survivor": in a batched
		## death the other corpses are still sitting in their slots until
		## `_cleanup_dead` reaches them, and Essence must not chain through one.
		if u == null or not u.is_alive():
			continue
		var d: int = abs(i - si)
		if d < best_d:
			best_d = d
			best = u
	return best


## `Essence N` — pay N from the pool to move a dying unit's Earth and attached
## energy to the nearest living friendly unit on the same board.
##
## This is the deliberate exception to "attached energy is lost when the unit
## dies" (CLAUDE.md). It is priced rather than free: the energy must have been
## banked BEFORE the death, so a board wipe still lands — you can only afford one
## or two funerals. Gaia has no ramp, which is what makes carrying the energy
## forward necessary rather than greedy.
##
## The rule is "you MAY pay", so the owner is prompted. `_choose_from`
## auto-resolves for AI players and headless harnesses, taking the first option —
## which is why "pay" is listed first.
##
## Returns true if the transfer happened.
func _try_essence(p: Player, b: Board, si: int, u: Unit) -> bool:
	if not u.has_essence():
		return false
	var cost: int = u.essence()
	if p.pool < cost:
		return false
	## Nothing to pass on is not a decision worth interrupting for.
	if u.attached <= 0 and u.earth() <= 0:
		return false
	var heir: Unit = _nearest_living_on_board(b, si)
	if heir == null:
		return false

	var carried_energy: int = u.attached
	var carried_earth: int = u.earth()

	## `_choose_from` is callback-based and resolves SYNCHRONOUSLY for AI players
	## and for any caller with no picker attached (headless harnesses) — it calls
	## `done` inline in those cases. That matters here: `_kill` runs inside
	## `_cleanup_dead`'s board sweep, so the answer has to land before the death
	## finishes resolving. A human with the picker attached gets the prompt.
	##
	## PAY is deliberately first: the headless path takes `choices.slice(0, n)`,
	## so the auto-resolved answer is the affirmative one.
	var pay_label := "Pay %d: pass %d energy and %d Earth to %s" % [
		cost, carried_energy, carried_earth, heir.card.name
	]
	## Boxed in an Array because a GDScript lambda captures locals BY VALUE —
	## assigning a plain `bool` inside the callback would be invisible out here.
	var answer: Array = [false]
	_choose_from(p, "Essence — %s is dying" % u.card.name,
		[pay_label, "Decline"], 1,
		func(picked: Array) -> void:
			answer[0] = picked.size() > 0 and picked[0] == pay_label
	)
	if not answer[0]:
		return false

	p.pool -= cost
	heir.attached += carried_energy
	heir.earth_grown += carried_earth
	u.attached = 0
	_log("  Essence: %s pays %d to pass %d energy and %d Earth to %s." % [
		u.card.name, cost, carried_energy, carried_earth, heir.card.name
	])
	return true


func _kill(p: Player, b: Board, si: int, u: Unit) -> void:
	## Essence moves the investment off the body BEFORE the slot is cleared and
	## before Toll's log line reads `u.attached` — the energy is passed on, not
	## lost, and the "N attached energy lost" message has to reflect that.
	_try_essence(p, b, si, u)

	b.slots[si] = null
	p.unit_died_this_turn = true
	p.units_died_this_turn += 1

	## A Tool goes to the discard with the body it was attached to.
	if u.tool != null:
		p.discard.append(u.tool.id)
		_log("  %s is discarded with %s." % [u.tool.name, u.card.name])
		u.tool = null

	## The stages underneath a dead evolved unit go to the discard with it.
	for base_id in u.evolution_path:
		p.discard.append(base_id)

	## Toll pays into the pool — immediately exposed to decay.
	var t := u.toll()
	if t > 0:
		p.gain_energy(t)
		_log("%s dies. Toll %d (pool %d). %d attached energy lost." % [u.card.name, t, p.pool, u.attached])
	else:
		_log("%s dies. %d attached energy lost." % [u.card.name, u.attached])

	if u.has_rise():
		p.pending_rise.append(u.make_risen())
		_log("  %s will Rise next turn at half HP." % u.card.name)
	else:
		p.discard.append(u.card.id)


func _check_throne(p: Player) -> void:
	if p.throne_hp <= 0 and not finished:
		finished = true
		winner = P1 if p == players[P2] else P2
		_log("*** %s's throne falls. %s wins! ***" % [p.display_name, players[winner].display_name])
		game_over.emit(winner)


# ---------------------------------------------------------- special attacks

func _do_last_toll(p: Player, enemy: Player, atk: AttackData) -> void:
	var per := atk.effect_value("last_toll", 15)
	_log("*** THE LAST TOLL ***")

	var count := p.all_units().size() + enemy.all_units().size()

	## Kill everything. Friendly Tolls still pay out.
	for side_player in [p, enemy]:
		for bi in side_player.boards.size():
			var b: Board = side_player.boards[bi]
			for si in Board.SLOT_COUNT:
				var u: Unit = b.slots[si]
				if u != null:
					u.hp = 0
		_cleanup_dead(side_player)

	var dmg := per * count
	_log("  %d units destroyed -> %d damage to the enemy throne." % [count, dmg])
	enemy.throne_take_damage(dmg)
	_check_throne(enemy)


func _do_reanimate(p: Player, atk: AttackData) -> void:
	var n := atk.effect_value("reanimate", 2)
	var brought := 0
	for i in n:
		var slot_info := _find_empty_slot(p)
		if slot_info[0] < 0:
			break
		var idx := _last_unit_in_discard(p)
		if idx < 0:
			break
		var cid: String = p.discard[idx]
		p.discard.remove_at(idx)
		var b: Board = p.boards[slot_info[0]]
		b.place(Unit.new(CardDB.get_card(cid)), slot_info[1])
		brought += 1
		_log("  Claim the Fallen returns %s to the board." % CardDB.get_card(cid).name)
	if brought == 0:
		_log("  Claim the Fallen finds nothing to return.")


## `target` is the friendly unit to devour. When none is given — the AI, and any
## caller with no UI to pick with — the unit holding the most attached energy is
## chosen, since rescuing the largest investment is the reason to play the card.
## ---------------------------------------------------------------- Void: theft
##
## `Siphon N` — MOVE up to N attached energy from an enemy unit onto this one.
##
## Target selection mirrors the lane-damage chain rather than inventing a second
## targeting rule: the slot across first, then the leftmost living unit. Unlike
## damage it never falls through to a tower or throne — structures hold no
## attached energy, so a Siphon into an empty board simply does nothing.
##
## The energy lands on the siphoning unit, not in the pool. That is the faction's
## self-cost: stolen energy sits on a body that can die holding it, and Void
## therefore carries the most vulnerable energy on the board.
func _do_siphon(p: Player, enemy: Player, u: Unit, n: int, bi: int, si: int) -> int:
	if n <= 0 or bi < 0:
		return 0
	var victim: Unit = _energy_target(enemy, bi, si)
	if victim == null:
		_log("  Siphon finds nothing to take.")
		return 0
	var taken: int = min(n, victim.attached)
	if taken <= 0:
		_log("  Siphon: %s holds no energy." % victim.card.name)
		return 0
	victim.attached -= taken
	u.attached += taken
	_log("  Siphon %d: %s takes %d energy from %s." % [n, u.card.name, taken, victim.card.name])
	return taken


## `Void N` — DESTROY up to N attached energy on an enemy unit. Takes nothing
## back, which is why it is priced below Siphon on the same body: it is the
## meaner effect for the opponent but the weaker one for you.
func _do_void_energy(p: Player, enemy: Player, u: Unit, n: int, bi: int, si: int) -> int:
	if n <= 0 or bi < 0:
		return 0
	var victim: Unit = _energy_target(enemy, bi, si)
	if victim == null or victim.attached <= 0:
		return 0
	var burned: int = min(n, victim.attached)
	victim.attached -= burned
	_log("  Void %d: %d energy unmade on %s." % [n, burned, victim.card.name])
	return burned


## The one rule-breaker: destruction aimed at the POOL rather than at a body.
## `CLAUDE.md` makes attached energy the default target for Void's denial, so
## this exists as a printed exception on a single Stage 2 — worthless early when
## nobody is banking, devastating late against a hoarder. Percentage-based so it
## scales with what is actually there, exactly like the 20% end-of-turn decay it
## is modelled on.
func _do_void_pool(p: Player, enemy: Player, pct: int) -> int:
	var loss: int = max(2, int(floor(enemy.pool * pct / 100.0)))
	loss = min(loss, enemy.pool)
	if loss <= 0:
		return 0
	enemy.pool -= loss
	_log("  The pool is unmade: %s loses %d energy (%d left)." % [enemy.display_name, loss, enemy.pool])
	return loss


## Shared target picker for Siphon and Void: slot across, else leftmost living.
## Deliberately the same deterministic chain as damage, so energy denial cannot
## reach past a shield that damage could not.
func _energy_target(enemy: Player, bi: int, si: int) -> Unit:
	var eb: Board = enemy.boards[bi]
	var t: Unit = eb.unit_at(si)
	if t == null or not t.is_alive():
		t = eb.leftmost_living_unit()
	return t


## `Silence Eternal` — the faction's win condition. Converts the Gap into throne
## damage, which is the one thing Rift cannot do (Rift only ever adds to a lane
## attack, and lane attacks are stopped by shielding).
##
## This does NOT break the shielding rule: it still routes through the ordinary
## targeting chain, so the enemy board must already be clear for it to reach the
## throne at all. What it breaks is the damage curve, and only in proportion to a
## Gap the player had to build.
func _do_gap_throne(p: Player, enemy: Player, u: Unit, atk: AttackData) -> void:
	var per: int = atk.effect_value("gap_throne_damage", 0)
	var cap: int = atk.effect_value("gap_throne_max", 100)
	var dmg: int = min(cap, per * gap_for(p))
	if dmg <= 0:
		_log("%s uses %s — no Gap, no effect." % [u.card.name, atk.name])
		return
	var dealt := enemy.throne_take_damage(dmg)
	_log("%s uses %s: %d to the enemy THRONE (Gap %d, %d HP left)." % [
		u.card.name, atk.name, dealt, gap_for(p), enemy.throne_hp])
	_check_throne(enemy)


func _do_devour(p: Player, u: Unit, _atk: AttackData, target = null) -> void:
	var best: Unit = null

	if target is Unit and target != u and target.is_alive() and p.all_units().has(target):
		best = target
	else:
		for other in p.all_units():
			if other == u:
				continue
			if best == null or other.attached > best.attached:
				best = other

	if best == null:
		_log("  Consume the Fallen has no friendly unit to devour.")
		return

	var moved := best.attached
	u.attached += moved
	best.attached = 0
	best.hp = 0
	_log("  Consume the Fallen devours %s, moving %d energy to %s." % [best.card.name, moved, u.card.name])
	_cleanup_dead(p)     ## still triggers Toll


## Vernal Rite: move every point of GROWN Earth from a friendly unit onto this
## one. Essence without the death — the way a board consolidates its accumulated
## Earth onto one survivor before a wipe takes all of it.
##
## Only `earth_grown` moves, never the printed value: printed Earth is a property
## of the card, and moving it would let a board strip its own chaff for a stat
## line those bodies never stopped having. Grown Earth is the *investment*, and
## the investment is what this card rescues.
##
## The board total is unchanged by a move — this is not ramp, it is insurance
## against the aura being killed piecemeal.
func _do_move_earth(p: Player, u: Unit, target = null) -> void:
	var src: Unit = null

	if target is Unit and target != u and target.is_alive() and p.all_units().has(target):
		src = target
	else:
		## No pick: take from whoever has the most to lose.
		for other in p.all_units():
			if other == u or not other.is_alive():
				continue
			if other.earth_grown <= 0:
				continue
			if src == null or other.earth_grown > src.earth_grown:
				src = other

	if src == null or src.earth_grown <= 0:
		_log("  %s has no friendly unit holding grown Earth." % u.card.name)
		return

	var moved: int = src.earth_grown
	src.earth_grown = 0
	u.earth_grown += moved
	_log("  %s draws %d Earth from %s (board total unchanged at %d)." % [
		u.card.name, moved, src.card.name, earth_for(p)
	])
	refresh_aura(p)


func _return_unit_from_discard(p: Player, n: int) -> void:
	for i in n:
		var idx := _last_unit_in_discard(p)
		if idx < 0:
			return
		var cid: String = p.discard[idx]
		p.discard.remove_at(idx)
		p.hand.append(cid)
		_log("  Scavenge returns %s to hand." % CardDB.get_card(cid).name)


func _last_unit_in_discard(p: Player) -> int:
	for i in range(p.discard.size() - 1, -1, -1):
		var c: CardData = CardDB.get_card(p.discard[i])
		if c != null and c.is_unit():
			return i
	return -1


func _find_empty_slot(p: Player) -> Array:
	for bi in p.boards.size():
		var b: Board = p.boards[bi]
		var s := b.first_empty_slot()
		if s >= 0:
			return [bi, s]
	return [-1, -1]


# ---------------------------------------------------------------- turn flow

func _advance_turn() -> void:
	active = 1 - active
	if active == P1:
		turn += 1                    ## a full round has passed
	_begin_turn_for(me())
	state_changed.emit()


func _begin_turn_for(p: Player) -> void:
	p.begin_turn()

	## Rise: returned units come back at the start of your next turn.
	if not p.pending_rise.is_empty():
		var still_waiting: Array = []
		for u in p.pending_rise:
			var slot_info := _find_empty_slot(p)
			if slot_info[0] < 0:
				still_waiting.append(u)
				continue
			p.boards[slot_info[0]].place(u, slot_info[1])
			_log("%s Rises at %d HP." % [u.card.name, u.hp])
		p.pending_rise = still_waiting

	var drawn := p.draw(Player.DRAW_PER_TURN)
	if drawn.is_empty() and p.deck_out():
		_log("%s has no cards left to draw." % p.display_name)

	_log("=== %s's turn (round %d) ===" % [p.display_name, turn])

	## Locked attacks re-queue themselves now, after the draw, so the whole turn
	## is spent adjusting a board that is already set rather than re-clicking it.
	_fire_locked_attacks(p)


## Re-queue the attack each locked unit used last turn.
##
## This is a convenience, never a rule change: it queues only attacks the player
## could have queued by hand, it pays the same pool cost through the same path,
## and anything it queues can still be cancelled. A unit whose attack is no
## longer affordable is skipped silently and simply does not fire — the lock
## never spends energy the player was saving for something else beyond the
## attack's own printed cost.
##
## Abilities are deliberately excluded. They resolve immediately and some destroy
## attached energy, so auto-firing them could burn an investment the player was
## holding. Abilities stay a manual decision.
func _fire_locked_attacks(p: Player) -> void:
	var fired: Array[String] = []

	for unit_any in p.all_units():
		var u: Unit = unit_any
		if u.queued_attack != null or u.last_attack == null:
			continue
		if not u.is_attack_locked(p.auto_lock_attacks):
			continue

		## The remembered attack must still be a line on the card this unit is
		## currently showing — evolution clears it, but a Tool's cost penalty can
		## also put it out of reach.
		if not u.card.attack_lines().has(u.last_attack):
			continue
		if u.pool_needed(u.last_attack) > p.pool:
			continue

		if queue_attack(p, u, u.last_attack):
			fired.append("%s > %s" % [u.card.name, u.last_attack.name])

	if not fired.is_empty():
		_log("[L] Locked attacks re-queued: %s" % ", ".join(fired))


## Called once by the combat screen. Opens the setup phase rather than round 1 —
## `finish_setup` for both players is what starts the game proper.
func start() -> void:
	_log("=== Setup — mulligan, then place your Basics ===")
	state_changed.emit()


# ----------------------------------------------------------------- setup phase
#
# Before round 1 both players deploy Basics for free. Deployment only: no energy, no
# supports, no evolution, no attacks. See CLAUDE.md's Setup section for why — briefly,
# turn 1 was otherwise spent on the one move every deck makes identically, and the
# player who deployed first ate a tower shot the other did not yet face.
#
# Deployment is not interactive between the players: neither side's setup reacts to the
# other's, because placement decides facing and a player who could counter-place would
# be handed the whole targeting geometry.

func in_setup() -> bool:
	return phase == Phase.SETUP


## Jump straight to round 1 with whatever board is already there.
##
## For harnesses that place units directly and drive the rules API — they are testing
## the damage pipeline, not deployment, and every main-phase call is gated on the phase.
## Deliberately NOT used by the AI-vs-AI harnesses: those play a whole game and should
## go through the real setup, since setup deployment is part of what they measure.
func skip_setup() -> void:
	phase = Phase.PLAYING
	setup_done = [true, true]


## Mulligan during setup. Legal only before this player has deployed anything —
## the decision is meant to be made on the hand alone.
func mulligan(p: Player) -> bool:
	if not in_setup():
		return false
	var idx: int = 0 if p == players[P1] else 1
	if setup_done[idx]:
		return false
	if not p.all_units().is_empty():
		return false
	if not p.mulligan():
		return false
	_log("%s mulligans." % p.display_name)
	state_changed.emit()
	return true


## Deploy a Basic during setup. Delegates to `play_unit`, which already enforces
## Basics-only, slot legality, and the retreat lock — this adds only the phase gate, so
## there is no second set of deployment rules to drift from the first.
func setup_deploy(p: Player, hand_index: int, board_index: int, slot: int) -> bool:
	if not in_setup():
		return false
	var idx: int = 0 if p == players[P1] else 1
	if setup_done[idx]:
		return false
	return play_unit(p, hand_index, board_index, slot)


## This player is finished placing. Round 1 begins once both are.
func finish_setup(p: Player) -> void:
	if not in_setup():
		return
	var idx: int = 0 if p == players[P1] else 1
	if setup_done[idx]:
		return
	setup_done[idx] = true
	_log("%s is ready." % p.display_name)

	if setup_done[P1] and setup_done[P2]:
		_begin_play()
	else:
		state_changed.emit()


## Leave setup and open round 1. The active player's own turn-start hook runs here —
## draw, Rise, locked attacks — the same as every later turn, so round 1 is an ordinary
## turn in every respect except that towers are silent through it.
func _begin_play() -> void:
	phase = Phase.PLAYING
	active = P1
	turn = 1
	_log("=== Setup complete ===")
	_begin_turn_for(me())
	state_changed.emit()
