extends RefCounted
## Shared deterministic combat driver for balance measurements and regression tests.
const Catalog = preload("res://scripts/combat_catalog.gd")

func configure(game, depth: int, build: String, variant: int, weapon: int) -> void:
	game.start_run()
	game.floor_number = depth
	# Exactly depth-1 legal cards. These fixed policies isolate builds from card draw luck.
	for i in range(depth - 1):
		var sequence: Array = [0, 1, 3, 2]
		if build == "primary": sequence = [0, 1, 0, 1, 3, 2]
		elif build == "sub": sequence = [6, 7, 0, 3, 2]
		var card: int = sequence[i % sequence.size()]
		if not game.session.run.can_upgrade(card): card = [0, 3, 1, 2][i % 4]
		game.apply_upgrade(card)
	game.rng.seed = 19045
	game.new_floor(variant)
	game.sub_weapon = weapon
	game.player = game.center(Vector2i(2,1)) if game.boss_floor else game.entrances[1][0]
	game.discovered[1] = true
	game.camera_pos = game.player
	game.build_flow()

func drive(game, frame: int, protected: bool, scatter_distance: float = 120.0) -> void:
	var target: Dictionary = {}
	var distance := INF
	# Prioritize the boss, but the real projectile/area rules still allow summons to intercept.
	for enemy in game.enemies:
		if enemy.hp <= 0 or (game.boss_floor and enemy.kind != Catalog.Enemy.BOSS): continue
		var candidate: float = game.player.distance_to(enemy.p)
		if candidate < distance: target = enemy; distance = candidate
	if target.is_empty(): return
	var aim: Vector2 = game.player.direction_to(target.p)
	var desired: float = [scatter_distance, game.SHOCK_RADIUS * 0.75, 220.0][game.sub_weapon]
	var movement := Vector2.ZERO
	if distance > desired + 15: movement = aim
	elif distance < desired - 25: movement = -aim
	# Normal trial includes basic orbiting/evasion; no invulnerability or retries counted as success.
	if not protected:
		movement += aim.orthogonal() * 0.65
		for bullet in game.bullets:
			if bullet.hostile and bullet.p.distance_to(game.player) < 65:
				movement += bullet.p.direction_to(game.player) * 1.5
	if not game.walkable(game.player + movement.normalized() * 24, game.PLAYER_HIT_RADIUS): movement = -movement
	if protected: game.grace = 2.0
	game.replay_input = {"movement":movement,"aim":aim,"primary":frame > 0,"secondary":frame > 0}

func measure(game, depth: int, build: String, variant: int, weapon: int, protected: bool, frames: int = 2100, scatter_distance: float = 120.0) -> Dictionary:
	configure(game, depth, build, variant, weapon)
	var total_hp: float = game.boss_max_hp if game.boss_floor else 0.0
	var max_bullets := 0
	var max_adds := 0
	var samples: Array[float] = []
	var outcome := "timeout"
	var elapsed := 0.0
	for frame in range(frames):
		drive(game, frame, protected, scatter_distance)
		var start := Time.get_ticks_usec()
		game._physics_process(1.0/60.0)
		samples.append((Time.get_ticks_usec()-start)/1000.0)
		elapsed = (frame + 1) / 60.0
		max_bullets = maxi(max_bullets, game.bullets.size())
		var adds := 0
		for enemy in game.enemies:
			if Catalog.is_mob(enemy.kind): adds += 1
		max_adds = maxi(max_adds, adds)
		if game.pending_respawn: outcome = "death"; break
		if (game.boss_floor and game.stairs_unlocked) or game.choosing: outcome = "clear"; break
		if not game.boss_floor and game.enemies.all(func(e): return e.room != 1): outcome = "room_clear"; break
	samples.sort()
	return {"depth":depth,"build":build,"boss":variant,"weapon":weapon,"protected":protected,"power":game.power,"rate":game.fire_rate,"recharge":game.session.run.recharge,"hp":total_hp,"outcome":outcome,"seconds":elapsed,"remaining_hp":game.boss.health(game) if game.boss_floor else 0.0,"kills":game.kills,"max_bullets":max_bullets,"max_mobs":max_adds,"cpu_p95_ms":samples[mini(samples.size()-1,ceili(samples.size()*0.95)-1)]}
