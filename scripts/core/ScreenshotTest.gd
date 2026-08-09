extends SceneTree

## Renders the combat screen with a representative board and saves a PNG so the
## card layout can be inspected without launching the editor.
##   godot --path <proj> --script res://scripts/core/ScreenshotTest.gd
## (must run WITHOUT --headless: headless has no rendering device)

const OUT := "user://combat_shot.png"


func _initialize() -> void:
	var db = root.get_node_or_null("CardDB")
	if db != null and db._cards.is_empty():
		db._load()
	var ds = root.get_node_or_null("DeckStore")
	if ds != null:
		## Never write the player's real save file from a test run.
		ds.use_sandbox_path("screenshot")
		if ds.deck.is_empty():
			ds.deck = ds.default_deck()

	root.content_scale_size = Vector2i(1600, 1000)

	var combat = load("res://scenes/Combat.tscn").instantiate()
	root.add_child(combat)
	await process_frame
	await process_frame

	var gs = combat.gs
	var you = gs.players[0]
	var foe = gs.players[1]
	var UnitC = load("res://scripts/core/Unit.gd")

	## Stage a board that shows every card state at once.
	var a = UnitC.new(db.get_card("carrion_crawler"))   ## Basic, Toll + Decay
	a.attached = 1
	you.boards[0].place(a, 0)

	var b = UnitC.new(db.get_card("nithogg_root_gnawer"))  ## Stage 1, evolved
	b.attached = 3
	b.hp = 60
	you.boards[0].place(b, 1)

	var c = UnitC.new(db.get_card("hel_queen"))         ## Stage 2, big cost
	c.attached = 7
	you.boards[1].place(c, 0)

	var d = UnitC.new(db.get_card("charnel_colossus"))  ## two attacks
	d.attached = 2
	you.boards[1].place(d, 1)

	var e = UnitC.new(db.get_card("thornshade"))
	foe.boards[0].place(e, 0)
	var f = UnitC.new(db.get_card("grave_tide"))
	f.hp = 40
	foe.boards[1].place(f, 1)

	you.pool = 9
	combat._refresh()

	for i in 6:
		await process_frame

	var img := root.get_texture().get_image()
	img.save_png(OUT)
	print("saved %s  (%dx%d)" % [ProjectSettings.globalize_path(OUT), img.get_width(), img.get_height()])
	quit(0)
