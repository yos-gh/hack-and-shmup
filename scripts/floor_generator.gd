extends RefCounted

const Catalog = preload("res://scripts/combat_catalog.gd")
const Data = preload("res://scripts/floor_data.gd")
const Settings = preload("res://scripts/floor_settings.gd")
const Boss = preload("res://scripts/boss.gd")

func generate(settings: Settings, seed_value: int) -> Data:
	var random := RandomNumberGenerator.new()
	random.seed = seed_value
	return generate_from_state(settings,random.state)

func generate_from_state(settings: Settings, random_state: int) -> Data:
	var data := Data.new()
	data.rng.state = random_state
	data.floor_number = settings.depth
	data.move_bonus = settings.move_bonus
	data.power = settings.power
	data.fire_rate = settings.fire_rate
	data.recharge = settings.recharge
	data.physics_ticks = settings.physics_ticks
	data.boss_floor = settings.depth % 5 == 0
	if data.boss_floor:
		data.boss_variant = data.rng.randi_range(0,2) if settings.boss_choice < 0 else clampi(settings.boss_choice,0,2)
		Boss.new().build_layout(data)
		return data
	# Scatter larger rooms without overlap, then connect a spanning tree and loops.
	var target_count: int = data.rng.randi_range(7, 10)
	for attempt in range(600):
		if data.rooms.size() >= target_count: break
		var r := Rect2i(data.rng.randi_range(-52, 52), data.rng.randi_range(-44, 44), data.rng.randi_range(18, 25), data.rng.randi_range(16, 22))
		var overlaps := false
		for other in data.rooms:
			if r.grow(5).intersects(other): overlaps = true; break
		if overlaps: continue
		data.rooms.append(r)
		var shape: int = data.rng.randi_range(0, 4)
		data.room_shapes.append(shape)
		for cy in range(r.position.y, r.end.y):
			for cx in range(r.position.x, r.end.x):
				if data.room_contains(Vector2i(cx,cy),r,shape): data.cells[Vector2i(cx,cy)] = data.rooms.size() - 1
	var connected: Array[int] = [0]
	while connected.size() < data.rooms.size():
		var best := Vector2i(-1,-1)
		var best_distance := INF
		for a in connected:
			for b in range(data.rooms.size()):
				if b in connected: continue
				var distance := Vector2(data.rooms[a].get_center()).distance_squared_to(Vector2(data.rooms[b].get_center()))
				if distance < best_distance: best_distance = distance; best = Vector2i(a,b)
		data.connect_rooms(best.x,best.y)
		data.room_links.append(best)
		connected.append(best.y)
	for extra in range(2):
		var a: int = data.rng.randi_range(0,data.rooms.size()-1)
		var b: int = data.rng.randi_range(0,data.rooms.size()-1)
		if a != b and not Vector2i(a,b) in data.room_links and not Vector2i(b,a) in data.room_links:
			data.connect_rooms(a,b)
			data.room_links.append(Vector2i(a,b))
	for i in range(data.rooms.size()):
		var r: Rect2i = data.rooms[i]
		var c := r.get_center()
		var obstacle_candidates: Array[Vector2i] = []
		for cell in data.cells:
			if data.cells[cell] == i and not data.corridor_cells.has(cell) and absi(cell.x-c.x)>2 and absi(cell.y-c.y)>2:
				obstacle_candidates.append(cell)
		for n in range(mini(18,obstacle_candidates.size())):
			var pick: int = data.rng.randi_range(0,obstacle_candidates.size()-1)
			data.cells.erase(obstacle_candidates[pick])
			obstacle_candidates.remove_at(pick)
	data.spawn_point = data.center(data.rooms[0].get_center())
	data.player = data.spawn_point
	data.build_flow()
	# Remove isolated pockets left by obstacles, before choosing enemy positions.
	for c in data.cells.keys():
		if not data.flow.has(c): data.cells.erase(c)
	data.goal_room = 1
	var longest := 0
	for i in range(1,data.rooms.size()):
		var cursor: Vector2i = data.rooms[i].get_center()
		var distance := 0
		while cursor != data.tile(data.spawn_point) and data.flow.has(cursor):
			cursor = data.flow[cursor]
			distance += 1
		if distance > longest: longest = distance; data.goal_room = i
	data.stairs = data.center(data.rooms[data.goal_room].get_center())
	for i in range(1,data.rooms.size()):
		data.entrances[i] = []
		for cell in data.cells:
			if data.cells[cell] != i: continue
			for d in [Vector2i.LEFT,Vector2i.RIGHT,Vector2i.UP,Vector2i.DOWN]:
				if data.cells.has(cell+d) and data.cells[cell+d] != i:
					data.entrances[i].append(data.center(cell))
					break
		var candidates: Array[Vector2i] = []
		for cell in data.cells:
			if data.cells[cell] == i and data.entry_safe(data.center(cell),i): candidates.append(cell)
		var count := mini(mini(18+data.floor_number*4,85),candidates.size())
		var flankers := mini(6,roundi(count*0.10)) if data.floor_number >= 6 else 0
		var interceptors := mini(2,roundi(count*0.05)) if data.floor_number >= 11 else 0
		var replacement_index := 0
		for n in range(count):
			if candidates.is_empty(): break
			var candidate_index: int = data.rng.randi_range(0,candidates.size()-1)
			var p := candidates[candidate_index]
			candidates.remove_at(candidate_index)
			var kind := Catalog.Enemy.CHASER
			if n % 7 == 0: kind = Catalog.Enemy.SNIPER
			elif n % 11 == 0: kind = Catalog.Enemy.SHIELD
			else:
				if replacement_index < flankers: kind = Catalog.Enemy.FLANKER
				elif replacement_index < flankers + interceptors: kind = Catalog.Enemy.INTERCEPTOR
				replacement_index += 1
			data.enemies.append({"p":data.center(p), "kind":kind, "hp":data.enemy_health(kind, data.floor_number),
				"flank_side":1 if n % 2 == 0 else -1, "warp_cd":0.0, "warp_warning":0.0, "arrival":0.0, "escape_time":0.0,
				"room":i, "active":false, "searching":false, "notice":data.rng.randf_range(0.35,0.85), "turn_speed":data.rng.randf_range(1.8,3.8),
				"cd":data.rng.randf_range(0.25,0.65), "charge":0.0, "stun":0.0, "dir":Vector2.from_angle(data.rng.randf()*TAU), "push":Vector2.ZERO})
	data.player = data.spawn_point
	data.build_flow()
	var cursor: Vector2i = data.tile(data.stairs)
	var steps := 0
	while cursor != data.tile(data.spawn_point) and data.flow.has(cursor):
		cursor = data.flow[cursor]
		steps += 1
	# Budget follows the actual navigable shortest route and current movement speed.
	data.route_seconds = steps * data.TILE / (data.SPEED + data.move_bonus)
	data.time_limit = (data.route_seconds * 1.35 + 2.0) * 1.5
	return data
