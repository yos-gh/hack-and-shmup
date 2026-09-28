extends SceneTree
## Render real lethal-hit events at fixed ages for all boss palettes.
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var output := "res://docs/validation/boss-destruction"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
	var game = load("res://main.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	for variant in range(3):
		game.practice.variant = variant
		game.practice.depth = 25
		game.practice.start(game)
		game.discovered[1] = true
		var enemy: Dictionary = game.enemies[0]
		game.player = enemy.p+Vector2(-240,100)
		game.camera_pos = enemy.p+Vector2(-80,0)
		game.banner = 0
		game.presentation.reset()
		game.hurt_enemy(enemy,enemy.hp+1,Vector2.RIGHT,0,true)
		var last_age := 0.0
		for age in [0.06,0.28,0.65,1.1,1.5]:
			game.presentation.advance(game,age-last_age)
			last_age = age
			game.menus.sync()
			game.queue_redraw()
			for frame in range(8): await process_frame
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png(output+"/boss-%d-%03d.png" % [variant,roundi(age*100)])
		if not game.presentation.pulses.is_empty():
			push_error("FAIL: boss destruction did not expire")
			quit(1)
			return
	game.free()
	print("PASS: three real boss kills render and expire")
	quit()
