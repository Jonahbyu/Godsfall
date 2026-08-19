extends SceneTree

## Tempest harness — `Charge` (a per-unit banked counter that grows when the unit
## DEALS damage) and `Storm` (a global damage ramp both players read).
## See docs/specs/2026-08-17-tempest-faction-design.md.
##
## Run: godot --headless --path <project> --script res://scripts/core/TempestTest.gd

## Total assertions this harness is expected to run. Checked at the end, because
## a crash mid-file produces "0 failed" and exit 0 — the assertions after the
## crash simply never run, and silence reads identically to success.
const EXPECTED_ASSERTIONS := 10

const CardDataS = preload("res://scripts/core/CardData.gd")
const UnitS = preload("res://scripts/core/Unit.gd")

var _pass := 0
var _fail := 0


func _check(label: String, got, want) -> void:
	if got == want:
		_pass += 1
	else:
		_fail += 1
		print("FAIL: %s — got %s, want %s" % [label, got, want])


func _ok(label: String, cond: bool) -> void:
	_check(label, cond, true)


## A bare unit from an inline card dict, so these tests do not depend on
## data/cards.json having been regenerated yet.
func _unit(d: Dictionary) -> Unit:
	return UnitS.new(CardDataS.from_dict(d))


func _charger(n: int) -> Dictionary:
	return {
		"id": "t_a", "name": "Testsile", "type": "unit", "faction": "tempest",
		"stage": "basic", "hp": 50, "keywords": [{"kw": "charge", "n": n}],
		"attacks": [],
	}


## `_initialize()` rather than `_init()`, and CardDB registered by hand: under
## `--script` the autoloads are not in the tree, and without this `Player.new()`
## inside `GameState._init` resolves to a bare GDScript and returns null.
func _initialize() -> void:
	var db = root.get_node_or_null("CardDB")
	if db == null:
		db = load("res://scripts/core/CardDB.gd").new()
		db.name = "CardDB"
		root.add_child(db)
	if db._cards.is_empty():
		db._load()

	_test_charge_counter()
	_test_charge_persistence()

	print("%d passed, %d failed" % [_pass, _fail])
	if _pass + _fail != EXPECTED_ASSERTIONS:
		print("FAIL: expected %d assertions, ran %d" % [EXPECTED_ASSERTIONS, _pass + _fail])
		_fail += 1
	quit(1 if _fail > 0 else 0)


func _test_charge_counter() -> void:
	var u := _unit(_charger(3))
	_check("charge starts at 0", u.charge, 0)
	u.add_charge(3)
	_check("add_charge raises it", u.charge, 3)
	u.add_charge(3)
	_check("charge accumulates", u.charge, 6)
	_check("spend_charge returns the whole counter", u.spend_charge(), 6)


func _test_charge_persistence() -> void:
	var evolved := CardDataS.from_dict({
		"id": "t_a2", "name": "Testgale", "type": "unit", "faction": "tempest",
		"stage": "stage1", "hp": 96, "keywords": [{"kw": "charge", "n": 8}],
		"attacks": [],
	})

	## Evolution CARRIES the value and CHANGES the rate. The exception to
	## "new printed card, new everything", and the whole reason Tempest can evolve.
	var u := _unit(_charger(3))
	u.add_charge(21)
	_check("basic banks at its printed rate", u.charge_rate(), 3)
	u.evolve_into(evolved)
	_check("charge SURVIVES evolution", u.charge, 21)
	_check("but the rate is the new card's", u.charge_rate(), 8)

	## Rise restores the card, not the history — the rule grown Earth follows.
	var r := _unit(_charger(3))
	r.add_charge(30)
	_check("Rise returns the unit with no charge", r.make_risen().charge, 0)

	## kw_mods clear on evolution, so a raised rate does not ride along.
	var m := _unit(_charger(3))
	m.add_kw_mod("charge", 5)
	_check("a raised Charge rate reads modified", m.charge_rate(), 8)
	m.evolve_into(evolved)
	_check("the modifier cleared - this is the new print", m.charge_rate(), 8)
