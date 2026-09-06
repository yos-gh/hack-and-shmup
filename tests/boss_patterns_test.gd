extends SceneTree
var failures := 0
func _initialize() -> void:
	call_deferred("run")
func check(ok: bool, message: String) -> void:
	if not ok:
		push_error("FAIL: "+message)
		failures += 1
func run() -> void:
	var game = load("res://main.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	game.title_screen = false
	game.floor_number = 15
	game.new_floor(1)
	var owner: Dictionary = game.enemies[0]
	game.player = owner.p+Vector2(120,0)
	var close_velocity: Vector2 = game.boss.hunter_velocity(game,owner,Vector2.RIGHT)
	check(close_velocity.x < 0, "hunter retreats from close player")
	game.player = owner.p+Vector2(360,0)
	var far_velocity: Vector2 = game.boss.hunter_velocity(game,owner,Vector2.RIGHT)
	check(far_velocity.x > 0, "hunter closes distant player")
	game.player = owner.p+Vector2(260,0)
	var orbit_velocity: Vector2 = game.boss.hunter_velocity(game,owner,Vector2.RIGHT)
	check(absf(orbit_velocity.y) > 170 and absf(orbit_velocity.x) < 1, "hunter strafes at fighting distance")
	owner.p = game.center(Vector2i(26,1))
	game.player = owner.p-Vector2(120,0)
	check(game.boss.hunter_velocity(game,owner,Vector2.LEFT).x < 0, "hunter steers away from arena edge")
	game.new_floor(0)
	owner = game.enemies[0]
	for i in range(1,6): game.enemies[i].hp = 0
	owner.shots = 2
	game.boss.fire(game,owner,Vector2.RIGHT)
	check(game.boss.salvos.size() == 1, "last turret adds delayed anti-camping burst")
	game.bullets.clear()
	game.player = owner.p+Vector2(0,200)
	game.boss.advance_attacks(game,0.44)
	check(game.bullets.is_empty(), "anti-camping burst provides warning")
	game.boss.advance_attacks(game,0.02)
	check(game.bullets.size() == 3 and game.bullets[1].v.normalized().dot(Vector2.DOWN) > 0.999, "triplet targets updated player position")
	game.new_floor(2)
	owner = game.enemies[0]
	owner.shots = 0
	game.boss.fire_halo(game,owner,Vector2.RIGHT)
	game.bullets.clear()
	game.player = owner.p+Vector2(0,-200)
	game.boss.advance_attacks(game,0.23)
	check(game.bullets.any(func(b): return b.v.normalized().dot(Vector2.UP) > 0.999), "stream re-aims each fan")
	game.boss.reset()
	game.bullets.clear()
	owner.shots = 2
	game.boss.fire_halo(game,owner,Vector2.RIGHT)
	game.bullets.clear()
	game.boss.advance_attacks(game,0.36)
	check(game.bullets.all(func(b): return b.v.x > 0), "pincer stays locked to initial aim")
	for b in game.bullets: check(absf(b.v.angle()) > 0.20, "pincer preserves traversable center")
	check(game.boss.lasers.is_empty(), "halo no longer creates lasers")
	owner.hp = 0
	game.bullets.clear()
	game.boss.advance_attacks(game,2.0)
	check(game.bullets.is_empty() and game.boss.salvos.is_empty(), "dead owner cancels queued fire")
	game.restart_attempt()
	check(game.boss.salvos.is_empty(), "retry clears attack sequences")
	# Use real bullet motion/collision: camping loses, moving across the aimed
	# stream survives. Disable the core's other attacks to isolate this choice.
	for move in [false,true]:
		game.floor_number = 5
		game.new_floor(2)
		owner = game.enemies[0]
		owner.active = true
		owner.cd = 99
		game.discovered[1] = true
		game.player = owner.p+Vector2(-260,0)
		game.grace = 0
		game.boss.fire_halo(game,owner,Vector2.LEFT)
		for frame in range(150):
			if move and frame < 65: game.player += Vector2(0,-game.SPEED/60.0)
			game._physics_process(1.0/60)
			if game.pending_respawn: break
		check(game.pending_respawn != move, "aimed stream punishes camping and permits lateral dodge")
	# Probe eight former camping directions, using the full encounter updates.
	for variant in [0,2]:
		for direction in range(8):
			game.floor_number = 15
			game.new_floor(variant)
			owner = game.enemies[0]
			owner.p = game.center(Vector2i(14,1))
			owner.active = true
			owner.cd = 0.6
			owner.shots = 2 if variant == 0 else 0
			if variant == 0:
				for i in range(1,6): game.enemies[i].hp = 0
			game.player = owner.p+Vector2.from_angle(direction*TAU/8)*240.0
			game.discovered[1] = true
			game.grace = 0
			for frame in range(360):
				game._physics_process(1.0/60)
				if game.pending_respawn: break
			check(game.pending_respawn, "no stationary safe angle around turret or halo")
	if failures == 0: print("PASS: reactive movement, anti-camping fire, streaming, pincer gaps, cleanup and real dodge choice")
	game.free()
	quit(1 if failures else 0)
