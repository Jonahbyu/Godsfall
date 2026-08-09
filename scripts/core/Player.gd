class_name Player
extends RefCounted

## One side of the game: two boards, a throne, a deck, a hand, and the energy pool.

const BOARD_COUNT := 2
const HAND_SIZE_START := 6
const DRAW_PER_TURN := 1
const MAX_HAND := 10             ## checked at end of turn, after everything else

var display_name: String = "Player"
var is_ai: bool = false

var boards: Array = []           ## Array[Board], length 2
var throne_hp: int = 100
var throne_max_hp: int = 100

var pool: int = 0                ## energy pool — decays 20% at end of turn
var deck: Array = []             ## Array[String] card ids
var hand: Array = []             ## Array[String] card ids
var discard: Array = []          ## Array[String] card ids

var energy_played_this_turn: bool = false
var mulligan_used: bool = false

## Global attack lock. When true, every unit re-queues the attack it used last
## turn at the start of your turn, unless that unit is individually unlocked.
## A convenience over the rules, not a rule: it only ever queues attacks the
## player could have queued by hand, and anything auto-queued can be cancelled.
var auto_lock_attacks: bool = false
var eot_multiplier: int = 1      ## set by Dirge / Requiem, reset each turn
var unit_died_this_turn: bool = false
var units_died_this_turn: int = 0    ## Sift the Ashes counts these

## Cards that returned to hand by retreat this turn and may not be played again
## until next turn. The hand is a flat list of ids, so the lock is a count per
## id: `{card_id: n}` means the n most recently added copies are locked.
## Rally the Line clears this.
var locked: Dictionary = {}

## Units awaiting Rise, returned at the start of this player's next turn.
var pending_rise: Array = []     ## Array[Unit]


func _init(name: String = "Player", ai: bool = false) -> void:
	display_name = name
	is_ai = ai
	boards = []
	for i in BOARD_COUNT:
		boards.append(Board.new())


func load_deck(card_ids: Array) -> void:
	deck = card_ids.duplicate()
	deck.shuffle()


## ------------------------------------------------------------- the opening hand

## How many times to reshuffle looking for a Basic before giving up. A deck running
## any Basics at all clears this on the first or second try; the cap exists so a deck
## with none — legal, but unable to take a single action — terminates instead of
## spinning.
const OPENING_DEAL_TRIES := 20


## Deal the opening hand, guaranteeing at least one Basic unit in it.
##
## This is a DEAL FILTER, not a stacked hand: the whole hand goes back and the deck is
## reshuffled and re-dealt, rather than a Basic being searched out and put on top. That
## keeps everything except the guarantee as random as the deck makes it — a two-Basic
## opener stays exactly as likely as it should be.
##
## The guarantee matters because a hand with no Basic cannot take ANY action on turn 1:
## units are the only free play, a Stage 1 needs a body already on the board, and energy
## with nothing to charge does nothing. That is not a mulligan decision, it is a lost
## turn against a scaling tower.
##
## Returns true if the dealt hand contains a Basic. A false return means the deck holds
## none and the hand stands as dealt — the caller does not need to do anything about it,
## it is reported only so a harness can assert on it.
func deal_opening_hand() -> bool:
	for attempt in OPENING_DEAL_TRIES:
		_return_hand_to_deck()
		draw(HAND_SIZE_START)
		if has_basic_in_hand():
			return true
	return false


## Shuffle the whole hand back into the deck. Used by the opening deal and the mulligan.
func _return_hand_to_deck() -> void:
	for id in hand:
		deck.append(id)
	hand.clear()
	## Locks describe cards in hand, and there are none now.
	locked.clear()
	deck.shuffle()


func has_basic_in_hand() -> bool:
	for id in hand:
		var c: CardData = CardDB.get_card(id)
		if c != null and c.is_unit() and c.stage == CardData.Stage.BASIC:
			return true
	return false


## Mulligan: shuffle the opening hand back and draw a fresh one, same size, same
## guaranteed-Basic rule. Once per game, and only before any Basic has been deployed —
## the caller enforces the timing, this enforces the once.
##
## No card-loss penalty (contrast Magic's draw-7-bottom-1): the opening hand is only 6,
## the Basic guarantee already removes the disaster case a penalty would guard against,
## and opening a card down against a scaling tower is a far steeper cost here.
func mulligan() -> bool:
	if mulligan_used:
		return false
	mulligan_used = true
	deal_opening_hand()
	return true


func draw(n: int = 1) -> Array:
	var drawn: Array = []
	for i in n:
		if deck.is_empty():
			break
		var id: String = deck.pop_back()
		hand.append(id)
		drawn.append(id)
	return drawn


func deck_out() -> bool:
	return deck.is_empty()


# ---------------------------------------------------------------- hand lock

## A retreated card is locked until this player's next turn. Locked cards are
## ordinary cards otherwise — they still count toward the hand limit and may be
## discarded to it, so a wipe plus a retreat can't jam the hand solid.
func lock_card(card_id: String) -> void:
	locked[card_id] = int(locked.get(card_id, 0)) + 1


func locked_count(card_id: String) -> int:
	return int(locked.get(card_id, 0))


## True when every copy of this id in hand is locked. With n copies in hand and
## k locked, the k *most recent* are the locked ones, so a card is playable as
## long as at least one unlocked copy exists.
func is_locked(card_id: String) -> bool:
	return locked_count(card_id) >= _copies_in_hand(card_id)


func _copies_in_hand(card_id: String) -> int:
	var n := 0
	for id in hand:
		if id == card_id:
			n += 1
	return n


## Keeps the lock count from outliving the cards it refers to. Called after a
## copy leaves hand: if there are now fewer copies than locks, one locked copy
## is the one that left, so retire a lock. Playing an *unlocked* copy leaves
## count <= copies and correctly changes nothing.
func reconcile_locks(card_id: String) -> void:
	var n := locked_count(card_id)
	if n <= 0:
		return
	var copies := _copies_in_hand(card_id)
	if n <= copies:
		return
	if copies <= 0:
		locked.erase(card_id)
	else:
		locked[card_id] = copies


func clear_locks() -> void:
	locked.clear()


func over_hand_limit() -> int:
	return max(0, hand.size() - MAX_HAND)


## Drop a card from hand by index, retiring a lock if it was one.
func discard_from_hand(i: int) -> String:
	if i < 0 or i >= hand.size():
		return ""
	var id: String = hand[i]
	hand.remove_at(i)
	reconcile_locks(id)
	discard.append(id)
	return id


## All living units across both boards.
func all_units() -> Array:
	var out: Array = []
	for b in boards:
		out.append_array(b.units())
	return out


func empty_slots_total() -> int:
	var n := 0
	for b in boards:
		for i in b.usable_slots():
			if b.slots[i] == null:
				n += 1
	return n


func throne_alive() -> bool:
	return throne_hp > 0


func throne_take_damage(amount: int) -> int:
	var dealt: int = min(amount, throne_hp)
	throne_hp -= dealt
	return dealt


func grow_structures() -> void:
	throne_max_hp += 5
	throne_hp += 5
	for b in boards:
		b.grow_tower()


## 20% of pool, minimum 1, rounded down. Returns amount lost.
func apply_decay() -> int:
	if pool <= 0:
		return 0
	var loss: int = max(1, int(floor(pool * 0.2)))
	loss = min(loss, pool)
	pool -= loss
	return loss


## Energy card played on turn t gives t + 1 energy.
func play_energy(turn: int) -> int:
	var gain := turn + 1
	pool += gain
	energy_played_this_turn = true
	return gain


func gain_energy(n: int) -> void:
	pool += n


## Move energy from pool onto a unit. Free action, unlimited per turn.
func charge(u: Unit, n: int) -> int:
	var moved: int = min(n, pool)
	pool -= moved
	u.attached += moved
	return moved


func find_unit(u: Unit) -> Array:
	for bi in boards.size():
		var b: Board = boards[bi]
		for si in Board.SLOT_COUNT:
			if b.slots[si] == u:
				return [bi, si]
	return [-1, -1]


func begin_turn() -> void:
	energy_played_this_turn = false
	eot_multiplier = 1
	unit_died_this_turn = false
	units_died_this_turn = 0
	## The retreat lock lasts exactly one turn — cards returned last turn are
	## playable again now.
	clear_locks()
	for u in all_units():
		u.protected_this_turn = false
		u.decay_taken_this_turn = 0
		u.clear_abilities_used()      ## activated abilities are once per turn
