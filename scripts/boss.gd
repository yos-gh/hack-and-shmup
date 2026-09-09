extends RefCounted

var siege = preload("res://scripts/boss_siege.gd").new()
var hunter = preload("res://scripts/boss_hunter.gd").new()
var halo = preload("res://scripts/boss_halo.gd").new()

const TURRETS := 6
const GUIDED_SPEED := 130.0
const GUIDED_TURN_RATE := 2.8
const HUNTER_SPEED := 180.0
const SUMMON_INTERVAL := 5.5 / 3.0

# Keep dense volleys in lobes, with wide gaps independent of bullet count.
func fan_angle(index: int, count: int) -> float:
	return siege.fan_angle(self,index,count)

func radial_angle(index: int, count: int) -> float:
	return halo.radial_angle(self,index,count)

# Indexed by surviving turrets minus one. Per-turret volleys grow, with caps.
const VOLLEY_COUNTS := [13, 8, 5, 3, 2, 1]
const MAX_VOLLEY_COUNTS := [22,16,12,9,6,4]
const SHOT_INTERVALS := [0.7, 0.95, 1.2, 1.5, 1.8, 2.1]
const NAMES := ["SIEGE ARRAY", "VECTOR HUNTER", "HALO ENGINE"]
const COLORS := [Color("d996ed"), Color("78dbea"), Color("ffc46b")]
var lasers: Array[Dictionary] = []
var pending_summons: Array[Dictionary] = []
var salvos: Array[Dictionary] = []
var options: Array[Dictionary] = []
var turret_gap := 0.0

func turret_positions(game) -> Array[Vector2i]:
	# Different tactical routes, all with generous spacing and an entry buffer.
	var formations := [
		[Vector2i(8,-6),Vector2i(20,-6),Vector2i(8,1),Vector2i(20,1),Vector2i(8,8),Vector2i(20,8)],
		[Vector2i(6,-6),Vector2i(14,-4),Vector2i(22,-6),Vector2i(6,8),Vector2i(14,6),Vector2i(22,8)],
		[Vector2i(6,-5),Vector2i(12,-7),Vector2i(20,-5),Vector2i(23,2),Vector2i(17,8),Vector2i(8,7)],
		[Vector2i(14,-7),Vector2i(6,-3),Vector2i(22,-3),Vector2i(6,6),Vector2i(22,6),Vector2i(14,9)]]
	var formation: Array = formations[game.rng.randi_range(0,3)]
	var mirror: bool = game.rng.randi_range(0,1) == 1
	var shift := Vector2i(game.rng.randi_range(-1,1),0)
	var positions: Array[Vector2i] = []
	for point: Vector2i in formation:
		positions.append(Vector2i(28-point.x if mirror else point.x,point.y)+shift)
	return positions

func reset() -> void:
	lasers.clear()
	pending_summons.clear()
	salvos.clear()
	options.clear()
	turret_gap = 0.0

func tier(game) -> int:
	return clampi(int(game.floor_number / 5) - 1,0,8)

func rate_scale(game) -> float:
	return 1.0 + tier(game)*0.1

func build_layout(data) -> void:
	data.rooms.assign([Rect2i(-12,-4,9,9), Rect2i(0,-10,28,22)])
	data.room_shapes.assign([0,0])
	for i in range(2):
		var room: Rect2i = data.rooms[i]
		for y in range(room.position.y,room.end.y):
			for x in range(room.position.x,room.end.x): data.cells[Vector2i(x,y)] = i
	data.connect_rooms(0,1)
	data.room_links.append(Vector2i(0,1))
	data.goal_room = 1
	data.spawn_point = data.center(data.rooms[0].get_center())
	data.stairs = data.center(data.rooms[1].get_center())
	data.entrances[1] = [data.center(Vector2i(0,0)),data.center(Vector2i(0,1))]
	# About ten seconds of accurate sustained MG fire in total, leaving room
	# for dodging and repositioning within a roughly 20-30 second encounter.
	var hp: float = maxf(8.0, data.power * minf(data.fire_rate / 0.09,60.0) * 1.6)
	if data.boss_variant == 1: hp *= 0.72
	var positions := turret_positions(data)
	if data.boss_variant != 0: positions = [Vector2i(14,1)]
	for i in range(positions.size()):
		data.enemies.append({"p":data.center(positions[i]),"kind":3,"hp":hp if data.boss_variant == 0 else hp*TURRETS,"room":1,
			"active":false,"searching":false,"notice":0.65,"turn_speed":2.4,
			"cd":0.8+i*0.22,"charge":0.0,"stun":0.0,"dir":Vector2.LEFT,
			"push":Vector2.ZERO,"shots":i % 2,"summon_cd":1.0,"pressure_cd":1.1,"orbit_side":1.0,"laser_cd":2.0})
	data.boss_max_hp = hp * TURRETS
	data.time_limit = 0.0
	data.route_seconds = 0.0
	data.player = data.spawn_point
	data.build_flow()

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
	siege.fire(self,game,e,toward)

func queue_aimed(e: Dictionary, delay: float, count: int, spacing: float, speed: float) -> void:
	var offsets := PackedFloat32Array()
	for i in range(count): offsets.append((i-(count-1)*0.5)*spacing)
	salvos.append({"owner":e,"delay":delay,"offsets":offsets,"speed":speed,"aim":Vector2.ZERO})

func emit_salvo(game, salvo: Dictionary) -> void:
	var owner: Dictionary = salvo.owner
	var origin: Vector2 = salvo.get("origin",owner.p)
	var aim: Vector2 = salvo.aim
	if aim == Vector2.ZERO: aim = origin.direction_to(game.player)
	for offset in salvo.offsets:
		game.emit_shot(origin,aim.rotated(offset),salvo.speed,1,true,1200)
		game.bullets[-1]["pressure"] = salvo.speed > 120.0

func warning(e: Dictionary) -> float:
	var value := clampf(1.0-e.cd/0.6,0.0,1.0)
	for salvo in salvos:
		if salvo.owner == e and not salvo.has("origin"):
			value = maxf(value,clampf(1.0-salvo.delay/0.45,0.0,1.0))
	return value

func option_warning(option: Dictionary) -> float:
	var charge := 0.0
	for salvo in salvos:
		if salvo.owner == option.owner and salvo.get("origin",Vector2.INF) == option.p:
			charge = maxf(charge,clampf(1.0-salvo.delay/0.7,0.0,1.0))
	return charge

func hunter_velocity(game, e: Dictionary, toward: Vector2) -> Vector2:
	return hunter.hunter_velocity(self,game,e,toward)

func enemy_velocity(game, e: Dictionary, delta: float, toward: Vector2) -> Vector2:
	match game.boss_variant:
		0: return siege.advance(self,game,e,delta,toward)
		1: return hunter.advance(self,game,e,delta,toward)
	return halo.advance(self,game,e,delta,toward)

func fire_halo(game, e: Dictionary, toward: Vector2) -> void:
	halo.fire_halo(self,game,e,toward)

func advance_attacks(game, delta: float) -> void:
	turret_gap = maxf(0.0,turret_gap-delta)
	for option in options: option.life -= delta
	options = options.filter(func(option: Dictionary) -> bool: return option.life > 0 and option.owner.hp > 0)
	for salvo in salvos:
		salvo.delay -= delta
		if salvo.delay <= 0 and salvo.owner.hp > 0: emit_salvo(game,salvo)
	salvos = salvos.filter(func(salvo: Dictionary) -> bool: return salvo.delay > 0 and salvo.owner.hp > 0)
	advance_lasers(game,delta)

func deploy_options(game, e: Dictionary, phase: int) -> void:
	halo.deploy_options(self,game,e,phase)

func summon(game, e: Dictionary) -> void:
	hunter.summon(self,game,e)

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
