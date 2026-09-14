extends SceneTree

const Scenario = preload("res://tools/dev_scenario.gd")
var failures := 0

func _initialize() -> void:
	call_deferred("run")

func snapshot(game) -> PackedByteArray:
	return var_to_bytes([Scenario.digest(game), game.effects_rng.state, game.particles,
		game.effects, game.damage_labels, game.discovered, game.camera_pos,
		game.time_left, game.main_cd, game.sub_cd, game.grace, game.choices,
		game.paused, game.choosing, game.title_screen, game.replay_input])

func check(ok: bool, message: String) -> void:
	if not ok:
		push_error("FAIL: " + message)
		failures += 1

func run() -> void:
	if DisplayServer.get_name() == "headless":
		printerr("View state test requires a display renderer")
		quit(2)
		return
	var game = load("res://main.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	game.set_process_unhandled_input(false)
	for scenario in ["normal19", "halo45"]:
		Scenario.configure(game, scenario, 19045, 0)
		for frame in range(120):
			Scenario.input_frame(game, frame)
			game._physics_process(1.0 / 60.0)
		for state in range(7):
			game.sub_weapon = state % 3
			game.paused = state == 3
			game.choosing = state == 4
			game.choices.assign([0, 1, 2])
			game.title_screen = state >= 5
			game.practice.selecting = state == 6
			var before := snapshot(game)
			game.queue_redraw()
			await process_frame
			await RenderingServer.frame_post_draw
			check(snapshot(game) == before, "render leaves simulation and effects unchanged: %s/%d" % [scenario, state])
	game.replay_input = {"cursor": Vector2(800, 500), "movement": Vector2.LEFT, "primary": true, "secondary": false}
	game.player = Vector2(120, 70)
	game.camera_pos = Vector2(100, 50)
	var expected: Vector2 = (game.screen_to_world(Vector2(800,500))-game.player).normalized()
	check(game.controls.aim(game).is_equal_approx(expected), "aim includes camera lag and screen center")
	check(game.controls.movement(game) == Vector2.LEFT and game.controls.primary(game) and not game.controls.secondary(game), "replay overrides input devices")
	game.replay_input.aim = Vector2.DOWN
	check(game.controls.aim(game) == Vector2.DOWN, "explicit replay aim takes priority")
	game.free()
	if failures == 0: print("PASS: world/HUD rendering is read-only and shared input coordinates agree")
	quit(1 if failures else 0)
