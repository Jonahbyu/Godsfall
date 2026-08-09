extends SceneTree

## Renders the deck select screen with a few saved decks so the layout can be
## inspected without launching the editor.
##   godot --path <proj> --script res://scripts/core/DeckSelectShot.gd
## (must run WITHOUT --headless: headless has no rendering device)

const OUT := "user://deckselect_shot.png"


func _initialize() -> void:
	var db = root.get_node_or_null("CardDB")
	if db != null and db._cards.is_empty():
		db._load()

	var ds = root.get_node_or_null("DeckStore")
	## Staging a collection writes to disk — keep it off the real save.
	ds.use_sandbox_path("deckselectshot")

	## Stage a collection: a full deck, a lean one, and an illegal one.
	ds.decks = []
	ds.decks = [ds._new_entry("Toll Control", ds.default_deck())]
	ds.active_index = 0

	ds.create_deck("Whelp Rush")
	for i in 4:
		ds.add("grave_whelp")
	for i in 4:
		ds.add("carrion_crawler")
	for i in 10:
		ds.add("hel_energy")

	ds.create_deck("Unfinished Brew")
	ds.add("hel_queen")

	ds.select(0)

	root.content_scale_size = Vector2i(1600, 1000)

	var screen = load("res://scenes/DeckSelect.tscn").instantiate()
	root.add_child(screen)

	for i in 8:
		await process_frame

	var img := root.get_texture().get_image()
	img.save_png(OUT)
	print("saved %s  (%dx%d)" % [ProjectSettings.globalize_path(OUT), img.get_width(), img.get_height()])
	quit(0)
