extends SceneTree
## Native visual/settings smoke check, also usable against the exported package.
var failures := 0
var output := ""
func _initialize() -> void: call_deferred("run")
func check(ok: bool, message: String) -> void:
	if not ok:
		push_error("FAIL: "+message)
		failures += 1
func capture(game, name: String) -> void:
	game.menus.sync()
	game.queue_redraw()
	for frame in range(8): await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(output+"/"+name+".png")
func run() -> void:
	output = OS.get_cmdline_user_args()[0] if not OS.get_cmdline_user_args().is_empty() else ProjectSettings.globalize_path("res://docs/validation")
	DirAccess.make_dir_recursive_absolute(output)
	var game = load("res://main.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	game.practice.open(game)
	await capture(game,"boss-roster")
	var buttons: Array = game.menus._buttons()
	check(buttons.size() == 9,"three bosses, four actions and both settings")
	buttons[7].pressed.emit()
	check(game.audio_mode == 2 and game.practice.selecting,"sound changes in selector without starting")
	game.menus._buttons()[7].pressed.emit()
	game.menus._buttons()[7].pressed.emit()
	check(game.audio_mode == 1,"sound cycles back to SE only")
	game.menus._buttons()[8].pressed.emit()
	await create_timer(0.3).timeout
	check(DisplayServer.window_get_mode() in [DisplayServer.WINDOW_MODE_FULLSCREEN,DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN],"selector enters fullscreen")
	await capture(game,"boss-roster-fullscreen")
	game.menus._buttons()[8].pressed.emit()
	await create_timer(0.3).timeout
	check(DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_WINDOWED,"selector returns to windowed")
	for variant in range(3):
		game.practice.variant = variant
		game.practice.depth = 25
		game.practice.start(game)
		game.discovered[1] = true
		var e: Dictionary = game.enemies[0]
		game.player = e.p+Vector2(-320,0)
		game.camera_pos = game.player
		game.banner = 0
		game.build_flow()
		for frame in range(120):
			game.grace = 2
			game.paused = false
			game.replay_input = {"movement":Vector2.ZERO,"aim":Vector2.RIGHT,"primary":false,"secondary":false}
			game._physics_process(1.0/60)
		check(game.boss_variant == variant and e.has("plates"),"selected large boss starts")
		await capture(game,"boss-roster-fight-%d" % variant)
	game.free()
	if failures == 0: print("PASS: native three-boss roster, sound/fullscreen settings and all encounters render")
	quit(1 if failures else 0)
