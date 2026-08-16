class_name CardData
extends RefCounted

## A card definition, loaded from data/cards.json.
## This is the immutable *printed* card. Runtime state lives in Unit.

enum Type { UNIT, ENERGY, SUPPORT, TOOL, TOWER_SUPPORT }
enum Stage { BASIC, STAGE1, STAGE2 }

var id: String = ""
var name: String = ""
var type: Type = Type.UNIT
var faction: String = "hel"
var stage: Stage = Stage.BASIC
var max_hp: int = 0
var evolves_from: String = ""
var flavor: String = ""

## Rules text as printed on the card. Supports have no attack lines, so this is
## what the card frame and the deck builder show instead.
var text: String = ""

## Tower support only: true if this occupies the tower's one modification slot.
## One-shots (Rebuild, Open the Gate) are false and never take the slot.
var permanent: bool = false

## Support / Tool / Tower support effect list — Array[Dictionary] {op, n, ...}.
## Same shape as AttackData.effects so GameState can share resolution helpers.
var effects: Array = []

## Pool energy spent to play this support. 0 for the overwhelming majority; 1-3
## on the handful that buy their way above the power band. The one sanctioned
## exception to "energy only buys attacks" — see CLAUDE.md, *Priced supports*.
##
## NOT YET ENFORCED: play_support does not check or spend this. Printed on the
## card so it reads correctly and so the data is right when the rule is built,
## the same way retreat costs shipped ahead of the retreat action.
var cost: int = 0

## Attached energy spent to return this unit to hand. A *design-time* number
## printed on the card (HP / 25, adjusted per card) — it never recalculates in
## play. The retreat action itself is not implemented yet; this is carried so the
## card reads correctly, and so the data is already right when retreat is built.
var retreat: int = 0

## keyword name -> value. e.g. {"toll": 2, "decay": 5, "rise": 0}
var keywords: Dictionary = {}

## Array[AttackData] — every printed line on the card, attacks and abilities
## alike, in printed order. Use attack_lines() / ability_lines() to get one kind;
## this stays the full list so the two-line rule is checked against one array.
var attacks: Array = []


static func from_dict(d: Dictionary) -> CardData:
	var c := CardData.new()
	c.id = d.get("id", "")
	c.name = d.get("name", "?")
	c.faction = d.get("faction", "hel")
	c.flavor = d.get("flavor", "")
	c.text = d.get("text", "")

	match d.get("type", "unit"):
		"energy": c.type = Type.ENERGY
		"support": c.type = Type.SUPPORT
		"tool": c.type = Type.TOOL
		"tower_support": c.type = Type.TOWER_SUPPORT
		_: c.type = Type.UNIT

	if c.type == Type.ENERGY:
		return c

	## Every card type may carry an effect list. Supports, Tools and tower support
	## use it INSTEAD of attacks; units use it alongside them, for card text the
	## keyword system does not cover — Gaia's `earth_from_attached` and
	## `earth_rate`, and Makeshift Tower's `auto_fire`.
	##
	## This used to sit inside the non-unit branch below, which silently dropped
	## `effects` on every unit — the value parsed fine and simply never arrived.
	c.effects = d.get("effects", [])

	## `permanent` and `cost` stay support-only: a unit is free to play by the
	## core rules, so a unit printing a cost would be a rule-break, not a typo.
	if c.type != Type.UNIT:
		c.permanent = bool(d.get("permanent", false))
		c.cost = int(d.get("cost", 0))
		return c

	c.max_hp = int(d.get("hp", 0))
	c.retreat = int(d.get("retreat", 0))
	c.evolves_from = str(d.get("evolves_from", "")) if d.get("evolves_from") != null else ""

	match d.get("stage", "basic"):
		"stage1": c.stage = Stage.STAGE1
		"stage2": c.stage = Stage.STAGE2
		_: c.stage = Stage.BASIC

	for k in d.get("keywords", []):
		c.keywords[k.get("kw", "")] = int(k.get("n", 0))

	for a in d.get("attacks", []):
		c.attacks.append(AttackData.from_dict(a))

	return c


## The lines that are queued and resolve at end of turn.
func attack_lines() -> Array:
	var out: Array = []
	for a in attacks:
		if not a.is_ability:
			out.append(a)
	return out


## The lines activated immediately during the main phase, once per turn each.
func ability_lines() -> Array:
	var out: Array = []
	for a in attacks:
		if a.is_ability:
			out.append(a)
	return out


func has_kw(kw: String) -> bool:
	return keywords.has(kw)


func kw(kw_name: String) -> int:
	return int(keywords.get(kw_name, 0))


func is_unit() -> bool:
	return type == Type.UNIT


func is_energy() -> bool:
	return type == Type.ENERGY


## Support, Tool, and tower support — everything played for a one-off or lasting
## effect rather than deployed as a body. All are free to play.
func is_support_like() -> bool:
	return type == Type.SUPPORT or type == Type.TOOL or type == Type.TOWER_SUPPORT


func is_tool() -> bool:
	return type == Type.TOOL


func is_tower_support() -> bool:
	return type == Type.TOWER_SUPPORT


func has_effect(op: String) -> bool:
	for e in effects:
		if e.get("op", "") == op:
			return true
	return false


func effect_value(op: String, fallback: int = 0) -> int:
	for e in effects:
		if e.get("op", "") == op:
			return int(e.get("n", fallback))
	return fallback


## A STRING field on an effect, for ops whose payload is not a number.
##
## `buff_keyword` needs to name which keyword it raises — {"op": "buff_keyword",
## "kw": "toll", "n": 2} — so one op serves every keyword rather than the engine
## needing a separate `grant_*` op per keyword.
func effect_text(op: String, field: String, fallback: String = "") -> String:
	for e in effects:
		if e.get("op", "") == op:
			return str(e.get(field, fallback))
	return fallback


## "Free" or "2 energy" — the printed cost line on a support card.
func cost_string() -> String:
	return "Free" if cost <= 0 else "%d energy" % cost


func type_label() -> String:
	match type:
		Type.ENERGY: return "Energy"
		Type.SUPPORT: return "Support"
		Type.TOOL: return "Tool"
		Type.TOWER_SUPPORT: return "Tower Support" + (" (permanent)" if permanent else " (one-shot)")
		_: return stage_name()


func stage_name() -> String:
	match stage:
		Stage.STAGE1: return "Stage 1"
		Stage.STAGE2: return "Stage 2"
		_: return "Basic"


## "Toll 2, Decay 5" — the printed ability line.
func keyword_line() -> String:
	if keywords.is_empty():
		return ""
	var parts: Array[String] = []
	for k in keywords:
		var n: int = keywords[k]
		var kw_label: String = str(k).capitalize()
		parts.append(kw_label if n == 0 else "%s %d" % [kw_label, n])
	return ", ".join(parts)
