extends SceneTree
## Repeatable practice-build orbit: damage budget, not a human difficulty rating.
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var live: bool = "--live" in OS.get_cmdline_user_args()
	var game = load("res://main.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	game.depth_view.set_process(false)
	for depth in [20,40,50]:
		for side in [-1,1]:
			game.practice.variant = 2
			game.practice.depth = depth
			game.practice.start(game)
			game.rng.seed = 19045
			game.discovered[1] = true
			game.sub_weapon = 0
			var e: Dictionary = game.enemies[0]
			game.player = e.p+Vector2(-390,0)
			game.build_flow()
			var elapsed := 0.0
			var exposed := 0
			var maximum := 0
			for frame in range(3600):
				game.grace = 0.0 if live else 2.0
				var radial: Vector2 = e.p.direction_to(game.player)
				var movement: Vector2 = radial.orthogonal()*side-radial*(game.player.distance_to(e.p)-390)/65.0
				game.replay_input = {"movement":movement,"aim":-radial,"primary":frame > 0,"secondary":frame > 0}
				game._physics_process(1.0/60)
				if game.bullets.any(func(b: Dictionary) -> bool: return b.hostile and b.p.distance_squared_to(game.player) < 30*30): exposed += 1
				maximum = maxi(maximum,game.bullets.size())
				elapsed = (frame+1)/60.0
				if game.stairs_unlocked or game.pending_respawn: break
			print("ORBIT floor=%d side=%d clear=%s seconds=%.2f bullet_exposure=%.2fs peak=%d" % [depth,side,game.stairs_unlocked,elapsed,exposed/60.0,maximum])
			if game.pending_respawn:
				var nearest := INF
				for b in game.bullets:
					if b.hostile: nearest = minf(nearest,b.p.distance_to(game.player))
				print("ORBIT HIT nearest_bullet=%.2f" % nearest)
	game.free()
	quit()
