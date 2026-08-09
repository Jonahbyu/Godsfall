class_name AttackData
extends RefCounted

## One line on a unit card — either an **attack** or an **ability**.
##
## Both are modelled here because they share almost everything (a name, rules
## text, an effect list). What separates them is when they resolve and what they
## may charge for:
##
##   Attack   queued during the main phase, resolves at end of turn, and pays a
##            *requirement* cost from the pool onto the unit. That energy stays
##            attached, so the attack is free every turn thereafter.
##   Ability  resolves immediately when activated, once per turn per unit, and
##            is FREE — with exactly one exception, `Consume N`, which destroys
##            N attached energy on use rather than merely requiring it.
##
## The "abilities are free unless they Consume" rule is enforced by
## activation_cost(): an ability's `cost` block is ignored outright, so a card
## cannot accidentally price an ability by filling in the wrong field.

var id: String = ""
var name: String = ""
var damage: int = 0
var text: String = ""
var targeting: String = ""       ## "" = default (slot across), "friendly_unit" = pick a friendly
## Colored cost, and which color it is. The pool is a single untyped int (see
## Player.pool), so the color is currently *display only* — it is parsed and
## printed but never enforced, because colorless is counted in the total and any
## energy pays it. It is stored rather than discarded so the day multi-color
## enforcement is built, the data is already right.
var cost_faction: int = 0
var cost_color: String = ""      ## "hel" / "heaven" / "void" — the color that was printed
var cost_colorless: int = 0
var effects: Array = []          ## Array[Dictionary] — {op: String, n: int}

## True when this line is an ability rather than an attack.
var is_ability: bool = false

## Consume N — attached energy *destroyed* on activation, not merely required.
## The only cost an ability may carry, and priced on the steeper Consume curve
## (~20 damage per energy consumed) when it deals damage at all. See CLAUDE.md.
var consume: int = 0


static func from_dict(d: Dictionary) -> AttackData:
	var a := AttackData.new()
	a.id = d.get("id", "")
	a.name = d.get("name", "?")
	a.damage = int(d.get("damage", 0))
	a.text = d.get("text", "")
	a.targeting = d.get("targeting", "")
	a.effects = d.get("effects", [])
	a.is_ability = bool(d.get("ability", false))
	a.consume = int(d.get("consume", 0))
	## Read whichever color key is present rather than hard-coding one. This was
	## `c.get("hel", 0)`, which silently priced every Heaven attack at 0 the moment
	## Heaven shipped with `{"heaven": N}` cost blocks.
	var c: Dictionary = d.get("cost", {})
	a.cost_colorless = int(c.get("colorless", 0))
	for key in c.keys():
		if key != "colorless" and int(c[key]) > 0:
			a.cost_faction = int(c[key])
			a.cost_color = str(key)
			break
	return a


## Energy that must be *attached* for this line to be usable. For an attack this
## is the printed cost; for an ability it is only ever its Consume, because
## abilities are free. An ability's cost block is deliberately ignored rather
## than asserted on, so bad data reads as free instead of breaking the card.
func total_cost() -> int:
	if is_ability:
		return consume
	return cost_faction + cost_colorless


## Energy destroyed when this line resolves. Only Consume ever destroys energy —
## an ordinary attack's cost stays attached and pays for itself every turn after.
func consume_cost() -> int:
	return consume


## "1 Hel, 1 colorless" — or for an ability, "Free" / "Consume 1".
func cost_string() -> String:
	if is_ability:
		return "Consume %d" % consume if consume > 0 else "Free"
	var parts: Array[String] = []
	if cost_faction > 0:
		parts.append("%d %s" % [cost_faction, cost_color.capitalize() if cost_color != "" else "colored"])
	if cost_colorless > 0:
		parts.append("%d colorless" % cost_colorless)
	return ", ".join(parts) if parts.size() > 0 else "Free"


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
