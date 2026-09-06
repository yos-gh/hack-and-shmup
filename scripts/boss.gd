extends RefCounted

const TURRETS := 6
const GUIDED_SPEED := 150.0
const GUIDED_TURN_RATE := 2.8
# Indexed by surviving turrets minus one. Total fire density rises at each loss.
const VOLLEY_COUNTS := [13, 8, 5, 3, 2, 1]
const SHOT_INTERVALS := [0.7, 0.95, 1.2, 1.5, 1.8, 2.1]

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
	for i in range(TURRETS):
		game.enemies.append({"p":game.center(positions[i]),"kind":3,"hp":hp,"room":1,
			"active":false,"searching":false,"notice":0.65,"turn_speed":2.4,
			"cd":0.8+i*0.22,"charge":0.0,"stun":0.0,"dir":Vector2.LEFT,
			"push":Vector2.ZERO,"shots":i % 2})
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
	var count: int = VOLLEY_COUNTS[stage]
	for i in range(count):
		var aim := toward.rotated((i - (count-1)*0.5)*0.20)
		game.emit_shot(e.p,aim,GUIDED_SPEED if guided else 235.0,1,true,1200)
		if guided:
			game.bullets[-1]["homing_time"] = 1.0
			game.bullets[-1]["turn_rate"] = GUIDED_TURN_RATE
			game.bullets[-1]["guided"] = true
	e.shots += 1
	e.cd = SHOT_INTERVALS[stage]
