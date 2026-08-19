class_name TutorialData
extends RefCounted

## All tutorial content: the lesson scripts and the compendium pages.
##
## DATA ONLY — nothing here touches the UI, builds a node, or reads a live
## `GameState`. `TutorialState` runs these; `Tutorial.gd` and `Compendium.gd`
## render them. Keeping the content in one script means a rules change is a text
## edit in a single file rather than a hunt through three screens.
##
## The rules restated here are the ones in CLAUDE.md, and CLAUDE.md stays the
## source of truth. Nothing in this file may invent a rule: if a lesson cannot be
## built without an engine change, the lesson is wrong.


# =========================================================================
#  Lesson steps
# =========================================================================
#
# A step is a Dictionary. Every key is optional except `text`:
#
#   text       String    what the coach panel says
#   title      String    short heading; defaults to the lesson title
#   advance    String    the predicate that completes this step — see
#                        TutorialState.step_satisfied(). "" means the step is
#                        pure exposition and advances on Next.
#   allow      Array     action names legal during this step. Absent means
#                        "everything is legal"; an empty array means "nothing is",
#                        which is what exposition steps want.
#   highlight  Dictionary  a widget to ring. {kind=..., ...} — see Combat.
#   setup      String    a scripted board mutation applied when the step opens,
#                        resolved by TutorialState._apply_setup().
#   enemy      String    what the scripted opponent does at the next end of turn.
#   read_more  String    compendium page id for the "Read more" link.
#
# `advance` predicates are evaluated against the real GameState, so a step
# completes because the rules engine agrees the action happened — never because
# a click was counted.


## The ordered lesson list. `id` is stable and is what progress is saved against,
## so lessons may be reordered freely but never renamed.
static func lessons() -> Array:
	return [
		_l_board(),
		_l_energy(),
		_l_attacking(),
		_l_wall(),
		_l_aim(),
		_l_towers(),
		_l_growing(),
		_l_retreat(),
		_l_support(),
		_l_hel(),
		_l_heaven(),
		_l_void(),
		_l_gaia(),
		_l_deckbuilding(),
	]


static func lesson_count() -> int:
	return lessons().size()


static func lesson_by_id(id: String) -> Dictionary:
	for l in lessons():
		if l.get("id", "") == id:
			return l
	return {}


static func lesson_index(id: String) -> int:
	var all := lessons()
	for i in all.size():
		if all[i].get("id", "") == id:
			return i
	return -1


# ---------------------------------------------------------------- 1. the board

static func _l_board() -> Dictionary:
	return {
		"id": "board",
		"title": "First Blood",
		"blurb": "The board, your first units, and how a turn ends.",
		"teaches": "Board layout · Setup · Deploying · Ending the turn",
		## A deck stacked so the opening hand is all Basics and one energy card.
		## Not shuffled — a lesson that deals a different hand each run cannot
		## have scripted steps.
		"deck": _stack([
			["barrow_knight", 4], ["grave_whelp", 4], ["thornshade", 4],
			["hel_energy", 8], ["carrion_crawler", 4],
		]),
		"enemy_deck": _stack([["grave_whelp", 12], ["hel_energy", 8]]),
		"hand": ["barrow_knight", "grave_whelp", "thornshade", "carrion_crawler", "hel_energy", "hel_energy"],
		"steps": [
			{
				"title": "Two boards, two fights",
				"text": "You have [b]two boards[/b]. Each is a lane three slots wide, and the rightmost slot is taken by your [color=#6b8fbf]tower[/color] until it dies — so you have [b]two usable slots per board, four in total[/b].\n\nBehind both boards sits your [color=#bf6b9e]throne[/color] at 150 HP. [b]Lose the throne and you lose the game.[/b] That is the only way to lose.",
				"allow": [],
				"read_more": "board",
			},
			{
				"title": "The boards never help each other",
				"text": "This is the rule that decides most games: [b]each board is its own fight[/b].\n\nAn attack against your left board can only ever hit things on your left board. Units on your right board defend nothing there. Two boards, two independent battles — and you must hold both.",
				"allow": [],
				"read_more": "board",
			},
			{
				"title": "Setup — put a body down",
				"text": "Before round 1 both players deploy [b]Basic[/b] units for free. Nothing else happens: no energy, no attacks.\n\n[b]Drag a Basic from your hand onto an empty slot[/b] — or click the card, then click the slot.",
				"advance": "unit_count>=1",
				"allow": ["deploy", "select"],
				"highlight": {"kind": "my_slot", "board": 0, "slot": 0},
				"read_more": "setup",
			},
			{
				"title": "Cards are free",
				"text": "Notice it cost you nothing. [b]Units are always free to play.[/b] Energy in this game does not buy cards — it only buys [i]attacks[/i].\n\nThat is the whole idea: deploying is unconstrained, [b]acting[/b] is what is scarce. A board full of units you cannot afford to activate is decoration.\n\nDeploy a second Basic.",
				"advance": "unit_count>=2",
				"allow": ["deploy", "select"],
				"highlight": {"kind": "my_slot", "board": 1, "slot": 0},
				"read_more": "economy",
			},
			{
				"title": "Placement decides who gets hit",
				"text": "Where you deploy matters. An attack with no chosen target hits [b]the slot directly across from the attacker[/b], so your placement decides which of your units absorbs which enemy attack.\n\nYou will learn to override that in a later lesson — but it is always the default.",
				"allow": [],
				"read_more": "targeting",
			},
			{
				"title": "Ready",
				"text": "You are done placing. Press [b]Ready[/b] to commit your board.\n\nBoth players place at the same time and neither sees the other first — a side that could counter-place would be handed the whole geometry for free.",
				"advance": "playing",
				"allow": ["end_turn"],
				"highlight": {"kind": "end_turn"},
			},
			{
				"title": "Round 1",
				"text": "Round 1 has begun and you drew your cards. You draw [b]two cards per turn[/b] from a 60-card deck, and your hand caps at 10.\n\nA turn is: draw, do whatever you like in any order, then end the turn — and [b]everything you queued resolves when the turn ends[/b], not when you click it.",
				"allow": [],
				"read_more": "turn",
			},
			{
				"title": "End your turn",
				"text": "Nothing to spend yet — you have no energy. Press [b]End Turn[/b].\n\nTowers are silent in round 1, so this first turn is free. From round 2 they start firing.",
				"advance": "round>=2",
				"allow": ["end_turn"],
				"highlight": {"kind": "end_turn"},
			},
			{
				"title": "That is the loop",
				"text": "Deploy, act, end the turn. Everything else in Godsfall hangs off the one decision the next lesson is about: [b]where your energy goes[/b].",
				"allow": [],
				"final": true,
			},
		],
	}


# --------------------------------------------------------------- 2. the economy

static func _l_energy() -> Dictionary:
	return {
		"id": "energy",
		"title": "Energy",
		"blurb": "The pool, decay, and the one decision the whole game is built on.",
		"teaches": "Energy cards · Pool · Decay · Charging · Attached energy",
		"deck": _stack([
			["hel_energy", 10], ["barrow_knight", 6], ["grave_whelp", 4],
		]),
		"enemy_deck": _stack([["grave_whelp", 12], ["hel_energy", 8]]),
		"hand": ["hel_energy", "hel_energy", "barrow_knight", "grave_whelp", "hel_energy", "barrow_knight"],
		"start_board": [["barrow_knight", 0, 0]],
		"enemy_board": [["grave_whelp", 0, 0]],
		"skip_setup": true,
		"steps": [
			{
				"title": "Energy cards are in your deck",
				"text": "Energy is not a resource that arrives on its own — [b]you build energy cards into your deck[/b] and decide how many. That ratio is one of the biggest deckbuilding choices you make.\n\nYou may play [b]one energy card per turn[/b].",
				"allow": [],
				"read_more": "economy",
			},
			{
				"title": "It is worth more later",
				"text": "An energy card played on turn [i]t[/i] gives you [b]t + 1[/b] energy.\n\nTurn 1 -> 2 energy. Turn 5 -> 6. Turn 9 -> 10.\n\nSo [b]holding an energy card makes it worth more[/b] — but one-per-turn means a skipped play can never be made up. That is the first spend-or-save decision.\n\nPlay an energy card now.",
				"advance": "played_energy",
				"allow": ["play_energy", "select"],
				"highlight": {"kind": "hand_type", "value": "energy"},
				"read_more": "economy",
			},
			{
				"title": "The pool decays",
				"text": "That energy went to your [b]pool[/b], shown by the meter near End Turn.\n\nThe pool [b]carries across turns[/b] — it does not refresh. But at the end of every turn it [b]loses 20%[/b], minimum 1.\n\nBanking is possible. It is just taxed.",
				"allow": [],
				"read_more": "economy",
			},
			{
				"title": "Charging — moving energy onto a body",
				"text": "You can move energy from the pool [b]onto a unit[/b]. It is free and unlimited.\n\nAttached energy is [b]immune to decay[/b], it is [b]permanent[/b], and it [b]carries through evolution[/b].\n\nClick your unit, then use [b]Charge[/b].",
				"advance": "attached>=1",
				"allow": ["charge", "select"],
				"highlight": {"kind": "my_unit"},
				"read_more": "economy",
			},
			{
				"title": "The trade",
				"text": "Here is the skill gap of the entire game, and it is worth reading twice:\n\n[b]Pool[/b] — decays 20% a turn, but is safe when your units die.\n[b]Attached[/b] — immune to decay, but [b]lost entirely when that unit dies[/b].\n\nCommitting energy to a unit protects it from decay and stakes it on that unit surviving. There is no safe choice. That is the point.",
				"allow": [],
				"read_more": "economy",
			},
			{
				"title": "End the turn and watch it bleed",
				"text": "End your turn. Watch the pool number drop by 20% while the energy you attached stays exactly where it is.",
				"advance": "round>=2",
				"allow": ["end_turn"],
				"highlight": {"kind": "pool"},
			},
			{
				"title": "Why attaching pays",
				"text": "The energy on your unit survived. The energy in your pool did not, entirely.\n\nBut do not read that as \"always attach\": a charged unit that dies loses every point on it. Against a board that can kill it, the pool is the safer bank.\n\n[b]That judgement is the game.[/b]",
				"allow": [],
				"final": true,
			},
		],
	}


# -------------------------------------------------------------- 3. attacking

static func _l_attacking() -> Dictionary:
	return {
		"id": "attacking",
		"title": "Attacking",
		"blurb": "Queueing attacks, what they cost, and when they resolve.",
		"teaches": "Queueing · Cost · End-of-turn resolution · Free forever after",
		"deck": _stack([["hel_energy", 10], ["barrow_knight", 6], ["grave_whelp", 4]]),
		"enemy_deck": _stack([["grave_whelp", 12], ["hel_energy", 8]]),
		"hand": ["hel_energy", "barrow_knight", "grave_whelp", "hel_energy", "barrow_knight", "hel_energy"],
		"start_board": [["barrow_knight", 0, 0]],
		"enemy_board": [["grave_whelp", 0, 0]],
		"skip_setup": true,
		"pool": 6,
		"steps": [
			{
				"title": "Attacks cost energy",
				"text": "Your Barrow Knight has [b]Cleave[/b] — 25 damage for 2 energy.\n\nThat is the standard rate: roughly [b]12 damage per energy[/b]. Bigger attacks are not more efficient per point; they are better because the board caps at four units, so [b]concentrated damage beats spread damage[/b].\n\nClick your unit to see its attacks.",
				"advance": "selected_my_unit",
				"allow": ["select"],
				"highlight": {"kind": "my_unit"},
				"read_more": "combat",
			},
			{
				"title": "Queue it",
				"text": "Click [b]Cleave[/b].\n\nQueueing pulls [b]exactly[/b] the attack's cost from your pool onto the unit — a 2-cost attack takes 2, even from a pool of 20. No overpayment, no waste.",
				"advance": "queued>=1",
				"allow": ["queue", "select"],
				"highlight": {"kind": "attack_row"},
				"read_more": "combat",
			},
			{
				"title": "Nothing happened yet",
				"text": "The attack is [b]queued[/b], not resolved. Attacks happen at [b]end of turn[/b], all together.\n\nThat delay is what makes the game readable: your opponent can see what is coming, and you can queue several attacks and decide what order they land in.\n\nEnd your turn.",
				"advance": "round>=2",
				"allow": ["end_turn", "queue", "select"],
				"highlight": {"kind": "end_turn"},
			},
			{
				"title": "The payment was one-time",
				"text": "The 2 energy Cleave cost is now [b]attached[/b] to your unit — and it stays there.\n\n[b]That attack is free every turn from now on.[/b] You paid once. An attack's cost is an annuity, not a rent.\n\nThat is why charging a unit up is an investment, and why losing that unit hurts twice: you lose the body and the energy.",
				"allow": [],
				"read_more": "combat",
			},
			{
				"title": "Attack again — for free",
				"text": "Queue Cleave again. Notice your pool does not move: the energy is already on the unit.",
				"advance": "queued>=1",
				"allow": ["queue", "select"],
				"highlight": {"kind": "my_unit"},
			},
			{
				"title": "One-directional",
				"text": "One more rule: attacks are [b]one-directional[/b]. The defender does not strike back unless a card says so.\n\nAnd units [b]persist[/b] — attacking does not exhaust them. A charged unit attacks every single turn, forever, for free.",
				"allow": [],
				"final": true,
			},
		],
	}


# ----------------------------------------------------------------- 4. shielding

static func _l_wall() -> Dictionary:
	return {
		"id": "wall",
		"title": "The Wall",
		"blurb": "Why your units are the only thing protecting your tower.",
		"teaches": "Shielding · The fallback chain · Clearing a board",
		"deck": _stack([["hel_energy", 10], ["barrow_knight", 8], ["grave_whelp", 6]]),
		"enemy_deck": _stack([["grave_whelp", 12], ["hel_energy", 8]]),
		"hand": ["hel_energy", "barrow_knight", "grave_whelp", "barrow_knight", "hel_energy", "grave_whelp"],
		"start_board": [["barrow_knight", 0, 0]],
		"enemy_board": [["grave_whelp", 0, 0], ["grave_whelp", 0, 1]],
		"skip_setup": true,
		"pool": 8,
		"steps": [
			{
				"title": "Units shield everything behind them",
				"text": "[b]As long as anything is alive on a board, attacks against that board can only hit units.[/b] Never the tower. Never the throne.\n\nThe enemy left board has two units on it. Until [b]both[/b] are dead, that tower cannot be touched.",
				"allow": [],
				"read_more": "targeting",
			},
			{
				"title": "The fallback chain",
				"text": "When an attack resolves, it picks its target in this order:\n\n[b]1.[/b] The target you named, if still alive\n[b]2.[/b] The unit in the slot directly across\n[b]3.[/b] Otherwise the [b]leftmost[/b] living unit on that board\n[b]4.[/b] Otherwise that board's [b]tower[/b]\n[b]5.[/b] Otherwise the [b]throne[/b]\n\nIt is deterministic. You are never asked to pick again mid-resolution.",
				"allow": [],
				"read_more": "targeting",
			},
			{
				"title": "Holes do not open a path",
				"text": "Slots [b]never compact[/b] — a dead unit leaves a permanent hole. But a hole does [b]not[/b] funnel damage to the tower while anything else on that board lives.\n\nWhat a hole costs you is [b]concentration[/b]: attacks that would have spread across three bodies now all pile onto whatever is left.",
				"allow": [],
			},
			{
				"title": "Kill the first one",
				"text": "Queue an attack. It will hit the unit across from yours — that is the default.\n\nOne kill is not enough to reach the tower. Watch what your damage does when one body is left.",
				"advance": "queued>=1",
				"allow": ["queue", "select"],
				"highlight": {"kind": "my_unit"},
			},
			{
				"title": "End the turn",
				"text": "Resolve it.",
				"advance": "round>=2",
				"allow": ["end_turn", "queue", "select"],
				"highlight": {"kind": "end_turn"},
			},
			{
				"title": "Clearing is what opens a board",
				"text": "The board still holds a living unit, so the tower behind it is still untouchable.\n\n[b]A board is only reachable past its units once every unit on it is dead[/b] — including ones that died earlier in the same turn.\n\nThis is the single biggest reason games last: reaching a tower is something you [b]earn by clearing a board[/b], not by connecting one attack into a gap.",
				"allow": [],
				"final": true,
				"read_more": "targeting",
			},
		],
	}


# ---------------------------------------------------------------------- 5. aim

static func _l_aim() -> Dictionary:
	return {
		"id": "aim",
		"title": "Aim",
		"blurb": "Choosing targets, ordering your volley, and never wasting damage.",
		"teaches": "Chosen targets · Volley ordering · No overkill",
		"deck": _stack([["hel_energy", 10], ["barrow_knight", 8], ["grave_whelp", 6]]),
		"enemy_deck": _stack([["grave_whelp", 12], ["hel_energy", 8]]),
		"hand": ["hel_energy", "barrow_knight", "grave_whelp", "barrow_knight", "hel_energy", "grave_whelp"],
		"start_board": [["barrow_knight", 0, 0], ["barrow_knight", 0, 1]],
		"enemy_board": [["grave_whelp", 0, 0], ["grave_whelp", 0, 1]],
		"skip_setup": true,
		"pool": 10,
		"steps": [
			{
				"title": "You may name a target",
				"text": "An attack does not have to hit the slot across. [b]You may name any living enemy unit on the board it faces.[/b]\n\nWhat you may [b]not[/b] do is pick past the wall: never the tower, never the throne, never the other board. Choosing a target picks [i]among[/i] the shield, never through it.",
				"allow": [],
				"read_more": "targeting",
			},
			{
				"title": "Aim at the far unit",
				"text": "Queue an attack and [b]name the enemy unit that is not across from you[/b] — click your unit, choose the attack, then click the enemy you want.\n\nAiming is always safe: if your target dies first, the attack falls back down the chain rather than fizzling.",
				"advance": "queued>=1",
				"allow": ["queue", "select", "target"],
				"highlight": {"kind": "enemy_unit"},
			},
			{
				"title": "Damage is never wasted",
				"text": "[b]Once a unit dies, no further attack that turn may hit it.[/b] A later attack aimed at a corpse re-resolves from the top of the chain and hits something living instead.\n\nExcess damage is not banked either — an overkill's leftover simply does not happen. [b]The attack retargets whole.[/b]",
				"allow": [],
				"read_more": "targeting",
			},
			{
				"title": "Order is yours to choose",
				"text": "Your queued attacks are an [b]ordered list[/b], and you can rearrange them freely until you end the turn. The default is left to right.\n\nThis matters because [b]a kill by an early attack changes what every later attack hits[/b]. Sequencing a volley so the kills land first is how you clear a board in one turn — and clearing is how you reach a tower.",
				"allow": [],
				"read_more": "combat",
			},
			{
				"title": "Resolve the volley",
				"text": "Queue a second attack if you can, then end the turn and watch the order resolve.",
				"advance": "round>=2",
				"allow": ["queue", "select", "target", "end_turn"],
				"highlight": {"kind": "end_turn"},
			},
			{
				"title": "Aim is a plan",
				"text": "Focus fire concentrates damage; ordering decides what falls through. Together they are how a good turn turns two bodies into an open board.",
				"allow": [],
				"final": true,
			},
		],
	}


# ------------------------------------------------------------------- 6. towers

static func _l_towers() -> Dictionary:
	return {
		"id": "towers",
		"title": "Towers",
		"blurb": "The clock that punishes you for doing nothing.",
		"teaches": "Tower fire · The damage curve · Structure chip · Winning",
		"deck": _stack([["hel_energy", 10], ["barrow_knight", 8], ["grave_whelp", 6]]),
		"enemy_deck": _stack([["grave_whelp", 12], ["hel_energy", 8]]),
		"hand": ["hel_energy", "barrow_knight", "grave_whelp", "barrow_knight", "hel_energy", "grave_whelp"],
		"start_board": [["barrow_knight", 0, 0]],
		"enemy_board": [["grave_whelp", 0, 0]],
		"skip_setup": true,
		"pool": 6,
		"steps": [
			{
				"title": "Each board has a tower",
				"text": "A tower has 75 HP, sits in the third slot, and [b]fires at the board across from it every turn[/b].\n\nIt is not a wall. It is an [b]attrition engine[/b] — every turn you fail to answer it, it eats another unit.",
				"allow": [],
				"read_more": "towers",
			},
			{
				"title": "The curve",
				"text": "Towers are [b]silent in round 1[/b]. Then:\n\nRound 2 -> [b]5[/b] damage · Round 3 -> [b]8[/b] · Round 4 -> [b]11[/b]\n\n…climbing [b]+3 every round[/b], forever. By round 12 that is 35 a turn.\n\nThe early game is forced tempo: break through, or face both the tower and their board later.",
				"allow": [],
				"read_more": "towers",
			},
			{
				"title": "An empty board is not safe",
				"text": "If the board a tower faces has [b]no living unit[/b], it fires at the structures instead — the tower first, then the throne once that tower is dead — for [b]half[/b] damage.\n\nSo abandoning a board does not make it safe. It makes it bleed.",
				"allow": [],
				"read_more": "towers",
			},
			{
				"title": "Structures grow",
				"text": "Towers and thrones gain [b]+5 max HP once per round[/b], after both players have acted.\n\nSo the throne you are racing is slowly getting harder to kill. Slow games get [b]harder[/b] to close, not easier — which is why passivity loses.",
				"allow": [],
			},
			{
				"title": "Take the tower shot",
				"text": "End your turn and watch the towers fire.\n\nYour unit will absorb the shot at full damage — which is exactly what it is there for. A living body on a board means the structures behind it take nothing.",
				"advance": "round>=2",
				"allow": ["end_turn", "queue", "select"],
				"highlight": {"kind": "end_turn"},
			},
			{
				"title": "How you actually win",
				"text": "Kill a tower and that slot opens for its owner — [b]three usable slots instead of two[/b] — but it exposes their throne on that board.\n\nYou can even sacrifice your own tower for the space. [b]Lose the throne and you lose.[/b] Nothing else ends the game.",
				"allow": [],
				"final": true,
				"read_more": "towers",
			},
		],
	}


# ------------------------------------------------------- 7. evolution & abilities

static func _l_growing() -> Dictionary:
	return {
		"id": "growing",
		"title": "Growing",
		"blurb": "Evolution, abilities, and the cost that burns your investment.",
		"teaches": "Evolution · Two-line rule · Abilities vs. attacks · Consume",
		"deck": _stack([
			["gravebound_reaper", 4], ["hel_energy", 8], ["grave_whelp", 6],
			["charnel_colossus", 4],
		]),
		"enemy_deck": _stack([["grave_whelp", 12], ["hel_energy", 8]]),
		"hand": ["gravebound_reaper", "hel_energy", "grave_whelp", "charnel_colossus", "hel_energy", "grave_whelp"],
		"start_board": [["grave_whelp", 0, 0]],
		"enemy_board": [["grave_whelp", 0, 0]],
		"skip_setup": true,
		"pool": 6,
		"attach": [[0, 0, 3]],
		"steps": [
			{
				"title": "Units evolve",
				"text": "Units come in three stages — [b]Basic[/b], [b]Stage 1[/b], [b]Stage 2[/b] — and a card names what it evolves from.\n\nEvolving is [b]free[/b], like everything that is not an attack. It is a pure board-quality upgrade that raises your energy demands.",
				"allow": [],
				"read_more": "units",
			},
			{
				"title": "Energy carries forward",
				"text": "Your Grave Whelp has 3 energy attached.\n\n[b]Evolution carries attached energy forward.[/b] This is mandatory — without it no Stage 2 could ever be charged, because you would have to start paying from zero on a body that costs 6 to swing.\n\nDrop the Stage 1 from your hand onto the unit.",
				"advance": "stage>=1",
				"allow": ["evolve", "select"],
				"highlight": {"kind": "my_unit"},
				"read_more": "units",
			},
			{
				"title": "Bigger, and hungrier",
				"text": "Same energy, much bigger body — and access to a far more expensive attack.\n\nHP by stage: [b]Basic 40–90[/b], [b]Stage 1 80–120[/b], [b]Stage 2 110–175[/b]. The bands overlap on purpose: stage is not a power ranking, and a big Basic has paid for its size elsewhere.",
				"allow": [],
			},
			{
				"title": "Every unit has exactly two lines",
				"text": "A hard structural rule: [b]every unit has at most two lines[/b] — either one ability and one attack, or two attacks.\n\nThat forces each card to commit to an identity instead of accumulating text. If a card looks simple, that is deliberate.",
				"allow": [],
				"read_more": "units",
			},
			{
				"title": "Abilities are not attacks",
				"text": "[b]Attacks[/b] are queued and resolve at end of turn, and their cost stays attached — free every turn after.\n\n[b]Abilities[/b] resolve [b]immediately[/b], are limited to [b]once per turn[/b], and are [b]free[/b]. Energy only buys attacks, and an ability is not an attack.",
				"allow": [],
				"read_more": "units",
			},
			{
				"title": "Consume — the one cost an ability may carry",
				"text": "Some lines require [b]Consume N[/b]: they [b]destroy N attached energy[/b] on activation rather than merely requiring it.\n\nThat is the opposite of an attack's annuity — it charges [b]every single use[/b], which is what stops a free once-per-turn ability from becoming a permanent no-cost engine.\n\nConsume attacks pay about [b]20 damage per energy[/b] against the standard 12, because they burn the investment.",
				"allow": [],
				"final": true,
				"read_more": "units",
			},
		],
	}


# ------------------------------------------------------------------- 8. retreat

static func _l_retreat() -> Dictionary:
	return {
		"id": "retreat",
		"title": "Pulling Out",
		"blurb": "Saving a unit — and what it costs you to do it.",
		"teaches": "Retreat · Paying from attached · The hand lock",
		"deck": _stack([["hel_energy", 10], ["barrow_knight", 8], ["grave_whelp", 6]]),
		"enemy_deck": _stack([["grave_whelp", 12], ["hel_energy", 8]]),
		"hand": ["hel_energy", "barrow_knight", "grave_whelp", "barrow_knight", "hel_energy", "grave_whelp"],
		"start_board": [["barrow_knight", 0, 0], ["grave_whelp", 1, 0]],
		"enemy_board": [["grave_whelp", 0, 0]],
		"skip_setup": true,
		"pool": 4,
		"attach": [[0, 0, 3]],
		"steps": [
			{
				"title": "Retreat pulls a unit back to hand",
				"text": "There is no bench in Godsfall. [b]Retreat returns a unit to your hand[/b] and leaves the slot empty.\n\nEvery unit prints a [b]Retreat cost[/b], which is its HP ÷ 40, rounded down. Most small bodies cost 1.",
				"allow": [],
				"read_more": "retreat",
			},
			{
				"title": "It is paid from the unit itself",
				"text": "The cost comes [b]from that unit's own attached energy[/b] — never from your pool, never from another unit.\n\nSo [b]an uncharged unit cannot retreat.[/b] It is stuck on the board.\n\nRetreat your charged unit.",
				"advance": "hand_has_retreated",
				"allow": ["retreat", "select"],
				"highlight": {"kind": "my_unit"},
				"read_more": "retreat",
			},
			{
				"title": "The leftover comes back",
				"text": "The retreat cost was [b]spent[/b] — gone. But every point of [b]leftover attached energy returned to your pool[/b].\n\nThis is the only way attached energy ever comes off a unit without that unit dying.",
				"allow": [],
			},
			{
				"title": "Locked for a turn",
				"text": "The card came back [b]healed to full[/b] — and [b]locked[/b]. You cannot play it again until your next turn.\n\nWithout that lock, retreat would be a free full-heal reset every single turn.",
				"allow": [],
				"read_more": "retreat",
			},
			{
				"title": "Retreat is the alternative to dying",
				"text": "A retreated unit [b]did not die[/b]. It pays no [b]Toll[/b], it does not [b]Rise[/b], and it does not go to the discard.\n\nAnd an evolved unit brings its [b]whole evolution path[/b] back — Basic, Stage 1, Stage 2, as separate cards, all locked. You rebuild from the bottom.",
				"allow": [],
			},
			{
				"title": "Why saving a unit is not free",
				"text": "That sounds generous, and it is — deliberately. [b]Saving a unit does not win the game; it removes a shield.[/b]\n\nYour board is your only defence. Retreating thins it, so the remaining units absorb everything, die faster, and clearing that board is what exposes your tower.\n\nGetting the card back is not the same as getting the board back.",
				"allow": [],
				"final": true,
			},
		],
	}


# ------------------------------------------------------------------ 9. supports

static func _l_support() -> Dictionary:
	return {
		"id": "support",
		"title": "Support",
		"blurb": "The third card type — one-shots, Tools, and tower upgrades.",
		"teaches": "Supports · Priced supports · Tools · Tower support · Hand limit",
		"deck": _stack([
			["shore_up", 4], ["gravekeepers_ledger", 4], ["bone_splint", 4],
			["reinforced_base", 4], ["field_surgery", 4], ["hel_energy", 6],
			["barrow_knight", 4],
		]),
		"enemy_deck": _stack([["grave_whelp", 12], ["hel_energy", 8]]),
		"hand": ["shore_up", "field_surgery", "bone_splint", "reinforced_base", "gravekeepers_ledger", "hel_energy"],
		"start_board": [["barrow_knight", 0, 0]],
		"enemy_board": [["grave_whelp", 0, 0]],
		"skip_setup": true,
		"pool": 6,
		"damage": [[0, 0, 25]],
		"steps": [
			{
				"title": "The third card type",
				"text": "Alongside units and energy there are [b]support cards[/b]: one-shot effects. Play, resolve, discard.\n\nThey are [b]usually free[/b] and there is [b]no per-turn limit[/b]. Play as many as you drew.",
				"allow": [],
				"read_more": "support",
			},
			{
				"title": "Hand size is the cost",
				"text": "With no play limit, what stops you? [b]A support is a card you drew instead of a unit[/b], in a game where you draw two per turn.\n\nPlaying four supports in a turn means you spent two turns of draw to do it. That is the whole limiter.",
				"allow": [],
			},
			{
				"title": "Play a heal",
				"text": "Your unit is damaged. Play [b]Shore Up[/b] and pick it — a support that needs a target puts you into targeting mode, then you click what it hits.",
				"advance": "unit_healed",
				"allow": ["play_support", "select", "target"],
				"highlight": {"kind": "hand_type", "value": "support"},
			},
			{
				"title": "Some supports cost energy",
				"text": "Most supports are free. A minority cost [b]1–3 pool energy[/b] — the one sanctioned exception to \"energy only buys attacks\".\n\nIt exists so the same effect can be printed twice: [b]Shore Up[/b] heals 20 for free, [b]Field Surgery[/b] heals 50 for 1. The free one is always castable; the priced one is better when you have the pool.\n\nIf you cannot pay, you cannot play it.",
				"allow": [],
				"read_more": "support",
			},
			{
				"title": "Tools attach and stay",
				"text": "A [b]Tool[/b] is a support that attaches to a unit permanently — the one exception to play-resolve-discard.\n\n[b]One Tool per unit.[/b] It stays through evolution, and it goes to the discard when the unit [b]dies or retreats[/b]. Retreat saves the body, not the equipment.\n\nTools pay out every turn, so each instance does less — a Tool takes 3–4 turns to match what a one-shot does immediately. They are a [b]bet that the unit survives[/b].",
				"allow": [],
				"read_more": "support",
			},
			{
				"title": "Tower support",
				"text": "[b]Tower support[/b] cards modify a tower you control, and unlike Tools they [b]stack without limit[/b] — four copies of a +20 HP card is +80.\n\nThe hard line: [b]no tower support may raise the rate at which a tower hits structures.[/b] A tower that threatened the throne at full rate would make units irrelevant.\n\nThey are cheap because they are self-limiting: [b]a tower you keep alive is a lane slot you never get to use.[/b]",
				"allow": [],
				"read_more": "support",
			},
			{
				"title": "The hand limit",
				"text": "You may never hold more than [b]10 cards[/b], checked [b]at end of turn[/b] — after everything else resolves.\n\nEnd-of-turn rather than continuous is deliberate: a draw-3 from a hand of 9 draws all three. You just have to spend or pitch the excess before the turn ends.",
				"allow": [],
				"final": true,
				"read_more": "support",
			},
		],
	}


# ---------------------------------------------------------------------- 10. Hel

static func _l_hel() -> Dictionary:
	return {
		"id": "hel",
		"title": "Death is a Resource",
		"blurb": "Hel — where your units dying is the plan.",
		"teaches": "Toll · Decay · Rise · Retribution",
		"deck": _stack([["hel_energy", 8], ["barrow_knight", 6], ["hollow_servant", 4], ["thornshade", 4]]),
		"enemy_deck": _stack([["grave_whelp", 12], ["hel_energy", 8]]),
		"hand": ["hel_energy", "thornshade", "hollow_servant", "barrow_knight", "hel_energy", "barrow_knight"],
		"start_board": [["thornshade", 0, 0], ["hollow_servant", 1, 0]],
		"enemy_board": [["barrow_knight", 0, 0]],
		"skip_setup": true,
		"pool": 6,
		"steps": [
			{
				"title": "A faction is an energy colour",
				"text": "There are four factions, and [b]a faction is a colour of energy[/b]. Cards of a colour need that colour to pay for their attacks.\n\n[b]Hel[/b] is death, decay, and the dead. Its verb is [b]recycle[/b].",
				"allow": [],
				"read_more": "factions",
			},
			{
				"title": "Toll — dying pays you back",
				"text": "[b]Toll N[/b]: when this unit dies, you [b]gain N energy[/b].\n\nN is the unit's HP ÷ 25, printed on the card. It makes a bad trade into a turn of income, and it is why Hel is the faction that does not mind losing bodies.\n\nRetreat pays no Toll. Hel chooses between the refund and the card — never both.",
				"allow": [],
				"read_more": "kw_toll",
			},
			{
				"title": "Decay — free chip every turn",
				"text": "[b]Decay N[/b]: at end of turn, deal N damage to the unit across from this one.\n\nIt costs nothing and it never stops. Decay follows the same targeting chain as everything else, so it cannot chip a throne past a wall.",
				"allow": [],
				"read_more": "kw_decay",
			},
			{
				"title": "Retribution — hitting you costs them",
				"text": "[b]Retribution N[/b]: when this unit takes damage from an attack, it [b]deals N back to the attacker[/b].\n\nYour Thornshade has Retribution 10. And a unit destroyed mid-attack still deals its recoil — [b]nothing leaves the board until the attack finishes[/b], so an attacker cannot dodge the counter-punch by killing fast enough. If the recoil kills them, both die.",
				"allow": [],
				"read_more": "kw_retribution",
			},
			{
				"title": "Rise — coming back",
				"text": "[b]Rise[/b]: when this dies, it returns to an empty slot at the start of your next turn, at [b]half HP[/b] and [b]without Rise[/b].\n\nEverything else comes back intact, at printed values. Attached energy does not, and neither does anything the card [b]grew[/b] in play. [b]Rise restores the card, not the history[/b] — that is what caps the loop.",
				"allow": [],
				"read_more": "kw_rise",
			},
			{
				"title": "Let something die",
				"text": "End your turn. Your units will trade, and you will see Toll pay out.\n\nFor Hel, a dead unit is not a loss. It is income, a Rise trigger, and a discard pile to recur from.",
				"advance": "round>=2",
				"allow": ["end_turn", "queue", "select", "target"],
				"highlight": {"kind": "end_turn"},
			},
			{
				"title": "Subfactions",
				"text": "A faction is not one deck — it is a colour hosting several themes. Hel's first is [b]Toll[/b], where every unit refunds energy on death.\n\nNew content ships as a new subfaction inside an existing colour, so the colour count stays low and each faction keeps room to grow.",
				"allow": [],
				"final": true,
			},
		],
	}


# ------------------------------------------------------------------- 11. Heaven

static func _l_heaven() -> Dictionary:
	return {
		"id": "heaven",
		"title": "Judgment & Sanctuary",
		"blurb": "Heaven — reprieves, executions, and shields that eat whole attacks.",
		"teaches": "Judgment (both halves) · Sanctuary N · Resolution order",
		"deck": _stack([["heaven_energy", 8], ["censer_bearer", 6], ["warden_of_the_lamp", 4], ["radiant_bastion", 4]]),
		"enemy_deck": _stack([["grave_whelp", 12], ["hel_energy", 8]]),
		"hand": ["heaven_energy", "censer_bearer", "warden_of_the_lamp", "radiant_bastion", "heaven_energy", "censer_bearer"],
		"start_board": [["censer_bearer", 0, 0], ["warden_of_the_lamp", 1, 0]],
		"enemy_board": [["barrow_knight", 0, 0]],
		"skip_setup": true,
		"pool": 6,
		"steps": [
			{
				"title": "Heaven protects",
				"text": "[b]Heaven[/b] is order, light, and judgment. Its verb is [b]protect[/b] — it stacks reprieves and converts durability into kills.",
				"allow": [],
				"read_more": "factions",
			},
			{
				"title": "Judgment does two jobs",
				"text": "[b]Judgment N[/b] is one printed number doing two things:\n\n[b]Defensive[/b] — when this unit would die, it instead [b]survives at N HP[/b].\n[b]Offensive[/b] — when this unit attacks and leaves the defender at [b]N or below[/b], that defender is [b]destroyed[/b].\n\n[i]I survive at N, and I kill anything I leave at N.[/i]",
				"allow": [],
				"read_more": "kw_judgment",
			},
			{
				"title": "One charge, spent by either half",
				"text": "Here is the balance: [b]it is a single charge, and either use spends it.[/b]\n\nA Judgment 100 unit is enormously powerful exactly once, then an ordinary body. So every turn asks: [b]cash the charge to delete something, or hold it as the insurance keeping this unit alive?[/b]\n\nA spent Judgment disappears from the card on the board — if you can still see the chip, you still have it.",
				"allow": [],
				"read_more": "kw_judgment",
			},
			{
				"title": "A judged unit still shields",
				"text": "A unit that survives at N is [b]alive[/b] — so it still blocks the path to the tower and still absorbs the next attack.\n\nJudgment does not only save a body. It [b]denies the opponent the retarget[/b] they needed.",
				"allow": [],
			},
			{
				"title": "Sanctuary absorbs whole attacks",
				"text": "[b]Sanctuary N[/b] is a pool of N that damage depletes. When the pool is exhausted it becomes plain [b]Sanctuary[/b] for one final [b]full absorb[/b], then is spent.\n\nSo [b]N is a floor, not a ceiling[/b] — 110 damage into Sanctuary 100 is [b]entirely blocked[/b], because the pool cannot cover it.\n\nThe counterplay is inverted on purpose: [b]many small hits beat it, one haymaker feeds it.[/b]",
				"allow": [],
				"read_more": "kw_sanctuary",
			},
			{
				"title": "The order everything resolves in",
				"text": "Within a single attack:\n\n[b]1.[/b] Pick the target  [b]2.[/b] Sanctuary absorbs  [b]3.[/b] Damage lands\n[b]4.[/b] Defensive Judgment  [b]5.[/b] Offensive Judgment  [b]6.[/b] Retribution  [b]7.[/b] Deaths resolve\n\nSanctuary is [b]prevention[/b], so it must come first — otherwise a unit could die, survive at N, then discover it had a shield that would have stopped the hit.",
				"allow": [],
				"read_more": "combat",
			},
			{
				"title": "Attack and watch",
				"text": "Queue an attack and end the turn. Watch a keyword fire.\n\nAnd note the price Heaven pays: [b]Judgment units buy damage at about 8 per energy instead of 12[/b], because the execute is itself worth energy. Heaven's biggest attacks sit on Sanctuary bodies, not Judgment ones.",
				"advance": "round>=2",
				"allow": ["end_turn", "queue", "select", "target"],
				"highlight": {"kind": "end_turn"},
				"final": true,
			},
		],
	}


# --------------------------------------------------------------------- 12. Void

static func _l_void() -> Dictionary:
	return {
		"id": "void",
		"title": "Denial",
		"blurb": "Void — taking their energy instead of killing their units.",
		"teaches": "Siphon · Void N · The Gap · Rift N",
		"deck": _stack([["void_energy", 8], ["hollow_acolyte", 6], ["null_adept", 6], ["draw_down", 4]]),
		"enemy_deck": _stack([["grave_whelp", 12], ["hel_energy", 8]]),
		"hand": ["void_energy", "hollow_acolyte", "null_adept", "draw_down", "void_energy", "null_adept"],
		"start_board": [["hollow_acolyte", 0, 0], ["null_adept", 1, 0]],
		"enemy_board": [["barrow_knight", 0, 0]],
		"skip_setup": true,
		"pool": 6,
		"enemy_attach": [[0, 0, 4]],
		"steps": [
			{
				"title": "Void denies",
				"text": "[b]Void[/b] is absence and entropy. Its verb is [b]deny[/b] — and it is the only faction that attacks the [b]energy economy[/b] rather than bodies.\n\nIt is the predator for players who hoard.",
				"allow": [],
				"read_more": "factions",
			},
			{
				"title": "Siphon takes, it does not destroy",
				"text": "[b]Siphon N[/b] [b]moves[/b] N attached energy from an enemy unit [b]onto this one[/b].\n\nThat is the crucial word: taken, not burned. Void funds its own expensive attacks off what it steals — and the stolen energy now sits on a fragile body that can die holding it. That self-cost is what keeps denial from being purely subtractive.\n\nOn a [i]support[/i] card Siphon goes to your [b]pool[/b] instead, because a support has no body to carry it.",
				"allow": [],
				"read_more": "kw_siphon",
			},
			{
				"title": "Void N destroys outright",
				"text": "[b]Void N[/b] destroys N attached energy with no one gaining it.\n\nDenial hits [b]attached[/b] energy, not the pool — attached is the investment the opponent chose to make. Pool destruction exists only on printed rule-breakers.\n\nAnd denial obeys the [b]same targeting chain as damage[/b]: it can never reach somewhere an attack could not.",
				"allow": [],
				"read_more": "kw_void",
			},
			{
				"title": "The Gap",
				"text": "The [b]Gap[/b] is a global board value, like the round counter:\n\n[b]Gap = your total attached energy − theirs[/b], floored at 0.\n\nIt counts [b]attached energy on living units only[/b] — pool energy is invisible to it. That makes the Gap a measure of [b]commitment[/b], not of wealth. Each player has their own, and they are not symmetric.",
				"allow": [],
				"read_more": "gap",
			},
			{
				"title": "Siphon swings it twice",
				"text": "Every successful Siphon lowers their total and raises yours — it moves the Gap by [b]2N[/b] in your favour.\n\nSteal 1 energy and the Gap moves 2. That is why the direction of the Gap is defined the way it is.",
				"allow": [],
			},
			{
				"title": "Rift cashes it in",
				"text": "[b]Rift N[/b]: this unit's attacks deal [b]+N damage per point of Gap[/b].\n\nThat is the payoff. Siphon starves them early, the Gap it opens pays out through the midgame, and pool-destruction rule-breakers close the game late.\n\nSiphon is designed to [b]fall off[/b] — energy income grows every turn, so stealing 1 stops mattering. It expires on its own rather than being nerfed.",
				"allow": [],
				"read_more": "kw_rift",
			},
			{
				"title": "Steal something",
				"text": "Queue your Siphon attack and end the turn. Watch their attached energy move onto your unit — and watch the Gap swing.",
				"advance": "round>=2",
				"allow": ["end_turn", "queue", "select", "target"],
				"highlight": {"kind": "end_turn"},
				"final": true,
			},
		],
	}


# --------------------------------------------------------------------- 13. Gaia

static func _l_gaia() -> Dictionary:
	return {
		"id": "gaia",
		"title": "Growth",
		"blurb": "Gaia — one aura that feeds your whole board and both towers.",
		"teaches": "Earth · Essence · Resist",
		"deck": _stack([["gaia_energy", 8], ["gaia_sapling_warden", 6], ["gaia_seedbearer", 4], ["gaia_mossback_tortoise", 4]]),
		"enemy_deck": _stack([["grave_whelp", 12], ["hel_energy", 8]]),
		"hand": ["gaia_energy", "gaia_sapling_warden", "gaia_seedbearer", "gaia_mossback_tortoise", "gaia_energy", "gaia_sapling_warden"],
		"start_board": [["gaia_sapling_warden", 0, 0], ["gaia_seedbearer", 1, 0]],
		"enemy_board": [["barrow_knight", 0, 0]],
		"skip_setup": true,
		"pool": 6,
		"steps": [
			{
				"title": "Gaia grows",
				"text": "[b]Gaia[/b] is life and growth. Its verb is [b]fuel[/b] — it builds one number up and lets everything on the board read it.",
				"allow": [],
				"read_more": "factions",
			},
			{
				"title": "Earth is an aura, summed live",
				"text": "[b]Earth N[/b] contributes N to a board-wide aura. Your [b]total Earth[/b] is the sum across every [b]living[/b] unit you control, on both boards.\n\nThat total gives [b]+1 max HP and +1 damage[/b] to every one of your units [b]and both your towers[/b], per point.\n\nAt 8 Earth that is +8 on six different things at once.",
				"allow": [],
				"read_more": "kw_earth",
			},
			{
				"title": "Killing an Earth body shrinks it instantly",
				"text": "The aura is a [b]live sum[/b], not a permanent accrual. Kill an Earth unit and the whole aura drops immediately — towers included.\n\nThat is the counterplay, and it is why the aura is safe to make this strong. Gaia's own board is its only defence.",
				"allow": [],
			},
			{
				"title": "Gaia pays for it below the curve",
				"text": "Earth-carrying bodies buy damage at about [b]9 per energy[/b] against the standard 12.\n\nThat is not a weakness — [b]the aura is the damage[/b]. Every point of Earth is already +1 on every attack from every unit and both towers.",
				"allow": [],
			},
			{
				"title": "Essence — carrying the investment forward",
				"text": "[b]Essence N[/b]: when this unit dies, spend N [b]pool[/b] energy to move its Earth and attached energy to the [b]nearest living friendly unit on the same board[/b].\n\nIt is the mirror of Hel's Toll — same trigger, opposite direction. And it is the reason Gaia is the only faction with a reason to hold pool energy [b]defensively[/b].\n\nIt is priced, so a board wipe still lands: you can only afford one or two funerals.",
				"allow": [],
				"read_more": "kw_essence",
			},
			{
				"title": "Resist — the inverse of Sanctuary",
				"text": "[b]Resist X[/b] reduces [b]each incoming instance[/b] of damage by X, to a [b]minimum of 1[/b].\n\nThe floor matters: without it a Resist 5 body would make Decay 5 do literally nothing forever.\n\nIt is deliberately the opposite of Sanctuary: [b]Resist is strong against chip and weak to burst[/b]; Sanctuary is strong against burst and weak to chip.",
				"allow": [],
				"read_more": "kw_resist",
			},
			{
				"title": "Watch the aura work",
				"text": "Queue an attack and end the turn. Your damage is higher than the card prints, because the aura is adding to it.",
				"advance": "round>=2",
				"allow": ["end_turn", "queue", "select", "target"],
				"highlight": {"kind": "end_turn"},
				"final": true,
			},
		],
	}


# -------------------------------------------------------------- 14. deckbuilding

static func _l_deckbuilding() -> Dictionary:
	return {
		"id": "deckbuilding",
		"title": "Building a Deck",
		"blurb": "Sixty cards, four copies, and the one ratio that decides your game.",
		"teaches": "Deck size · Copy limits · The energy ratio · Evolution lines",
		## The only lesson that is not a battle — it is read alongside the deck
		## builder, because deckbuilding is not something you can do on a board.
		"builder": true,
		"steps": [
			{
				"title": "Exactly 60 cards",
				"text": "Not \"up to\" — [b]a deck that is not exactly 60 cards cannot be taken into a fight.[/b]\n\nA fixed size means an opening hand of 8 and two draws per turn represent the same fraction of the deck in every game, so the ratios you choose are real decisions rather than something you can dodge by trimming the list.",
				"read_more": "deckbuilding",
			},
			{
				"title": "Four copies maximum",
				"text": "[b]At most 4 copies of any card[/b] — and support cards are [b]not[/b] exempt. That cap is what stops a support-heavy deck from becoming a combo deck.",
				"read_more": "deckbuilding",
			},
			{
				"title": "Energy is the exception",
				"text": "[b]Energy cards ignore the 4-copy limit[/b], and how many you run is the core dial of the whole format:\n\n[b]Energy-light[/b] — fast, but hits a ceiling\n[b]Energy-heavy[/b] — stalls early, dominates late\n\nThe shipped decks run [b]15–22[/b]. That is the working range, not a rule.",
				"read_more": "deckbuilding",
			},
			{
				"title": "Run the whole evolution line",
				"text": "The classic trap in a themed deck: [b]an evolution whose Basic is not in the deck[/b].\n\nA Stage 1 needs its Basic already on the board. If you run four Stage 1s and no copies of what they evolve from, those four cards are blanks.",
			},
			{
				"title": "Supports are half the game",
				"text": "Every shipped deck runs [b]15–21 support cards[/b], and the [b]mix[/b] is the identity — an aggressive deck takes draw and reach, a defensive one takes healing and tower support, and they barely overlap.\n\nA unit-only deck never sees half the decision space.",
			},
			{
				"title": "Build around one idea",
				"text": "A deck holding one of everything has no plan to read and plays the same whatever you draw.\n\nEvery shipped deck is built around a [b]single idea[/b] — cheap bodies that pay out when they die, or walls that win on attrition, or a ramp deck that does nothing early and everything late.\n\nPick one thing your deck does better than anything else, and cut what does not serve it.",
				"final": true,
			},
		],
	}


## Build a deck list from `[[id, count], ...]`.
##
## Order is preserved and the list is deliberately NOT shuffled — a lesson deals
## the same hand every run, which is the entire requirement for a scripted step to
## be able to name a card.
##
## Because the order IS the deal, `_stack` interleaves one of each named card
## before repeating any of them. A naive expansion puts all four copies of the
## first card into the opening hand, which for most of these decks means six
## identical cards and — for the lessons whose first card is energy — an opening
## hand with no Basic in it, and therefore no legal first action at all. Round
## robin gives every lesson a hand holding one of each thing it means to talk
## about, which is what the steps are written against.
static func _stack(spec: Array) -> Array:
	var out: Array = []
	var remaining: Array = []
	for pair in spec:
		remaining.append([String(pair[0]), int(pair[1])])

	var any := true
	while any:
		any = false
		for entry in remaining:
			if entry[1] > 0:
				out.append(entry[0])
				entry[1] -= 1
				any = true
	return out


# =========================================================================
#  Compendium
# =========================================================================
#
# Browsable reference. Sections hold pages; a page is {id, title, body}.
# Bodies are BBCode for RichTextLabel.
#
# Keyword page ids are `kw_<keyword>` and TutorialTest asserts that every
# keyword in Palette.KEYWORD_COLORS has one — so a new keyword fails the suite
# until it is documented here.

static func compendium() -> Array:
	return [
		{"title": "Basics", "pages": [
			_p_overview(), _p_board(), _p_turn(), _p_setup(),
		]},
		{"title": "Economy", "pages": [
			_p_economy(), _p_units(), _p_retreat(),
		]},
		{"title": "Combat", "pages": [
			_p_combat(), _p_targeting(), _p_towers(),
		]},
		{"title": "Cards", "pages": [
			_p_support(), _p_deckbuilding(),
		]},
		{"title": "Keywords", "pages": [
			_p_kw_toll(), _p_kw_decay(), _p_kw_rise(), _p_kw_retribution(),
			_p_kw_consume(), _p_kw_judgment(), _p_kw_sanctuary(), _p_kw_windfury(),
			_p_kw_resist(), _p_kw_siphon(), _p_kw_void(), _p_kw_rift(),
			_p_kw_earth(), _p_kw_essence(),
			_p_kw_stoke(), _p_kw_scrap(),
			_p_kw_charge(), _p_kw_storm(),
		]},
		{"title": "Factions", "pages": [
			_p_factions(), _p_gap(),
		]},
	]


static func all_pages() -> Array:
	var out: Array = []
	for sec in compendium():
		for p in sec.get("pages", []):
			out.append(p)
	return out


static func page_by_id(id: String) -> Dictionary:
	for p in all_pages():
		if p.get("id", "") == id:
			return p
	return {}


static func _p_overview() -> Dictionary:
	return {"id": "overview", "title": "What Godsfall Is", "body":
"A turn-based deckbuilding card game for two players.

[b]The core idea: cards are free to play. Energy only buys attacks.[/b]

Deployment is unconstrained — the constraint is [i]acting[/i]. A board full of units you cannot afford to activate is decoration. Every turn is a triage problem: four units, enough energy for one or two attacks, pick.

[b]You win by destroying the enemy throne.[/b] Nothing else ends the game.

Three things stand between you and it:
• Their [b]units[/b], which shield everything behind them
• Their two [b]towers[/b], one per board
• Their [b]throne[/b] at 150 HP, which grows +5 max HP every round

[b]The three decisions that matter[/b]
[b]1.[/b] When to play an energy card — it is worth more the longer you hold it, but you may only play one per turn, so a skipped play can never be made up.
[b]2.[/b] Whether energy sits in your pool or on a unit — the pool decays 20% a turn; attached energy is immune to decay but dies with the body.
[b]3.[/b] Which of your units gets to act — you will always have more units than energy."}


static func _p_board() -> Dictionary:
	return {"id": "board", "title": "The Board", "body":
"Each player has [b]2 boards[/b]. Each board is [b]one lane, 3 slots wide[/b], and its [b]tower[/b] occupies one of those slots until it dies.

While towers live: [b]2 usable unit slots per board — 4 total.[/b]
When both towers die: [b]3 slots per board — 6 total.[/b]

[code]              ENEMY THRONE (150 HP)
   ┌─────────────────────┐  ┌─────────────────────┐
   │  [ 1 ][ 2 ][TOWER]  │  │  [ 1 ][ 2 ][TOWER]  │   enemy
   └─────────────────────┘  └─────────────────────┘
   ┌─────────────────────┐  ┌─────────────────────┐
   │  [ 1 ][ 2 ][TOWER]  │  │  [ 1 ][ 2 ][TOWER]  │   yours
   └─────────────────────┘  └─────────────────────┘
              YOUR THRONE (150 HP)[/code]

[b]Each board is its own fight.[/b] An attack resolves entirely within the board it faces. Units on your other board defend nothing here — if the board being attacked has no living units, its tower is exposed no matter how crowded the board beside it is.

[b]Slots do not compact.[/b] A dead unit leaves a permanent hole. The hole does not open a path to the tower, but it does concentrate damage onto whatever is left.

Killing a tower opens that slot for its owner — but exposes their throne on that board. You may deliberately sacrifice your own tower for the space."}


static func _p_turn() -> Dictionary:
	return {"id": "turn", "title": "The Turn", "body":
"[b]1. Draw[/b] one card.

[b]2. Main phase[/b] — in any order, any number of times:
• Play unit cards (free)
• Evolve units
• Play [b]one[/b] energy card
• Play [b]any number[/b] of support cards
• [b]Charge[/b] — move energy from pool onto a unit (free, unlimited)
• [b]Retreat[/b] a unit
• [b]Queue attacks[/b], optionally naming a target
• [b]Reorder[/b] the volley
• Activate abilities (free, immediate, once per turn each)

[b]3. End of turn resolution[/b], in this order:
[b]1.[/b] Queued attacks resolve in your chosen order
[b]2.[/b] End-of-turn effects (Decay, Tools)
[b]3.[/b] Towers fire — full damage to a unit, half to structures if the board is clear. [b]Silent in round 1.[/b]
[b]4.[/b] Towers and thrones gain [b]+5 max HP, once per round[/b]
[b]5.[/b] Pool decays [b]20%[/b] (minimum 1)
[b]6.[/b] Discard down to [b]10[/b] cards

[b]The attack lock[/b] is a convenience: a locked unit re-queues the attack it used last turn automatically. It only ever queues something you could have queued by hand, and it can be cancelled. Abilities are never auto-used — some destroy attached energy."}


static func _p_setup() -> Dictionary:
	return {"id": "setup", "title": "Setup & Opening Hand", "body":
"Before round 1:

[b]1.[/b] Both players draw [b]8 cards[/b], guaranteed to contain [b]two[/b] Basic units.
[b]2.[/b] Each player may [b]mulligan once[/b].
[b]3.[/b] Both players deploy Basics into empty slots. Nothing else — no energy, no supports, no attacks.
[b]4.[/b] Round 1 begins. Towers are silent through it.

[b]The guaranteed Basics are a deal filter, not a stacked hand.[/b] The deck is reshuffled and re-dealt whole rather than Basics being searched to the top, so everything except the guarantee stays as random as the deck makes it.

It exists because [b]a hand with no Basic cannot take a single action all turn[/b]: units are the only free play, a Stage 1 needs a body on the board, and energy with nothing to charge does nothing.

[b]The mulligan is free and has no penalty.[/b] Same hand size, once per game, setup only — the decision is meant to be made on the hand alone, before any unit is placed.

[b]Setup deployment is simultaneous.[/b] Neither player's setup reacts to the other's, because placement decides facing and a side that could counter-place would be handed the whole targeting geometry."}


static func _p_economy() -> Dictionary:
	return {"id": "economy", "title": "Energy", "body":
"[b]Income[/b]
Energy cards are [b]built into your deck[/b] and you choose how many. You may play [b]one per turn[/b].

An energy card played on turn [i]t[/i] gives [b]t + 1[/b] energy. Turn 1 -> 2. Turn 5 -> 6. Turn 9 -> 10.

So holding an energy card makes it worth more — but one-per-turn means a skipped play can never be made up.

[b]The pool[/b]
Persistent — it carries across turns and does not refresh. At end of turn it [b]decays 20%[/b], minimum 1, rounded down. That stabilises the pool around 5 × (t+1): banking is possible, just taxed.

[b]Attaching[/b]
[b]Charging[/b] moves energy from the pool onto a unit. Free, unlimited.

Attached energy is [b]permanent[/b], survives attacking, carries [b]through evolution[/b], and is [b]immune to decay[/b] — but is [b]lost entirely when the unit dies[/b].

Queueing an attack pulls [b]exactly[/b] its cost from the pool onto the unit. A 1-cost attack takes 1, even from a 20-energy pool. Once enough is attached, that attack is [b]free every turn[/b] — the payment is one-time.

[b]The two-sided risk[/b]
[b]Pool[/b] — decays, but safe from unit death.
[b]Attached[/b] — safe from decay, but dies with the body.

That is the game's central skill expression.

[b]Damage rates[/b]
Standard attack: [b]≈12 damage per energy[/b] — a one-time cost that pays out every turn, priced as an annuity.
Consume attack: [b]≈20 per energy consumed[/b] — it destroys the investment, so it pays ~1.7× up front.
Judgment units: [b]≈8 per energy[/b] — the execute is worth the difference."}


static func _p_units() -> Dictionary:
	return {"id": "units", "title": "Units, Stages & Abilities", "body":
"[b]HP by stage[/b]
[b]Basic[/b] 40–90 · [b]Stage 1[/b] 80–120 · [b]Stage 2[/b] 110–175

These are [b]bands, not targets[/b], and they overlap deliberately. Stage is not a power ranking: a 90 HP Basic has paid for its size in attack cost or text, and a small Stage 1 is buying utility instead of a body.

[b]The two-line rule[/b]
[b]Every unit has at most two lines[/b] — either one passive ability and one attack, or two attacks. A hard structural constraint that forces every card to commit to an identity instead of accumulating text. Multiple keywords on one line count as one line.

[b]Abilities vs. attacks[/b]
[table=3]
[cell][/cell][cell][b]Attack[/b][/cell][cell][b]Ability[/b][/cell]
[cell]Resolves[/cell][cell]End of turn[/cell][cell]Immediately[/cell]
[cell]Cost from[/cell][cell]Pool -> attached[/cell][cell]Nothing, or Consume[/cell]
[cell]After first use[/cell][cell]Free — energy stays[/cell][cell]Free, unless it Consumes[/cell]
[cell]Limit[/cell][cell]One queued per unit[/cell][cell]Once per turn[/cell]
[/table]

An attack's cost is an [b]annuity[/b] — pay once, free every turn after. A Consume is the opposite: it charges every single time, which is what lets Consume abilities be strong without becoming permanent engines.

[b]Evolution[/b]
Free, like all card plays. [b]Carries attached energy forward[/b] — mandatory, or no Stage 2 could ever be charged. Evolving does [b]not[/b] discard the base card: it stays under the unit and reaches the discard only when the unit dies.

[b]Combat[/b]
Attacks are [b]one-directional[/b] — the defender does not strike back unless a card says so. Units [b]persist[/b] between turns and are not exhausted by attacking. Dead units go to the discard, and their attached energy is lost."}


static func _p_retreat() -> Dictionary:
	return {"id": "retreat", "title": "Retreat", "body":
"[b]Retreat pulls a unit off the board and back into your hand.[/b] There is no bench — nothing takes its place.

[b]How it resolves[/b]
[b]1.[/b] Pay the retreat cost [b]from the unit's own attached energy[/b]. Never from the pool, never from another unit.
[b]2.[/b] That energy is [b]spent[/b] — gone.
[b]3.[/b] [b]Leftover attached energy returns to your pool.[/b] The only way attached energy comes off a unit without it dying.
[b]4.[/b] The card returns to hand, [b]healed to full[/b], and [b]locked for one turn[/b].
[b]5.[/b] The slot is empty and does not compact.

[b]If attached energy is less than the retreat cost, the unit cannot retreat.[/b] An uncharged unit is stuck on the board.

[b]Cost = HP ÷ 40[/b], rounded down.
40–79 -> 1 · 80–119 -> 2 · 120–159 -> 3 · 160+ -> 4

Printed on the card at design time. It never recalculates: buffs, debuffs and damage never move it.

[b]Retreat is cheaper than Toll deliberately.[/b] Retreat divides by 40, Toll by 25 — so on the same body, saving it is the [b]affordable[/b] line and feeding it to the discard is the [b]deliberate[/b] one.

[b]Evolved units[/b] bring their [b]whole evolution path[/b] back as separate cards, all locked. You rebuild from the bottom.

[b]Retreat does not trigger death effects.[/b] No Toll, no Rise, no discard. It is the [b]alternative[/b] to dying — never both.

[b]Why it is not overpowered:[/b] saving a unit does not win the game, it [b]removes a shield[/b]. Your board is your only defence, and retreating thins it. Near the 10-card hand limit, retreating a Stage 2 puts three unplayable cards in your hand at once."}


static func _p_combat() -> Dictionary:
	return {"id": "combat", "title": "Damage Resolution", "body":
"Attacks resolve [b]in the order you chose[/b], defaulting to left to right, board by board. [b]Each attack resolves fully before the next begins.[/b]

Within a single attack:

[b]1. Select target[/b] — named -> slot across -> leftmost living -> tower -> throne. Dead units are skipped.
[b]2. Apply Sanctuary[/b] — prevention absorbs first.
[b]3. Deal remaining damage[/b] — HP drops.
[b]4. Defensive Judgment[/b] — if HP ≤ 0 and the defender has Judgment: survive at N, spend it.
[b]5. Offensive Judgment[/b] — if the defender survived at ≤ N: destroy it, spend the attacker's Judgment.
[b]6. Retribution[/b] — defender deals recoil to the attacker.
[b]7. Deaths resolve[/b] — everything marked dead leaves together: discard, attached energy lost, Tools discarded, Toll and Rise fire.

[b]Sanctuary before Judgment[/b] because a shield is [b]prevention[/b] — it can never be \"too late\" to matter. The reverse order gives the absurd case of a unit dying, surviving at N, then discovering it had a shield.

[b]Nothing leaves the board mid-attack.[/b] A unit destroyed at step 5 remains present through step 6, so it still deals its Retribution recoil. An attacker cannot dodge the counter-punch by killing fast enough. If that recoil kills the attacker, both die.

That guarantee is scoped [b]within a single attack[/b] — attack 1's deaths resolve before attack 2 begins, so a board can still be cleared within one volley.

[b]Volley ordering[/b]
Your queued attacks are an ordered list, rearrangeable any time before you end the turn, and you may interleave both boards freely.

This is what makes Judgment play the way it reads: put the heavy hitter first and the Judgment body second, and the execute becomes a plan rather than a coincidence."}


static func _p_targeting() -> Dictionary:
	return {"id": "targeting", "title": "Targeting & Shielding", "body":
"[b]Units shield the structures behind them.[/b] As long as anything is alive on a board, attacks against that board can only hit units — never the tower, never the throne.

[b]Shielding is per-board and never crosses boards.[/b]

[b]The chain[/b]
[b]1.[/b] The [b]named target[/b], if the attacker chose one and it is still alive
[b]2.[/b] The unit in the [b]slot directly across[/b]
[b]3.[/b] Otherwise the [b]leftmost[/b] living unit on that board
[b]4.[/b] Otherwise that board's [b]tower[/b]
[b]5.[/b] Otherwise the [b]throne[/b]

The fallback is [b]deterministic[/b] — leftmost, always. No prompt.

[b]Chosen targets[/b]
When you queue an attack you may name any [b]living enemy unit on the board that attacker faces[/b]. Never the tower, never the throne, never the other board — choosing picks [i]among[/i] the wall, never past it.

[b]Legality is checked when the attack resolves, not when it is queued.[/b] A named target that died earlier in the volley is simply gone, and the attack falls back to the slot across, then the leftmost survivor. Aiming at a unit something else might kill is always safe.

[b]A stale pick does not slide sideways.[/b] It reverts to an ordinary untargeted attack — it does not hunt for the nearest living body to the one you pointed at.

[b]No overkill[/b]
Once a unit dies, no further attack in that resolution may hit it. A later attack aimed at a corpse [b]re-resolves from the top of the chain[/b].

Damage is never wasted on a corpse, and never banked: the excess from an overkill does not carry to the next target. [b]The attack retargets whole.[/b]

This makes intra-turn ordering matter [b]more[/b], not less. Sequencing a volley so the kills land first is the way to reach a tower in one turn.

[b]All lane damage follows this chain[/b], not just attacks — Decay uses it too. The only exception is a card that explicitly prints one."}


static func _p_towers() -> Dictionary:
	return {"id": "towers", "title": "Towers & Throne", "body":
"[b]Tower[/b] — one per board, 2 total. 75 HP. Gains +5 max HP per round.
[b]Throne[/b] — 150 HP. Gains +5 max HP per round.

[b]Growth is per round[/b], not per turn — once both players have acted.

[b]The damage curve[/b]
[b]Towers are silent for the whole of round 1.[/b] Then:

[table=9]
[cell][b]Round[/b][/cell][cell]1[/cell][cell]2[/cell][cell]3[/cell][cell]4[/cell][cell]5[/cell][cell]8[/cell][cell]12[/cell][cell]20[/cell]
[cell][b]Damage[/b][/cell][cell]0[/cell][cell]5[/cell][cell]8[/cell][cell]11[/cell][cell]14[/cell][cell]23[/cell][cell]35[/cell][cell]59[/cell]
[cell][b]vs structure[/b][/cell][cell]0[/cell][cell]2[/cell][cell]4[/cell][cell]5[/cell][cell]7[/cell][cell]11[/cell][cell]17[/cell][cell]29[/cell]
[/table]

The formula is [b]5 + 3 × (round − 2)[/b], floored at 0 before round 2.

[b]Against an empty board[/b]
A tower whose facing board holds [b]no living unit[/b] fires at that board's structures for [b]half[/b] damage, rounded down, minimum 1 — the tower first, the throne only once that tower is dead.

[b]A single living unit anywhere on the board absorbs the shot at full damage[/b] and the structures behind it take nothing. Clearing a board is still what exposes what is behind it.

[b]Why half and not full:[/b] a tower hitting structures at full rate is two structures racing each other with no way for either player to interact. Halving keeps tower fire a [b]unit[/b] weapon whose reach past an empty board is real pressure rather than a kill.

[b]Why the grace round:[/b] both players open with an empty board and one draw. A tower firing at the end of the very first turn meant the game's first action was structural chip nobody could answer.

[b]Towers are an attrition engine, not a wall.[/b] Every turn you do not answer a tower, it eats another unit. The early game is forced tempo.

[b]Tower support[/b] cards modify a tower you control and [b]stack without limit[/b]. The hard line: [b]no tower support may raise the rate at which a tower hits structures.[/b] A stack adding +10 damage adds 5 to a throne shot, not 10.

Modifications are lost when the tower dies, and do not transfer."}


static func _p_support() -> Dictionary:
	return {"id": "support", "title": "Support, Tools & Tower Support", "body":
"[b]Support cards[/b] are one-shot effects: play, resolve, discard. Usually free, [b]no per-turn limit[/b], no item/supporter split.

[b]Hand size is the cost.[/b] A support is a card you drew instead of a unit, in a game where you draw two per turn.

[b]The power band[/b]
A support sits at roughly [b]one turn of tempo[/b]. Nothing should win a game on its own.

Draw ~3 cards · Search 1–2 Basics · Heal 20 baseline · +2 to +3 pool energy · ~20 direct damage · Move a unit or its energy

[b]Supports must not sell damage at attack rates.[/b] That is the one line to hold — a free 25-damage support would make the energy economy optional.

[b]Priced supports[/b]
A minority cost [b]1–3 pool energy[/b] — the sanctioned exception to \"energy only buys attacks\", paid from the pool so it competes directly with attacking that turn.

It exists because cost is the cleanest way to print [b]two versions of one card[/b]:
• [b]Shore Up[/b] heals 20, free -> [b]Field Surgery[/b] heals 50, for 1
• [b]Collapse[/b] deals 20 to an [i]uncharged[/i] unit -> the priced version drops the restriction

The free one is a floor every deck can run; the priced one drops the restriction. They should [b]trade off, not rank[/b].

Healing sets the reference rate: [b]20 baseline, +30 per energy[/b]. [b]No card fully heals a unit[/b] — every heal is a flat number, never a percentage, because a heal that scales with its target cannot be priced.

[b]Tools[/b]
A Tool attaches to a unit and [b]stays[/b] — the one exception to play-resolve-discard.

[b]One Tool per unit.[/b] Free to attach. Stays through evolution. Goes to the discard when the unit [b]dies or retreats[/b] — retreat saves the body, not the equipment.

Tools are priced [b]below[/b] one-shots because they pay out every turn: a Tool should take [b]3–4 turns to match[/b] what a one-shot does immediately. That delay is enforced by the board — a Tool only pays while its unit lives, which makes Tools a natural fit for walls and a trap on chaff.

[b]Tower support[/b]
Modifies a tower you control; does nothing if both your towers are dead. [b]Permanents stack without limit[/b] — unlike Tools, because a tower is a fixed thing you choose to invest in and the interesting question is [b]how much[/b], not whether.

Cheap because self-limiting: [b]a live tower is a lane slot you never get to use.[/b]

[b]The hand limit[/b]
[b]Maximum 10 cards[/b], checked [b]at end of turn[/b] after everything else resolves. Checking then rather than continuously is what makes draw supports work — a draw-3 from a hand of 9 draws all three."}


static func _p_deckbuilding() -> Dictionary:
	return {"id": "deckbuilding", "title": "Deckbuilding", "body":
"[b]Exactly 60 cards.[/b] Not \"up to\" — a deck that is not 60 cannot be taken into a fight. A fixed size makes draw probabilities mean the same thing in every matchup.

[b]Maximum 4 copies[/b] of any card. [b]Support cards are not exempt[/b] — that cap is what keeps a support-heavy deck from becoming a combo deck.

[b]Energy cards are exempt[/b] from the 4-copy limit. How many you run is a core dial:
• [b]Energy-light[/b] — fast, but hits a ceiling
• [b]Energy-heavy[/b] — stalls early, dominates late

Shipped decks run [b]15–22[/b] energy and [b]15–21[/b] supports.

[b]Draw & hand[/b]
Opening hand [b]6[/b], draw [b]1[/b] per turn, maximum hand size [b]10[/b].

[b]Multi-faction decks[/b] should be common and manageable. Multi-faction units cost more total energy but get [b]stronger effects[/b] — never higher raw damage.

[b]Practical advice[/b]
• [b]Run the whole evolution line.[/b] A Stage 1 with no Basic in the deck is a blank card.
• [b]Build around one idea.[/b] A deck holding one of everything has no plan to read.
• [b]Do not skip supports.[/b] A unit-only deck never sees half the decision space."}


static func _p_factions() -> Dictionary:
	return {"id": "factions", "title": "The Factions", "body":
"[b]A faction is an energy colour.[/b] Four exist.

[b]Hel[/b] — death, decay, the dead. Verb: [b]recycle[/b].
Signatures: [b]Toll[/b], [b]Decay[/b]. The banking faction — its units dying is the plan, because dying pays.

[b]Void[/b] — absence, entropy, unmaking. Verb: [b]deny[/b].
Signatures: [b]Siphon[/b], [b]Void N[/b]. The only faction that attacks the [b]energy economy[/b] rather than bodies. The predator for hoarders.

[b]Gaia[/b] — life, growth, nature. Verb: [b]fuel[/b].
Signatures: [b]Earth[/b], [b]Essence[/b]. One aura that feeds every unit and both towers at once.

[b]Heaven[/b] — order, light, judgment. Verb: [b]protect[/b].
Prints [b]Judgment[/b] and [b]Sanctuary[/b] most often and largest. Stacks reprieves and converts durability into kills.

[b]Keywords are shared by default.[/b] A keyword belongs to the whole game unless a faction claims it as a signature. Each faction may hold up to [b]two[/b] signatures; everything else — Rise, Retribution, Consume, Windfury, Sanctuary, Judgment, Resist — any faction may print.

Factions are defined by [b]which keywords they combine and how large they print them[/b], not by owning them outright.

[b]Subfactions[/b]
A faction is not one deck — it is a shared colour hosting several themes, each built around its own mechanic. Subfactions mix freely in a deck. New content ships as a new subfaction inside an existing colour, which keeps the colour count low while giving each faction room to grow."}


static func _p_gap() -> Dictionary:
	return {"id": "gap", "title": "The Gap", "body":
"[b]The Gap is a global board state, not a keyword[/b] — a number both players can read at any time, like the round counter. It is defined here because it is a property of the [b]board[/b], not of a card.

[b]Gap = your total attached energy − the opponent's, floored at 0.[/b]

Each player has their own, and they are [b]not symmetric[/b]: if you hold 10 attached and they hold 4, your Gap is 6 and theirs is 0.

[b]It counts attached energy only.[/b] Pool energy is invisible to it — which makes the Gap a measure of [b]commitment[/b] rather than of wealth. Energy sitting safely in a pool has not been staked on anything.

[b]It counts living units only.[/b] A unit marked dead mid-volley still sits on the board for Retribution, but its energy is already forfeit.

[b]It floors at 0.[/b] Cards that read the Gap only ever promise a bonus, so a negative value would silently become a penalty on a card whose text never mentioned one.

[b]Siphon swings it by 2N[/b] — it lowers their total and raises yours at the same time. That is why the Gap is defined in this direction: the opposite definition would make Void's primary keyword turn off its own payoff cards.

Read by [b]Rift N[/b]."}


# ------------------------------------------------------------- keyword pages

static func _p_kw_toll() -> Dictionary:
	return {"id": "kw_toll", "title": "Toll N", "keyword": "toll", "faction": "Hel signature", "body":
"[b]When this unit dies, gain N energy.[/b]

N is derived from the card's HP at design time — [b]HP ÷ 25[/b], rounded down — and [b]printed on the card[/b]. It never recalculates in play: buffs, debuffs and damage never move it.

Toll turns a bad combat into a turn of income, and it is the reason Hel does not mind losing bodies.

[b]Retreat pays no Toll.[/b] A retreated unit did not die. Hel chooses between the refund and the card — never both.

Toll and retreat deliberately use different divisors (25 vs 40), so [b]retreat is systematically cheaper than the Toll refund[/b] on the same body. Saving a unit is the affordable line; feeding it to the discard is the deliberate one."}


static func _p_kw_decay() -> Dictionary:
	return {"id": "kw_decay", "title": "Decay N", "keyword": "decay", "faction": "Hel signature", "body":
"[b]At end of turn, deal N damage to the unit across from this one.[/b]

Free, automatic, and it never stops. Decay is chip damage that costs no energy — the purest expression of Hel's attrition.

[b]Decay follows the standard targeting chain[/b], the same as attacks: named target, slot across, leftmost living, then structures. So a Decay board cannot chip a throne past a wall.

Decay is weak against [b]Resist[/b] — a Resist 5 body takes only the minimum 1 from a Decay 5 tick — and strong against [b]Sanctuary N[/b], because many small hits are what deplete a Sanctuary pool efficiently."}


static func _p_kw_rise() -> Dictionary:
	return {"id": "kw_rise", "title": "Rise", "keyword": "rise", "faction": "Shared", "body":
"[b]When this dies, return it to an empty slot on your side at the start of your next turn, at half HP and without Rise.[/b]

Every other ability, attack and keyword returns [b]intact, at printed values[/b].

What does [b]not[/b] come back:
• [b]Attached energy[/b] — lost with the death, like any other
• [b]Anything the card grew in play[/b] — notably Gaia's Earth

[b]Rise restores the card, not the history.[/b] That is what caps the loop: without it, Rise plus any growth keyword would be an engine — die, keep the accumulation, return, grow further.

Losing only Rise (and keeping everything else) is what lets a Rising unit pay its [b]Toll[/b] twice."}


static func _p_kw_retribution() -> Dictionary:
	return {"id": "kw_retribution", "title": "Retribution N", "keyword": "retribution", "faction": "Shared", "body":
"[b]When this unit takes damage from an attack, deal N damage back to the attacker.[/b]

Retribution resolves at [b]step 6[/b] of the damage order — after damage, after both halves of Judgment, before deaths resolve.

That position matters: [b]nothing leaves the board mid-attack[/b]. A unit destroyed by the attack is [b]marked[/b] dead but remains present through the Retribution step, so it [b]still deals its recoil[/b]. An attacker cannot dodge the counter-punch by killing fast enough — and if the recoil kills the attacker, both die.

Retribution is what makes a wall expensive to break rather than merely slow, and Tools like [b]Iron Standard[/b] stack with the printed value."}


static func _p_kw_consume() -> Dictionary:
	return {"id": "kw_consume", "title": "Consume N", "keyword": "consume", "faction": "Shared", "body":
"[b]This line destroys N attached energy on activation[/b] — rather than merely requiring it.

Priced at [b]≈20 damage per energy consumed[/b] against the standard 12, because it burns the investment rather than banking it.

Consume may appear on an [b]attack or an ability[/b], and on an ability it is [b]the only cost permitted[/b].

That is the whole reason it exists. An activated ability is otherwise [b]free[/b] — energy only buys attacks. Consume is what stops a free once-per-turn effect from being a permanent no-cost engine: the unit has to be re-charged to keep using it.

[b]An attack's cost is an annuity[/b] — pay once, free every turn after. [b]A Consume charges every single use.[/b] That asymmetry is what lets Consume abilities be strong.

Every faction has access to Consume, tuned to its own identity."}


static func _p_kw_judgment() -> Dictionary:
	return {"id": "kw_judgment", "title": "Judgment N", "keyword": "judgment", "faction": "Heaven (prints it most)", "body":
"[b]One charge, spent by either use.[/b]

[b]Defensive[/b] — when this unit would die, it instead [b]survives at N HP[/b].
[b]Offensive[/b] — when this unit attacks and leaves the defender at [b]N HP or below[/b], that defender is [b]destroyed[/b].

[i]I survive at N, and I kill anything I leave at N.[/i]

[b]The cost is not the number — it is that using it either way consumes it.[/b] A larger N is better in both directions with no downside dial, so a Judgment 100 unit is enormously powerful [b]exactly once[/b] and is then an ordinary body.

That poses a decision every turn: [b]cash the charge to delete something, or hold it as the insurance keeping this unit alive?[/b]

[b]On-hit only.[/b] The execute fires only when [i]this attack[/i] leaves the defender at ≤ N. Never a passive board check, never at end of turn.

[b]A judged unit still shields.[/b] It survived, so it is alive, so it still blocks the path to the tower. Judgment does not only save a body — it [b]denies the opponent the retarget[/b].

[b]Judgment combos with itself.[/b] A unit judged down to N is inside execute range of every other Judgment unit you control.

[b]N is capped by stage:[/b] Basic ≤ 20, Stage 1 ≤ 40, Stage 2 ≤ 50.

[b]The mirror resolves by ordering.[/b] Defensive is checked before offensive, so a Judgment 30 attacking a Judgment 10 for lethal leaves the defender alive at 10 with its charge spent — then the attacker's execute fires on a survivor at ≤ 30, spending its own. Both charges spend, one unit lives.

[b]Judgment units buy damage at ≈8 per energy[/b] instead of 12 — a flat one-third cut, because the execute is a discount on the kill.

Returns only if the card returns to hand. [b]Windfury may never appear on a Judgment unit.[/b]"}


static func _p_kw_sanctuary() -> Dictionary:
	return {"id": "kw_sanctuary", "title": "Sanctuary / Sanctuary N", "keyword": "sanctuary", "faction": "Heaven (prints it most)", "body":
"[b]Plain Sanctuary[/b] absorbs the next instance of damage [b]entirely[/b], from any source, then is spent.

[b]Sanctuary N[/b] is a [b]pool of N[/b] that damage depletes. When the pool is exhausted it becomes plain Sanctuary for one final [b]full absorb[/b], then is spent.

[b]N is a floor, not a ceiling.[/b]

[table=2]
[cell][b]Incoming[/b][/cell][cell][b]Result[/b][/cell]
[cell]30 into Sanctuary 100[/cell][cell]Absorbed. Now Sanctuary 70.[/cell]
[cell]110 into Sanctuary 100[/cell][cell]Pool cannot cover it -> [b]full absorb[/b]. All 110 blocked.[/cell]
[cell]30 into Sanctuary 20[/cell][cell]Pool cannot cover it -> [b]full absorb[/b].[/cell]
[cell]30 × 4 into Sanctuary 100[/cell][cell]100 -> 70 -> 40 -> 10, then the fourth is fully absorbed. Four attacks blocked.[/cell]
[/table]

[b]Blocks all damage sources[/b] — attacks, tower fire, Decay, support damage, Retribution.

[b]Why a pool and not a boolean:[/b] a boolean shield is popped identically by a free Decay 5 tick and a 75-damage attack, making the cheapest possible chip the best answer to the most expensive shield. A pool makes small hits inefficient while the terminal overflow still eats one whole big hit.

[b]Minimum printed N is 60.[/b] Below that the number does no work — because of the free overflow, a Sanctuary 30 against a 38-damage attack blocks all 38, identical to plain Sanctuary. Printed values are plain, 60, 80, or 100.

[b]The counterplay is inverted, deliberately: many small hits beat it, one haymaker feeds it.[/b] Wide boards break Sanctuary; burst does not.

Sanctuary resolves [b]before[/b] Judgment — it is prevention, so it can never be too late to matter."}


static func _p_kw_windfury() -> Dictionary:
	return {"id": "kw_windfury", "title": "Windfury", "keyword": "windfury", "faction": "Shared", "body":
"[b]This unit may attack twice per turn.[/b]

[b]Windfury must never appear on any unit that holds or grants Judgment.[/b] Two attacks is two chances at the execute threshold, and on a Judgment-reset card it collapses the execute/recharge rhythm into a single turn, removing the brake entirely. Multi-attack plus threshold removal is the most dangerous combination available.

[i]Documented but not yet implemented — no card currently uses it.[/i] It is defined so that Tempest, the reserve storm faction, and future rule-breakers have a home. Tempest's identity would be [b]cheap, repeated, unconditional[/b] multi-attack — printing Windfury widest and cheapest rather than owning it."}


static func _p_kw_resist() -> Dictionary:
	return {"id": "kw_resist", "title": "Resist X", "keyword": "resist", "faction": "Shared", "body":
"[b]Reduce each incoming instance of damage by X, to a minimum of 1 damage.[/b]

[b]The minimum-1 floor is not optional.[/b] Without it a Resist 5 body would make Hel's Decay 5 do literally nothing, forever — and \"my entire keyword does nothing\" is the worst outcome available.

[b]Per instance[/b] is the whole character of the keyword. Four attacks of 10 into Resist 5 take 20 total, not 35.

[b]Resist is the deliberate inverse of Sanctuary N:[/b]
• [b]Resist[/b] — per instance. [b]Strong against chip, weak to burst.[/b]
• [b]Sanctuary[/b] — a depleting pool. [b]Strong against burst, weak to chip.[/b]

Resist applies in both damage paths and to Retribution recoil.

Deliberately [b]not[/b] part of any faction's identity, Gaia's included — the shared keyword list exists so any card can reach for it on flavour."}


static func _p_kw_stoke() -> Dictionary:
	return {"id": "kw_stoke", "title": "Stoke N", "keyword": "stoke", "faction": "Forge signature", "body":
"[b]A free once-per-turn ability: deal N damage to this unit. It has [i]stoked[/i] until the end of your turn.[/b]

[b]Stoke does not pay for anything by itself.[/b] Activating it is the whole action — you lose the HP, and the unit is now flagged. [b]Other lines read that flag[/b]: \"if this unit stoked this turn, +10 damage\", \"...this attack costs no energy\", \"...it burns past living units\".

That separation is the entire keyword. The HP is spent [b]before you know what you will need it for[/b], and everything that pays you back has to already be on the board.

[b]Stoke damage is unpreventable.[/b] Sanctuary does not absorb it, Resist does not reduce it, and Retribution does not recoil — there is no attacker. It is a [b]cost you choose to pay[/b], not damage from a source. If it went through the damage path, a shielded body would stoke for free and the faction's central cost would be optional in exactly the matchups where it has to be real.

[b]It may kill the unit paying it[/b], and that death is an ordinary one — Toll refunds, Rise returns it, Essence may pay for it. Forge gets no private kind of death.

[b]The flag is per-unit.[/b] Unit A stoking does not turn on unit B's attack. A card that reads another unit's flag has to print that it does.

[b]N varies by unit[/b], and that is a balance axis: a Basic prints Stoke 20, a Stage 2 may print Stoke 50. The anchor is roughly [b]20 HP ≈ 1 energy of value[/b]. Payoffs that scale with the amount, or that require a threshold, are what make a large printed Stoke worth having."}


static func _p_kw_scrap() -> Dictionary:
	return {"id": "kw_scrap", "title": "Scrap", "keyword": "scrap", "faction": "Forge signature", "body":
"[b]An ability cost: destroy another unit you control to activate this line.[/b]

Where Stoke spends a body gradually, Scrap spends one outright.

[b]Another unit — never itself.[/b] A line that ate its own body would resolve with nothing left to have resolved from.

[b]The scrapped unit really dies.[/b] Toll refunds, Rise returns it, Essence may pay for it, its attached energy is lost and its Tool is discarded. That is the opposite of [b]retreat[/b], which is the alternative to dying and fires none of them.

That is also the deliberate multi-faction door: [b]Forge/Hel[/b] scraps a Toll body and gets paid for the fuel.

[b]It charges every single use.[/b] An attack's cost stays attached and fires free every turn after — an annuity. Scrap, like Consume, is the opposite, which is what lets a free once-per-turn ability be strong without becoming a permanent engine.

[b]Scrap is rare[/b], and the reason is board width: every Scrap costs a slot, and a thin board is a board whose tower is about to be exposed."}


static func _p_kw_siphon() -> Dictionary:
	return {"id": "kw_siphon", "title": "Siphon N", "keyword": "siphon", "faction": "Void signature", "body":
"[b]Move N attached energy from an enemy unit onto this one.[/b]

[b]Siphon takes, it does not destroy.[/b] That is the load-bearing word. It lets Void fund its own expensive attacks without a second ramp mechanic — and it puts the stolen energy on a [b]fragile body that can die holding it[/b], which is the self-cost that keeps denial from being purely subtractive.

[b]On a support card, Siphon goes to your pool instead[/b], because a support has no body to carry it. That split matters: pool energy is safe from unit death but exposed to decay and [b]does not feed the Gap[/b]. So support Siphon is ramp, while unit Siphon is ramp [b]and[/b] Gap — which keeps units at the centre of the faction.

[b]Siphon swings the Gap by 2N[/b] — it lowers their total and raises yours simultaneously.

[b]It obeys the standard targeting chain[/b] and never falls through to a tower or throne. Denial must never reach somewhere an attack could not.

[b]Siphon is designed to fall off.[/b] Energy income is t+1 and grows every turn, so stealing 1–2 is a large fraction of a turn-3 board and irrelevant by turn 10. It expires on its own — the cheapest possible way for a mechanic to have a lifespan."}


static func _p_kw_void() -> Dictionary:
	return {"id": "kw_void", "title": "Void N", "keyword": "void", "faction": "Void signature", "body":
"[b]Destroy N attached energy on an enemy unit.[/b] No one gains it.

The harder, blunter half of Void's denial. Siphon [b]takes[/b] and funds you; Void [b]destroys[/b] and funds nobody.

[b]Denial hits attached energy, not the pool.[/b] Attached energy is the investment the opponent [b]chose[/b] to make — destroying it punishes commitment, which is the behaviour Void exists to prey on. Pool destruction exists only on explicitly printed rule-breakers.

[b]It obeys the standard targeting chain[/b] — slot across, then leftmost — and never falls through to a tower or throne."}


static func _p_kw_rift() -> Dictionary:
	return {"id": "kw_rift", "title": "Rift N", "keyword": "rift", "faction": "Void signature", "body":
"[b]This unit's attacks deal +N damage per point of Gap.[/b]

Rift is Void's payoff — the card that cashes in what Siphon spent the early game building. See [b]The Gap[/b] for how that number is computed.

[b]It is deliberately uncapped.[/b] Reaching a large Gap [i]means[/i] having staked that much energy on bodies that can all die at once, so winning from there is the payout, not a failure.

Rift attacks pay [b]8 damage per Rift point[/b] off their printed base — the keyword is priced for [b]existing[/b], not for its tail. Only one card in the game prints [b]Rift 2[/b].

[b]Void's three phases:[/b]
[b]Early[/b] — Siphon starves. 1–2 energy is a large fraction of a turn-3 board.
[b]Mid[/b] — Rift pays out off the Gap that early siphoning opened.
[b]Late[/b] — pool-destruction rule-breakers close."}


static func _p_kw_earth() -> Dictionary:
	return {"id": "kw_earth", "title": "Earth N", "keyword": "earth", "faction": "Gaia signature", "body":
"[b]Earth N contributes N to a board-wide aura.[/b]

Your [b]total Earth[/b] is the sum across every [b]living[/b] unit you control, on [b]both boards[/b]. That total grants:

[b]+1 max HP and +1 damage per point[/b], to [b]every one of your units and both your towers[/b].

At 8 Earth that is +8 on six different things simultaneously — which is why Gaia's bodies buy damage at [b]≈9 per energy[/b] against the standard 12. [b]The aura is the damage.[/b]

[b]It is a live sum, not a permanent accrual.[/b] Kill an Earth body and the whole aura shrinks [b]immediately[/b], towers included. That is the counterplay, and it is what makes an aura this broad safe to print: Gaia's own board is its only defence, and the opponent's removal is the answer.

[b]The aura is linear at +1/+1, and cards may only break the rate additively[/b] — \"Earth grants +2 instead of +1\". A multiplier on the Earth total would be exponential across six things at once.

[b]Earth growth is card text, not keyword text.[/b] The keyword defines the aura only; cards gain Earth however they print it — on attack, on being damaged, from an ability, or derived live from attached energy.

[b]Grown Earth resets on Rise and on evolution[/b], exactly as attached energy does. Rise restores the card, not the history."}


static func _p_kw_essence() -> Dictionary:
	return {"id": "kw_essence", "title": "Essence N", "keyword": "essence", "faction": "Gaia signature", "body":
"[b]When this unit dies, spend N pool energy to move its Earth and attached energy to the nearest living friendly unit on the same board.[/b]

The [b]structural mirror of Hel's Toll[/b] — same trigger, opposite direction. Toll converts a death into income; Essence converts a death into [b]continuity[/b].

It is the deliberate exception to [i]attached energy is lost when the unit dies[/i].

[b]It is priced, not free.[/b] The energy must have been banked in [b]advance[/b], so a board wipe still lands — you can only afford one or two funerals. That is why Gaia is the only faction with a reason to hold pool energy [b]defensively[/b], and it matters because Gaia has no ramp: carrying the investment forward is necessary rather than greedy.

[b]Nearest living friendly unit, same board, ties go left.[/b] It never crosses boards — crossing would make Essence best at exactly the moment it should fail, when the board it defended has been cleared.

If you cannot pay, it simply does not fire."}


static func _p_kw_charge() -> Dictionary:
	return {"id": "kw_charge", "title": "Charge N", "keyword": "charge", "faction": "Tempest signature", "body":
"[b]A visible counter on this unit. It grows by N each time this unit deals an instance of damage, and a Discharge ability spends the whole thing at once.[/b]

[b]It grows on damage DEALT, never on damage taken.[/b] The unit has to be swinging, which costs energy and exposes the body — so banking is a decision rather than something that happens to you. If it grew on damage taken, the opponent's only counterplay would be to stop attacking, which is no counterplay at all.

[b]The counter persists across turns, and it survives evolution.[/b] Attached energy and Tools are the only other things that do. The value carries and the [i]rate[/i] comes from the new card, so [b]evolving is a rate increase[/b] — a Basic banking 3 a hit that evolves into a Stage 1 keeps its counter and starts banking 8.

[b]It is lost when the unit dies.[/b] That is the whole counterplay, and it is the same bargain attached energy already makes: kill the body and the investment goes with it. It is also lost on [i]Rise[/i] and on retreat — Rise restores the card, not the history, and retreat would otherwise launder a counter past every piece of removal in the game.

[b]What a discharge does is printed on the card.[/b] The baseline is [i]this attack deals the counter as bonus damage and strikes a second unit for the counter[/i], but different cards spend it differently — into one target, split across a board, or as healing.

[b]Discharge damage never grows the counter back.[/b] A spend is a spend."}


static func _p_kw_storm() -> Dictionary:
	return {"id": "kw_storm", "title": "Storm N", "keyword": "storm", "faction": "Tempest signature", "body":
"[b]A global counter both players read. Every attack in the game deals one additional instance of N damage.[/b]

Storm is a property of the [b]board[/b], not of a card — the same category as the Gap. It is [b]0 until a Tempest card raises it[/b], it never falls, and it is [b]symmetric[/b]: one number shared by both players, where each player has their own Gap.

[b]One instance of N, never N instances of 1.[/b] This matters more than it sounds. [i]Resist X[/i] reduces each incoming [b]instance[/b] to a minimum of 1 damage, so N separate ticks would slip past armour entirely as Storm climbed. As a single instance, Resist blunts it normally and armour keeps working.

[b]A Tempest unit's Storm instance is doubled.[/b] That is the asymmetry that makes Storm a Tempest mechanic rather than a house rule — it is a shared resource the faction simply uses better.

[b]The extra instance obeys the targeting chain on its own.[/b] If the main attack killed the defender, the Storm instance retargets to the next living unit, and falls through to the tower once the board is clear — so Storm quietly rewards clearing a board.

[b]Retribution still fires only once per attack[/b], not once per instance. Otherwise every wall's recoil would double the moment Storm appeared."}
