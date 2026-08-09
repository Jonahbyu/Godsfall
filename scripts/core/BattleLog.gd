class_name BattleLog
extends RefCounted

## Appends a one-block record of a finished game to `logs/battles.log`.
##
## This exists for **balance analysis after the fact**, not for debugging. Every
## balance number in the design docs is currently a single AI sample someone read
## off the console and typed into a table by hand; a file that accumulates across
## runs turns "Toll Engine feels strong" into something countable.
##
## What each record holds, and why:
##
## | Field | Why it's here |
## |---|---|
## | Both deck names | A damage table is meaningless without the matchup |
## | Winner and round | The headline balance number — who wins, how fast |
## | Throne HP, both sides | How *close* the loss was; 95/100 and 5/100 are different games |
## | Tower HP + max, all 4 | Whether towers survived, and how far tower support inflated them |
## | Damage per card | Which cards actually did the work, split unit/tower/throne |
## | Tower fire total | Large in long games, and belongs to no card, so it is counted apart |
##
## The file is **append-only and never rotated**. It is plain text a human (or
## Claude) reads end to end, and a run is a few dozen lines — losing history to
## rotation would defeat the point of accumulating it.

const LOG_PATH := "res://logs/battles.log"
const EXPORT_LOG_PATH := "user://battles.log"


## Where the log is written. `res://logs/` in the editor, `user://` in an
## exported build.
##
## The split is forced by the export, not chosen: `res://` lives inside the
## packed `.pck` and is **read-only** once exported, and on Web it isn't a real
## filesystem path at all. Keeping `res://logs/` under the editor is what
## matters for the workflow — the balance log, the error log, and the design
## docs all sit together in the project folder, and that is where they are read
## from. An exported build has no such folder, so it falls back to `user://`,
## which on Web is browser storage.
static func log_path() -> String:
	return LOG_PATH if OS.has_feature("editor") else EXPORT_LOG_PATH


## Append `gs` as one record. `tag` names what produced it — "RulesTest",
## "Combat" — so harness noise can be told apart from real games when reading.
##
## Never raises: a balance log that can break a game or fail a test suite is
## worse than no log at all, so a write failure is silently skipped.
static func record(gs, tag: String = "") -> void:
	var text := format(gs, tag)
	var path := log_path()

	# `globalize_path` only means anything for `res://` under the editor. On an
	# exported build it returns a path that may not exist, so `user://` is passed
	# to FileAccess as-is and Godot resolves it.
	if path.begins_with("res://"):
		path = ProjectSettings.globalize_path(path)
		DirAccess.make_dir_recursive_absolute(path.get_base_dir())

	var f := FileAccess.open(path, FileAccess.READ_WRITE)
	if f == null:
		f = FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return
	f.seek_end()
	f.store_string(text)
	f.close()


## The record as a string. Split out from `record` so tests can assert on the
## content without touching the filesystem.
static func format(gs, tag: String = "") -> String:
	var s := "\n" + "=".repeat(72) + "\n"
	var stamp := Time.get_datetime_string_from_system()
	s += "%s%s\n" % [stamp, ("  [%s]" % tag) if tag != "" else ""]

	var n0: String = gs.deck_names[0]
	var n1: String = gs.deck_names[1]
	s += "%s  vs  %s\n" % [n0, n1]

	if gs.finished and gs.winner >= 0:
		s += "Result: %s wins on round %d\n" % [gs.deck_names[gs.winner], gs.turn]
	else:
		## A stall is the single most important thing this file can capture —
		## it is the one failure mode that makes a game formally unwinnable.
		s += "Result: NO WINNER — stalled at round %d\n" % gs.turn

	s += "-".repeat(72) + "\n"
	for i in 2:
		var p = gs.players[i]
		s += "%s (%s)\n" % [gs.deck_names[i], p.display_name]
		s += "  throne %d / %d\n" % [max(0, p.throne_hp), p.throne_max_hp]
		for bi in p.boards.size():
			var b = p.boards[bi]
			var state := "%d / %d" % [max(0, b.tower_hp), b.tower_max_hp]
			if not b.tower_alive():
				state = "DESTROYED (max was %d)" % b.tower_max_hp
			s += "  tower %d: %s%s\n" % [
				bi + 1, state,
				("  +%d dmg" % b.tower_damage_bonus) if b.tower_damage_bonus > 0 else ""
			]
		s += "  tower fire dealt: %d\n" % gs.tower_damage_dealt[i]

	s += "-".repeat(72) + "\n"
	s += "Damage by card (unit / tower / throne, total):\n"
	for i in 2:
		s += "  %s\n" % gs.deck_names[i]
		var rows := _ranked(gs.damage_by_card[i])
		if rows.is_empty():
			s += "    (no card damage dealt)\n"
		for r in rows:
			s += "    %-28s %5d  (%d / %d / %d over %d hits)\n" % [
				r["name"], r["total"], r["unit"], r["tower"], r["throne"], r["hits"]
			]
	return s


## Card damage rows, biggest total first. Ties broken by name so a diff between
## two runs is stable rather than reordering on every write.
static func _ranked(table: Dictionary) -> Array:
	var rows: Array = []
	for id in table:
		var e: Dictionary = table[id]
		var total: int = int(e["unit"]) + int(e["tower"]) + int(e["throne"])
		var card = CardDB.get_card(id)
		rows.append({
			"name": card.name if card != null else id,
			"total": total,
			"unit": int(e["unit"]),
			"tower": int(e["tower"]),
			"throne": int(e["throne"]),
			"hits": int(e["hits"]),
		})
	rows.sort_custom(func(a, b):
		if a["total"] != b["total"]:
			return a["total"] > b["total"]
		return a["name"] < b["name"]
	)
	return rows
