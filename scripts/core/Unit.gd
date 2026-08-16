class_name Unit
extends RefCounted

## A unit in play. Wraps a CardData with mutable battlefield state.

var card: CardData
var hp: int = 0
var attached: int = 0            ## attached energy — immune to decay, lost on death
var lost_rise: bool = false      ## true once Rise has been spent
var judgment_spent: bool = false ## true once Judgment has fired, either half

## Earth this unit has GROWN in play, above its printed value. Reset to 0 on Rise
## and on evolution: Rise restores the card, not the history (CLAUDE.md).
var earth_grown: int = 0

## Max HP this unit has grown in play. Makeshift Tower gains +5 a round the way a
## real tower does; nothing else in the game grows a unit's max HP. Like
## `earth_grown` this is history, so Rise and evolution reset it.
var hp_grown: int = 0

## Sanctuary runtime state. `sanctuary_pool` is the remaining absorb pool; when it
## hits 0 the shield is still live for one final full absorb (plain Sanctuary), and
## only then is `sanctuary_active` cleared. Plain Sanctuary starts with pool 0.
var sanctuary_active: bool = false
var sanctuary_pool: int = 0
var queued_attack: AttackData = null
var queued_target = null         ## optional target payload for targeted attacks
var dies_at_eot: bool = false    ## set by Final Verdict

## Ability ids already activated this turn. Activated abilities are once per turn
## per unit — a global rule, not a per-card clause (CLAUDE.md) — so this is
## tracked on the unit and cleared at the start of each of its owner's turns.
var abilities_used: Array = []   ## Array[String] attack/ability ids

## ------------------------------------------------------------- attack lock
##
## The last attack this unit queued. Kept after it resolves so a locked unit can
## re-queue the same attack automatically next turn.
var last_attack: AttackData = null

## Per-unit lock override, tri-state, so a unit can opt out of the global lock:
##   LOCK_DEFAULT  follow the player's global autolock setting
##   LOCK_ON       always re-fire, even with the global toggle off
##   LOCK_OFF      never re-fire, even with the global toggle on
##
## Tri-state rather than a bool because "unlock this one card" has to survive the
## global toggle being on — that is the whole point of the individual override.
enum { LOCK_DEFAULT, LOCK_ON, LOCK_OFF }
var lock_mode: int = LOCK_DEFAULT


## Whether this unit should auto-fire, given the player's global setting.
func is_attack_locked(global_lock: bool) -> bool:
	match lock_mode:
		LOCK_ON: return true
		LOCK_OFF: return false
		_: return global_lock


## Cycle the per-unit toggle. From the default it moves to the *opposite* of what
## the global setting is currently doing, so one click always visibly changes the
## behaviour rather than being a no-op.
func cycle_lock(global_lock: bool) -> void:
	match lock_mode:
		LOCK_DEFAULT: lock_mode = LOCK_OFF if global_lock else LOCK_ON
		LOCK_ON: lock_mode = LOCK_OFF
		_: lock_mode = LOCK_ON

## The one Tool attached to this unit, or null. Carries through evolution like
## attached energy; discarded when the unit dies *or* retreats.
var tool: CardData = null

## Set by Hold the Slot — cannot be reduced below 1 HP until end of turn.
var protected_this_turn: bool = false

## Decay damage taken this turn, so Reconsecrate can undo it.
var decay_taken_this_turn: int = 0

## The evolution path underneath this unit, oldest first: the card ids this unit
## was built from. Retreat returns all of them to hand as separate cards.
var evolution_path: Array = []   ## Array[String] card ids


## ------------------------------------------------------- keyword modifiers
##
## Keyword values a card has RAISED on this unit, as {keyword: amount}. A printed
## `Toll 2` under a "+2 Toll" support reads 4, and every rule that consumes Toll
## reads the modified value rather than the print.
##
## This exists because the engine was inconsistent about it. `rift()` and
## `earth()` already accepted Tool grants and card effects, while `toll()`,
## `siphon()`, `decay()`, `judgment()`, `essence()` and `resist()` returned
## `card.kw(...)` flat — so "a support that boosts Toll by 2" had no path while
## the identical card for Rift already worked. That asymmetry was an accident of
## which keyword happened to need a Tool when it shipped, not a design decision.
##
## Modifiers STACK WITHOUT LIMIT, deliberately. Two "+2 Toll" effects make Toll 6.
## The bound on Tools is one-per-unit; a board-wide support has no such bound and
## is not given an artificial one.
##
## This is history, not print, so like `earth_grown` it resets on Rise and on
## evolution — Rise restores the card, not the history.
var kw_mods: Dictionary = {}


## The live value of `kw` on this unit: printed, plus anything raised on it.
##
## Floored at 0 so a reducing effect can never make a keyword negative — every
## keyword in the game reads as "N of something", and a negative N has no meaning
## the rules define.
func kw_value(kw_name: String) -> int:
	var n: int = card.kw(kw_name) + int(kw_mods.get(kw_name, 0))
	return maxi(0, n)


## Raise `kw` on this unit by `n`. Negative lowers it; the floor is applied on
## read rather than here, so a -5 followed by a +5 returns to the printed value
## instead of being clamped away in between.
func add_kw_mod(kw_name: String, n: int) -> void:
	kw_mods[kw_name] = int(kw_mods.get(kw_name, 0)) + n


## True when this unit's `kw` differs from its printed value — the board renderer
## uses this to mark a modified keyword so the player can see it (CLAUDE.md's rule
## that per-unit state the engine tracks has to be visible per-unit).
func kw_is_modified(kw_name: String) -> bool:
	return int(kw_mods.get(kw_name, 0)) != 0


func _init(c: CardData) -> void:
	card = c
	hp = c.max_hp
	_reset_sanctuary()


## Arm Sanctuary from the printed card. Plain Sanctuary is pool 0 — still live,
## because an exhausted pool grants one final full absorb before the shield is gone.
func _reset_sanctuary() -> void:
	sanctuary_active = card.has_kw("sanctuary")
	sanctuary_pool = card.kw("sanctuary")


## The PRINTED max plus anything this unit has grown. Deliberately does not
## include the Earth aura — that depends on the owning player's whole board, and
## a Unit has no owner reference. Use `GameState.effective_max_hp(p, u)` for the
## aura-adjusted ceiling.
func max_hp() -> int:
	return card.max_hp + hp_grown


func is_alive() -> bool:
	return hp > 0


## Toll: printed, plus any modifier a card has raised on this unit. Damage and
## debuffs still never move it — only an effect that explicitly says it does.
func toll() -> int:
	return kw_value("toll")


func decay() -> int:
	return kw_value("decay")


func retribution() -> int:
	return kw_value("retribution")


## --------------------------------------------------------------- Void keywords
##
## `Siphon N` — attached energy this unit's line MOVES from an enemy unit onto
## itself. Printed, plus any modifier raised on this unit.
func siphon() -> int:
	return kw_value("siphon")


## `Rift N` — bonus damage per point of Gap. Printed value plus any granted by a
## Tool (Event Horizon), because a Tool is a permanent modification to the body
## in exactly the way an aura is not. Stacking is intentional and bounded: one
## Tool per unit, so the most any body can hold is printed + 1.
func rift() -> int:
	var n: int = kw_value("rift")
	if tool != null and tool.has_effect("grant_rift"):
		n += tool.effect_value("grant_rift", 0)
	return n


func has_rift() -> bool:
	return rift() > 0


## --------------------------------------------------------------- Gaia keywords
##
## `Earth N` — this unit's contribution to its owner's board-wide aura. Printed,
## plus anything the card grew in play (see `earth_grown`). The aura itself is
## summed on GameState, because a Unit has no reference to the player whose other
## units it must count — the same reason Rift reads the Gap from there.
func earth() -> int:
	var n: int = kw_value("earth") + earth_grown
	## Verdant Anchor grants Earth the same way Event Horizon grants Rift — a Tool
	## is a permanent modification to the body, which is exactly what the aura
	## reads. Bounded by one-Tool-per-unit.
	if tool != null and tool.has_effect("grant_earth"):
		n += tool.effect_value("grant_earth", 0)
	## Living Conduit: Earth equals attached energy, live and continuous. READ
	## rather than banked — attacking does not spend attached energy, so a card
	## that banked Earth per attack would grant the same energy's worth every
	## turn forever (gaia.md). Losing the energy costs the aura at the same time,
	## which is what welds Gaia onto the pool-versus-attached decision.
	if card.has_effect("earth_from_attached"):
		n += attached * card.effect_value("earth_from_attached", 1)
	return n


## `Essence N` — pool energy the owner may pay when this unit dies to move its
## Earth and attached energy to the nearest friendly unit on the same board.
func essence() -> int:
	return kw_value("essence")


func has_essence() -> bool:
	return card.has_kw("essence")


## `Resist X` — flat reduction on each incoming instance of damage. Shared
## keyword; any faction may print it.
func resist() -> int:
	return kw_value("resist")


func has_rise() -> bool:
	return card.has_kw("rise") and not lost_rise


## The printed Judgment value. Like Toll, buffs and damage never change it.
func judgment() -> int:
	return kw_value("judgment")


func has_judgment() -> bool:
	return card.has_kw("judgment") and not judgment_spent


## Absorb `amount` into Sanctuary and return the damage that gets through.
##
## The pool depletes first. When the pool cannot cover the hit, the shield eats the
## *whole* instance and is spent — that terminal overflow is what makes Sanctuary
## resistant to burst as well as to chip, and it is why a small pool is never wasted.
func absorb(amount: int) -> int:
	if not sanctuary_active or amount <= 0:
		return amount
	if amount <= sanctuary_pool:
		sanctuary_pool -= amount
		return 0
	## Pool cannot cover it: full absorb, shield spent.
	sanctuary_pool = 0
	sanctuary_active = false
	return 0


## Restore Sanctuary to its printed value — Rekindle and Aegis of the Choir.
func restore_sanctuary() -> void:
	_reset_sanctuary()


## Grant plain Sanctuary to a unit whose printed card has none (Aegis of the Choir).
## Granted Sanctuary is deliberately not restorable by Court of Bells, which reads
## printed keywords only.
func grant_sanctuary() -> void:
	sanctuary_active = true
	sanctuary_pool = max(sanctuary_pool, 0)


## The printed retreat cost, reduced by any Tool that modifies it (Grave Anchor).
## The printed number itself never changes — this is the *payable* cost.
func retreat_cost() -> int:
	var base: int = card.retreat
	if tool != null and tool.has_effect("retreat_reduction"):
		base -= tool.effect_value("retreat_reduction", 0)
	return max(0, base)


## Retreat is paid from the unit's own attached energy — never the pool, never
## another unit. A unit that cannot pay is stuck on the board.
func can_retreat() -> bool:
	return attached >= retreat_cost()


func has_tool() -> bool:
	return tool != null


## Bonus damage granted by a Tool (Weighted Chain).
func tool_damage_bonus() -> int:
	if tool != null and tool.has_effect("attack_damage"):
		return tool.effect_value("attack_damage", 0)
	return 0


## Extra energy an attack costs because of a Tool (Deadweight, on enemy units).
func tool_cost_penalty() -> int:
	if tool != null and tool.has_effect("attack_cost_increase"):
		return tool.effect_value("attack_cost_increase", 0)
	return 0


## Retribution from the printed card plus any granted by a Tool (Iron Standard).
## They stack — on a Mourning Bell with Iron Standard that's Retribution 20.
func total_retribution() -> int:
	var n: int = retribution()
	if tool != null and tool.has_effect("grant_retribution"):
		n += tool.effect_value("grant_retribution", 0)
	return n


## Heal, capped at printed max HP. Healing never goes above the printed number,
## so it can't combo with an HP buff and never moves Toll or Retreat.
func heal(amount: int) -> int:
	var healed: int = min(amount, max_hp() - hp)
	if healed <= 0:
		return 0
	hp += healed
	return healed


## Returns damage actually dealt (capped at remaining HP).
## Hold the Slot floors the unit at 1 HP for the turn.
func take_damage(amount: int) -> int:
	var floor_hp: int = 1 if protected_this_turn else 0
	var dealt: int = min(amount, max(0, hp - floor_hp))
	hp -= dealt
	return dealt


## What this attack actually costs on this unit, including a Deadweight tax.
func attack_cost(atk: AttackData) -> int:
	return atk.total_cost() + tool_cost_penalty()


func can_afford(atk: AttackData, pool: int) -> bool:
	return attached + pool >= attack_cost(atk)


## Energy still needed from the pool to queue this attack.
func pool_needed(atk: AttackData) -> int:
	return max(0, attack_cost(atk) - attached)


## ---------------------------------------------------------------- abilities

## Abilities are free — the only energy one may ask for is Consume, which is
## paid out of *attached* energy and destroyed. Nothing here ever touches the
## pool: an ability is not an attack and cannot pull from it.
func can_use_ability(ab: AttackData) -> bool:
	if not ab.is_ability or not is_alive():
		return false
	if has_used_ability(ab):
		return false
	return attached >= ab.consume_cost()


func has_used_ability(ab: AttackData) -> bool:
	return abilities_used.has(ab.id)


## Burn the Consume cost and mark the ability spent for this turn.
func spend_ability(ab: AttackData) -> void:
	attached = max(0, attached - ab.consume_cost())
	abilities_used.append(ab.id)


func clear_abilities_used() -> void:
	abilities_used.clear()


## Clears the pending attack but deliberately keeps `last_attack` — that is the
## memory the lock re-fires from, and it has to outlive the attack resolving.
func clear_queue() -> void:
	queued_attack = null
	queued_target = null


## Build the Rise replacement: half HP, keeps everything but Rise, no attached energy.
func make_risen() -> Unit:
	var u := Unit.new(card)
	u.hp = int(card.max_hp / 2.0)
	u.lost_rise = true
	u.attached = 0
	## Earth grown in play is lost with the body, exactly as attached energy is.
	## Rise restores the CARD, not the history (CLAUDE.md) — otherwise Rise plus
	## any Earth-growth card is an engine: die, keep the accumulation, return,
	## grow further. `earth_grown` starts at 0 on a fresh Unit, so this is
	## belt-and-braces against a future `make_risen` that copies more state.
	u.earth_grown = 0
	## A risen Makeshift Tower comes back at its printed size, not the size it
	## had grown to — same rule, same reason.
	u.hp_grown = 0
	## Keyword modifiers are history too — a "+2 Toll" support raised the body
	## that died, not the card. A risen unit comes back at its printed values.
	u.kw_mods = {}
	## A returned body is a fresh printed card: Judgment and Sanctuary are restored.
	## This is the stacked-reprieve combo Heaven's Rise cards are built on.
	u.judgment_spent = false
	u._reset_sanctuary()
	## The Tool went to the discard with the body that died — a Rising unit
	## comes back bare. Its evolution path is gone too: it returns as the
	## printed card, not as a stack that could be retreated for free cards.
	return u


func evolve_into(new_card: CardData) -> void:
	## Damage carried forward is measured against the max this unit ACTUALLY had,
	## grown included — otherwise a grown body would appear to have taken damage
	## it never took (or to have healed) the moment it evolved.
	var missing: int = max_hp() - hp
	evolution_path.append(card.id)           ## the stage underneath comes back on retreat
	card = new_card
	hp_grown = 0                             ## new printed card, new size
	earth_grown = 0                          ## new printed card, new Earth
	kw_mods = {}                             ## new printed card, new keyword values
	hp = max(1, new_card.max_hp - missing)
	lost_rise = false                        ## new printed card, new keywords
	judgment_spent = false                   ## new printed card, new charge
	_reset_sanctuary()                       ## new printed card, new shield
	clear_queue()
	## The remembered attack belonged to the old printed card and does not exist
	## on the new one, so the lock has nothing to re-fire until you pick an
	## attack on the evolved body. The lock *setting* is kept — it's the player's
	## stated preference for this unit, not a property of the card.
	last_attack = null
	abilities_used.clear()                   ## new card, new once-per-turn lines
	dies_at_eot = false
	## attached energy and the Tool both carry through evolution — see CLAUDE.md


## Every card this unit would return to hand on retreat: the whole evolution
## path plus the current stage, as separate cards.
func retreat_cards() -> Array:
	var out: Array = evolution_path.duplicate()
	out.append(card.id)
	return out
