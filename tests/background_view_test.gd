extends SceneTree
const Scenario = preload("res://tools/dev_scenario.gd")
const Background = preload("res://scripts/background_style.gd")
var failures := 0

func _initialize() -> void: call_deferred("run")

func check(ok: bool, message: String) -> void:
	if not ok:
		push_error("FAIL: "+message)
		failures += 1

func run() -> void:
	if DisplayServer.get_name() == "headless":
		printerr("Background view test requires a display renderer")
		quit(2)
		return
	var game = load("res://main.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	game.set_process_unhandled_input(false)
	DirAccess.make_dir_recursive_absolute("res://docs/validation/background")
	var seen: Array = []
	for seed_value in range(19045,19077):
		Scenario.configure(game,"normal19",seed_value,1)
		game.set_depth_view(true)
		var palette := Background.palette(game)
		if seen.has(palette): continue
		seen.append(palette)
		game.camera_pos = game.center(game.rooms[1].get_center())
		game.banner = 0
		var before := var_to_bytes([Scenario.digest(game),game.effects_rng.state,game.discovered])
		game.depth_view.sync(game)
		var lower: MultiMesh = game.depth_view.batches.bg_lower
		check(lower.visible_instance_count > 0,"visible room has a decorative lower layer")
		for index in range(lower.visible_instance_count):
			var origin := lower.get_instance_transform(index).origin
			var belongs_to_floor := false
			for offset in [Vector2.ZERO,Vector2(0.1,0),Vector2(-0.1,0),Vector2(0,0.1),Vector2(0,-0.1)]:
				var cell: Vector2i = game.tile(Vector2(origin.x,-origin.y)+offset)
				belongs_to_floor = belongs_to_floor or game.cells.has(cell)
			check(belongs_to_floor,"decorative lower faces remain within the floor footprint")
		await process_frame
		await RenderingServer.frame_post_draw
		check(before == var_to_bytes([Scenario.digest(game),game.effects_rng.state,game.discovered]),"background render preserves simulation and both random streams")
		root.get_texture().get_image().save_png("res://docs/validation/background/palette-%d.png" % seen.size())
		# Rendering the lower trays must actually change the floor image.
		var with_lower: Image = game.depth_view.viewport.get_texture().get_image()
		var count := lower.visible_instance_count
		lower.visible_instance_count = 0
		await process_frame
		await RenderingServer.frame_post_draw
		var without_lower: Image = game.depth_view.viewport.get_texture().get_image()
		check(with_lower.get_data() != without_lower.get_data(),"lower structure is visible through the floor")
		lower.visible_instance_count = count
		game.discovered[2] = true
		check(Background.palette(game) == palette,"discovering rooms does not reroll colors")
		game.restart_attempt()
		game.depth_view.sync(game)
		check(Background.palette(game) == palette,"retry keeps the floor palette")
		check(game.depth_view.batches.bg_lower.visible_instance_count == count,"retry preserves decoration layout while restoring hidden colors")
		if seen.size() == Background.PAIRS.size(): break
	check(seen.size() == 4,"different floor seeds cover all four two-color palettes")
	game.free()
	if failures == 0: print("PASS: four palettes, visible lower layer, discovery/retry cleanup and RNG isolation")
	quit(1 if failures else 0)
