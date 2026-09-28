extends SceneTree
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var game = load("res://main.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	game.depth_view.set_process(false)
	var failed := false
	for depth in [5,20,40,50]:
		game.practice.variant = 2
		game.practice.depth = depth
		game.practice.start(game)
		game.rng.seed = 19045
		game.discovered[1] = true
		game.sub_weapon = 0
		var e: Dictionary = game.enemies[0]
		game.player = e.p+Vector2(-420,0)
		game.build_flow()
		var elapsed := 0.0
		for frame in range(4200):
			game.grace = 2.0
			var follow: Vector2 = e.p+Vector2.from_angle(PI+elapsed*0.24)*420-game.player
			var firing: bool = frame%180 > 0 and frame%180 <= 45
			game.replay_input = {"movement":follow if follow.length() > 8 else Vector2.ZERO,"aim":game.player.direction_to(e.p),"primary":firing,"secondary":firing}
			game._physics_process(1.0/60.0)
			elapsed = (frame+1)/60.0
			if game.stairs_unlocked: break
		print("SERAPH TIME: practice floor %d, 25%% primary + Scatter uptime, %.2fs, clear=%s" % [depth,elapsed,game.stairs_unlocked])
		if not game.stairs_unlocked or elapsed > 60:
			failed = true
			push_error("FAIL: seraph intermittent practice weapon budget")
	game.free()
	if not failed: print("PASS: seraph intermittent practice weapons clear within one minute")
	quit(1 if failed else 0)
