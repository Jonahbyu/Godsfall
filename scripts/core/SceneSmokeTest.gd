extends SceneTree

## Instantiates every screen headlessly to catch UI runtime errors that the
## rules harness can't see.
##   godot --headless --script res://scripts/core/SceneSmokeTest.gd

const SCENES := [
	"res://scenes/MainMenu.tscn",
	"res://scenes/DeckSelect.tscn",
	"res://scenes/DeckBuilder.tscn",
	"res://scenes/Combat.tscn",
]


func _initialize() -> void:
	## Make sure the autoloads are populated before any screen touches them.
	var db = root.get_node_or_null("CardDB")
	if db != null and db._cards.is_empty():
		db._load()
	var ds = root.get_node_or_null("DeckStore")
	if ds != null:
		## Never write the player's real save file from a test run.
		ds.use_sandbox_path("smoke")
		if ds.deck.is_empty():
			ds.deck = ds.default_deck()

	var failed := 0
	print("\n=== Scene smoke test ===\n")

	for path in SCENES:
		var packed := load(path)
		if packed == null:
			print("  FAIL could not load %s" % path)
			failed += 1
			continue
		var inst = packed.instantiate()
		if inst == null:
			print("  FAIL could not instantiate %s" % path)
			failed += 1
			continue
		root.add_child(inst)
		## Let _ready() and any deferred calls run.
		await process_frame
		await process_frame
		## A screen that built nothing means its script failed to attach or
		## _ready() bailed — that is a failure, not a pass.
		if inst.get_child_count() == 0:
			print("  FAIL %s built 0 child nodes (script error?)" % path)
			failed += 1
			inst.queue_free()
			await process_frame
			continue
		print("  ok   %s (%d child nodes)" % [path, inst.get_child_count()])
		inst.queue_free()
		await process_frame

	print("\n%s\n" % ("all scenes loaded" if failed == 0 else "%d scene(s) failed" % failed))
	quit(1 if failed > 0 else 0)
