extends Node

## Autoload: Tutorial
##
## Owns the tutorial session: which lesson is running, which step it is on, and
## which lessons the player has finished. `Combat` asks this object what is
## allowed and what to highlight; everything else in the game ignores it.
##
## The whole feature is inert unless `active` is true. Every hook `Combat` calls
## returns the permissive answer when no lesson is running, so the ordinary game
## path is unchanged by construction rather than by care.
##
## Progress lives in its own file, NOT in `user://decks.json`. A corrupt tutorial
## state must never be able to take the player's deck collection with it — the
## decision log already carries two data-loss bugs caused by sharing a write path.

signal step_changed()
signal lesson_finished()

const SAVE_PATH := "user://tutorial.json"

## Overridable so harnesses never write the player's real progress file. Same
## reasoning as `DeckStore.save_path`, and for the same reason: a test that shares
## a mutable file with the user is a data-loss bug.
var save_path: String = SAVE_PATH

var active: bool = false
var lesson: Dictionary = {}
var step_index: int = 0

## Lesson ids the player has completed. A Dictionary used as a set.
var completed: Dictionary = {}

## Set by Combat when a lesson battle is running, so predicates can read the
## live game. Null in the deckbuilding lesson, which has no battle.
var gs = null

## Recorded when a lesson starts so `unit_healed` and friends can spot a change
## rather than an absolute value.
var _baseline: Dictionary = {}


func _ready() -> void:
	_load()


# ------------------------------------------------------------------ progress

func _load() -> void:
	completed = {}
	if not FileAccess.file_exists(save_path):
		return
	var f := FileAccess.open(save_path, FileAccess.READ)
	if f == null:
		return
	var raw := f.get_as_text()
	f.close()
	var parsed = JSON.parse_string(raw)
	if typeof(parsed) != TYPE_DICTIONARY:
		return
	var done = parsed.get("completed", [])
	if typeof(done) != TYPE_ARRAY:
		return
	for id in done:
		completed[String(id)] = true


func _save() -> void:
	var f := FileAccess.open(save_path, FileAccess.WRITE)
	if f == null:
		return
	f.store_string(JSON.stringify({"completed": completed.keys()}))
	f.close()


## Point progress at a scratch file. Harnesses MUST call this before touching
## anything that writes.
func use_sandbox_path(tag: String) -> void:
	save_path = "user://test_tutorial_%s.json" % tag
	completed = {}


func is_complete(id: String) -> bool:
	return completed.has(id)


func completed_count() -> int:
	var n := 0
	for l in TutorialData.lessons():
		if completed.has(l.get("id", "")):
			n += 1
	return n


func all_complete() -> bool:
	return completed_count() >= TutorialData.lesson_count()


func mark_complete(id: String) -> void:
	if id == "":
		return
	completed[id] = true
	_save()


func reset_progress() -> void:
	completed = {}
	_save()


# --------------------------------------------------------------- the session

## Begin a lesson. `Combat` (or `DeckBuilder`, for the deckbuilding lesson) reads
## `lesson` on _ready and configures itself from it.
func begin(lesson_id: String) -> bool:
	var l := TutorialData.lesson_by_id(lesson_id)
	if l.is_empty():
		return false
	lesson = l
	step_index = 0
	active = true
	gs = null
	_baseline = {}
	return true


## Leave the tutorial. Called on quitting a lesson and on finishing one, so no
## tutorial state can survive into an ordinary game.
func end() -> void:
	active = false
	lesson = {}
	step_index = 0
	gs = null
	_baseline = {}


func lesson_id() -> String:
	return String(lesson.get("id", ""))


func lesson_title() -> String:
	return String(lesson.get("title", ""))


func steps() -> Array:
	return lesson.get("steps", [])


func step_count() -> int:
	return steps().size()


func step() -> Dictionary:
	var s := steps()
	if step_index < 0 or step_index >= s.size():
		return {}
	return s[step_index]


func is_last_step() -> bool:
	return step_index >= step_count() - 1


## True when this lesson runs in the deck builder rather than in combat.
func is_builder_lesson() -> bool:
	return bool(lesson.get("builder", false))


## Advance one step. Emits `lesson_finished` instead when the last step is done,
## which is what marks the lesson complete.
func advance() -> void:
	if not active:
		return
	if is_last_step():
		mark_complete(lesson_id())
		lesson_finished.emit()
		return
	step_index += 1
	_capture_baseline()
	step_changed.emit()


func go_back() -> void:
	if not active or step_index <= 0:
		return
	step_index -= 1
	_capture_baseline()
	step_changed.emit()


# ---------------------------------------------------------------- the hooks
#
# Everything below is what `Combat` calls. All of them answer permissively when
# no lesson is running.

## May the player take this action right now?
##
## A step's `allow` list names the legal actions. An ABSENT list means everything
## is legal — that is the default so a step only has to think about gating when
## it actually wants to. An EMPTY list means nothing is, which is what pure
## exposition steps want.
func allows(action: String) -> bool:
	if not active:
		return true
	var s := step()
	if s.is_empty():
		return true
	if not s.has("allow"):
		return true
	return String(action) in (s.get("allow", []) as Array)


## The widget this step wants ringed, or {} for none.
func highlight() -> Dictionary:
	if not active:
		return {}
	return step().get("highlight", {})


## The nudge shown when a gated action is refused. Deliberately never silent —
## a click that does nothing reads as a bug.
func blocked_hint() -> String:
	if not active:
		return ""
	return "Not part of this step — follow the coach, or press Skip step."


# ------------------------------------------------------------- the predicates

## Is the current step's completion condition met?
##
## Evaluated against the REAL GameState, so a step advances because the rules
## engine agrees the thing happened — never because a click was counted. That is
## what keeps a lesson honest when the engine changes underneath it.
func step_satisfied() -> bool:
	if not active:
		return false
	var s := step()
	if s.is_empty():
		return false
	var cond := String(s.get("advance", ""))
	if cond == "":
		return false        ## exposition — advances on Next only
	if gs == null:
		return false
	return _eval(cond)


func _eval(cond: String) -> bool:
	var p = _me()
	if p == null:
		return false

	## `key>=n` — the only operator form, kept deliberately small.
	if cond.contains(">="):
		var parts := cond.split(">=")
		var key := parts[0].strip_edges()
		var want := int(parts[1].strip_edges())
		return _metric(key, p) >= want

	match cond:
		"playing":
			return not gs.in_setup()
		"played_energy":
			return p.energy_played_this_turn
		"selected_my_unit":
			## Satisfied by the UI, which reports selection through `note()`.
			return _baseline.get("selected", false)
		"hand_has_retreated":
			return not p.locked.is_empty()
		"unit_healed":
			return _baseline.get("healed", false)
		_:
			return false


## Numeric metrics for the `key>=n` form.
func _metric(key: String, p) -> int:
	match key:
		"unit_count":
			return p.all_units().size()
		"attached":
			var n := 0
			for u in p.all_units():
				n = max(n, u.attached)
			return n
		"queued":
			var n := 0
			for u in p.all_units():
				if u.queued_attack != null:
					n += 1
			return n
		"round":
			return gs.turn
		"stage":
			var best := 0
			for u in p.all_units():
				if u.card != null:
					best = max(best, int(u.card.stage))
			return best
		"pool":
			return p.pool
		_:
			return 0


func _me():
	if gs == null:
		return null
	return gs.players[0]


## The UI reports things the rules engine does not model — a selection, a heal it
## just applied — so a predicate can read them. Kept to the few cases where the
## GameState genuinely holds no evidence the action happened.
func note(key: String, value = true) -> void:
	if not active:
		return
	_baseline[key] = value


func _capture_baseline() -> void:
	_baseline = {}
