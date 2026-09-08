extends SceneTree

const Scenario = preload("res://tools/dev_scenario.gd")
var failures := 0

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, message: String) -> void:
	if not ok:
		push_error("FAIL: " + message)
		failures += 1

func state(game) -> PackedByteArray:
	return var_to_bytes([Scenario.digest(game), game.effects_rng.state, game.particles,
		game.effects, game.damage_labels, game.discovered, game.camera_pos, game.time_left])

func run() -> void:
	if DisplayServer.get_name() == "headless":
		printerr("Depth test requires a display renderer")
		quit(2)
		return
	var game = load("res://main.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	game.set_process_unhandled_input(false)
	for scenario in ["normal19", "halo45"]:
		var expected := PackedByteArray()
		for mode in range(2):
			Scenario.configure(game, scenario, 19045, 1)
			game.set_depth_view(mode == 1)
			for frame in range(120):
				Scenario.input_frame(game, frame)
				game._physics_process(1.0/60)
				if mode == 1: game.depth_view.sync(game)
			if mode == 0: expected = state(game)
			else: check(state(game) == expected, "3D synchronization preserves replay: " + scenario)
		var before := state(game)
		await process_frame
		await RenderingServer.frame_post_draw
		check(state(game) == before, "actual 3D rendering has no gameplay side effects")
	for size_value in [Vector2i(1280,800), Vector2i(960,600), Vector2i(1000,800)]:
		root.size = size_value
		await process_frame
		game.depth_view.sync(game)
		var screen: Vector2 = game.get_viewport_rect().size
		for offset in [Vector2.ZERO, Vector2(-370,-220), Vector2(410,210)]:
			var point: Vector2 = game.camera_pos+offset
			for height in [0.0, 7.0, 40.0]:
				var projected: Vector2 = game.depth_view.camera.unproject_position(game.depth_view.project_point(point, height))
				check(projected.distance_to(offset+screen*0.5) < 0.05, "orthographic position matches 2D at all tested heights/sizes")
	var node_count: int = game.depth_view.stage.get_child_count()
	for i in range(8):
		var before := state(game)
		game.set_depth_view(false)
		check(not game.depth_view.is_processing() and game.depth_view.viewport.render_target_update_mode == SubViewport.UPDATE_DISABLED, "hidden 3D renderer stops work")
		game.set_depth_view(true)
		game.depth_view.sync(game)
		check(state(game) == before and game.depth_view.stage.get_child_count() == node_count, "switching reuses renderer without state changes or node growth")
	game.restart_attempt()
	game.view_comparison = true
	var toggle := InputEventKey.new()
	toggle.keycode = KEY_F6
	toggle.pressed = true
	game._unhandled_input(toggle)
	check(not game.depth_enabled, "F6 switches to classic view")
	toggle.echo = true
	game._unhandled_input(toggle)
	check(not game.depth_enabled, "held F6 does not toggle repeatedly")
	toggle.echo = false
	game._unhandled_input(toggle)
	check(game.depth_enabled, "F6 returns to 3D view")
	game.depth_view.sync(game)
	check(game.depth_view.cached_discovery == hash(game.discovered), "retry refreshes discovery cache")
	game.floor_number = 19
	game.new_floor()
	game.depth_view.sync(game)
	check(game.depth_view.cached_floor == game.floor_revision, "new floor invalidates geometry even with equal discovery count")
	print("Depth sync max ms: ", game.depth_view.max_sync_ms, "; last floor rebuild ms: ", game.depth_view.last_rebuild_ms)
	game.free()
	if failures == 0: print("PASS: 3D/2D projection, replay parity, resize, toggle reuse and floor/retry invalidation")
	quit(1 if failures else 0)
