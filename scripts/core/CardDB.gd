extends Node

## Autoload: CardDB
## Loads data/cards.json once at startup and serves CardData lookups.

const CARDS_PATH := "res://data/cards.json"

var _cards: Dictionary = {}        ## id -> CardData
var _order: Array[String] = []     ## preserves JSON order for the collection UI


func _ready() -> void:
	_ensure_loaded()


## Load on first use rather than trusting `_ready()` ordering.
##
## Autoload `_ready()` order is not something callers can rely on: DeckStore
## reads the card data while *its own* `_ready()` runs, which happened before
## this node's had a chance to fire. Every lookup went to an empty `_cards`,
## `_sanitize()` concluded the player's card ids no longer existed, and the
## next edit wrote the emptied deck back over the save file. Loading on demand
## removes the ordering dependency entirely.
func _ensure_loaded() -> void:
	if not _cards.is_empty():
		return
	_load()


func _load() -> void:
	var f := FileAccess.open(CARDS_PATH, FileAccess.READ)
	if f == null:
		push_error("CardDB: could not open %s" % CARDS_PATH)
		return

	var parsed: Variant = JSON.parse_string(f.get_as_text())
	f.close()

	if typeof(parsed) != TYPE_DICTIONARY or not parsed.has("cards"):
		push_error("CardDB: %s is not a valid card file" % CARDS_PATH)
		return

	for entry in parsed["cards"]:
		var card := CardData.from_dict(entry)
		if card.id == "":
			push_warning("CardDB: skipping card with no id")
			continue
		_cards[card.id] = card
		_order.append(card.id)

	print("CardDB: loaded %d cards" % _cards.size())


func get_card(id: String) -> CardData:
	_ensure_loaded()
	if not _cards.has(id):
		push_error("CardDB: unknown card id '%s'" % id)
		return null
	return _cards[id]


func has(id: String) -> bool:
	_ensure_loaded()
	return _cards.has(id)


func all_ids() -> Array[String]:
	_ensure_loaded()
	return _order.duplicate()


## All units of a faction, in JSON order. Excludes energy cards.
func units_of(faction: String) -> Array:
	_ensure_loaded()
	var out: Array = []
	for id in _order:
		var c: CardData = _cards[id]
		if c.faction == faction and c.is_unit():
			out.append(c)
	return out


func energy_card_of(faction: String) -> CardData:
	_ensure_loaded()
	for id in _order:
		var c: CardData = _cards[id]
		if c.faction == faction and c.is_energy():
			return c
	return null


## Supports, Tools, and tower support of a faction, in JSON order.
## The neutral ones are playable in any deck.
func supports_of(faction: String) -> Array:
	_ensure_loaded()
	var out: Array = []
	for id in _order:
		var c: CardData = _cards[id]
		if c.faction == faction and c.is_support_like():
			out.append(c)
	return out


## Supports filtered to one card type — used by the deck builder's sections.
func supports_of_type(faction: String, t: int) -> Array:
	var out: Array = []
	for c in supports_of(faction):
		if c.type == t:
			out.append(c)
	return out


## What a given card evolves into, if anything. Returns Array[CardData].
func evolutions_of(card_id: String) -> Array:
	_ensure_loaded()
	var out: Array = []
	for id in _order:
		var c: CardData = _cards[id]
		if c.is_unit() and c.evolves_from == card_id:
			out.append(c)
	return out
