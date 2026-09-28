extends SceneTree
func _initialize() -> void: call_deferred("run")
func capture(game, name: String, overview: bool = false) -> void:
	if overview and not game.enemies.is_empty(): game.camera_pos = game.enemies[0].p
	game.depth_view.sync(game)
	game.queue_redraw()
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://docs/validation/seraph-%s.png" % name)
func run() -> void:
	var game = load("res://main.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	for depth in [20,40,50]:
		game.practice.variant = 2
		game.practice.depth = depth
		game.practice.start(game)
		game.set_depth_view(true)
		game.discovered[1] = true
		var e: Dictionary = game.enemies[0]
		game.player = e.p+Vector2(-380,40)
		game.camera_pos = game.player
		game.build_flow()
		game.banner = 0
		for frame in range(1920):
			game.grace = 2
			game.replay_input = {"movement":Vector2.ZERO,"aim":game.player.direction_to(e.p),"primary":false,"secondary":false}
			game._physics_process(1.0/60.0)
			if frame == 60: await capture(game,"%d-body" % depth,true)
			if frame == 175: await capture(game,"%d-needle-warning" % depth,true)
			if frame == 225: await capture(game,"%d-needle-burst" % depth,true)
			if frame == 420: await capture(game,"%d-spiral" % depth,true)
			if frame == 570: await capture(game,"%d-weave" % depth,true)
			if frame == 960: await capture(game,"%d-player-view" % depth)
			if frame == 850:
				e.hp = e.max_hp*0.4
				await capture(game,"%d-reverse" % depth,true)
		game.player = e.cover_points[0]+Vector2(-65,0)
		e.eviction_cd = 0
		game.boss.seraph.advance(game.boss,game,e,0.1,Vector2.ZERO)
		await capture(game,"%d-eviction" % depth,true)
		game.set_depth_view(false)
		await capture(game,"%d-2d" % depth,true)
	game.practice.open(game)
	game.practice.variant = 2
	game.menus.sync()
	await capture(game,"practice-menu")
	game.free()
	print("PASS: Seraph body, three motifs, laser, cover strike and practice rendered")
	quit()
