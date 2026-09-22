extends SceneTree
func _initialize() -> void: call_deferred("run")
func capture(game, name: String) -> void:
	game.depth_view.sync(game)
	game.queue_redraw()
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://docs/validation/bastion-%s.png" % name)
func run() -> void:
	var game = load("res://main.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	for depth in [25,50]:
		game.practice.variant = 4
		game.practice.depth = depth
		game.practice.start(game)
		game.set_depth_view(true)
		game.discovered[1] = true
		var e: Dictionary = game.enemies[0]
		game.player = e.p+Vector2(-300,0)
		game.build_flow()
		game.banner = 0
		var seen_orb := false
		var seen_charge := false
		var seen_flight := false
		var seen_missile := false
		var seen_missile_flight := false
		var seen_impact := false
		for frame in range(1000):
			game.grace = 2
			game.replay_input = {"movement":Vector2.ZERO,"aim":Vector2.RIGHT,"primary":false,"secondary":false}
			game._physics_process(1.0/60.0)
			if frame == 60: await capture(game,"%d-arena" % depth)
			if not seen_orb and game.bullets.any(func(b): return b.get("energy_orb",false)):
				seen_orb = true
				await capture(game,"%d-orb" % depth)
			if not seen_charge and game.bullets.any(func(b): return b.get("energy_orb",false) and b.orb_phase == "charge" and b.orb_radius >= 48):
				seen_charge = true
				await capture(game,"%d-orb-charged" % depth)
			if not seen_flight and game.bullets.any(func(b): return b.get("energy_orb",false) and b.orb_phase == "flight" and b.v.length() >= 280):
				seen_flight = true
				await capture(game,"%d-orb-flight" % depth)
			if not seen_missile and not e.slam.is_empty():
				seen_missile = true
				await capture(game,"%d-missile" % depth)
			if not seen_missile_flight and e.slam.any(func(m): return not m.fired and m.time/m.warning < 0.25):
				seen_missile_flight = true
				await capture(game,"%d-missile-flight" % depth)
			if not seen_impact and e.slam.any(func(m): return m.fired):
				seen_impact = true
				await capture(game,"%d-impact" % depth)
		if depth == 25:
			for edge in [-470,470]:
				game.player = e.p+Vector2(-300,edge)
				game.camera_pos = game.player
				await capture(game,"%d-%s" % [depth,"north" if edge < 0 else "south"])
			game.player = e.p+Vector2(-300,0)
			game.camera_pos = game.player
		game.set_depth_view(false)
		await capture(game,"%d-2d" % depth)
	game.practice.open(game)
	game.practice.variant = 4
	game.menus.sync()
	await capture(game,"practice-menu")
	game.free()
	print("PASS: bastion arena, projectile and missile frames rendered")
	quit()
