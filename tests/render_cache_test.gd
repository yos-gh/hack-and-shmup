extends SceneTree
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, message: String) -> void:
	if not ok:
		push_error("FAIL: "+message)
		failures += 1
func colors(view) -> Dictionary:
	var result := {}
	for key in view.floor_entries:
		var values := PackedColorArray()
		for i in range(view.batches[key].visible_instance_count): values.append(view.batches[key].get_instance_color(i))
		result[key] = values
	return result
func run() -> void:
	var game = load("res://main.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	game.depth_view.set_process(false)
	game.start_run()
	for seed_value in [19045,12,37,88]:
		game.rng.seed = seed_value
		game.new_floor()
		game.depth_view.sync(game)
		for room in range(1,game.rooms.size()):
			game.discovered[room] = true
			game.depth_view.refresh_discovery(game)
			var updated := colors(game.depth_view)
			game.depth_view.rebuild_floor(game)
			check(updated == colors(game.depth_view),"incremental colors match full rebuild for every batch")
		game.discovered = {0:true}
		game.depth_view.refresh_discovery(game)
		var reset := colors(game.depth_view)
		game.depth_view.rebuild_floor(game)
		check(reset == colors(game.depth_view),"retry discovery colors match full rebuild")
		for origin in [game.player,game.entrances[1][0]]:
			for radius in [0.0,1.0,3.7,25.0,61.0,99.9,game.SHOCK_RADIUS]:
				var outline: PackedVector2Array = game.world_view.shock_outline(game,origin,radius)
				for i in range(97):
					var expected: Vector2 = game.attack_end(origin,Vector2.from_angle(i*TAU/96),radius)
					check(outline[i].distance_to(expected)<0.01,"cached shockwave preserves clipped partial samples")
	game.free()
	if failures == 0: print("PASS: incremental background colors, retry reset, cached shockwave clipping parity")
	quit(1 if failures else 0)
