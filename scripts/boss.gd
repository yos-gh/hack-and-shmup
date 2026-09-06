extends RefCounted

const TURRETS := 6
const GUIDED_SPEED := 150.0
const GUIDED_TURN_RATE := 2.8
const HUNTER_SPEED := 180.0
const SUMMON_INTERVAL := 5.5 / 3.0

# Keep dense volleys in lobes, with wide gaps independent of bullet count.
func fan_angle(index: int, count: int) -> float:
	if count < 9: return (index-(count-1)*0.5)*0.20
	var left_count := int(ceil(count*0.5))
	if index < left_count:
		return lerpf(-1.2,-0.28,float(index)/maxi(left_count-1,1))
	return lerpf(0.28,1.2,float(index-left_count)/maxi(count-left_count-1,1))

func radial_angle(index: int, count: int) -> float:
	# Four 54-degree clusters separated by persistent 36-degree corridors.
	var sector := index % 4
	var local_index := index / 4
	var local_count := (count-1-sector)/4+1
	return sector*TAU/4.0 + lerpf(-0.47,0.47,float(local_index)/maxi(local_count-1,1))
# Indexed by surviving turrets minus one. Total fire density rises at each loss.
const VOLLEY_COUNTS := [13, 8, 5, 3, 2, 1]
const SHOT_INTERVALS := [0.7, 0.95, 1.2, 1.5, 1.8, 2.1]
const NAMES := ["SIEGE ARRAY", "VECTOR HUNTER", "HALO ENGINE"]
const COLORS := [Color("d996ed"), Color("78dbea"), Color("ffc46b")]
var lasers: Array[Dictionary] = []
var pending_summons: Array[Dictionary] = []

func reset() -> void:
	lasers.clear()
	pending_summons.clear()

func tier(game) -> int:
	return clampi(int(game.floor_number / 5) - 1,0,8)

func rate_scale(game) -> float:
	return 1.0 + tier(game)*0.1

func build(game) -> void:
	game.rooms.assign([Rect2i(-12,-4,9,9), Rect2i(0,-10,28,22)])
	game.room_shapes.assign([0,0])
	for i in range(2):
		var room: Rect2i = game.rooms[i]
		for y in range(room.position.y,room.end.y):
			for x in range(room.position.x,room.end.x): game.cells[Vector2i(x,y)] = i
	game.connect_rooms(0,1)
	game.room_links.append(Vector2i(0,1))
	game.goal_room = 1
	game.spawn_point = game.center(game.rooms[0].get_center())
	game.stairs = game.center(game.rooms[1].get_center())
	game.entrances[1] = [game.center(Vector2i(0,0)),game.center(Vector2i(0,1))]
	# About ten seconds of accurate sustained MG fire in total, leaving room
	# for dodging and repositioning within a roughly 20-30 second encounter.
	var hp: float = maxf(8.0, game.power * minf(game.fire_rate / 0.09,60.0) * 1.6)
	var positions := [Vector2i(8,-6),Vector2i(18,-6),Vector2i(23,1),Vector2i(18,8),Vector2i(8,8),Vector2i(5,1)]
	if game.boss_variant != 0: positions = [Vector2i(14,1)]
	for i in range(positions.size()):
		game.enemies.append({"p":game.center(positions[i]),"kind":3,"hp":hp if game.boss_variant == 0 else hp*TURRETS,"room":1,
			"active":false,"searching":false,"notice":0.65,"turn_speed":2.4,
			"cd":0.8+i*0.22,"charge":0.0,"stun":0.0,"dir":Vector2.LEFT,
			"push":Vector2.ZERO,"shots":i % 2,"summon_cd":1.0,"laser_cd":2.0,"waypoint":0})
	game.initial_enemies = game.enemies.duplicate(true)
	game.boss_max_hp = hp * TURRETS
	game.floor_start_kills = game.kills
	game.time_limit = 0.0
	game.route_seconds = 0.0
	game.player = game.spawn_point
	game.build_flow()
	game.restart_attempt()

func remaining(game) -> int:
	var count := 0
	for e in game.enemies:
		if e.kind == 3 and e.hp > 0: count += 1
	return count

func health(game) -> float:
	var hp := 0.0
	for e in game.enemies:
		if e.kind == 3: hp += maxf(0.0,e.hp)
	return hp

func fire(game, e: Dictionary, toward: Vector2) -> void:
	var stage := clampi(remaining(game),1,TURRETS)-1
	var guided: bool = e.shots % 2 == 1
	var count: int = VOLLEY_COUNTS[stage] * (1 + mini(tier(game),3))
	for i in range(count):
		var offset := fan_angle(i,count)
		var aim := toward.rotated(offset)
		game.emit_shot(e.p,aim,GUIDED_SPEED if guided else 235.0,1,true,1200)
		if guided:
			game.bullets[-1]["homing_time"] = 1.0
			game.bullets[-1]["turn_rate"] = GUIDED_TURN_RATE
			game.bullets[-1]["guided"] = true
			# Prevent homing from collapsing both lobes into the central gap.
			game.bullets[-1]["homing_offset"] = offset if count >= 9 else 0.0
	e.shots += 1
	e.cd = SHOT_INTERVALS[stage]/rate_scale(game)

func enemy_velocity(game, e: Dictionary, delta: float, toward: Vector2) -> Vector2:
	if game.boss_variant == 0:
		if e.cd <= 0: fire(game,e,toward)
		return Vector2.ZERO
	if game.boss_variant == 1:
		e.summon_cd -= delta
		if e.summon_cd <= 0:
			summon(game,e)
			e.summon_cd = SUMMON_INTERVAL/rate_scale(game)
		if e.cd <= 0:
			var count := 1 + mini(tier(game),4)
			for i in range(count):
				var aim := toward.rotated((i-(count-1)*0.5)*0.24)
				add_laser(e.p,game.attack_end(e.p,aim,1100.0),0.8,0.35,e)
			e.cd = 2.7/rate_scale(game)
			e.shots += 1
		# Hold still while the line is being announced so its safe side is stable.
		for beam in lasers:
			if beam.owner == e and beam.warning > 0: return Vector2.ZERO
		var points := [Vector2i(7,-4),Vector2i(21,-4),Vector2i(21,6),Vector2i(7,6)]
		var destination: Vector2 = game.center(points[e.waypoint])
		if e.p.distance_to(destination) < 12:
			e.waypoint = (e.waypoint+1)%points.size()
		return e.p.direction_to(destination)*HUNTER_SPEED
	e.laser_cd -= delta
	if e.laser_cd <= 0:
		var count := 1 + mini(tier(game)/2,3)
		for i in range(count):
			var lane: int = (e.shots+i)%4
			var a: Vector2
			var b: Vector2
			if lane < 2:
				var y := -3 if lane == 0 else 5
				a = game.center(Vector2i(1,y)); b = game.center(Vector2i(26,y))
			else:
				var x := 8 if lane == 2 else 20
				a = game.center(Vector2i(x,-9)); b = game.center(Vector2i(x,10))
			add_laser(a,b,0.95,1.1,e)
		e.laser_cd = 5.0/rate_scale(game)
	if e.cd <= 0:
		var radial: bool = e.shots % 2 == 1
		var count := 12+tier(game)*4 if radial else 5+tier(game)*2
		for i in range(count):
			var aim := Vector2.from_angle(radial_angle(i,count)) if radial else toward.rotated(fan_angle(i,count)*0.65)
			game.emit_shot(e.p,aim,165.0 if radial else 190.0,1,true,1200)
		e.shots += 1
		e.cd = 1.65/rate_scale(game)
	return Vector2.ZERO

func summon(game, e: Dictionary) -> void:
	var adds := 0
	for enemy in game.enemies:
		if enemy.kind < 3 and enemy.hp > 0: adds += 1
	var count := mini(2+tier(game),8)
	for i in range(mini(count,24-adds)):
		var p: Vector2 = e.p + Vector2.from_angle(TAU*i/count+e.shots)*100
		if game.cells.get(game.tile(p),-1) != 1 or not game.walkable(p) or p.distance_to(game.player) < 96: continue
		var kind := i%2
		pending_summons.append({"p":p,"kind":kind,"hp":game.enemy_health(kind,game.floor_number),"room":1,
			"active":false,"searching":true,"notice":0.65,"turn_speed":2.4,"cd":0.6,
			"charge":0.0,"stun":0.0,"dir":Vector2.from_angle(TAU*i/count),"push":Vector2.ZERO})

func add_laser(a: Vector2, b: Vector2, warning: float, duration: float, owner: Dictionary) -> void:
	lasers.append({"a":a,"b":b,"warning":warning,"duration":duration,"owner":owner})

func advance_lasers(game, delta: float) -> void:
	for beam in lasers:
		if beam.owner.hp <= 0: beam.duration = 0; continue
		if beam.warning > 0:
			beam.warning = maxf(0.0,beam.warning-delta)
			continue
		beam.duration -= delta
		if beam.duration > 0:
			var nearest := Geometry2D.get_closest_point_to_segment(game.player,beam.a,beam.b)
			if nearest.distance_to(game.player) < 6.0+game.PLAYER_HIT_RADIUS: game.die()
	lasers = lasers.filter(func(beam: Dictionary) -> bool: return beam.duration > 0)

func draw_lasers(game) -> void:
	for beam in lasers:
		if beam.owner.hp <= 0: continue
		if beam.warning > 0:
			game.draw_line(beam.a,beam.b,Color(1,0.45,0.35,0.65),1.5)
		else:
			game.draw_line(beam.a,beam.b,Color(1,0.35,0.25,0.35),12)
			game.draw_line(beam.a,beam.b,Color("ffe2c9"),4)
