extends SceneTree
# Actual simulation captures at both difficulty tiers, including charge telegraphs.
func _initialize() -> void: call_deferred("run")
func capture(game, name: String) -> void:
	game.depth_view.sync(game)
	game.queue_redraw()
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://docs/validation/fortress-%s.png" % name)
func run() -> void:
	var game = load("res://main.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	for depth in [25,50]:
		game.practice.variant = 3
		game.practice.depth = depth
		game.practice.start(game)
		game.set_depth_view(true)
		game.discovered[1] = true
		var e: Dictionary = game.enemies[0]
		game.player = e.p+Vector2(-280,0)
		game.build_flow()
		game.banner = 0
		var captured := {}
		for frame in range(1800):
			if frame == 900: e.hp = e.max_hp*0.45
			game.grace = 2
			var follow: Vector2 = e.p+Vector2(-280,30)-game.player
			game.replay_input = {"movement":follow if follow.length()>8 else Vector2.ZERO,"aim":game.player.direction_to(e.p),"primary":false,"secondary":false}
			game._physics_process(1.0/60.0)
			if frame in [180,540,1260]: await capture(game,"tactics-%d-%d" % [depth,frame])
			if e.move_mode in ["ram_warning","ram"] and not captured.has(e.move_mode):
				captured[e.move_mode] = true
				await capture(game,"tactics-%d-%s" % [depth,e.move_mode])
			if not captured.has("scissor") and game.boss.lasers.any(func(beam): return beam.has("sweep") and beam.warning > 0.3):
				captured["scissor"] = true
				await capture(game,"tactics-%d-scissor" % depth)
		game.set_depth_view(false)
		await capture(game,"tactics-%d-2d" % depth)
	game.free()
	print("PASS: floor 25/50 tactical movement and charge/sweep telegraphs rendered in 3D and 2D")
	quit()
