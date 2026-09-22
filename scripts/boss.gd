extends RefCounted

const Catalog = preload("res://scripts/combat_catalog.gd")

var fortress = preload("res://scripts/boss_fortress.gd").new()
var bastion = preload("res://scripts/boss_bastion.gd").new()
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
const NAMES := ["SIEGE ARRAY", "VECTOR HUNTER", "HALO ENGINE", "IRON CITADEL", "BASTION OF STARS"]
const COLORS := [Color("d996ed"), Color("78dbea"), Color("ffc46b"), Color("ff9470"), Color("e0a5fa")]
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
	if data.boss_variant == 3: data.rooms[1] = Rect2i(0,-17,48,36)
	if data.boss_variant == 4: data.rooms[1] = Rect2i(0,-20,32,42)
	data.room_shapes.assign([0,0])
	for i in range(2):
		var room: Rect2i = data.rooms[i]
		for y in range(room.position.y,room.end.y):
			for x in range(room.position.x,room.end.x): data.cells[Vector2i(x,y)] = i
	if data.boss_variant == 3:
		for pillar in [Vector2i(7,-11),Vector2i(7,11),Vector2i(39,-11),Vector2i(39,11)]:
			for y in range(2):
				for x in range(2): data.cells.erase(pillar+Vector2i(x,y))
	if data.boss_variant == 4:
		# The solid east wall contains the core; there is no route behind it.
		for y in range(-20,22):
			for x in range(27,32): data.cells.erase(Vector2i(x,y))
		for pillar in [Vector2i(6,-15),Vector2i(6,15),Vector2i(13,-7),Vector2i(13,6)]:
			for y in range(2):
				for x in range(2): data.cells.erase(pillar+Vector2i(x,y))
	data.connect_rooms(0,1)
	data.room_links.append(Vector2i(0,1))
	data.goal_room = 1
	data.spawn_point = data.center(data.rooms[0].get_center())
	data.stairs = data.center(data.rooms[1].get_center())
	data.entrances[1] = [data.center(Vector2i(0,0)),data.center(Vector2i(0,1))]
	# Combined primary/sub budget, fixed at generation and shared by practice mode.
	var total_hp: float = 0.0 if data.boss_variant == 4 else preload("res://scripts/combat_balance.gd").boss_health(data.power, data.fire_rate, data.recharge, data.boss_variant, data.physics_ticks, data.floor_number)
	var hp: float = total_hp / TURRETS
	var positions := turret_positions(data)
	if data.boss_variant != 0: positions = [Vector2i(14,1)]
	if data.boss_variant == 4: positions = [Vector2i(26,1)]
	for i in range(positions.size()):
		data.enemies.append({"p":data.center(positions[i]),"kind":Catalog.Enemy.BOSS,"hp":hp if data.boss_variant == 0 else hp*TURRETS,"room":1,
			"active":false,"searching":false,"notice":0.65,"turn_speed":2.4,
			"cd":0.8+i*0.22,"charge":0.0,"stun":0.0,"dir":Vector2.LEFT,
			"push":Vector2.ZERO,"shots":i % 2,"summon_cd":1.0,"pressure_cd":1.1,"orbit_side":1.0,"laser_cd":2.0})
	if data.boss_variant == 3:
		data.enemies[0].p = data.center(Vector2i(24,1))+Vector2(-240,0)
		fortress.setup(data,data.enemies[0])
	if data.boss_variant == 4: bastion.setup(data,data.enemies[0])
	data.boss_max_hp = data.enemies[0].hp if data.boss_variant in [3,4] else hp * TURRETS
	data.time_limit = 0.0
	data.route_seconds = 0.0
	data.player = data.spawn_point
	data.build_flow()

func remaining(game) -> int:
	var count := 0
	for e in game.enemies:
		if e.kind == Catalog.Enemy.BOSS and e.hp > 0: count += 1
	return count

func health(game) -> float:
	var hp := 0.0
	for e in game.enemies:
		if e.kind == Catalog.Enemy.BOSS: hp += maxf(0.0,e.hp)
	return hp

func present_siege_shot(game, e: Dictionary) -> void:
	game.enemy_attack_cue("siege_fire",e.p)

func shot_flash(game, position: Vector2) -> float:
	var flash := 0.0
	for effect in game.effects:
		if effect.kind == 4 and effect.p == position:
			flash = maxf(flash,clampf(effect.life/0.16,0,1))
	return flash

func fire(game, e: Dictionary, toward: Vector2) -> void:
	siege.fire(self,game,e,toward)

func queue_aimed(e: Dictionary, delay: float, count: int, spacing: float, speed: float) -> void:
	var offsets := PackedFloat32Array()
	for i in range(count): offsets.append((i-(count-1)*0.5)*spacing)
	salvos.append({"owner":e,"delay":delay,"offsets":offsets,"speed":speed,"aim":Vector2.ZERO})

func emit_salvo(game, salvo: Dictionary) -> void:
	var owner: Dictionary = salvo.owner
	if game.boss_variant == 0: present_siege_shot(game,owner)
	var origin: Vector2 = salvo.get("origin",owner.p)
	if game.boss_variant == 3:
		if salvo.has("gun"): origin = fortress.gun_position(owner,salvo.gun)
		game.enemy_attack_cue("siege_fire",origin)
	if game.boss_variant == 4:
		if salvo.has("gun"):
			if owner.turrets[salvo.gun].hp <= 0: return
			origin = bastion.gun_position(owner,salvo.gun)
		game.enemy_attack_cue("halo_fire",origin)
	if game.boss_variant == 2: game.enemy_attack_cue("halo_option" if salvo.has("origin") else "halo_fire",origin)
	elif game.boss_variant == 1: game.enemy_attack_cue("hunter_burst",origin)
	var aim: Vector2 = salvo.aim
	if aim == Vector2.ZERO: aim = origin.direction_to(game.player+owner.get("player_velocity",Vector2.ZERO)*salvo.get("lead",0.0))
	for offset in salvo.offsets:
		var shot_speed: float = salvo.speed*(owner.get("bullet_scale",1.0) if game.boss_variant in [3,4] else 1.0)
		game.emit_shot(origin,aim.rotated(offset),shot_speed,1,true,1200)
		game.bullets[-1]["pressure"] = salvo.speed > 120.0
		if salvo.get("guided",false):
			game.bullets[-1].merge({"guided":true,"pressure":false,"homing_time":1.15,"turn_rate":1.25},true)
		if salvo.has("pattern"):
			game.bullets[-1]["pattern"] = salvo.pattern
			if salvo.pattern == "radial": game.bullets[-1].pressure = false

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
		3: return fortress.advance(self,game,e,delta,toward)
		4: return bastion.advance(self,game,e,delta,toward)
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
	lasers.append({"a":a,"b":b,"warning":warning,"duration":duration,"peak_duration":duration,"owner":owner})

func advance_lasers(game, delta: float) -> void:
	var sounded_owners: Array = []
	for beam in lasers:
		if beam.owner.hp <= 0: beam.duration = 0; continue
		if beam.has("gun"):
			if beam.warning <= 0 and beam.has("sweep"): beam.heading = beam.heading.rotated(beam.sweep*minf(delta,beam.duration))
			beam.a = fortress.gun_position(beam.owner,beam.gun)
			beam.b = game.attack_end(beam.a,beam.heading,1800)
		if beam.warning > 0:
			beam.warning = maxf(0.0,beam.warning-delta)
			if beam.warning == 0 and game.boss_variant in [1,3] and not sounded_owners.has(beam.owner):
				game.enemy_attack_cue("hunter_fire",beam.a)
				sounded_owners.append(beam.owner)
			continue
		beam.duration -= delta
		if beam.duration > 0:
			var nearest := Geometry2D.get_closest_point_to_segment(game.player,beam.a,beam.b)
			if nearest.distance_to(game.player) < 6.0+game.PLAYER_HIT_RADIUS: game.die()
	lasers = lasers.filter(func(beam: Dictionary) -> bool: return beam.duration > 0)
