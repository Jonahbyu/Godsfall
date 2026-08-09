class_name Board
extends RefCounted

## One board: a 3-slot lane. The tower occupies slot 2 until it dies.
## Slots do NOT compact — a dead unit leaves a permanent hole.

const SLOT_COUNT := 3
const TOWER_SLOT := 2

var slots: Array = [null, null, null]   ## Array[Unit or null]
var tower_hp: int = 50
var tower_max_hp: int = 50

## The permanent tower supports on this tower, in the order they were played.
## There is no cap: a tower may hold any number, including repeats of the same
## card, and their effects stack. One-shots (Rebuild, Open the Gate) never enter
## this list. All are lost when the tower dies — they do not transfer to the
## other tower and do not return to hand.
##
## The 4-copy deck limit is the only bound on stacking. See CLAUDE.md's stall
## note: if fortification ever gets oppressive the dial is a deck-level cap on
## how many permanent tower supports a list may run, not a per-tower slot.
var tower_mods: Array = []   ## Array[CardData]

## Bonus damage from a permanent modification (Murder Holes).
var tower_damage_bonus: int = 0

## Max HP currently granted by a Gaia Earth aura. Tracked separately from
## `tower_max_hp` because the aura is LIVE — it rises and falls as Earth units
## come and go — so the engine has to know how much of the current max came from
## it in order to take back exactly that much. Tower support bonuses are
## permanent and are deliberately NOT tracked this way.
var earth_max_hp_bonus: int = 0


func tower_alive() -> bool:
	return tower_hp > 0


## Slots a unit may be deployed into. The tower slot opens up once the tower dies.
func usable_slots() -> Array[int]:
	var out: Array[int] = []
	for i in SLOT_COUNT:
		if i == TOWER_SLOT and tower_alive():
			continue
		out.append(i)
	return out


func is_slot_playable(i: int) -> bool:
	if i < 0 or i >= SLOT_COUNT:
		return false
	if i == TOWER_SLOT and tower_alive():
		return false
	return slots[i] == null


func first_empty_slot() -> int:
	for i in usable_slots():
		if slots[i] == null:
			return i
	return -1


func units() -> Array:
	var out: Array = []
	for s in slots:
		if s != null:
			out.append(s)
	return out


func unit_at(i: int) -> Unit:
	if i < 0 or i >= SLOT_COUNT:
		return null
	return slots[i]


## The leftmost living unit on this board, or null if the board is clear.
##
## Dead units are still sitting in their slots during attack resolution —
## `_cleanup_dead` only runs once the whole volley is done — so this must test
## `is_alive()` rather than just null. That is also what enforces "no overkill":
## a unit killed earlier in the same resolution is invisible here, so a later
## attack redirects past it instead of hitting the corpse.
func leftmost_living_unit() -> Unit:
	for i in SLOT_COUNT:
		var u: Unit = slots[i]
		if u != null and u.is_alive():
			return u
	return null


## True while anything on this board is alive. Living units shield this board's
## tower and the throne behind it — see CLAUDE.md's Targeting section. Shielding
## is strictly per-board: the other board defends nothing here.
func has_living_unit() -> bool:
	return leftmost_living_unit() != null


func place(u: Unit, i: int) -> bool:
	if not is_slot_playable(i):
		return false
	slots[i] = u
	return true


func remove_at(i: int) -> Unit:
	var u: Unit = slots[i]
	slots[i] = null
	return u


func tower_take_damage(amount: int) -> int:
	var dealt: int = min(amount, tower_hp)
	tower_hp -= dealt
	if tower_hp <= 0:
		## Modifications are lost with the tower. The +HP they granted is left
		## in tower_max_hp because the tower is dead and never heals back.
		tower_mods.clear()
		tower_damage_bonus = 0
	return dealt


## Repair, capped at max HP. There is deliberately no healing above printed max —
## uncapped tower healing plus the tower's own growth is the stall engine.
func tower_heal(amount: int) -> int:
	if not tower_alive():
		return 0
	var healed: int = min(amount, tower_max_hp - tower_hp)
	if healed <= 0:
		return 0
	tower_hp += healed
	return healed


## True if this tower can still take a permanent modification. A living tower
## always can — permanents stack without limit.
func can_take_tower_mod() -> bool:
	return tower_alive()


## Every permanent mod on this tower carrying `key`. Effects stack, so callers
## that deal damage or read a value must fold across all of them rather than
## taking the first.
func mods_with(key: String) -> Array:
	var out: Array = []
	for m in tower_mods:
		if m != null and m.has_effect(key):
			out.append(m)
	return out


## Summed value of `key` across every mod on this tower.
func mod_total(key: String, def: int = 0) -> int:
	var total: int = 0
	for m in mods_with(key):
		total += m.effect_value(key, def)
	return total


func grow_tower() -> void:
	if tower_alive():
		tower_max_hp += 5
		tower_hp += 5
