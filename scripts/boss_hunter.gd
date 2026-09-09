extends RefCounted

# Variant-specific behavior; attack queues and warnings remain shared in Boss.

func hunter_velocity(boss, game, e: Dictionary, toward: Vector2) -> Vector2:
	var distance: float = e.p.distance_to(game.player)
	# Retreat when crowded, approach a distant player, strafe at weapon range.
	var direction := toward*clampf((distance-260.0)/100.0,-1.4,1.0)
	direction += toward.orthogonal()*e.orbit_side*0.8
	var interior := Rect2(Vector2(game.rooms[1].position)*game.TILE,Vector2(game.rooms[1].size)*game.TILE).grow(-65.0)
	if not interior.has_point(e.p+direction.normalized()*75.0):
		direction = e.p.direction_to(interior.get_center())*1.5+direction*0.3
	return direction.normalized()*boss.HUNTER_SPEED

func summon(boss, game, e: Dictionary) -> void:
	var adds := 0
	for enemy in game.enemies:
		if enemy.kind < 3 and enemy.hp > 0: adds += 1
	var count := mini(2+boss.tier(game),8)
	for i in range(mini(count,24-adds)):
		var p: Vector2 = e.p + Vector2.from_angle(TAU*i/count+e.shots)*100
		if game.cells.get(game.tile(p),-1) != 1 or not game.walkable(p) or p.distance_to(game.player) < 96: continue
		var kind := i%2
		boss.pending_summons.append({"p":p,"kind":kind,"hp":game.enemy_health(kind,game.floor_number),"room":1,
			"active":false,"searching":true,"notice":0.65,"turn_speed":2.4,"cd":0.6,
			"charge":0.0,"stun":0.0,"dir":Vector2.from_angle(TAU*i/count),"push":Vector2.ZERO})

func advance(boss, game, e: Dictionary, delta: float, toward: Vector2) -> Vector2:
	e.pressure_cd -= delta
	if e.pressure_cd <= 0:
		for i in range(3): boss.queue_aimed(e,0.45+i*0.20,3+2*mini(boss.tier(game)/3,1),0.10,210.0)
		e.pressure_cd = 0.85+1.4/boss.rate_scale(game)
	e.summon_cd -= delta
	if e.summon_cd <= 0:
		boss.summon(game,e)
		e.summon_cd = boss.SUMMON_INTERVAL/boss.rate_scale(game)
	if e.cd <= 0:
		var count := 1 + mini(boss.tier(game),4)
		for i in range(count):
			var aim := toward.rotated((i-(count-1)*0.5)*0.24)
			boss.add_laser(e.p,game.attack_end(e.p,aim,1100.0),0.8,0.35,e)
		e.cd = 2.7/boss.rate_scale(game)
		e.shots += 1
		e.orbit_side *= -1.0
	# Hold still while the line is being announced so its safe side is stable.
	for beam in boss.lasers:
		if beam.owner == e and beam.warning > 0: return Vector2.ZERO
	return boss.hunter_velocity(game,e,toward)
