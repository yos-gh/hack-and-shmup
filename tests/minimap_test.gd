extends SceneTree
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, message: String) -> void:
	if not ok:
		push_error("FAIL: "+message)
		failures += 1
func snapshot(game, name: String) -> void:
	if DisplayServer.get_name() == "headless": return
	game.camera_pos = game.player
	game.queue_redraw()
	for i in range(4):
		await process_frame
		await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute("res://docs/validation/minimap")
	root.get_texture().get_image().save_png("res://docs/validation/minimap/"+name+".png")
func run() -> void:
	var game = load("res://main.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	game.start_run()
	game.rng.seed = 19045
	game.new_floor()
	var map = game.hud.minimap
	map.prepare(game)
	var rng_state: int = game.rng.state
	var panel: Rect2 = game.hud.hud_layout(Vector2(1280,800)).map
	var rect: Rect2 = map.projection(panel)
	check(panel.encloses(rect.grow(4)),"marker fits inside panel at floor edges")
	var old_texture = map.texture
	map.prepare(game)
	check(map.texture == old_texture,"stationary rendering reuses cached floor")
	check(map.active_room >= 0,"spawn room is highlighted")
	await snapshot(game,"room")
	var passage := Vector2i.ZERO
	var found := false
	for cell in game.cells:
		if game.cells[cell] == -1:
			passage = cell
			found = true
			break
	check(found,"fixture contains passage")
	check(not map.detailed(game,passage),"remote corridor is hidden before walking")
	for cell in game.cells:
		if game.cells[cell] > 0: check(not map.detailed(game,cell),"unvisited rooms remain hidden")
	game.player = game.center(passage)
	map.observe(game)
	check(map.detailed(game,passage),"walking reveals corridor detail")
	map.prepare(game)
	check(map.active_room == -1,"passage does not highlight an unrelated room")
	var p: Vector2 = map.locate(game,game.player,rect)
	var q: Vector2 = map.locate(game,game.player+Vector2(4,0),rect)
	check(q.x>p.x and is_equal_approx(q.y,p.y),"position marker moves within one tile in corridors")
	await snapshot(game,"passage")
	check(game.rng.state == rng_state,"minimap does not consume gameplay random numbers")
	game.restart_attempt()
	check(not map.detailed(game,passage),"retry resets corridor exploration")
	game.new_floor()
	map.prepare(game)
	check(is_same(map.cached_cells,game.cells),"floor reset invalidates silhouette")
	game.free()
	if failures == 0: print("PASS: minimap room, passage position, cache, reset and RNG isolation")
	quit(1 if failures else 0)
