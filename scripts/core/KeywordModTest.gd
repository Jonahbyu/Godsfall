extends SceneTree
## Guards the keyword modifier layer — the thing that lets a card change another
## card's keyword value at runtime.
##
## Why this exists: the engine was inconsistent about whether a keyword could be
## modified at all. `rift()` and `earth()` already accepted Tool grants and card
## effects, while `toll()`, `siphon()`, `decay()`, `judgment()`, `essence()` and
## `resist()` returned `card.kw(...)` flat — so "a support that boosts Toll by 2"
## had no path while the identical card for Rift already worked. That asymmetry
## was an accident of which keyword needed a Tool when it shipped.
##
## Every keyword now reads through `Unit.kw_value()`, so a modifier composes with
## whatever the keyword already does. Modifiers stack without limit by design.

## 6 keyword-modifiable checks in the loop, plus 9 individual assertions.
const EXPECTED_ASSERTIONS := 15

var _pass := 0
var _fail := 0


func _check(label: String, got, want) -> void:
	if got == want:
		_pass += 1
	else:
		_fail += 1
		print("FAIL: %s — got %s, want %s" % [label, got, want])


func _unit(kw: String, n: int) -> Unit:
	var CardDataScript := load("res://scripts/core/CardData.gd")
	var c = CardDataScript.from_dict({
		"id": "probe", "name": "Probe", "type": "unit", "faction": "hel",
		"stage": "basic", "hp": 60, "retreat": 1,
		"keywords": [{"kw": kw, "n": n}],
		"attacks": [],
	})
	var UnitScript := load("res://scripts/core/Unit.gd")
	return UnitScript.new(c)


func _initialize() -> void:
	## Every previously-flat keyword now takes a modifier.
	for kw in ["toll", "siphon", "decay", "judgment", "essence", "resist"]:
		var u: Unit = _unit(kw, 2)
		u.add_kw_mod(kw, 2)
		_check("%s modifiable" % kw, u.kw_value(kw), 4)

	## Modifiers stack without limit — two +2 effects make 6, not a capped 4.
	var stack: Unit = _unit("toll", 2)
	stack.add_kw_mod("toll", 2)
	stack.add_kw_mod("toll", 2)
	_check("modifiers stack unbounded", stack.toll(), 6)

	## The accessor, not just the raw dictionary, reports the modified value —
	## this is what every rule in the engine actually calls.
	var acc: Unit = _unit("siphon", 1)
	acc.add_kw_mod("siphon", 3)
	_check("accessor reflects modifier", acc.siphon(), 4)

	## A reduction lowers it, and the floor is 0 rather than negative.
	var down: Unit = _unit("decay", 2)
	down.add_kw_mod("decay", -5)
	_check("modifier floors at zero", down.decay(), 0)

	## The floor is applied on READ, so -5 then +5 returns to the print rather
	## than being clamped away in between.
	down.add_kw_mod("decay", 5)
	_check("floor does not destroy the modifier", down.decay(), 2)

	## Modifiers are history, not print: Rise restores the card, not the history.
	var risen: Unit = _unit("toll", 2)
	risen.add_kw_mod("toll", 4)
	_check("modified before rise", risen.toll(), 6)
	var back: Unit = risen.make_risen()
	_check("rise clears modifiers", back.toll(), 2)

	## Evolution is the same rule — a new printed card brings its own values.
	var CardDataScript := load("res://scripts/core/CardData.gd")
	var evo: Unit = _unit("toll", 2)
	evo.add_kw_mod("toll", 4)
	var stage1 = CardDataScript.from_dict({
		"id": "probe2", "name": "Probe II", "type": "unit", "faction": "hel",
		"stage": "stage1", "hp": 90, "retreat": 2,
		"keywords": [{"kw": "toll", "n": 3}], "attacks": [],
	})
	evo.evolve_into(stage1)
	_check("evolution clears modifiers", evo.toll(), 3)

	## An unmodified keyword is not reported as modified — the board renderer uses
	## this to decide whether to show a live value, so a false positive would mark
	## every card in the game.
	var plain: Unit = _unit("toll", 2)
	_check("unmodified reads false", plain.kw_is_modified("toll"), false)
	plain.add_kw_mod("toll", 1)
	_check("modified reads true", plain.kw_is_modified("toll"), true)

	if _pass + _fail != EXPECTED_ASSERTIONS:
		print("MISCOUNT: ran %d assertions, expected %d"
			% [_pass + _fail, EXPECTED_ASSERTIONS])
		_fail += 1

	print("KeywordModTest: %d passed, %d failed" % [_pass, _fail])
	quit(1 if _fail > 0 else 0)
