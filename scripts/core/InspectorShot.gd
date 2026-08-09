extends SceneTree

## Renders the deck builder — the plain screen, then the card inspector open on
## several cards — so the layout can be checked without launching the editor.
##   godot --path <proj> --script res://scripts/core/InspectorShot.gd
## (must run WITHOUT --headless: headless has no rendering device)
##
## Shoots cards that stress different parts of the panel: a 1-attack Basic, a
## 2-attack Stage 2 at the top of a three-stage line, a Rise card, and the
## energy card.

const CARDS := ["grave_whelp", "hel_queen", "thornshade", "hollow_servant", "hel_energy"]


func _initialize() -> void:
	var db = root.get_node_or_null("CardDB")
	if db != null and db._cards.is_empty():
		db._load()
	var ds = root.get_node_or_null("DeckStore")
	if ds != null:
		## Never write the player's real save file from a test run.
		ds.use_sandbox_path("inspectorshot")
		if ds.deck.is_empty():
			ds.deck = ds.default_deck()

	root.content_scale_size = Vector2i(1600, 1000)

	var builder = load("res://scenes/DeckBuilder.tscn").instantiate()
	root.add_child(builder)
	for i in 8:
		await process_frame

	await _shoot("user://builder_grid.png")

	for id in CARDS:
		builder._open_inspector(db.get_card(id))
		for i in 6:
			await process_frame
		await _shoot("user://inspector_%s.png" % id)

	quit(0)


func _shoot(path: String) -> void:
	var img := root.get_texture().get_image()
	img.save_png(path)
	print("saved %s  (%dx%d)" % [
		ProjectSettings.globalize_path(path), img.get_width(), img.get_height()
	])
