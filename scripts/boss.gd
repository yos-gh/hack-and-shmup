extends RefCounted

const Catalog = preload("res://scripts/combat_catalog.gd")

var fortress = preload("res://scripts/boss_fortress.gd").new()
var bastion = preload("res://scripts/boss_bastion.gd").new()
var triad = preload("res://scripts/boss_triad.gd").new()
var wyrm = preload("res://scripts/boss_wyrm.gd").new()

# Index 3 is the Abyss Wyrm, which takes every 25th floor (FloorGenerator).
const NAMES := ["IRON CITADEL", "BASTION OF STARS", "TRIAD BATTERY", "ABYSS WYRM"]
const COLORS := [Color("ff9470"), Color("e0a5fa"), Color("f7dab0"), Color("8fc8ff")]
var lasers: Array[Dictionary] = []
var salvos: Array[Dictionary] = []

func controller(variant: int):
	match variant:
		0: return fortress
		1: return bastion
		3: return wyrm
	return triad

func reset() -> void:
	lasers.clear()
	salvos.clear()

func build_layout(data) -> void:
	var arenas := [Rect2i(0,-17,48,36),Rect2i(0,-20,32,42),Rect2i(0,-19,40,40),Rect2i(0,-22,56,44)]
	data.rooms.assign([Rect2i(-12,-4,9,9),arenas[data.boss_variant]])
	data.room_shapes.assign([0,0])
	for i in range(2):
		var room: Rect2i = data.rooms[i]
		for y in range(room.position.y,room.end.y):
			for x in range(room.position.x,room.end.x): data.cells[Vector2i(x,y)] = i
	if data.boss_variant == 0:
		for pillar in [Vector2i(7,-11),Vector2i(7,11),Vector2i(39,-11),Vector2i(39,11)]:
			for y in range(2):
				for x in range(2): data.cells.erase(pillar+Vector2i(x,y))
	if data.boss_variant == 1:
		# The solid east wall contains the core; there is no route behind it.
		for y in range(-20,22):
			var front: float = data.center(Vector2i(26,1)).x+20+bastion.wall_curve(data.center(Vector2i(0,y)).y-data.center(Vector2i(26,1)).y)
			for x in range(32):
				if x*data.TILE >= front: data.cells.erase(Vector2i(x,y))
		for pillar in [Vector2i(6,-15),Vector2i(6,15),Vector2i(13,-7),Vector2i(13,6)]:
			for y in range(2):
				for x in range(2): data.cells.erase(pillar+Vector2i(x,y))
	if data.boss_variant in [2,3]:
		for pillar in (triad.COVER_CELLS if data.boss_variant == 2 else wyrm.COVER_CELLS):
			for y in range(2):
				for x in range(2): data.cells.erase(pillar+Vector2i(x,y))
	data.connect_rooms(0,1)
	data.room_links.append(Vector2i(0,1))
	data.goal_room = 1
	data.spawn_point = data.center(data.rooms[0].get_center())
	data.stairs = data.center(data.rooms[1].get_center())
	data.entrances[1] = [data.center(Vector2i(0,0)),data.center(Vector2i(0,1))]
	# Every encounter is one shielded core; each boss owns its HP scaling.
	var position := Vector2i(14,1)
	if data.boss_variant == 1: position = Vector2i(26,1)
	if data.boss_variant == 2: position = Vector2i(20,1)
	data.enemies.append({"p":data.center(position),"kind":Catalog.Enemy.BOSS,"hp":1.0,"room":1,
		"active":false,"searching":false,"notice":0.65,"turn_speed":2.4,
		"cd":0.8,"charge":0.0,"stun":0.0,"dir":Vector2.LEFT,
		"push":Vector2.ZERO,"shots":0,"laser_cd":2.0})
	if data.boss_variant == 0:
		data.enemies[0].p = data.center(Vector2i(24,1))+Vector2(-240,0)
		fortress.setup(data,data.enemies[0])
	if data.boss_variant == 1: bastion.setup(data,data.enemies[0])
	if data.boss_variant == 2: triad.setup(data,data.enemies[0])
	if data.boss_variant == 3: wyrm.setup(data,data.enemies[0])
	data.boss_max_hp = data.enemies[0].hp
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

func shot_flash(game, position: Vector2) -> float:
	var flash := 0.0
	for effect in game.effects:
		if effect.kind == 4 and effect.p == position:
			flash = maxf(flash,clampf(effect.life/0.16,0,1))
	return flash

func queue_aimed(e: Dictionary, delay: float, count: int, spacing: float, speed: float) -> void:
	var offsets := PackedFloat32Array()
	for i in range(count): offsets.append((i-(count-1)*0.5)*spacing)
	salvos.append({"owner":e,"delay":delay,"offsets":offsets,"speed":speed,"aim":Vector2.ZERO})

func emit_salvo(game, salvo: Dictionary) -> void:
	var owner: Dictionary = salvo.owner
	var origin: Vector2 = salvo.get("origin",owner.p)
	if game.boss_variant == 0:
		if salvo.has("gun"): origin = fortress.gun_position(owner,salvo.gun)
		game.enemy_attack_cue("siege_fire",origin)
	if game.boss_variant == 1:
		if salvo.has("gun"):
			if owner.turrets[salvo.gun].hp <= 0: return
			origin = bastion.gun_position(owner,salvo.gun)
		game.enemy_attack_cue("halo_fire",origin)
	if game.boss_variant == 2: game.enemy_attack_cue("halo_fire",origin)
	var aim: Vector2 = salvo.aim
	if aim == Vector2.ZERO: aim = origin.direction_to(game.player+owner.get("player_velocity",Vector2.ZERO)*salvo.get("lead",0.0))
	for offset in salvo.offsets:
		var shot_speed: float = salvo.speed*(owner.get("bullet_scale",1.0) if game.boss_variant in [0,1] else 1.0)
		game.emit_shot(origin,aim.rotated(offset),shot_speed,1,true,1200)
		game.bullets[-1]["pressure"] = salvo.speed > 120.0
		if salvo.get("guided",false):
			game.bullets[-1].merge({"guided":true,"pressure":false,"homing_time":2.4,"turn_rate":1.6},true)
		if salvo.has("pattern"):
			game.bullets[-1]["pattern"] = salvo.pattern
			if salvo.pattern in ["radial","weave"]:
				game.bullets[-1].merge({"pressure":false,"field":true})

func warning(e: Dictionary) -> float:
	var value := clampf(1.0-e.cd/0.6,0.0,1.0)
	for salvo in salvos:
		if salvo.owner == e and not salvo.has("origin"):
			value = maxf(value,clampf(1.0-salvo.delay/0.45,0.0,1.0))
	return value

func enemy_velocity(game, e: Dictionary, delta: float, toward: Vector2) -> Vector2:
	match game.boss_variant:
		0: return fortress.advance(self,game,e,delta,toward)
		1: return bastion.advance(self,game,e,delta,toward)
		2: return triad.advance(self,game,e,delta,toward)
		3: return wyrm.advance(self,game,e,delta,toward)
	return Vector2.ZERO

func advance_attacks(game, delta: float) -> void:
	for salvo in salvos:
		salvo.delay -= delta
		if salvo.delay <= 0 and salvo.owner.hp > 0: emit_salvo(game,salvo)
	salvos = salvos.filter(func(salvo: Dictionary) -> bool: return salvo.delay > 0 and salvo.owner.hp > 0)
	advance_lasers(game,delta)

func add_laser(a: Vector2, b: Vector2, warning: float, duration: float, owner: Dictionary) -> void:
	lasers.append({"a":a,"b":b,"warning":warning,"duration":duration,"peak_duration":duration,"owner":owner})

func advance_lasers(game, delta: float) -> void:
	var sounded_owners: Array = []
	for beam in lasers:
		if beam.owner.hp <= 0: beam.duration = 0; continue
		if beam.get("triad",false):
			if beam.warning <= 0:
				var desired: Vector2 = beam.owner.p.direction_to(game.player)
				beam.heading = beam.heading.rotated(clampf(angle_difference(beam.heading.angle(),desired.angle()),-beam.turn_rate*delta,beam.turn_rate*delta))
			beam.a = beam.owner.p+beam.heading*beam.get("muzzle",82.0)
			beam.b = game.attack_end(beam.a,beam.heading,1600)
		if beam.has("mount"):
			beam.a = wyrm.mount_position(beam.owner,beam.mount)
			beam.b = game.attack_end(beam.a,beam.heading,1800)
		if beam.has("gun"):
			if beam.warning <= 0 and beam.has("sweep"): beam.heading = beam.heading.rotated(beam.sweep*minf(delta,beam.duration))
			beam.a = fortress.gun_position(beam.owner,beam.gun)
			beam.b = game.attack_end(beam.a,beam.heading,1800)
		if beam.warning > 0:
			beam.warning = maxf(0.0,beam.warning-delta)
			if beam.warning == 0 and game.boss_variant in [0,2,3] and not sounded_owners.has(beam.owner):
				game.enemy_attack_cue("boss_release" if beam.get("triad",false) else "hunter_fire",beam.a)
				sounded_owners.append(beam.owner)
			continue
		beam.duration -= delta
		if beam.duration > 0:
			var nearest := Geometry2D.get_closest_point_to_segment(game.player,beam.a,beam.b)
			if nearest.distance_to(game.player) < beam.get("width",6.0)*0.5+game.PLAYER_HIT_RADIUS: game.die()
	lasers = lasers.filter(func(beam: Dictionary) -> bool: return beam.duration > 0)
	var sustained := false
	var source := Vector2.ZERO
	for beam in lasers:
		if beam.get("triad",false) and beam.warning <= 0 and beam.owner.hp > 0:
			sustained = true
			source = beam.a
			break
	game.sound.set_boss_beam(game,sustained,source)
