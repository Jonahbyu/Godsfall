class_name Unit
extends RefCounted

## A unit in play. Wraps a CardData with mutable battlefield state.

var card: CardData
var hp: int = 0
var attached: int = 0            ## attached energy — immune to decay, lost on death
var lost_rise: bool = false      ## true once Rise has been spent
var lost_molt: bool = false      ## true once Molt has fired and not yet restored

## Molt granted by a card (`Second Skin`) to a unit whose printed card lacks
## it, until the unit's next death or evolution. Kept separate from the
## printed keyword, same reasoning as `grant_sanctuary()` for a unit with no
## printed Sanctuary: `has_molt()` below checks BOTH so granted Molt behaves
## identically to printed Molt everywhere it matters, but a printed-keywords
## check (kw() / has_kw()) alone would miss it, the same gap that made
## `grant_sanctuary()` necessary in the first place.
var granted_molt: bool = false
var judgment_spent: bool = false ## true once Judgment has fired, either half

## Earth this unit has GROWN in play, above its printed value. Reset to 0 on Rise
## and on evolution: Rise restores the card, not the history (CLAUDE.md).
var earth_grown: int = 0

## Max HP this unit has grown in play. Makeshift Tower gains +5 a round the way a
## real tower does; nothing else in the game grows a unit's max HP. Like
## `earth_grown` this is history, so Rise and evolution reset it.
var hp_grown: int = 0

## Tempest `Charge`: a banked counter that grows when this unit DEALS damage and
## is spent whole by a Discharge ability.
##
## Unlike every other accumulated value on a unit, this SURVIVES evolution — see
## evolve_into(). Attached energy and the Tool are the only other things that do,
## and the reason is identical: without it, evolving destroys the investment, so
## the correct play for the one faction whose resource is time would be never to
## evolve. It is still lost on death, on `Rise`, and on retreat.
var charge: int = 0

## Wilds `Ferocity N`: a banked stack counter that grows N per FRIENDLY death on
## this unit's own board — including a death answered by Molt or Rise, and
## including this same unit's own Molt-death (2026-08-19 wilds design spec).
##
## Unlike `charge`, this does NOT survive evolution: the spec's Numbers section
## has no rate-carries-through-evolution story the way Tempest's does, so it
## resets on evolve like every other grown value (earth_grown, hp_grown). It
## also does not survive an ordinary death or a Rise — it is wiped, same as
## attached energy — with exactly one printed exception: a unit's own `Molt`
## copies it forward, because the fiction is that body never really died.
var ferocity_stacks: int = 0

## Wilds `Molt`: this unit's stack count survives being wiped by an evolution
## reset ONLY via the explicit carry-through in the Molt copy-construction path
## (see GameState._kill). Nothing else reads or writes it directly.

## A discharge that has been paid for and is riding this unit's next attack.
## Kept separate from `charge` because the counter is already spent — this is the
## amount in flight, and it must never feed back into the counter. A spend is a
## spend, or a large discharge partially refunds itself.
var pending_discharge: int = 0
var pending_discharge_mult: int = 1
var pending_discharge_mode: String = ""

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

## Wilds: Retribution granted only until end of turn — Scarl's "Thicken the
## Hide" / "Harden the Hide" abilities. Kept separate from the printed keyword
## (which total_retribution() also reads) so it visibly expires rather than
## becoming a permanent kw_mod, the same reason protected_this_turn is its own
## field instead of routing through add_kw_mod.
var temp_retribution: int = 0

## HP this unit has Stoked this turn. Forge's signature: `Stoke N` is a free
## once-per-turn ability that deals N to this unit and sets this counter, and
## *other lines read it* — "if this unit stoked this turn, ...". See forge.md.
##
## An AMOUNT rather than a bool, because payoffs come in two shapes and both
## have to read one field: scaling ones ("+1 damage per 2 HP stoked") and
## thresholds ("if this unit stoked 40 or more"). A bool would make a large
## printed Stoke strictly worse than a small one.
##
## Cleared with the rest of the per-turn unit state in Player.start_turn().
var stoked_this_turn: int = 0

## Forge: a second attack this unit may queue this turn, granted by a
## `stoked_extra_attack` payoff. Conditional multi-attack rather than printed
## `Windfury` — the condition sits on a Forge body, which is what keeps it clear
## of the standing rule that Windfury may never share a card with `Judgment`.
##
## An extra SLOT rather than a flag: `queued_attack` holds one line, so a second
## attack needs somewhere to live. Resolution walks this after the primary.
var extra_attack: AttackData = null
var extra_target = null
var extra_attack_allowed: bool = false

## Forge: this unit may Stoke a second time this turn (`stoked_twice`). Breaks
## the once-per-turn ability limit for Stoke lines only, which is what doubles
## every amount-scaling payoff on the body.
var extra_stoke_allowed: bool = false

## Forge `stoked_cost_reduction`: energy taken off this unit's attacks this turn.
## Stacks (two grants are 2 cheaper) and floors the cost at 0 on read rather than
## being clamped as it accumulates, the same rule the keyword modifier layer uses.
var cost_reduction_this_turn: int = 0

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


## Grow the banked counter. Floored at 0 here rather than on read, because
## `charge` has no printed value to fall back to the way kw_mods does.
func add_charge(n: int) -> void:
	charge = maxi(0, charge + n)


## Spend the whole counter and return what it held.
func spend_charge() -> int:
	var held: int = charge
	charge = 0
	return held


## The printed Charge rate — how much this unit banks per damage instance dealt.
## Read through kw_value so a card that raises Charge is honoured, exactly as
## every other keyword works.
func charge_rate() -> int:
	return kw_value("charge")


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
##
## Ferocity's +2-per-stack IS included here, unlike Earth: it is per-unit state
## the Unit already owns outright, not a board-wide sum requiring a Player
## reference, so there is no reason to push it out to GameState the way Earth's
## aura has to be.
func max_hp() -> int:
	return card.max_hp + hp_grown + ferocity_hp_bonus()


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


## --------------------------------------------------------------- Wilds keywords
##
## `Molt N` — when this unit would die, it is instantly replaced in the same
## slot by a full-HP, full-energy copy of itself, and the copy loses Molt. Only
## restored by evolving (see evolve_into()). Deliberately spent-on-use, the same
## brake shape as Judgment and Rise, but the copy is otherwise exactly as strong
## as the original rather than diminished (wilds design spec).
func has_molt() -> bool:
	if granted_molt:
		return true
	return card.has_kw("molt") and not lost_molt


## `Ferocity N` — printed rate at which this unit's stack counter grows per
## qualifying friendly death on its own board. Read through kw_value so a card
## that raises Ferocity is honoured, exactly as every other keyword works.
func ferocity_rate() -> int:
	return kw_value("ferocity")


func has_ferocity() -> bool:
	return card.has_kw("ferocity")


## Grow the banked stack counter. Floored at 0, same shape as add_charge().
func add_ferocity(n: int) -> void:
	ferocity_stacks = maxi(0, ferocity_stacks + n)


## +2 max HP per stack held (wilds design spec's Numbers section). Folded into
## max_hp() below so every reader of a unit's ceiling sees it with no separate
## call site to remember, the same way hp_grown already works.
func ferocity_hp_bonus() -> int:
	return ferocity_stacks * 2


## +1 damage per stack held, read at attack resolution alongside Rift — see
## GameState._deliver_attack_damage.
func ferocity_dmg_bonus() -> int:
	return ferocity_stacks


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
	## Pool cannot cover it. The shield absorbs everything it still holds, is
	## spent, and the REMAINDER GETS THROUGH.
	##
	## This replaced an unbounded "terminal overflow" that absorbed the whole
	## instance no matter how large. That rule was adopted so a small pool is
	## never wasted and so Sanctuary resists burst as well as chip -- but it makes
	## every shielded body worth `pool + one arbitrarily large hit`, and a deck
	## running thirty of them (Sealed Light) simply cannot be killed: it measured
	## 88-91% across 3M games while its games ran 4 rounds longer than average,
	## i.e. it was surviving to win on the tower clock rather than out-playing
	## anyone. Draining the pool exactly keeps Sanctuary strong against chip --
	## which is its documented identity -- while letting a genuinely big attack
	## punch through the last sliver instead of being erased by it (heaven.md).
	## PLAIN Sanctuary (printed pool 0) is the exception and keeps the full
	## absorb: it is a boolean "block the next instance" shield, so draining it
	## exactly would make it block nothing at all and delete the keyword.
	if kw_value("sanctuary") <= 0:
		sanctuary_active = false
		return 0
	var through: int = amount - sanctuary_pool
	sanctuary_pool = 0
	sanctuary_active = false
	return through


## Restore Sanctuary to its printed value — Aegis of the Choir, and any card that
## spends a CARD to do it. A one-shot support paying full price gets full value.
func restore_sanctuary() -> void:
	_reset_sanctuary()


## Recharge Sanctuary by `amount`, never above its printed pool, and re-arm the
## shield if it had been spent entirely.
##
## This is the FREE, repeating form used by the end-of-turn `Rekindle` abilities,
## and it is deliberately weaker than `restore_sanctuary()`. A free once-per-turn
## refill to a printed 100 prevents more damage per turn than any attack in the
## game deals, which is why Sealed Light — running four such bodies — measured
## 89.2% over 1M games. Partial recharge keeps the "a shield that comes back"
## identity while making chip damage actually accumulate against it (heaven.md).
func recharge_sanctuary(amount: int) -> void:
	if amount <= 0:
		return
	var printed: int = kw_value("sanctuary")
	if printed <= 0:
		## Plain Sanctuary (printed 0) is a boolean shield: re-arm it, no pool.
		sanctuary_active = true
		return
	sanctuary_pool = min(printed, sanctuary_pool + amount)
	sanctuary_active = true


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


## Retribution from the printed card plus any granted by a Tool (Iron Standard)
## plus any this-turn grant (Wilds' Scarl chain). All three stack — on a
## Mourning Bell with Iron Standard that's Retribution 20, and a Scarl unit
## mid-Thicken stacks its temporary grant on top of whatever it prints.
func total_retribution() -> int:
	var n: int = retribution()
	if tool != null and tool.has_effect("grant_retribution"):
		n += tool.effect_value("grant_retribution", 0)
	return n + temp_retribution


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


## A self-inflicted hit that can never kill, floored at 1 HP for THIS instance
## only — unlike Hold the Slot, the protection does not persist for the rest
## of the turn (Wilds' `Running Wound`). Deliberately its own small function
## rather than toggling `protected_this_turn` around the call, which would
## leave the unit immune to unrelated damage for the rest of the turn if
## anything else hit it in between.
func take_self_damage_floored(amount: int) -> int:
	var dealt: int = min(amount, max(0, hp - 1))
	hp -= dealt
	return dealt


## Pay a Stoke cost: lose `amount` HP and record it for this turn's payoffs.
## Returns the HP actually spent.
##
## Deliberately NOT routed through take_damage(), and that is the whole keyword:
## Stoke is a COST the controller chooses to pay, not an incoming damage event.
## So `Sanctuary` does not absorb it, `Resist` does not reduce it, and
## `Retribution` does not recoil — there is no attacker. If it went through the
## damage path a shielded body would Stoke for FREE, and the faction's central
## cost would be optional in exactly the matchups where it has to be real.
##
## `protected_this_turn` is honoured, because Hold the Slot is a floor on the
## unit's HP rather than damage prevention — it says this body does not die this
## turn, and a voluntary cost should not be able to route around that either.
##
## Stoke MAY kill. The caller resolves the death through the normal path, so
## `Toll`, `Rise` and `Essence` all fire; Forge gets no private kind of death.
func pay_stoke(amount: int) -> int:
	if amount <= 0 or not is_alive():
		return 0
	var floor_hp: int = 1 if protected_this_turn else 0
	var spent: int = min(amount, max(0, hp - floor_hp))
	hp -= spent
	stoked_this_turn += spent
	return spent


## True if this unit has Stoked at all this turn — the plain flag most payoffs read.
func has_stoked() -> bool:
	return stoked_this_turn > 0


## Forge: an extra attack slot is only usable while it has been granted AND is
## still empty. Checked by GameState before a second queue is accepted.
func can_queue_extra() -> bool:
	return extra_attack_allowed and extra_attack == null and is_alive()


func clear_extra_queue() -> void:
	extra_attack = null
	extra_target = null


## What this attack actually costs on this unit, including a Deadweight tax.
func attack_cost(atk: AttackData) -> int:
	## Deadweight taxes upward, Forge's Stoke discount cuts downward, and the
	## result floors at 0 — an attack may become free but never pays the player.
	return max(0, atk.total_cost() + tool_cost_penalty() - cost_reduction_this_turn)


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
	## Forge `stoked_twice` lifts the once-per-turn limit for STOKE lines only,
	## and for exactly one extra use. Any other ability still gets one activation
	## — the payoff breaks its own rule, not the general one.
	if has_used_ability(ab):
		if not (ab.stoke > 0 and extra_stoke_allowed):
			return false
	if attached < ab.consume_cost():
		return false
	## A Stoke line needs the HP to actually spend. Requiring MORE than the cost
	## (not >=) is deliberate: a unit may Stoke itself to death, but only when the
	## HP is really there — a 20 HP body cannot pay Stoke 40 and it may not pay a
	## partial cost, the same way an unaffordable attack is simply illegal.
	if ab.stoke > 0 and hp < ab.stoke:
		return false
	return true


func has_used_ability(ab: AttackData) -> bool:
	return abilities_used.has(ab.id)


## Burn the Consume cost and mark the ability spent for this turn.
##
## Stoke is NOT paid here. It has to happen inside GameState, because paying it
## can kill the unit and a death has to resolve through the normal path so Toll,
## Rise and Essence all fire — which is not something a Unit can do to itself.
## Scrap likewise destroys a *different* unit and needs the board.
func spend_ability(ab: AttackData) -> void:
	attached = max(0, attached - ab.consume_cost())
	## A second Stoke consumes the grant rather than the once-per-turn slot, so
	## `stoked_twice` buys exactly one extra use. Without this the grant would
	## persist for the rest of the turn and Stoke would become unlimited, which
	## is the one thing the ability limit exists to prevent.
	if ab.stoke > 0 and abilities_used.has(ab.id) and extra_stoke_allowed:
		extra_stoke_allowed = false
	else:
		abilities_used.append(ab.id)


func clear_abilities_used() -> void:
	abilities_used.clear()


## Clears the pending attack but deliberately keeps `last_attack` — that is the
## memory the lock re-fires from, and it has to outlive the attack resolving.
func clear_queue() -> void:
	extra_attack = null
	extra_target = null
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
	## A banked Charge counter dies with the body. Rise restores the card, not
	## the history — refunding a full counter would make death nearly free for
	## the one faction whose counterplay IS death. Fresh Units start at 0, so
	## this is belt-and-braces against a make_risen that later copies more state.
	u.charge = 0
	## Keyword modifiers are history too — a "+2 Toll" support raised the body
	## that died, not the card. A risen unit comes back at its printed values.
	u.kw_mods = {}
	## A returned body is a fresh printed card: Judgment and Sanctuary are restored.
	## This is the stacked-reprieve combo Heaven's Rise cards are built on.
	u.judgment_spent = false
	u._reset_sanctuary()
	## A risen unit is a fresh printed card, so it has never spent Molt.
	u.lost_molt = false
	## Ferocity stacks are history, same reasoning as earth_grown and charge —
	## Rise restores the card, not the accumulation. Fresh Units start at 0,
	## this is belt-and-braces against a future make_risen copying more state.
	u.ferocity_stacks = 0
	## The Tool went to the discard with the body that died — a Rising unit
	## comes back bare. Its evolution path is gone too: it returns as the
	## printed card, not as a stack that could be retreated for free cards.
	return u


## Build the Molt replacement: full HP, full attached energy, Molt itself
## spent. This is the inversion of make_risen() in every axis but one — see
## the wilds design spec's comparison table — and the one shared axis is
## exactly this function's existence: a printed keyword produces a fresh Unit
## copy rather than mutating the dying one in place, the same shape Rise uses.
func make_molted() -> Unit:
	var u := Unit.new(card)
	u.hp = card.max_hp                       ## FULL HP — the loud difference from Rise
	u.lost_molt = true                       ## Molt is spent; only evolving restores it
	u.attached = attached                    ## FULL attached energy — deliberate exception
	                                          ## to "attached energy is lost when the unit
	                                          ## dies" (CLAUDE.md), same spirit as Forge's
	                                          ## stoked_unpreventable
	## Grown history resets exactly like Rise — Molt restores the card, not the
	## history, with ONE deliberate exception below.
	u.earth_grown = 0
	u.hp_grown = 0
	u.charge = 0
	u.kw_mods = {}
	u.judgment_spent = false
	u._reset_sanctuary()
	## THE deliberate exception: Ferocity stacks carry forward through a unit's
	## own Molt. Every other reset (ordinary death, Rise, evolution) wipes them;
	## this is the one place the spec says they survive, because the fiction is
	## that this body never really died at all.
	u.ferocity_stacks = ferocity_stacks
	## A Tool is discarded on Molt — the copy is not a returning card the way a
	## risen unit's Tool-loss is; it never left the board, so nothing carries a
	## Tool across a slot it never vacated. (Tools ride evolution, not Molt.)
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
	## Molt is the ONE place it must be granted back — the spec's whole brake on
	## the keyword is "spent until you evolve," so this is where that promise is
	## kept. Mirrors the one place Charge must NOT be reset, for the opposite
	## faction identity: Tempest banks across evolution, Wilds resets on it.
	lost_molt = false
	## A GRANTED Molt (Second Skin) is printed to last "until it next dies or
	## evolves" — this is the "or evolves" half. The new printed card gets to
	## decide for itself whether it has Molt; it does not inherit a borrowed one.
	granted_molt = false
	## Ferocity stacks are history, same as earth_grown and hp_grown above — a
	## grown value resets when the printed card underneath it changes, and
	## Molt's copy-construction is the one place that rule is deliberately
	## broken (GameState._kill), not this one.
	ferocity_stacks = 0
	judgment_spent = false                   ## new printed card, new charge
	## `charge` is deliberately NOT reset here. It is the third thing to survive
	## evolution, after attached energy and the Tool, and for the same reason:
	## without it, evolving destroys the investment, so the correct play for the
	## one faction whose resource is time would be never to evolve. The VALUE
	## carries and the RATE comes from the new card via kw_value(), which is what
	## makes evolving Tempest's rate increase. Guarded by TempestTest.
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
