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
	game.floor_number = 5
	var seen := {}
	for seed_value in range(30):
		game.rng.seed = seed_value
		game.new_floor()
		seen[game.boss_variant] = true
	check(seen.size() == 3, "seeded random selection covers all three bosses")
	for variant in range(3):
		game.new_floor(variant)
		var start: Vector2 = game.enemies[0].p
		game._physics_process(1.0/60)
		check(game.bullets.is_empty() and game.boss.lasers.is_empty(), "no boss attacks before entry")
		game.player = game.center(Vector2i(3,1))
		game.grace = 999
		for frame in range(300): game._physics_process(1.0/60)
		check(not game.pending_respawn and game.time_left == 0, "all variants have no deadline")
		if variant == 1:
			check(game.enemies[0].p != start, "hunter moves")
			check(game.enemies.any(func(e): return e.kind == 0) and game.enemies.any(func(e): return e.kind == 1), "hunter summons both enemy types")
		else:
			check(game.enemies[0].p == start, "turrets and halo core remain fixed")
		game.restart_attempt()
		check(game.boss_variant == variant and game.enemies == game.initial_enemies and game.boss.lasers.is_empty(), "retry keeps selected variant and resets encounter")
		for e in game.enemies: game.hurt_enemy(e,999999,Vector2.RIGHT)
		game._physics_process(1.0/60)
		check(game.stairs_unlocked and game.enemies.is_empty() and game.boss.lasers.is_empty(), "defeat clears threats and unlocks stairs")
	game.new_floor(1)
	var owner: Dictionary = game.enemies[0]
	game.player = owner.p + Vector2(100,0)
	game.grace = 0
	game.boss.add_laser(owner.p,owner.p+Vector2(300,0),0.8,0.35,owner)
	game.boss.advance_lasers(game,0.4)
	check(not game.pending_respawn, "warning line is harmless")
	game.boss.advance_lasers(game,0.4)
	check(not game.pending_respawn, "warning gets its full duration")
	game.boss.advance_lasers(game,0.016)
	check(game.pending_respawn, "live beam hits its visible segment")
	game.restart_attempt()
	owner = game.enemies[0]
	game.player = owner.p + Vector2(100,40)
	game.grace = 0
	game.boss.add_laser(owner.p,owner.p+Vector2(300,0),0,0.35,owner)
	game.boss.advance_lasers(game,0.016)
	check(not game.pending_respawn, "beside beam is safe")
	var baseline := {}
	for depth in [5,25]:
		game.floor_number = depth
		for variant in range(3):
			game.new_floor(variant)
			game.discovered[1] = true
			owner = game.enemies[0]
			owner.active = true
			owner.cd = 0
			game.boss.enemy_velocity(game,owner,1.0/60,Vector2.RIGHT)
			var count: int = game.boss.lasers.size() if variant == 1 else game.bullets.size()
			if depth == 5: baseline[variant] = count
			else: check(count > baseline[variant], "higher floors increase attack quantity")
			if variant == 0:
				for b in game.bullets: check(is_equal_approx(b.v.length(),235.0), "turret straight bullet speed fixed")
			if variant == 2:
				for b in game.bullets: check(is_equal_approx(b.v.length(),190.0), "halo aimed bullet speed fixed")
	for depth in [5,10,25,45]:
		game.floor_number = depth
		game.new_floor(0)
		var previous := 0.0
		var initial_density := 0.0
		for alive in range(6,0,-1):
			game.restart_attempt()
			for i in range(alive,6): game.enemies[i].hp = 0
			owner = game.enemies[0]
			game.boss.fire(game,owner,Vector2.RIGHT)
			var density: float = alive*game.bullets.size()/owner.cd
			check(density > previous, "turret losses intensify total fire at every tier")
			if alive == 6: initial_density = density
			if alive == 1: check(density >= initial_density*6.0, "final turret keeps sixfold overall intensity")
			previous = density
	game.floor_number = 25
	game.new_floor(1)
	game.player = game.spawn_point
	owner = game.enemies[0]
	for i in range(20):
		game.boss.summon(game,owner)
		game.enemies.append_array(game.boss.pending_summons)
		game.boss.pending_summons.clear()
	check(game.enemies.size() <= 25, "summons remain bounded")
	game.new_floor(2)
	owner = game.enemies[0]
	owner.shots = 1
	owner.cd = 0
	game.boss.enemy_velocity(game,owner,0.016,Vector2.RIGHT)
	check(game.bullets.size() == 28, "halo radial burst grows by tier")
	for b in game.bullets: check(is_equal_approx(b.v.length(),165.0), "radial speed fixed")
	for variant in range(3):
		game.floor_number = 45
		game.new_floor(variant)
		game.player = game.center(Vector2i(3,1))
		game.grace = 999
		for enemy in game.enemies: enemy.active = true
		if variant == 0:
			for i in range(1,6): game.enemies[i].hp = 0
		var peak := 0
		var started := Time.get_ticks_usec()
		for frame in range(600):
			game._physics_process(1.0/60)
			peak = maxi(peak,game.bullets.size())
		check(game.enemies.size() <= 25 and not game.pending_respawn, "high-tier simulation completes with bounded summons")
		print("HIGH TIER %d: peak bullets %d / mean physics %.3fms" % [variant,peak,(Time.get_ticks_usec()-started)/600000.0])
	print("PASS: all boss variants, random selection, movement, summons, lasers, retry, defeat and quantity scaling")
	game.free()
	quit(1 if failures else 0)
