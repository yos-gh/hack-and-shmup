extends SceneTree
var failures := 0
func _initialize() -> void:
	call_deferred("run")
func check(ok: bool, message: String) -> void:
	if not ok:
		push_error("FAIL: " + message)
		failures += 1
func run() -> void:
	var game = load("res://main.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	game.title_screen = false
	for depth in [5,10,15,20]:
		game.floor_number = depth
		game.new_floor()
		check(game.boss_floor and game.rooms.size() == 2 and game.enemies.size() == 6, "boss every fifth floor with two rooms")
		check(not game.stairs_unlocked, "stairs locked before defeat")
		for e in game.enemies:
			check(game.flow.has(game.tile(e.p)), "turret is reachable")
			check(e.p.distance_to(game.entrances[1][0]) > 96, "safe boss entry")
		check(game.flow.has(game.tile(game.stairs)), "stairs have a path")
	game._physics_process(1.0/60)
	check(not game.pending_respawn and game.time_left == 0, "boss has no time limit")
	check(game.bullets.is_empty(), "boss does not shoot before entry")
	game.player = game.stairs
	game.grace = 999
	game._physics_process(1.0/60)
	check(not game.choosing, "standing on locked stairs cannot skip boss")
	for frame in range(180): game._physics_process(1.0/60)
	check(game.bullets.any(func(b): return b.get("guided",false)), "boss fires guided bullets")
	check(game.enemies.all(func(e): return e.active), "all turrets activate after entry")
	var turret: Dictionary = game.enemies[0]
	var position: Vector2 = turret.p
	game.hurt_enemy(turret,1,Vector2.RIGHT)
	game._physics_process(1.0/60)
	check(turret.p == position and turret.push == Vector2.ZERO, "fixed turret cannot be knocked back")
	game.bullets.clear()
	game.boss.fire(game,turret,Vector2.RIGHT)
	var interval: float = turret.cd
	check(game.bullets.size() == 1, "initial single shot")
	for i in [1,2,3]: game.hurt_enemy(game.enemies[i],99999,Vector2.RIGHT)
	game.bullets.clear()
	game.boss.fire(game,turret,Vector2.RIGHT)
	check(game.bullets.size() == 5 and turret.cd < interval, "remaining turrets intensify after losses")
	var prior_density := 0.0
	for alive in range(6,0,-1):
		game.restart_attempt()
		for i in range(alive,6): game.enemies[i].hp = 0
		var shooter: Dictionary = game.enemies[0]
		shooter.shots = 1
		game.boss.fire(game,shooter,Vector2.RIGHT)
		var density: float = alive*game.bullets.size()/shooter.cd
		check(density > prior_density, "total boss fire increases with each turret loss")
		prior_density = density
		for b in game.bullets:
			check(is_equal_approx(b.v.length(),150.0) and b.turn_rate == 2.8 and b.homing_time == 1.0, "slower guided shots with stronger turning")
		if alive == 1:
			check(game.bullets.size() == 13 and density >= 6.0*(6.0/2.1), "last turret exceeds six times initial whole-boss fire density")
	game.bullets.clear()
	game.emit_shot(game.player+Vector2(0,100),Vector2.RIGHT,180,1,true)
	var shot: Dictionary = game.bullets[-1]
	shot.homing_time = 0.01
	game._physics_process(0.02)
	var heading: Vector2 = shot.v
	game.player += Vector2(0,50)
	game._physics_process(0.02)
	check(shot.homing_time == 0 and shot.v == heading, "homing stops after time window")
	game.restart_attempt()
	check(game.enemies == game.initial_enemies and not game.stairs_unlocked and game.bullets.is_empty(), "retry restores whole boss encounter")
	for e in game.enemies: game.hurt_enemy(e,99999,Vector2.RIGHT)
	game._physics_process(1.0/60)
	check(game.stairs_unlocked and game.enemies.is_empty(), "all turrets defeated unlock stairs")
	game.player = game.stairs
	game._physics_process(1.0/60)
	check(game.choosing and game.best_cleared == 20, "boss stairs offer upgrade and update record")
	game.upgrade(0)
	check(not game.boss_floor and game.rooms.size() >= 7 and game.stairs_unlocked and game.time_left > 0, "normal floor after boss")
	var e: Dictionary = game.enemies[0]
	e.active = true
	e.kind = 1
	e.cd = 0.2
	check(game.attack_warning(e) > 0, "sniper has pre-fire warning")
	e.kind = 2
	e.stun = 1.0
	check(game.attack_warning(e) == 0, "no warning during stun")
	e.stun = 0.0
	check(game.attack_warning(e) > 0, "shield has pre-charge warning")
	print("PASS: boss cadence, map, no timer, entry, projectiles, escalation, retry, victory and attack warnings")
	game.free()
	quit(1 if failures else 0)
