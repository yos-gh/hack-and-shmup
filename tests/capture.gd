extends SceneTree
func _initialize() -> void:
	call_deferred("capture")
func capture() -> void:
	var game = load("res://main.tscn").instantiate()
	root.add_child(game)
	game.start_run()
	game.set_physics_process(false)
	game.player = game.center(game.rooms[1].get_center())
	game.camera_pos = game.player
	game.discovered[1] = true
	game.enemies[0].p = game.player + Vector2(64,0)
	game.enemies[0].hp = 100
	game.sub_weapon = 2
	game.time_left = 2.5
	game.fire_sub(Vector2.RIGHT)
	game.effects[0].life = 0.25
	game.queue_redraw()
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://docs/prototype.png")
	game.effects.clear()
	game.damage_labels.clear()
	game.sub_weapon = 0
	game.sub_cd = 0
	game.queue_redraw()
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://docs/scatter-preview.png")
	game.power = 1.7
	game.fire_rate = 1.4
	game.move_bonus = 40
	game.paused = true
	game.queue_redraw()
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://docs/pause.png")
	game.paused = false
	game.choosing = true
	game.choices.assign([0,1,2])
	game.queue_redraw()
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://docs/upgrades.png")
	game.return_to_title()
	game.queue_redraw()
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://docs/title.png")
	game.floor_number = 5
	game.new_floor(0)
	game.title_screen = false
	game.player = game.center(Vector2i(10,1))
	game.grace = 999
	game.discovered[1] = true
	for enemy in game.enemies:
		enemy.active = true
		enemy.cd = 0.2 + game.enemies.find(enemy)*0.15
	for frame in range(90): game._physics_process(1.0/60)
	game.camera_pos = game.center(game.rooms[1].get_center())
	game.queue_redraw()
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://docs/boss.png")
	for variant in [1,2]:
		game.new_floor(variant)
		game.player = game.center(Vector2i(3,1))
		game.grace = 999
		game.discovered[1] = true
		var enemy: Dictionary = game.enemies[0]
		enemy.active = true
		enemy.cd = 0
		enemy.summon_cd = 0
		enemy.laser_cd = 0
		for frame in range(60): game._physics_process(1.0/60)
		game.camera_pos = game.center(game.rooms[1].get_center())
		game.queue_redraw()
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://docs/boss-%d.png" % (variant+1))
	game.queue_free()
	await process_frame
	await process_frame
	await create_timer(0.1).timeout
	quit()
