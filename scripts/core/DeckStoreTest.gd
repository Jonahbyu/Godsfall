extends SceneTree

## Total assertions this harness is expected to run; see the check at
## the end of the run. Update deliberately when assertions change.
const EXPECTED_ASSERTIONS := 70

## Exercises the saved-deck collection: create, select, rename, duplicate,
## delete, per-deck validation, and round-tripping through disk.
##   godot --headless --script res://scripts/core/DeckStoreTest.gd

var _passed := 0
var _failed := 0


func _initialize() -> void:
	## No `db._load()` priming here on purpose. CardDB loads on demand, and this
	## harness is the thing that would hide a regression if it primed the data
	## itself — the ordering bug it guards against looked exactly like a test
	## that had already loaded the cards by hand.
	var ds = root.get_node_or_null("DeckStore")
	if ds == null:
		print("DeckStore autoload missing")
		quit(1)
		return

	print("\n=== DeckStore collection test ===\n")

	## Redirect saves to a throwaway file. This test round-trips through disk, so
	## without it the run would overwrite the player's real deck collection.
	ds.use_sandbox_path("deckstore")

	## Start from a known state rather than whatever is on disk.
	ds.decks = []
	ds.active_index = 0
	ds.decks = [ds._new_entry("Hel Starter", ds.default_deck())]
	ds.save_decks()

	_defaults(ds)
	_create_and_select(ds)
	_naming(ds)
	_duplicate(ds)
	_deletion(ds)
	_isolation(ds)
	_persistence(ds)
	_exact_deck_size(ds)
	_survives_cold_carddb(ds)
	_opponent_choice(ds)
	_seed_samples(ds)
	_hero_card(ds)

	## A harness that errors out mid-run still reports "0 failed", because an
	## assertion that never RUNS cannot fail — that is how the Gaia harness passed
	## for several rounds while executing 7 of its 40 checks. Pinning the total
	## makes a crash that skips whole test functions a failure instead of silence.
	## Update this number deliberately when adding or removing assertions.
	if _passed + _failed != EXPECTED_ASSERTIONS:
		print("FAIL: expected %d assertions, ran %d — a test crashed before finishing."
			% [EXPECTED_ASSERTIONS, _passed + _failed])
		_failed += 1

	print("\n%d passed, %d failed" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)


func _check(label: String, cond: bool) -> void:
	if cond:
		_passed += 1
		print("  ok   %s" % label)
	else:
		_failed += 1
		print("  FAIL %s" % label)


func _defaults(ds) -> void:
	print("Baseline:")
	_check("one deck to start", ds.deck_count() == 1)
	_check("named Hel Starter", ds.active_name() == "Hel Starter")
	_check("starter is legal", ds.is_legal())
	_check("deck maps to the active entry", ds.total_cards() == ds.total_at(0))


func _create_and_select(ds) -> void:
	print("Create / select:")
	var i: int = ds.create_deck("Aggro Test")
	_check("second deck created", ds.deck_count() == 2)
	_check("new deck is active", ds.active_index == i)
	_check("new deck is empty", ds.total_cards() == 0)
	_check("empty deck is illegal", not ds.is_legal())
	_check("other deck still legal", ds.is_legal_at(0))

	_check("select(0) switches back", ds.select(0))
	_check("active is the starter again", ds.active_name() == "Hel Starter")
	_check("re-selecting the same deck is a no-op", not ds.select(0))
	_check("out-of-range select rejected", not ds.select(99))


func _naming(ds) -> void:
	print("Naming:")
	_check("rename works", ds.rename_deck("Toll Control", 0))
	_check("name applied", ds.name_at(0) == "Toll Control")
	_check("blank name rejected", not ds.rename_deck("   ", 0))
	_check("name unchanged after reject", ds.name_at(0) == "Toll Control")

	## A collision gets a numeric suffix instead of silently overwriting.
	ds.rename_deck("Toll Control", 1)
	_check("duplicate name suffixed", ds.name_at(1) == "Toll Control 2")

	var long_name := "x".repeat(80)
	ds.rename_deck(long_name, 1)
	_check("name truncated to MAX_NAME_LEN", ds.name_at(1).length() <= ds.MAX_NAME_LEN)


func _duplicate(ds) -> void:
	print("Duplicate:")
	var before: int = ds.deck_count()
	var src_total: int = ds.total_at(0)
	var i: int = ds.duplicate_deck(0)
	_check("deck count grew", ds.deck_count() == before + 1)
	_check("copy is active", ds.active_index == i)
	_check("copy has the same cards", ds.total_at(i) == src_total)
	_check("copy got a distinct name", ds.name_at(i) != ds.name_at(0))

	## The copy must be a real copy, not a shared reference.
	ds.remove("hel_energy")
	_check("editing the copy leaves the original alone", ds.total_at(0) == src_total)
	_check("copy actually shrank", ds.total_at(i) == src_total - 1)


func _deletion(ds) -> void:
	print("Deletion:")
	var before: int = ds.deck_count()
	_check("delete works", ds.delete_deck(before - 1))
	_check("count dropped", ds.deck_count() == before - 1)
	_check("active index stayed in range", ds.active_index < ds.deck_count())
	_check("out-of-range delete rejected", not ds.delete_deck(99))

	## Reduce to one deck, which then must be undeletable.
	while ds.deck_count() > 1:
		ds.delete_deck(ds.deck_count() - 1)
	_check("last deck cannot be deleted", not ds.delete_deck(0))
	_check("one deck remains", ds.deck_count() == 1)


func _isolation(ds) -> void:
	print("Edit isolation:")
	ds.rename_deck("Deck A", 0)
	ds.deck = ds.default_deck()
	var a_total: int = ds.total_cards()

	var b: int = ds.create_deck("Deck B")
	ds.add("grave_whelp")
	ds.add("grave_whelp")
	_check("Deck B has just its own cards", ds.total_cards() == 2)
	_check("Deck A untouched by Deck B edits", ds.total_at(0) == a_total)

	ds.select(0)
	_check("switching back restores Deck A's contents", ds.total_cards() == a_total)
	_check("card list matches the active deck", ds.to_card_list().size() == a_total)
	_check("list_at reads a non-active deck", ds.list_at(b).size() == 2)


func _persistence(ds) -> void:
	print("Persistence:")
	ds.save_decks()

	var names: Array = []
	var totals: Array = []
	for i in ds.deck_count():
		names.append(ds.name_at(i))
		totals.append(ds.total_at(i))
	var active: int = ds.active_index

	## Reload from disk into a fresh store, as a restart would. It has to read the
	## same sandbox file the test wrote, not the player's real save.
	var fresh = load("res://scripts/core/DeckStore.gd").new()
	fresh.save_path = ds.save_path
	fresh.legacy_save_path = ds.legacy_save_path
	fresh.decks = []
	var ok: bool = fresh.load_decks()

	_check("load reported success", ok)
	_check("deck count survived", fresh.deck_count() == names.size())
	_check("active selection survived", fresh.active_index == active)

	var names_ok := true
	var totals_ok := true
	for i in fresh.deck_count():
		if fresh.name_at(i) != names[i]:
			names_ok = false
		if fresh.total_at(i) != totals[i]:
			totals_ok = false
	_check("names survived", names_ok)
	_check("card counts survived", totals_ok)

	fresh.free()


## Decks are exactly DECK_SIZE — an under-filled deck is illegal, not merely small.
## The old rule was "up to 60", so this guards the boundary in both directions.
func _exact_deck_size(ds) -> void:
	print("Exact deck size:")
	var full: Dictionary = ds.default_deck()
	ds.decks = [ds._new_entry("Sized", full.duplicate())]
	ds.active_index = 0

	_check("a sample deck is exactly DECK_SIZE", ds.total_cards() == ds.DECK_SIZE)
	_check("a full deck is legal", ds.is_legal())

	## One short is illegal, and says so.
	var trimmed: String = ""
	for id in ds.deck:
		trimmed = id
		break
	ds.remove(trimmed)
	_check("one card short is illegal", not ds.is_legal())
	_check("the error names the shortfall",
		"\n".join(ds.validation_errors()).contains("add 1 more"))

	## can_add() is the builder's guard against going over.
	ds.add(trimmed)
	_check("back to full is legal again", ds.is_legal())
	_check("cannot add past DECK_SIZE", not ds.can_add(trimmed))
	_check("total never exceeded DECK_SIZE", ds.total_cards() == ds.DECK_SIZE)

	## Every shipped sample deck must be battle-ready as printed.
	var bad: Array = []
	for s in ds.sample_decks():
		var probe = load("res://scripts/core/DeckStore.gd").new()
		probe.use_sandbox_path("samplesize")
		probe.decks = [probe._new_entry(s["name"], s["cards"])]
		probe.active_index = 0
		if not probe.is_legal_at(0) or probe.total_at(0) != ds.DECK_SIZE:
			bad.append("%s (%d cards)" % [s["name"], probe.total_at(0)])
		probe.free()
	_check("every sample deck is a legal 60", bad.is_empty())
	if not bad.is_empty():
		print("     offenders: ", str(bad))


## Regression: a deck must survive being loaded before CardDB has read its data.
##
## The original bug. Autoload `_ready()` order put DeckStore's load ahead of
## CardDB's, so `_sanitize()` asked an empty database whether each card existed,
## was told no every time, and kept nothing. That alone was recoverable — but the
## next `add()`/`remove()` called `save_decks()`, which wrote the emptied deck
## over the file, so the player's collection was destroyed for good. A 15-card
## deck came back as the 4 copies of one card that happened to be re-added after.
##
## Simulating it means genuinely emptying CardDB, not just reordering calls.
func _survives_cold_carddb(ds) -> void:
	print("Cold CardDB (load-order regression):")
	var db = root.get_node_or_null("CardDB")
	if db == null:
		_check("CardDB autoload present", false)
		return

	var known: Dictionary = ds.default_deck()
	ds.decks = [ds._new_entry("Cold Load", known.duplicate())]
	ds.active_index = 0
	ds.save_decks()
	var expected: int = ds.total_at(0)

	## Force the exact precondition: no card data in memory at load time.
	db._cards = {}
	db._order.clear()

	var fresh = load("res://scripts/core/DeckStore.gd").new()
	fresh.save_path = ds.save_path
	fresh.legacy_save_path = ds.legacy_save_path
	fresh.decks = []
	fresh.load_decks()

	_check("deck is not emptied by a cold CardDB", fresh.total_at(0) == expected)
	_check("card data got loaded on demand", db._cards.size() > 0)

	## The destructive half: a save after a bad load is what made it permanent.
	fresh.save_decks()
	var after = load("res://scripts/core/DeckStore.gd").new()
	after.save_path = ds.save_path
	after.legacy_save_path = ds.legacy_save_path
	after.decks = []
	after.load_decks()
	_check("a save after loading does not shrink the deck", after.total_at(0) == expected)

	fresh.free()
	after.free()


## Which deck the AI brings. Random is the default; a pin must survive, and a pin
## that goes stale must fall back rather than pointing at the wrong list.
func _opponent_choice(ds) -> void:
	print("Opponent deck choice:")
	var store = load("res://scripts/core/DeckStore.gd").new()
	store.use_sandbox_path("opponentchoice")
	store.seed_samples()

	_check("defaults to random", store.opponent_index == store.OPPONENT_RANDOM)

	## Random always resolves to a legal deck, never to -1 or out of range.
	var all_legal := true
	var seen: Dictionary = {}
	for i in 40:
		var idx: int = store.resolve_opponent_index()
		if idx < 0 or idx >= store.deck_count() or not store.is_legal_at(idx):
			all_legal = false
		seen[idx] = true
	_check("random always resolves to a legal deck", all_legal)
	## 40 draws from 8 decks landing on one index would be a broken RNG, not luck.
	_check("random actually varies", seen.size() > 1)

	## A pinned deck is honoured every time.
	store.opponent_index = 2
	var pinned := true
	for i in 10:
		if store.resolve_opponent_index() != 2:
			pinned = false
	_check("a pinned deck is used every match", pinned)
	_check("pinned deck deals its own list",
		store.opponent_card_list().size() == store.total_at(2))

	## A pin that points past the end of the collection falls back to random
	## rather than returning an out-of-range index the caller would deal from.
	store.opponent_index = 99
	var fallback: int = store.resolve_opponent_index()
	_check("a stale pin falls back to a legal deck",
		fallback >= 0 and fallback < store.deck_count() and store.is_legal_at(fallback))

	## An illegal deck must never be handed to the AI — the player can't take one
	## into a fight, so the opponent must not either.
	store.decks[1].cards = {"grave_whelp": 1}
	store.opponent_index = 1
	_check("a pinned-but-illegal deck is not used", store.resolve_opponent_index() != 1)
	store.free()


## `DeckStore.new()` does not run `_ready()`, so a bare store has no decks at all.
## That was silent — empty names and empty card lists that still play a "game" —
## which is why the seeding is an explicit call.
func _seed_samples(ds) -> void:
	print("seed_samples (bare .new() has no decks):")
	var bare = load("res://scripts/core/DeckStore.gd").new()
	bare.use_sandbox_path("seedsamples")
	_check("a bare store starts empty", bare.decks.is_empty())
	_check("empty store yields an empty list", bare.list_at(0).is_empty())

	bare.seed_samples()
	_check("seeding fills the collection", bare.deck_count() == ds.sample_decks().size())
	_check("seeded decks are named", bare.name_at(0) != "")
	_check("seeded decks deal a full list", bare.list_at(0).size() == ds.DECK_SIZE)
	bare.free()


## `hero_card_at` picks the one card that fronts a deck in the deck list. It has
## to be deterministic — a hero that changed between refreshes would make the
## list flicker as it rebuilt — and it has to skip non-units, since an energy
## card is the same picture in every deck of that colour.
func _hero_card(ds) -> void:
	print("
Hero card:")

	ds.decks = []
	ds.active_index = 0
	ds.seed_samples()

	## Every shipped deck must front *something*, or the list falls back to a
	## bare spine for a deck that plainly has units in it.
	var all_have := true
	for i in ds.deck_count():
		if ds.hero_card_at(i) == null:
			all_have = false
	_check("every sample deck has a hero", all_have)

	## Stable across calls: same deck, same answer, every time.
	var a = ds.hero_card_at(0)
	var b = ds.hero_card_at(0)
	_check("hero is deterministic", a != null and b != null and a.id == b.id)

	## Never an energy card or a support — those identify a colour, not a deck.
	var units_only := true
	for i in ds.deck_count():
		var h = ds.hero_card_at(i)
		if h != null and not h.is_unit():
			units_only = false
	_check("hero is always a unit", units_only)

	## The highest stage present wins, because a deck's Stage 2 is what it is
	## trying to do. Checked against the deck's own contents rather than against
	## a hardcoded card name, so it survives any future rebalancing of the lists.
	## `CardDB` is resolved through the tree rather than named directly: naming
	## an autoload at class scope drags it into compile time under `--script`,
	## which fails before `_initialize` ever runs. Same trap the decision log
	## records for `Palette` in EnergyIcon.
	var db = root.get_node_or_null("CardDB")
	var stage_ok := db != null
	for i in ds.deck_count():
		var h = ds.hero_card_at(i)
		if h == null:
			continue
		var best := 0
		for id in ds.cards_at(i):
			var c = db.get_card(id)
			if c != null and c.is_unit():
				best = maxi(best, c.stage)
		if h.stage != best:
			stage_ok = false
	_check("hero is the highest stage in the deck", stage_ok)

	## A deck holding no units returns null rather than raising, so the caller
	## can fall back to the faction spine alone.
	var i2: int = ds.create_deck("Energy Only")
	ds.select(i2)
	ds.add("hel_energy")
	_check("unit-less deck has no hero", ds.hero_card_at(i2) == null)

	## An empty deck likewise.
	var i3: int = ds.create_deck("Empty")
	_check("empty deck has no hero", ds.hero_card_at(i3) == null)
