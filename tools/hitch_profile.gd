extends SceneTree
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var game = load("res://main.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	game.depth_view.set_process(false)
	preload("res://tools/dev_scenario.gd").configure(game,"normal19",19045,1)
	game.depth_view.sync(game)
	for i in range(20): await process_frame
	var results := []
	for i in range(1,mini(6,game.rooms.size())):
		game.discovered[i] = true
		var start := Time.get_ticks_usec()
		game.depth_view.sync(game)
		results.append({"room":i,"sync_ms":(Time.get_ticks_usec()-start)/1000.0,"rebuild_ms":game.depth_view.last_rebuild_ms})
	game.player = game.center(game.rooms[1].get_center())
	# Pick actual open floor, retaining the real room geometry and attack clipping.
	for cell in game.cells:
		if game.cells[cell]==1 and game.walkable(game.center(cell),20):
			game.player = game.center(cell)
			break
	game.camera_pos = game.player
	for i in range(80):
		game.enemies[i].p = game.player+Vector2.from_angle(i*TAU/80)*15
		game.enemies[i].hp = 1
		game.enemies[i].kind = 0
	var start := Time.get_ticks_usec()
	game.fire_sub(Vector2.RIGHT)
	var fire_ms := (Time.get_ticks_usec()-start)/1000.0
	var frames := []
	for i in range(24):
		for effect in game.effects: effect.life -= 1.0/60
		game.effects = game.effects.filter(func(e): return e.life>0)
		start = Time.get_ticks_usec()
		game.queue_redraw()
		await process_frame
		await RenderingServer.frame_post_draw
		frames.append((Time.get_ticks_usec()-start)/1000.0)
	print(JSON.stringify({"entry":results,"shock_fire_ms":fire_ms,"shock_frames_ms":frames}))
	game.free()
	quit()
