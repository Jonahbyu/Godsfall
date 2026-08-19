extends Node

## Autoload: DeckStore
## Holds a named collection of saved decks and tracks which one is active.
## Saves to user://decks.json.
##
## `deck` is always the *active* deck's card map, so everything that reads or
## edits a deck (DeckBuilder, Combat, the tests) works on the active deck
## without knowing the collection exists. Editing mutates `deck` in place and
## writes the whole collection back to disk.

const SAVE_PATH := "user://decks.json"
const LEGACY_SAVE_PATH := "user://deck.json"
## Decks are exactly this size — not "at most". A deck below it is illegal to
## take into a fight, and the builder refuses to go above it.
const DECK_SIZE := 60

## Where saves actually go. A variable, not a const, so the headless harnesses can
## redirect it with `use_sandbox_path()` — they used to write the *real* save file,
## which meant running the tests silently destroyed the player's decks.
var save_path: String = SAVE_PATH
var legacy_save_path: String = LEGACY_SAVE_PATH
const MAX_COPIES := 4
const MAX_NAME_LEN := 32

signal deck_changed()          ## active deck's contents changed
signal decks_changed()         ## the set of saved decks, their names, or the selection changed

## Array of { "name": String, "cards": Dictionary(card id -> count) }.
## Never empty — a collection with no decks gets the default deck back.
var decks: Array = []
var active_index: int = 0


func _ready() -> void:
	## `_active()` may already have seeded a placeholder if something touched
	## DeckStore before this ran; drop it so a real save still loads.
	decks = []
	var loaded := load_decks()
	if not loaded or decks.is_empty():
		decks = []
		for s in sample_decks():
			decks.append(_new_entry(s["name"], s["cards"]))
		active_index = 0
		save_decks()
	else:
		_add_missing_samples()


## Fill this store with the sample collection, ignoring any save file.
##
## `_ready()` is what normally does this, and it does not run for a bare
## `DeckStore.new()` — so a locally constructed store starts with **no decks**,
## and `name_at()` quietly returns "" while `list_at()` returns an empty list.
## That is silent rather than loud, which is exactly the failure mode worth
## giving a named entry point. Harnesses that want the sample decks as fixtures
## call this after `use_sandbox_path()`.
func seed_samples() -> void:
	decks = []
	for s in sample_decks():
		decks.append(_new_entry(s["name"], (s["cards"] as Dictionary).duplicate()))
	active_index = 0


## Append any sample deck the save doesn't already have, matched by name.
##
## Samples used to be laid down only on *first* run, which meant a player with an
## existing save never received decks shipped later — Heaven's two lists were
## invisible to anyone who had already played. Backfilling by name is the smallest
## fix that reaches them.
##
## Deliberately conservative: it only ever **appends**. A deck whose name matches a
## sample is left completely alone, even if the player has gutted it, because the
## alternative is overwriting someone's edits to a deck they renamed onto a sample's
## name. Losing a player's deck is far worse than failing to deliver a new one.
func _add_missing_samples() -> void:
	var have: Dictionary = {}
	for e in decks:
		have[e.name] = true

	var added := 0
	for s in sample_decks():
		if have.has(s["name"]):
			continue
		decks.append(_new_entry(s["name"], (s["cards"] as Dictionary).duplicate()))
		added += 1

	if added > 0:
		save_decks()
		decks_changed.emit()


## The active deck's card map. Mutated in place by add/remove/clear.
## Assigning to it replaces the active deck's contents.
var deck: Dictionary:
	get:
		return _active().cards
	set(value):
		_active().cards = value
		deck_changed.emit()


## Always returns a usable entry. The collection can legitimately be empty when
## a headless harness touches DeckStore before the autoload's _ready() runs, so
## this seeds an empty deck rather than indexing out of bounds.
func _active() -> DeckEntry:
	if decks.is_empty():
		decks = [_new_entry("My Deck", {})]
		active_index = 0
		return decks[0]
	active_index = clampi(active_index, 0, decks.size() - 1)
	return decks[active_index]


func _new_entry(name: String, cards: Dictionary) -> DeckEntry:
	return DeckEntry.new(name, cards)


## The deck a brand-new player is dropped into, and the one `reset_to_default()`
## restores. The first sample — Toll Engine — because it plays the faction's
## headline mechanic most directly.
func default_deck() -> Dictionary:
	return sample_decks()[0]["cards"]


## The starter collection laid down on first run.
##
## Four decks, each built around **one** idea rather than a spread of everything
## available. A pile holding one of each card teaches nothing: it has no plan to
## read, no reason to prefer one line over another, and it plays the same whatever
## you draw. These are meant to be legible — you can tell what each is trying to do
## from its list, and they beat each other in different ways.
##
## Every deck runs supports, because the support suite is half the game's decision
## space and a unit-only deck simply never sees it. The support *mix* is part of
## each identity: the aggro deck runs draw and reach, the wall deck runs healing and
## tower support, and they don't overlap much.
func sample_decks() -> Array:
	return [
		{
			"name": "Toll Engine",
			"cards": _toll_engine(),
		},
		{
			"name": "Barrow Wall",
			"cards": _barrow_wall(),
		},
		{
			"name": "Rise & Recur",
			"cards": _rise_and_recur(),
		},
		{
			"name": "Cacophony Ramp",
			"cards": _cacophony_ramp(),
		},
		{
			"name": "Verdict Engine",
			"cards": _verdict_engine(),
		},
		{
			"name": "Lamp Wall",
			"cards": _lamp_wall(),
		},
		{
			"name": "Starve",
			"cards": _starve(),
		},
		{
			"name": "Widening Rift",
			"cards": _widening_rift(),
		},
		{
			"name": "Standing Stones",
			"cards": _standing_stones(),
		},
		{
			"name": "Deep Grove",
			"cards": _deep_grove(),
		},
		{
			"name": "Wasting Fen",
			"cards": _wasting_fen(),
		},
		{
			"name": "Unquiet Dead",
			"cards": _unquiet_dead(),
		},
		{
			"name": "Sealed Light",
			"cards": _sealed_light(),
		},
		{
			"name": "Reaffirmation",
			"cards": _reaffirmation(),
		},
		{
			"name": "Total Eclipse",
			"cards": _total_eclipse(),
		},
		{
			"name": "Widening Dark",
			"cards": _widening_dark(),
		},
		{
			"name": "Bedrock",
			"cards": _bedrock(),
		},
		{
			"name": "Thicket",
			"cards": _thicket(),
		},
		{
			"name": "White Heat",
			"cards": _white_heat(),
		},
		{
			"name": "Scrap Line",
			"cards": _scrap_line(),
		},
		## The Forge expansion's five, each anchored on one of the new chains'
		## Stage 2 so the list reads as a plan rather than a pile of orange cards.
		{
			"name": "Second Wind",
			"cards": _second_wind(),
		},
		{
			"name": "Burning Line",
			"cards": _burning_line(),
		},
		{
			"name": "Nothing Holds",
			"cards": _nothing_holds(),
		},
		{
			"name": "Bank the Heat",
			"cards": _bank_the_heat(),
		},
		{
			"name": "Standing Heat",
			"cards": _standing_heat(),
		},
	]


## **Toll Engine** — trade constantly and get paid for it.
##
## Cheap bodies with the best Toll-per-HP in the pool, plus `Sift the Ashes` to turn
## a bad combat step into a full turn of energy. It *wants* units to die, so it runs
## no healing at all and spends the slots on draw instead: dying units are card
## disadvantage, and `Ledger`/`Last Rites` is how it keeps the board refilled.
## Low energy count (14) because Toll refunds are a second income stream.
func _toll_engine() -> Dictionary:
	return {
		## Bodies that pay out — Bonepicker and Barrow Knight are Toll 2 on 50 HP.
		"grave_whelp": 4,
		"carrion_crawler": 4,
		"bonepicker": 4,
		"barrow_knight": 4,
		"hollow_servant": 4,
		## Just enough evolution to have a real threat; this deck wins on volume.
		## Both lines evolve off Basics already in the list — Reaper from Grave Whelp,
		## Chorus from Bonepicker — so nothing here is stranded in hand.
		"gravebound_reaper": 3,
		"hels_chorus": 3,
		## Refund the deaths, then refill the hand.
		"sift_the_ashes": 4,
		"gravekeepers_ledger": 4,
		"last_rites": 3,
		"muster": 4,
		"grave_market": 3,
		"hel_energy": 16,
	}


## **Barrow Wall** — never lose the slot.
##
## Retribution punishes the attacker, healing keeps the wall standing, and tower
## support turns the two towers into a real second board rather than a liability.
## The plan is to survive past the point where the opponent's tower clock matters
## and let attrition do the work — so it runs the whole heal suite and the retreat
## cards the aggro decks skip. High energy (18) because it wins late.
func _barrow_wall() -> Dictionary:
	return {
		## Retribution bodies — Thornshade into Mourning Bell is the core.
		"thornshade": 4,
		"barrow_knight": 3,
		"hollow_servant": 3,
		"charnel_colossus": 3,
		"mourning_bell": 4,
		"grave_tide": 2,
		## Keep the wall alive.
		"shore_up": 4,
		"field_rites": 3,
		"last_breath": 2,
		"hold_the_slot": 2,
		## Tools that reward a body surviving — which is this deck's whole premise.
		"bone_splint": 2,
		"iron_standard": 2,
		## The towers are the second wall.
		"reinforced_base": 3,
		"rebuild": 2,
		"murder_holes": 2,
		"hel_energy": 19,
	}


## **Rise & Recur** — the same units, over and over.
##
## Rise brings units back once, Bonepicker's Scavenge pulls them out of the discard,
## Hel Queen returns two at a time, and `Grave Market` gambles for whatever else
## fell. The deck accepts losing fights because a dead unit is a resource, not a
## loss. Runs the retreat suite as a second recursion angle — `Ground Give` and
## `Escape Route` recycle a unit without it having to die first.
func _rise_and_recur() -> Dictionary:
	return {
		## Rise bodies and the discard engine.
		"hollow_servant": 4,
		"bonepicker": 4,
		"grave_whelp": 4,
		"grave_tide": 3,
		"gravebound_reaper": 3,
		## Hel Queen is the payoff — Consume 2 to return two units from the discard.
		"hel_queen": 2,
		"hels_chorus": 3,
		## Pull things back.
		"grave_market": 4,
		"line_of_succession": 3,
		"escape_route": 2,
		"ground_give": 2,
		"rally_the_line": 2,
		"withdraw": 2,
		"scavengers_instinct": 3,
		"hel_energy": 19,
	}


## **Cacophony Ramp** — one enormous turn.
##
## The big-attack deck. `Endless Hunger` costs 14 and `Requiem` costs 9, so the whole
## list is bent toward getting there: `Offering` for burst pool, `Tithe` and
## `Ration Pack` to funnel energy onto the one unit that matters, `Read the Bones`
## to find the Stage 2. Decay on the Nithogg line is the clock that makes stalling
## acceptable. Heaviest energy count in the collection (20) — it does nothing early
## and everything late.
func _cacophony_ramp() -> Dictionary:
	return {
		## The two ramp lines, complete.
		"carrion_crawler": 4,
		"nithogg_root_gnawer": 3,
		"nithogg_ascendant": 2,
		"bonepicker": 3,
		"hels_chorus": 3,
		"grand_cacophony": 2,
		## Bodies to hold the board while the pool builds.
		"thornshade": 3,
		"charnel_colossus": 2,
		## Energy acceleration and concentration.
		"offering": 4,
		"tithe": 3,
		"ration_pack": 2,
		"read_the_bones": 3,
		"second_thoughts": 2,
		"weighted_chain": 2,
		"hel_energy": 22,
	}


## **Verdict Engine** — kill the threshold, not the health bar.
##
## Heaven's execute deck. Every unit carries `Judgment`, so the plan is to soften a
## target with anything and let the threshold finish it — a Judgment 30 attacker only
## has to deal 20 to a fresh 50 HP basic. `Court of Bells` reloads the whole board's
## charges for Consume 2, and `Verdict of the Throne` converts the resulting kills
## into throne damage, which is the only way this deck closes a game.
##
## Runs `Collapse` and `Toppling Blow` because Judgment does not care *how* a unit got
## low, only that it is: cheap chip is removal in this deck in a way it is not in any
## other. Low energy (15) — Heaven's Judgment attacks are priced at ~8 damage per
## energy, so the curve tops out at 5.
##
## Evolution check: Arbiter needs Censer Bearer, Hand of the Verdict needs Lantern
## Acolyte, Court of Bells needs Bellringer, and both Stage 2s branch off Arbiter.
## All four Basics are in the list.
func _verdict_engine() -> Dictionary:
	return {
		## Judgment Basics — the whole deck is bodies that execute.
		"censer_bearer": 4,
		"lantern_acolyte": 3,
		"bellringer_of_the_court": 4,
		## The Ledger line, branching at Stage 2 into both payoffs.
		"arbiter_of_the_third_seal": 4,
		"seraph_of_the_final_ledger": 2,
		"verdict_of_the_throne": 2,
		## The reset engine, and a Rise body that brings its charge back.
		"court_of_bells": 3,
		"hand_of_the_verdict": 2,
		## Chip that turns into removal. Collapse hits uncharged units, which is
		## exactly what a board being softened for an execute looks like.
		"collapse": 4,
		"toppling_blow": 2,
		## Find the Arbiter — the whole deck branches off it.
		"muster": 4,
		"read_the_bones": 3,
		"gravekeepers_ledger": 3,
		"roll_call": 2,
		## Retreat is Heaven's third way to reload a charge: a spent unit returned to
		## hand comes back with its Judgment restored, and costs no Consume to do it.
		"ground_give": 2,
		"escape_route": 1,
		"heaven_energy": 15,
	}


## **Lamp Wall** — the bodies that do not die.
##
## Deliberately runs **no `Judgment` at all**, which is what lets it keep the standard
## 12-damage-per-energy curve: `Pillar of Light` is 65 for 5 and `Judgment of Light`
## is 75 for 6, the hardest hits in the faction. The Sanctuary chaff in front is there
## to absorb one attack each and buy the Bastion a turn to charge.
##
## `Empyrean Sentinel` is the win condition and the reason the deck exists — it
## refreshes its Sanctuary every end of turn, so it can only be killed by two damage
## instances in the *same* turn. `Aegis of the Choir` re-arms a spent shield.
##
## High energy (19) because the payoff attacks cost 5 and 6, and because a Sanctuary
## body is worth charging: it survives long enough to attack more than once.
##
## Evolution check: Radiant Bastion needs Warden of the Lamp, Empyrean Sentinel needs
## Radiant Bastion. Both are in the list, four and three deep.
func _lamp_wall() -> Dictionary:
	return {
		## The Lamp line, complete. No Judgment anywhere — that is the point.
		"warden_of_the_lamp": 4,
		"radiant_bastion": 3,
		"empyrean_sentinel": 2,
		## Cheap Sanctuary bodies. Each absorbs one full attack for free, which is
		## what a shield in front of a charging Bastion is worth.
		"cherub_of_the_open_gate": 4,
		## The one Judgment body, as a lane-holder rather than an executioner: it
		## must be killed three times and it never needs to attack to be useful.
		"throne_of_the_risen_court": 2,
		"hand_of_the_verdict": 3,
		"lantern_acolyte": 3,
		## Re-arm a spent shield. A Tool is a bet a body survives — these do.
		"aegis_of_the_choir": 3,
		"bone_splint": 2,
		## Keep the wall standing and the towers useful.
		"shore_up": 3,
		"field_rites": 2,
		"hold_the_slot": 2,
		"reinforced_base": 3,
		"murder_holes": 2,
		"rebuild": 2,
		"vigil": 1,
		"heaven_energy": 19,
	}


## **Starve** — the early half of Void's arc, played as fast as it will go.
##
## Siphon is at its strongest on turns 2–5, when taking 1–2 attached energy is a
## large fraction of everything on the board. This list leans all the way into
## that window: cheap thieves, the free repeating Siphon on `Ashen Pilgrim`, and
## enough draw to keep finding bodies. It runs light on energy (15) because it
## expects to be *funded by the opponent* rather than by its own income.
##
## It deliberately skips `Silence Eternal` and the Rift Stage 2s. This deck does
## not want to reach turn 12 — Siphon is noise by then, and a Starve deck that
## has not closed has already lost the argument.
func _starve() -> Dictionary:
	return {
		## The thieves. Ashen Pilgrim's ability is free and repeats every turn,
		## which is the engine the whole list is built around.
		"ashen_pilgrim": 4,
		"hollow_acolyte": 4,
		"severance_priest": 3,
		## Bodies that hit on the standard curve while the theft does its work.
		"rust_crawler": 4,
		"famine_of_forms": 2,
		## The conditional-damage card: zero against an empty board, 25 against a
		## charged one, which is exactly what this deck creates.
		"gnawing_absence": 3,
		"the_unwritten": 2,
		## Denial on cards, so a turn with no good attack is still a turn of theft.
		"draw_down": 4,
		"unwrite": 2,
		## Draw, because a deck this cheap empties its hand fast.
		"gravekeepers_ledger": 4,
		"read_the_bones": 2,
		"muster": 4,
		"collapse": 3,
		"shore_up": 3,
		"void_energy": 16,
	}


## **Widening Rift** — the midgame half, built to make the Gap enormous.
##
## Where Starve spends its stolen energy immediately, this deck *keeps* it: every
## point siphoned onto a body is two points of Gap, and every point of Gap is
## damage on each Rift unit for the rest of the game. It runs the full Rift line,
## both Gap payoffs, and `Silence Eternal` as the closer that converts the Gap
## into throne damage.
##
## Heavier on energy (19) than Starve because its attacks genuinely cost more,
## and because charging its own bodies is *how it builds the Gap* — this is the
## one deck in the game where dumping energy onto a unit is an offensive move.
func _widening_rift() -> Dictionary:
	return {
		## The Rift line, complete.
		"null_adept": 4,
		"entropy_warden": 3,
		"throat_of_the_void": 2,
		## Siphon that stays on a body, so it feeds the Gap rather than the pool.
		"hollow_acolyte": 3,
		"severance_priest": 2,
		"the_absence": 2,
		## Big bodies to hold the stolen energy. Void's self-cost is that this
		## energy dies with the unit, so the walls matter more here than anywhere.
		"sundered_wretch": 3,
		"hungering_maw": 2,
		## Rust Crawler is the Basic under BOTH Famine of Forms and (through it)
		## Silence Eternal. Running the payoffs without it is the evolution-orphan
		## trap `CLAUDE.md` warns about — the Stage 2 would be uncastable.
		"rust_crawler": 4,
		"famine_of_forms": 2,
		## The closer.
		"silence_eternal": 1,
		## A Tool that grants Rift — a bet on a body surviving, which is exactly
		## what a Gap deck is already making.
		"event_horizon": 2,
		"widening_rift": 2,
		## Keep the bodies alive; the Gap only exists while they stand.
		"shore_up": 2,
		"field_rites": 2,
		"muster": 3,
		"gravekeepers_ledger": 2,
		"void_energy": 19,
	}


# ---------------------------------------------------------------- deck collection

func deck_count() -> int:
	return decks.size()


func active_name() -> String:
	return _active().name


func name_at(i: int) -> String:
	if i < 0 or i >= decks.size():
		return ""
	return decks[i].name


func cards_at(i: int) -> Dictionary:
	if i < 0 or i >= decks.size():
		return {}
	return decks[i].cards


## Switch which deck is being edited and played.
func select(i: int) -> bool:
	if i < 0 or i >= decks.size() or i == active_index:
		return false
	active_index = i
	decks_changed.emit()
	deck_changed.emit()
	save_decks()
	return true


## Create a new empty deck and make it active. Returns its index.
func create_deck(name: String = "") -> int:
	var entry := _new_entry(_unique_name(name if name != "" else "New Deck"), {})
	decks.append(entry)
	active_index = decks.size() - 1
	decks_changed.emit()
	deck_changed.emit()
	save_decks()
	return active_index


## Copy a deck (default: the active one) and make the copy active.
func duplicate_deck(i: int = -1) -> int:
	var src: int = active_index if i < 0 else i
	if src < 0 or src >= decks.size():
		return -1
	var entry := _new_entry(_unique_name(decks[src].name + " Copy"), decks[src].cards.duplicate())
	decks.append(entry)
	active_index = decks.size() - 1
	decks_changed.emit()
	deck_changed.emit()
	save_decks()
	return active_index


## Delete a deck. The last remaining deck cannot be deleted — clear it instead.
func delete_deck(i: int) -> bool:
	if decks.size() <= 1 or i < 0 or i >= decks.size():
		return false
	decks.remove_at(i)
	if active_index > i:
		active_index -= 1
	elif active_index == i:
		active_index = clampi(i, 0, decks.size() - 1)
	decks_changed.emit()
	deck_changed.emit()
	save_decks()
	return true


## Rename a deck (default: the active one). Blank names are rejected;
## duplicates get a numeric suffix.
func rename_deck(new_name: String, i: int = -1) -> bool:
	var idx: int = active_index if i < 0 else i
	if idx < 0 or idx >= decks.size():
		return false
	var trimmed := new_name.strip_edges().substr(0, MAX_NAME_LEN)
	if trimmed == "":
		return false
	if trimmed == decks[idx].name:
		return true
	decks[idx].name = _unique_name(trimmed, idx)
	decks_changed.emit()
	save_decks()
	return true


## Append " 2", " 3", ... until the name is free. `ignore` skips one index
## (used when renaming so a deck doesn't collide with itself).
func _unique_name(base: String, ignore: int = -1) -> String:
	var trimmed := base.strip_edges().substr(0, MAX_NAME_LEN)
	if trimmed == "":
		trimmed = "New Deck"
	var candidate := trimmed
	var n := 2
	while _name_taken(candidate, ignore):
		candidate = "%s %d" % [trimmed, n]
		n += 1
	return candidate


func _name_taken(name: String, ignore: int) -> bool:
	for i in decks.size():
		if i != ignore and decks[i].name == name:
			return true
	return false


# ---------------------------------------------------------------- active deck editing

func count_of(card_id: String) -> int:
	return int(deck.get(card_id, 0))


func total_cards() -> int:
	return _total_of(deck)


func _total_of(cards: Dictionary) -> int:
	var n := 0
	for id in cards:
		n += int(cards[id])
	return n


func energy_count() -> int:
	return _energy_of(deck)


func _energy_of(cards: Dictionary) -> int:
	var n := 0
	for id in cards:
		var c: CardData = CardDB.get_card(id)
		if c != null and c.is_energy():
			n += int(cards[id])
	return n


## Supports, Tools, and tower support together — the non-unit, non-energy count.
func support_count() -> int:
	return _support_of(deck)


func _support_of(cards: Dictionary) -> int:
	var n := 0
	for id in cards:
		var c: CardData = CardDB.get_card(id)
		if c != null and c.is_support_like():
			n += int(cards[id])
	return n


## Card total of any saved deck — for listing decks without switching to them.
func total_at(i: int) -> int:
	return _total_of(cards_at(i))


func energy_at(i: int) -> int:
	return _energy_of(cards_at(i))


## The factions a saved deck actually runs, most-cards-first.
##
## Neutral cards are excluded: every deck may run them, so counting them would
## make every list read the same and defeat the point of asking. A deck that is
## nothing but neutral supports returns an empty array rather than a fake colour.
##
## Used by the UI to colour a deck entry by what it plays. Lives here rather than
## in the screen because "what colour is this deck" is a property of the deck,
## and two screens already want the answer.
func factions_at(i: int) -> Array:
	var tally: Dictionary = {}
	var cards: Dictionary = cards_at(i)
	for id in cards:
		var c: CardData = CardDB.get_card(id)
		if c == null or c.faction == "":
			continue
		tally[c.faction] = int(tally.get(c.faction, 0)) + int(cards[id])
	var out: Array = tally.keys()
	out.sort_custom(func(a, b): return int(tally[a]) > int(tally[b]))
	return out


## The one card that best represents a deck, for the deck list's art tile.
##
## Every card game fronts a saved deck with a picture rather than a name, because
## a shelf of ten identical rows is a reading task and a shelf of ten pictures is
## a looking one. The pick has to be deterministic — a hero that changed between
## refreshes would make the list flicker — so it is a plain ranking rather than
## anything random or usage-based:
##
##   the highest-stage unit, then the most expensive, then alphabetical
##
## Stage first because a deck's Stage 2 is what it is *trying* to do, and cost
## breaks the tie because among equals the expensive one is the payoff. Energy
## and supports are skipped: an energy card is the same picture in every deck of
## that colour, which is the opposite of identifying one. A deck holding no units
## at all returns null and the caller falls back to the faction spine alone.
## How a deck breaks down by card type: units, supports, tools, tower support
## and energy. The one number a deckbuilder needs that neither the card count
## nor the energy count answers — "what kind of deck is this".
##
## Returned as a plain Dictionary keyed by `CardData.Type` so the caller decides
## how to present it; `CompositionBar` draws it, and the deck-select contents
## pane prints it.
func composition_at(i: int) -> Dictionary:
	var out: Dictionary = {}
	for id in cards_at(i):
		var c: CardData = CardDB.get_card(id)
		if c == null:
			continue
		out[c.type] = int(out.get(c.type, 0)) + int(cards_at(i)[id])
	return out


func composition() -> Dictionary:
	return composition_at(active_index)


func hero_card_at(i: int) -> CardData:
	var best: CardData = null
	var best_cost: int = -1
	for id in cards_at(i):
		var c: CardData = CardDB.get_card(id)
		if c == null or not c.is_unit():
			continue
		var cost: int = 0
		for a in c.attacks:
			cost = maxi(cost, a.total_cost())
		if best == null 				or c.stage > best.stage 				or (c.stage == best.stage and cost > best_cost) 				or (c.stage == best.stage and cost == best_cost and c.name < best.name):
			best = c
			best_cost = cost
	return best


## Energy is the *only* exempt type. Supports obey the 4-copy limit like units —
## exempting them too would turn the deck into a combo engine.
func is_energy(card_id: String) -> bool:
	var c: CardData = CardDB.get_card(card_id)
	return c != null and c.is_energy()


## Energy cards are exempt from the 4-copy limit.
func max_copies_of(card_id: String) -> int:
	return 99 if is_energy(card_id) else MAX_COPIES


func can_add(card_id: String) -> bool:
	if total_cards() >= DECK_SIZE:
		return false
	return count_of(card_id) < max_copies_of(card_id)


func add(card_id: String) -> bool:
	if not can_add(card_id):
		return false
	deck[card_id] = count_of(card_id) + 1
	deck_changed.emit()
	save_decks()
	return true


func remove(card_id: String) -> bool:
	var n := count_of(card_id)
	if n <= 0:
		return false
	if n == 1:
		deck.erase(card_id)
	else:
		deck[card_id] = n - 1
	deck_changed.emit()
	save_decks()
	return true


func clear() -> void:
	deck.clear()
	deck_changed.emit()
	save_decks()


func reset_to_default() -> void:
	_active().cards = default_deck()
	deck_changed.emit()
	save_decks()


## Flat list of card ids, one entry per copy — what GameState consumes.
func to_card_list() -> Array:
	return list_at(active_index)


## Flat card list of any saved deck, so a match can be started from a deck
## other than the active one.
func list_at(i: int) -> Array:
	var out: Array = []
	var cards := cards_at(i)
	for id in cards:
		for j in int(cards[id]):
			out.append(id)
	return out


# ------------------------------------------------------------ opponent choice

## Which deck the AI brings. `OPPONENT_RANDOM` is the default: a fresh legal deck
## is rolled at the start of every match, so a session is a spread of matchups
## rather than one repeated pairing.
##
## Deliberately **not persisted**. It is a per-session choice about the fight you
## are about to have, not a property of the collection, and writing it into
## `decks.json` would mean a save-file migration for a preference that costs
## nothing to re-pick.
const OPPONENT_RANDOM := -1

var opponent_index: int = OPPONENT_RANDOM


## The deck index the AI will actually play this match.
##
## Random picks from the *legal* decks only — an illegal deck cannot be taken
## into a fight by the player, so the AI must not be handed one either. A
## same-deck pairing is allowed to come up by chance (roughly 1 match in 8): the
## draw is uniform, and forcing distinctness would quietly bias the sampling
## away from every pairing that happens to include the player's deck.
##
## Falls back to the active deck only if nothing legal exists, which keeps the
## caller from ever receiving an empty list.
func resolve_opponent_index() -> int:
	if opponent_index >= 0 and opponent_index < decks.size() and is_legal_at(opponent_index):
		return opponent_index

	var legal: Array[int] = []
	for i in decks.size():
		if is_legal_at(i):
			legal.append(i)
	if legal.is_empty():
		return active_index
	return legal[randi() % legal.size()]


## Flat card list for the AI's deck this match. Callers that need to *report* the
## matchup should call `resolve_opponent_index()` themselves and pass it to
## `list_at()`, so the name they print matches the list they dealt.
func opponent_card_list() -> Array:
	return list_at(resolve_opponent_index())


# ---------------------------------------------------------------- validation

## A deck is legal if it holds exactly DECK_SIZE cards, at least one Basic unit,
## and at least one energy card.
##
## Exactly 60 rather than "up to 60": a fixed deck size makes draw probabilities
## mean the same thing in every matchup, so the energy count a deck runs is a real
## ratio decision instead of something a player can dodge by trimming the list.
func validation_errors() -> Array[String]:
	return errors_at(active_index)


func errors_at(i: int) -> Array[String]:
	var cards := cards_at(i)
	var errs: Array[String] = []
	var total := _total_of(cards)
	if total == 0:
		errs.append("Deck is empty.")
		return errs
	if total < DECK_SIZE:
		errs.append("Deck has %d cards — add %d more (decks must be exactly %d)." % [
			total, DECK_SIZE - total, DECK_SIZE
		])
	elif total > DECK_SIZE:
		errs.append("Deck has %d cards — remove %d (decks must be exactly %d)." % [
			total, total - DECK_SIZE, DECK_SIZE
		])
	if _energy_of(cards) == 0:
		errs.append("Deck has no energy cards.")

	var basics := 0
	for id in cards:
		var c: CardData = CardDB.get_card(id)
		if c != null and c.is_unit() and c.stage == CardData.Stage.BASIC:
			basics += int(cards[id])
	if basics == 0:
		errs.append("Deck has no Basic units — you would never be able to deploy.")

	for id in cards:
		if not is_energy(id) and int(cards[id]) > MAX_COPIES:
			errs.append("%s: %d copies (max %d)." % [CardDB.get_card(id).name, cards[id], MAX_COPIES])

	return errs


func is_legal() -> bool:
	return validation_errors().is_empty()


func is_legal_at(i: int) -> bool:
	return errors_at(i).is_empty()


# ---------------------------------------------------------------- persistence

## Point saves at a throwaway file. Called by the headless harnesses so a test run
## can never touch the player's real collection. Returns self for chaining.
func use_sandbox_path(tag: String = "test") -> Node:
	save_path = "user://test_decks_%s.json" % tag
	legacy_save_path = "user://test_deck_%s.json" % tag
	if FileAccess.file_exists(save_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(save_path))
	return self


func save_decks() -> void:
	var out: Array = []
	for entry in decks:
		out.append({ "name": entry.name, "cards": entry.cards })
	var f := FileAccess.open(save_path, FileAccess.WRITE)
	if f == null:
		push_error("DeckStore: cannot write %s" % save_path)
		return
	f.store_string(JSON.stringify({ "decks": out, "active": active_index }, "  "))
	f.close()


## Returns true if a saved collection was read. False means "nothing on disk",
## which is what tells _ready() to lay down the starter deck.
func load_decks() -> bool:
	if not FileAccess.file_exists(save_path):
		return _migrate_legacy()
	var f := FileAccess.open(save_path, FileAccess.READ)
	if f == null:
		return false
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	f.close()
	if typeof(parsed) != TYPE_DICTIONARY:
		return false

	var saved: Array = parsed.get("decks", [])
	decks = []
	for entry in saved:
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		var name := str(entry.get("name", "Deck"))
		var cards: Dictionary = entry.get("cards", {})
		decks.append(_new_entry(_unique_name(name), _sanitize(cards)))

	active_index = clampi(int(parsed.get("active", 0)), 0, maxi(decks.size() - 1, 0))
	return not decks.is_empty()


## The pre-collection format was a single { "deck": {...} }. Carry that deck
## over as the first saved deck so an existing save isn't silently dropped.
func _migrate_legacy() -> bool:
	if not FileAccess.file_exists(legacy_save_path):
		return false
	var f := FileAccess.open(legacy_save_path, FileAccess.READ)
	if f == null:
		return false
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	f.close()
	if typeof(parsed) != TYPE_DICTIONARY:
		return false
	var cards: Dictionary = parsed.get("deck", {})
	if cards.is_empty():
		return false
	decks = [_new_entry("My Deck", _sanitize(cards))]
	active_index = 0
	save_decks()
	return true


## Drop ids that no longer exist in the card data.
##
## This is destructive — whatever it drops is gone the next time anything calls
## `save_decks()`. It once emptied real saves wholesale: `CardDB` had not loaded
## yet, so `has()` said no to *every* id, and the next deck edit wrote the husk
## back to disk. `CardDB` now loads on demand so that can't recur, but a bad card
## file would still reach here, so refuse to sanitize against an empty database
## rather than treating "no cards exist" as "your deck is invalid".
func _sanitize(cards: Dictionary) -> Dictionary:
	if CardDB.all_ids().is_empty():
		push_error("DeckStore: card data unavailable — keeping deck contents as-is")
		return cards.duplicate()
	var out: Dictionary = {}
	for id in cards:
		if CardDB.has(id):
			out[str(id)] = int(cards[id])
		else:
			push_warning("DeckStore: dropping unknown card id '%s'" % id)
	return out


## One saved deck. A class rather than a bare Dictionary so `deck` can hand out
## a live reference to the card map that add/remove mutate in place.
class DeckEntry:
	var name: String
	var cards: Dictionary

	func _init(n: String, c: Dictionary) -> void:
		name = n
		cards = c


## **Standing Stones** — the board that shoots back for free.
##
## Every Makeshift Tower is a unit that attacks at end of turn without spending a
## point of energy, so this deck's damage scales with how many bodies it can keep
## standing rather than with its pool. That inverts the game's central constraint
## on purpose: *energy only buys attacks* is the rule, and this chain is the
## sanctioned card that breaks it (design principle #1).
##
## The Earth aura is what makes it more than a pile of chip damage — auto-fire
## reads the aura, so each stone makes every other stone hit harder, and both
## real towers gain the max HP too. `Cairn` stacks on top of that.
##
## `Resist` on the stone chain is the reason it survives the wide boards it
## invites: many small hits are exactly what Resist is good against, and exactly
## what a board full of cheap attackers throws.
##
## Energy 17 — lower than a normal wall deck, because the auto-fire damage is
## free and the pool is only ever buying the Colossus's Tremor.
func _standing_stones() -> Dictionary:
	return {
		## The chain, complete. Makeshift Tower at 4 because every Bulwark needs
		## one underneath it — the evolution-orphan trap CLAUDE.md warns about.
		"gaia_makeshift_tower": 4,
		"gaia_bulwark_of_stone": 3,
		"gaia_the_standing_stone": 2,
		## Retribution walls to hold the lane the stones are shooting down. These
		## punish the removal that the aura is most afraid of.
		"gaia_mossback_tortoise": 4,
		"gaia_granite_colossus": 2,
		## A cheap Earth body that is also the Basic under nothing — pure aura.
		"gaia_sapling_warden": 3,
		## Grown Earth on the toughest thing on the board.
		"gaia_bedrock": 3,
		"gaia_verdant_anchor": 2,
		## Tower support, because this deck is already committed to structures.
		"gaia_cairn": 3,
		"reinforced_base": 2,
		## Keep the aura alive; every dead Earth body shrinks the whole board.
		"shore_up": 3,
		"field_rites": 4,
		"muster": 4,
		## Seedbearer is cheap Earth that dies usefully — this deck has no other
		## Essence, but a 1-cost body that passes its Earth on is pure upside on a
		## board whose whole plan is keeping the aura up.
		"gaia_seedbearer": 4,
		"gaia_energy": 17,
	}


## **Deep Grove** — bank Earth, then cash it everywhere at once.
##
## The opposite half of the faction. Where Standing Stones spreads Earth across
## many cheap bodies, this one *accumulates* it: Grovekeeper and Elder grow their
## own Earth every turn for free, `Living Conduit` converts attached energy into
## Earth directly, and `Deep Roots` doubles the rate for the whole board.
##
## Its weakness is the one gaia.md names — grown Earth dies with its holder, and
## this deck concentrates the investment. `Vernal Rite` is the answer: it moves
## grown Earth onto a survivor before a wipe takes it, and the Essence bodies
## carry energy and Earth forward when they die anyway.
##
## Energy 21 — it needs the pool for both `Essence` funerals and the expensive
## top end, and it has nothing free to fall back on early.
func _deep_grove() -> Dictionary:
	return {
		## The growth engine.
		"gaia_sapling_warden": 4,
		"gaia_grovekeeper": 3,
		"gaia_elder_of_the_grove": 2,
		## Earth from attached energy, and the single rate-breaker.
		"gaia_living_conduit": 4,
		"gaia_deep_roots": 3,
		"gaia_heartwood_ancient": 1,
		## Essence: die usefully, and consolidate before a wipe.
		"gaia_seedbearer": 3,
		"gaia_vernal_rite": 2,
		## Grow it faster.
		"gaia_bedrock": 3,
		"gaia_deep_communion": 2,
		"gaia_terraform": 2,
		"gaia_verdant_anchor": 1,
		## The aura only exists while the bodies do.
		"shore_up": 2,
		"field_surgery": 2,
		"muster": 3,
		"gravekeepers_ledger": 2,
		"gaia_energy": 21,
	}


## **Wasting Fen** — win without ever winning a fight.
##
## Every body prints `Decay`, so the board bleeds whether or not this deck can
## afford to attack, and both Stage 2s carry a free once-per-turn 15-to-every-enemy
## ability on top of it. That combination is the whole plan: Decay ticks are the
## chip Sanctuary is worst against, and two Interment/Pestilence activations clear
## a board of Basics without spending a single point of pool.
## `Reconsecrate` is here for the mirror — it is the one card that undoes a turn
## of Decay, and against another Hel deck it is the difference.
func _wasting_fen() -> Dictionary:
	return {
		## Cheap Decay bodies. They are chip that keeps ticking after they are paid for.
		"hollowgrub": 4,
		"blighthusk": 4,
		"rotwisp": 3,
		"gnawling": 3,
		## Both middle stages, because the Stage 2s are what the deck is for.
		"hollowmaw": 3,
		"blightfen": 3,
		"rotfen": 2,
		## Decay 10 apiece, and a free board-wide 15 every turn they live.
		"hollowdrung": 2,
		"blightknell": 2,
		## Undo a turn of Decay in the mirror; refill otherwise.
		"reconsecrate": 2,
		"gravekeepers_ledger": 3,
		"muster": 4,
		"sift_the_ashes": 3,
		## Reach: Decay cannot touch a structure, so the tower needs its own answer.
		"weighted_chain": 2,
		"toppling_blow": 2,
		"hel_energy": 18,
	}


## **Unquiet Dead** — the board refuses to stay cleared.
##
## Two full `Rise` chains, and both Stage 2s carry a free Exhume/Grave Call that
## returns a Hel unit from the discard to an empty slot every single turn. Rise is
## one reprieve per body; the Stage 2 ability is a *repeating* one, which is why
## this deck is happy to lose exchanges — the discard is its second board.
## Heavy energy (22), because nothing here is cheap and the payoff is a 12-cost
## Stage 2 that has to actually get charged.
func _unquiet_dead() -> Dictionary:
	return {
		## Rise Basics, plus two vanilla openers that evolve into Rise bodies.
		"osskin": 4,
		"tomblit": 4,
		"ashlit": 3,
		"osswisp": 3,
		## Middle stages — Rise on three of the four.
		"ossshroud": 3,
		"tombshroud": 3,
		"ashloam": 2,
		"ossloam": 2,
		## The engine: return a unit from the discard, free, every turn.
		"ossrend": 2,
		"tombthane": 2,
		## Reach into the discard by hand as well, so the engine has fuel early.
		"grave_market": 3,
		"last_rites": 2,
		"line_of_succession": 3,
		"scavengers_instinct": 2,
		"hel_energy": 22,
	}


## **Sealed Light** — nothing gets through, and it keeps not getting through.
##
## Deliberately **no `Judgment` at all**, like Lamp Wall, so it keeps the standard
## damage curve — but where Lamp Wall runs Sanctuary chaff in front of one big body,
## this runs the 60/80/100 ladder at every stage and both Stage 2s restore their own
## Sanctuary at end of turn. A shield that comes back is a different card from a
## shield that is spent, and it is what makes the wide-board answer to Sanctuary stop
## working: chip strips the pool, and the pool is simply back next turn.
## The `Aegis of the Choir` copies stack a second Sanctuary onto a body that already
## recharges one.
func _sealed_light() -> Dictionary:
	return {
		## Sanctuary 60 across the whole opening.
		"sanctim": 4,
		"solemim": 4,
		"empyriel": 3,
		"lucenmote": 3,
		"serakin": 2,
		## Sanctuary 80, and Empyrseraph adds Resist on top of it.
		"sanctcant": 3,
		"solemmant": 3,
		"empyrseraph": 2,
		"lucenlumen": 2,
		## Sanctuary 100 that restores itself at end of turn.
		"sanctthrone": 2,
		"solemtribune": 2,
		## Stack a second shield, then keep the body under it alive.
		"aegis_of_the_choir": 2,
		"shore_up": 3,
		"field_rites": 2,
		"reinforced_base": 2,
		"heaven_energy": 21,
	}


## **Reaffirmation** — spend the charge, then get it back.
##
## `Judgment` is one charge spent by either half, and that is the keyword's entire
## brake. This deck runs the three cards that release it: Halosear restores its own
## Judgment, and both Stage 2s restore Judgment to *every unit you control*, free,
## once per turn. A board of five Judgment bodies that all recharge is the most
## aggressive thing Heaven can do — every unit is an execute threat and
## unkillable-once at the same time.
##
## Lowest energy count of the Heaven decks (17) on purpose: Judgment units buy damage
## at the reduced ~8/energy rate, so this is not trying to land big attacks. It is
## trying to chip things into threshold range, which is cheap.
func _reaffirmation() -> Dictionary:
	return {
		## Judgment Basics — wide, so the board-wide reset has targets.
		"gloriamote": 4,
		"clariel": 4,
		"halokin": 3,
		"oratim": 3,
		"psalmiel": 3,
		"bellmote": 2,
		## Judgment 35-40 middles. Halosear recharges itself, which is the cheap
		## version of what the Stage 2s do for the whole board.
		"glorialumen": 3,
		"clarchoir": 3,
		"halosear": 3,
		"oratora": 2,
		"psalmcant": 2,
		## The payoff: restore Judgment to every unit you control, free, each turn.
		"gloriathrone": 2,
		"clararch": 2,
		## Find the bodies. The plan needs a wide board, not a big one.
		"muster": 3,
		"roll_call": 2,
		## Chip into execute range — 20 to an uncharged unit is often lethal here.
		"collapse": 2,
		"heaven_energy": 17,
	}


## **Total Eclipse** — they never get to spend it.
##
## The denial deck. `Siphon` on nearly every body moves energy off their units and
## onto yours, which funds this deck's own expensive attacks, and the Stage 2s go
## after what Siphon cannot reach — Expunge destroys attached energy outright and
## Consume Light eats a fifth of the pool. Between them there is no safe place to
## keep energy, which is the faction's thesis stated as a deck list.
##
## The Umbr line is a small second package rather than a full chain: two copies of a
## Stage 2 that hits the pool is what this deck wants, and Umbrreave carries Siphon
## as well, so it is never a dead draw.
func _total_eclipse() -> Dictionary:
	return {
		## Siphon Basics. Early Siphon is the largest fraction of a turn's income.
		"lacunith": 4,
		"pallith": 4,
		"scourwane": 3,
		"ebonith": 3,
		"sevith": 2,
		## Siphon 2 middles — two energy a turn off their board and onto yours.
		"lacunlack": 3,
		"pallgaunt": 3,
		"scourgaunt": 2,
		"ebonlack": 2,
		## Destroy attached energy outright, free, once a turn.
		"lacunabyss": 2,
		## The pool package: Consume Light eats 20% of what they were saving.
		"umbrsk": 2,
		"umbrfray": 2,
		"umbrreave": 2,
		## Denial by hand, for the body you cannot reach.
		"draw_down": 3,
		"exsanguinate": 2,
		"unwrite": 2,
		"void_energy": 19,
	}


## **Widening Dark** — the Gap is the win condition.
##
## Every unit prints `Rift`, so every attack scales with the Gap, and the Gap is your
## attached energy minus theirs. That makes this the one deck in the collection that
## *wants* to bank energy onto bodies rather than spend it — charging a unit it never
## intends to attack with still makes every other attack bigger.
##
## Two Rift 2 Stage 2s are the ceiling and `Event Horizon` turns an ordinary body
## into a third. `Widening Rift` is the reach: twice the Gap as direct damage, which
## by the time this deck is working is a removal spell. Heaviest Void energy count
## (21), because banking is the plan and pool energy does not feed the Gap — it has
## to get attached.
func _widening_dark() -> Dictionary:
	return {
		## Rift 1 on every Basic. Cheap bodies to hold the energy.
		"vastsk": 4,
		"gyresk": 4,
		"starksk": 3,
		"rivewane": 3,
		"waneith": 2,
		## Rift 1 middles, all scaling off the same number.
		"vastebb": 3,
		"gyrerift": 3,
		"starkrift": 3,
		"riveshear": 2,
		## Rift 2 — double scaling, plus a free pool-destruction ability on Gyreshear.
		"vastnought": 2,
		"gyreshear": 2,
		## Grant Rift to anything, and convert the Gap straight into damage.
		"event_horizon": 3,
		"widening_rift": 3,
		## One point of Siphon swings the Gap by two — theirs down, yours up.
		"draw_down": 2,
		"void_energy": 21,
	}


## **Bedrock** — the aura is the armour.
##
## `Earth` and `Resist` on the same bodies, which is the pairing that makes Gaia hard
## to remove rather than merely large. Earth raises max HP across every unit *and*
## both towers, and Resist takes a flat cut off each incoming instance — so a wide
## board of small hits, the thing that beats Sanctuary, is exactly what this deck is
## best against.
##
## Two Earth 3 / Resist 10 Stage 2s at 165 and 168 HP are the biggest bodies in the
## collection, and on an 8-Earth board they are effectively past 170. The price is
## speed: 23 energy, the heaviest list here, and nothing happens before the aura does.
func _bedrock() -> Dictionary:
	return {
		## Earth 1 / Resist 5 openers. Petriling is 70 HP, the largest Gaia Basic.
		"gaia_granling": 4,
		"gaia_caldling": 4,
		"gaia_tussling": 3,
		"gaia_petriling": 4,
		## Earth 2 / Resist 5 middles.
		"gaia_grancrag": 3,
		"gaia_caldcrag": 3,
		"gaia_tussbole": 3,
		## Earth 3 / Resist 10. Both carry a free "gain 1 Earth" ability, so the aura
		## keeps climbing without a card being spent on it.
		"gaia_granthane": 2,
		"gaia_caldthane": 2,
		## Push the aura, and put it on the towers too.
		"gaia_bedrock": 3,
		"gaia_cairn": 2,
		"gaia_verdant_anchor": 2,
		"gaia_terraform": 2,
		"gaia_energy": 23,
	}


## **Thicket** — attacking into this is the mistake.
##
## `Retribution` plus `Essence`, the two Gaia mechanics that punish the opponent for
## playing the game normally. Retribution 20-25 means attacking into the board costs
## the attacker a body's worth of HP over a few turns, and Essence means the units
## that do die hand their Earth and attached energy to the unit beside them instead
## of losing it.
##
## Thornheart is what the deck is built to reach: Earth 3, Retribution 25 and Essence
## 2 on one 155 HP body, with a free ability that moves its Earth away before it dies.
## `Iron Standard` stacks with printed Retribution, which is why it is here rather
## than in a deck with fewer bodies already carrying it.
func _thicket() -> Dictionary:
	return {
		## Retribution and Essence Basics.
		"gaia_thornbud": 4,
		"gaia_burrbud": 4,
		"gaia_sedgesprout": 3,
		"gaia_rootsprout": 3,
		"gaia_lichbud": 2,
		## Retribution 20 middles, and Essence 2 to carry the aura through a death.
		"gaia_thorncrag": 3,
		"gaia_burrcrag": 3,
		"gaia_sedgefen": 2,
		"gaia_rootwarden": 2,
		## Retribution 25 on Earth 3, with Essence 2 under it.
		"gaia_thornheart": 2,
		## Stacks with printed Retribution.
		"iron_standard": 2,
		## Grow the aura; Essence is what stops a death from wasting it.
		"gaia_deep_communion": 3,
		"gaia_bedrock": 2,
		"shore_up": 2,
		"gaia_energy": 23,
	}

## **White Heat** — spend the body, break the wall.
##
## The Forge deck that plays the keyword straight: `Stoke` big, then cash the flag
## on an attack that scales with how much was paid. Cindbrand adds +1 damage per 2
## HP stoked and Cindpyre burns *past living units* into the tower once it has
## stoked 40 — which is the deck's whole plan, because clearing a board is normally
## the gate on reaching a structure and this list simply declines to clear it.
##
## Quench is the sustain half and it is not a hedge: `The Long Temper` stokes 50 and
## heals all 50 back, so the unit is at full HP and *still counts as having stoked*.
## That is the interaction the faction is built around — the flag is a state you want
## to be in, not only a price you pay.
##
## Heavy on healing (Bank the Coals, Quenching Trough, Hearthstone) because HP is the
## resource being spent, and 19 energy because Stoke buys actions, not energy: an
## attack still has to be paid for.
func _white_heat() -> Dictionary:
	return {
		## The big stoker, complete. Stoke 20 / 30 / 50 up the chain.
		"forge_cindspark": 4,
		"forge_cindbrand": 3,
		"forge_cindpyre": 2,
		## The sustain chain — stoke and heal it straight back.
		"forge_quenchwick": 4,
		"forge_quenchbrand": 3,
		"forge_quenchanvil": 2,
		## Cheap flag-setter: Stoke 10 is the least HP that turns a payoff on.
		"forge_slagash": 4,
		"forge_slagkiln": 3,
		## HP is the currency, so healing is the mana base.
		"forge_bank_the_coals": 3,
		"forge_quenching_trough": 3,
		"forge_hearthstone": 3,
		"forge_stoke_the_works": 3,
		"shore_up": 4,
		"forge_energy": 19,
	}


## **Scrap Line** — the board is ammunition.
##
## Built on `Scrap`: Gristgnash, Gristforge and Gristsmith all pay by destroying
## another unit you control, and the deck runs cheap Hel bodies as the fuel. That
## pairing is deliberate and is supposed to be good — a scrapped unit really *dies*,
## so `Toll` refunds on it, and the fuel pays you back on the way out.
##
## Two colours, so it is the collection's demonstration that a multi-faction deck is
## buildable: 11 Hel energy and 12 Forge, with Hel providing bodies that want to die
## and Forge providing the reason. `Scrap Heap` recurs a spent one.
##
## The risk it accepts is board width — every Scrap costs a slot, and a thin board is
## a board whose tower is about to be exposed. It wins before that matters or not at all.
func _scrap_line() -> Dictionary:
	return {
		## The scrappers, complete.
		"forge_gristgnash": 4,
		"forge_gristforge": 3,
		"forge_gristsmith": 2,
		## The cleaver — Stoke splashes onto their board while ours thins.
		"forge_embash": 4,
		"forge_embkiln": 2,
		## Cheap Forge bodies that also serve as fuel.
		"forge_slagash": 3,
		## Hel fuel: cheap, and every one of them pays a Toll when it is eaten.
		"grave_whelp": 4,
		"carrion_crawler": 4,
		"bonepicker": 3,
		## Recursion, so the fuel comes back.
		"forge_scrap_heap": 3,
		"sift_the_ashes": 2,
		"forge_bank_the_coals": 3,
		"forge_energy": 12,
		"hel_energy": 11,
	}


## **Second Wind** — one body, twice a turn.
##
## Built on `Bellowmaul`, whose Full Bellows grants the extra attack slot AND a
## discount in the same activation: two swings from one unit, each one cheaper.
## That is Forge's answer to a board capped at 4 — if you cannot have more bodies,
## have more actions.
##
## The deck is deliberately TALL rather than wide. Every energy spent goes into one
## charged attacker, because doubling a 54-damage attack is worth far more than
## doubling a 26-damage one, and the extra slot only ever helps the unit that stoked.
## Cokewright is the early discount body so the plan exists before the Stage 2 lands.
##
## 19 energy, high for Forge: the second attack still costs energy, so a turn that
## uses the grant fully is a turn that spends double.
func _second_wind() -> Dictionary:
	return {
		## The multi-attack chain, complete.
		"forge_bellowwick": 4,
		"forge_bellowbrand": 3,
		"forge_bellowmaul": 2,
		## The discount pair — the same payoff one stage earlier.
		"forge_cokewrightslag": 4,
		"forge_cokewrightforge": 3,
		## A cheap flag-setter that also refills the hand.
		"forge_tapwright": 3,
		## Healing, because every activation is paid in HP.
		"forge_bank_the_coals": 3,
		"forge_bellows_rig": 3,
		"forge_second_wind": 3,
		"shore_up": 3,
		## Digging for Bellowmaul matters more here than in any other Forge list:
		## the whole plan is one specific Stage 2, so the deck pays slots to find it.
		"gravekeepers_ledger": 3,
		"muster": 3,
		"forge_open_the_doors": 4,
		"forge_energy": 19,
	}


## **Burning Line** — kill the rank, not the unit.
##
## `Charpyre` and `Charkiln` both convert a big Stoke into a board-wide sweep, and
## the sweep is what makes the no-overkill rule work for you: clear the front rank
## and everything queued behind it falls through to whatever is left.
##
## It is the one Forge deck that WANTS a wide enemy board, which is exactly the
## board that beats `Sanctuary`. Sootfall is in for the same reason from the other
## side — it splashes the tower behind without needing the board cleared at all.
##
## Runs `Cold Shut` over more healing: against a wide board the removal is what
## turns a sweep into a clear.
func _burning_line() -> Dictionary:
	return {
		## The sweeper chain, complete.
		"forge_charash": 4,
		"forge_charkiln": 3,
		"forge_charpyre": 2,
		## Tower splash — reach that does not need the board cleared first.
		"forge_sootfallash": 4,
		"forge_sootfallkiln": 3,
		## A cheap body that turns a flag on for almost nothing.
		"forge_tindspark": 3,
		"forge_cold_shut": 3,
		"forge_the_long_shift": 2,
		"forge_bank_the_coals": 2,
		"forge_hearthstone": 2,
		## More bodies to hold a lane while the sweeper charges, and draw to find it.
		"forge_slakeling": 3,
		"gravekeepers_ledger": 3,
		"forge_the_reclaim": 2,
		"field_rites": 4,
		"forge_energy": 20,
	}


## **Nothing Holds** — the printed answer to shield decks.
##
## Every attacker here can make its damage unpreventable, which is the one thing
## `Sanctuary` and `Resist` have no answer to. It exists because making Stoke itself
## unpreventable cost Forge/Heaven and Forge/Gaia their free keyword synergy — this
## is the *printed* reason those matchups are winnable rather than a keyword accident.
##
## `Scoriasmith` is the closer: unpreventable AND a 15-point tower splash on the same
## swing, so a shielded wall neither absorbs the hit nor protects what is behind it.
## Cinderling is the cheap version of the same effect so the plan starts on turn 2.
##
## Low-ish energy at 18: the payoff is a condition rather than extra damage, so the
## attacks themselves stay ordinary sized.
func _nothing_holds() -> Dictionary:
	return {
		## The anti-shield chain, complete.
		"forge_scoriaslag": 4,
		"forge_scoriaforge": 3,
		"forge_scoriasmith": 2,
		## The same effect, cheaper and earlier.
		"forge_cinderlingwick": 4,
		"forge_cinderlingbrand": 3,
		## A Stage 2 that is unpreventable above a threshold, and scraps for value.
		"forge_cindergaunt": 2,
		"forge_forgehand": 3,
		"forge_bank_the_coals": 3,
		"forge_draw_the_temper": 2,
		"forge_deadmans_hammer": 2,
		## A second unpreventable body low on the curve, plus the draw to assemble.
		"forge_tapwright": 3,
		"forge_slakeling": 3,
		"gravekeepers_ledger": 3,
		"forge_open_the_doors": 2,
		"shore_up": 3,
		"forge_energy": 18,
	}


## **Bank the Heat** — the economy deck, and the only Forge list that plays long.
##
## `Fluxanvil` suspends the pool's decay and draws two in one activation, so this is
## the deck that *keeps* its energy rather than spending it the turn it arrives. Every
## other Forge list burns principal; this one refuses the tax on saving it.
##
## The trick is that a suspended decay plus a discount means a turn where a big attack
## costs almost nothing and the pool survives intact into the next one. Tind is the
## engine half — stoke twice, draw twice, then convert with a scaling payoff.
##
## 21 energy, the highest in the faction, because a deck built on banking energy has
## to have energy to bank.
func _bank_the_heat() -> Dictionary:
	return {
		## The economy chain, complete.
		"forge_fluxwick": 4,
		"forge_fluxbrand": 3,
		"forge_fluxanvil": 2,
		## The engine chain — double stoke into an amount-scaling payoff.
		"forge_tindspark": 4,
		"forge_tindkiln": 3,
		"forge_tindpyre": 2,
		## Draws off the flag for free.
		"forge_tapwright": 3,
		"forge_second_wind": 3,
		"forge_bank_the_coals": 2,
		"forge_the_reclaim": 2,
		"forge_hearthstone": 2,
		## A banked pool is only worth what it eventually buys, so the deck runs
		## a real body to spend it on and the draw to keep finding one.
		"forge_annealash": 3,
		"gravekeepers_ledger": 3,
		"shore_up": 3,
		"forge_energy": 21,
	}


## **Standing Heat** — the wall that punishes being hit.
##
## The defensive reading of Forge: it does not block, it makes attacking into it
## expensive. `Annealanvil` is Retribution 25 and Resist 5 on a 168 HP body that heals
## back everything it stokes, so it can hold a lane indefinitely while still turning
## its payoffs on — the one Forge body that spends HP without ever running out.
##
## `Deadman's Hammer` is the multiplier: Retribution 15 on top of a printed 20 or 25
## means a wide attacker takes 40 back per swing. Slakeling and Annealash are the
## cheap versions holding the other lane.
##
## It is slow and it is supposed to be. Forge's losing condition is failing to close,
## and this is the list that answers it by not needing to close early.
func _standing_heat() -> Dictionary:
	return {
		## The Retribution wall, complete.
		"forge_annealash": 4,
		"forge_annealbrand": 3,
		"forge_annealanvil": 2,
		## Cheap sustain bodies that also turn a flag on.
		"forge_slakeling": 4,
		"forge_quenchwick": 3,
		"forge_quenchbrand": 2,
		## Retribution on a Tool, stacking with the printed value.
		"forge_deadmans_hammer": 3,
		"forge_the_long_shift": 2,
		"forge_bank_the_coals": 3,
		"forge_murder_holes_hot": 2,
		"iron_standard": 2,
		## Tower support and healing: the wall wins by outlasting, so the slots go
		## to staying alive rather than to reach.
		"reinforced_base": 2,
		"field_rites": 3,
		"forge_draw_the_temper": 2,
		"forge_bellows_rig": 3,
		"forge_energy": 20,
	}
