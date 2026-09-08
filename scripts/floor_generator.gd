extends RefCounted

# Generation boundary. Writes the existing floor model without changing RNG order.

func generate(game, boss_choice: int = -1) -> void:
	game.floor_revision += 1
	game.cells.clear()
	game.rooms.clear()
	game.room_shapes.clear()
	game.entrances.clear()
	game.effects.clear()
	game.damage_labels.clear()
	game.discovered.clear()
	game.enemies.clear()
	game.bullets.clear()
	game.particles.clear()
	game.room_links.clear()
	game.corridor_cells.clear()
	game.boss_floor = game.floor_number % 5 == 0
	if game.boss_floor:
		game.boss_variant = game.rng.randi_range(0,2) if boss_choice < 0 else clampi(boss_choice,0,2)
		game.boss.build(game)
		return
	# Scatter larger rooms without overlap, then connect a spanning tree and loops.
	var target_count: int = game.rng.randi_range(7, 10)
	for attempt in range(600):
		if game.rooms.size() >= target_count: break
		var r := Rect2i(game.rng.randi_range(-52, 52), game.rng.randi_range(-44, 44), game.rng.randi_range(18, 25), game.rng.randi_range(16, 22))
		var overlaps := false
		for other in game.rooms:
			if r.grow(5).intersects(other): overlaps = true; break
		if overlaps: continue
		game.rooms.append(r)
		var shape: int = game.rng.randi_range(0, 4)
		game.room_shapes.append(shape)
		for cy in range(r.position.y, r.end.y):
			for cx in range(r.position.x, r.end.x):
				if game.room_contains(Vector2i(cx,cy),r,shape): game.cells[Vector2i(cx,cy)] = game.rooms.size() - 1
	var connected: Array[int] = [0]
	while connected.size() < game.rooms.size():
		var best := Vector2i(-1,-1)
		var best_distance := INF
		for a in connected:
			for b in range(game.rooms.size()):
				if b in connected: continue
				var distance := Vector2(game.rooms[a].get_center()).distance_squared_to(Vector2(game.rooms[b].get_center()))
				if distance < best_distance: best_distance = distance; best = Vector2i(a,b)
		game.connect_rooms(best.x,best.y)
		game.room_links.append(best)
		connected.append(best.y)
	for extra in range(2):
		var a: int = game.rng.randi_range(0,game.rooms.size()-1)
		var b: int = game.rng.randi_range(0,game.rooms.size()-1)
		if a != b and not Vector2i(a,b) in game.room_links and not Vector2i(b,a) in game.room_links:
			game.connect_rooms(a,b)
			game.room_links.append(Vector2i(a,b))
	for i in range(game.rooms.size()):
		var r: Rect2i = game.rooms[i]
		var c := r.get_center()
		var obstacle_candidates: Array[Vector2i] = []
		for cell in game.cells:
			if game.cells[cell] == i and not game.corridor_cells.has(cell) and absi(cell.x-c.x)>2 and absi(cell.y-c.y)>2:
				obstacle_candidates.append(cell)
		for n in range(mini(18,obstacle_candidates.size())):
			var pick: int = game.rng.randi_range(0,obstacle_candidates.size()-1)
			game.cells.erase(obstacle_candidates[pick])
			obstacle_candidates.remove_at(pick)
	game.spawn_point = game.center(game.rooms[0].get_center())
	game.player = game.spawn_point
	game.build_flow()
	# Remove isolated pockets left by obstacles, before choosing enemy positions.
	for c in game.cells.keys():
		if not game.flow.has(c): game.cells.erase(c)
	game.goal_room = 1
	var longest := 0
	for i in range(1,game.rooms.size()):
		var cursor: Vector2i = game.rooms[i].get_center()
		var distance := 0
		while cursor != game.tile(game.spawn_point) and game.flow.has(cursor):
			cursor = game.flow[cursor]
			distance += 1
		if distance > longest: longest = distance; game.goal_room = i
	game.stairs = game.center(game.rooms[game.goal_room].get_center())
	for i in range(1,game.rooms.size()):
		game.entrances[i] = []
		for cell in game.cells:
			if game.cells[cell] != i: continue
			for d in [Vector2i.LEFT,Vector2i.RIGHT,Vector2i.UP,Vector2i.DOWN]:
				if game.cells.has(cell+d) and game.cells[cell+d] != i:
					game.entrances[i].append(game.center(cell))
					break
		var candidates: Array[Vector2i] = []
		for cell in game.cells:
			if game.cells[cell] == i and game.entry_safe(game.center(cell),i): candidates.append(cell)
		for n in range(mini(18+game.floor_number*4,85)):
			if candidates.is_empty(): break
			var candidate_index: int = game.rng.randi_range(0,candidates.size()-1)
			var p := candidates[candidate_index]
			candidates.remove_at(candidate_index)
			var kind := 0
			if n % 7 == 0: kind = 1
			elif n % 11 == 0: kind = 2
			game.enemies.append({"p":game.center(p), "kind":kind, "hp":game.enemy_health(kind, game.floor_number),
				"room":i, "active":false, "searching":false, "notice":game.rng.randf_range(0.35,0.85), "turn_speed":game.rng.randf_range(1.8,3.8),
				"cd":game.rng.randf_range(0.25,0.65), "charge":0.0, "stun":0.0, "dir":Vector2.from_angle(game.rng.randf()*TAU), "push":Vector2.ZERO})
	game.player = game.spawn_point
	game.build_flow()
	var cursor: Vector2i = game.tile(game.stairs)
	var steps := 0
	while cursor != game.tile(game.spawn_point) and game.flow.has(cursor):
		cursor = game.flow[cursor]
		steps += 1
	# Budget follows the actual navigable shortest route and current movement speed.
	game.route_seconds = steps * game.TILE / (game.SPEED + game.move_bonus)
	game.time_limit = (game.route_seconds * 1.35 + 2.0) * 1.5
	game.session.floor_snapshot.capture(game)
	game.restart_attempt()


func room_contains(_game, p: Vector2i, r: Rect2i, shape: int) -> bool:
	var local := p - r.position
	var mid := r.get_center() - r.position
	var dx := absi(local.x - mid.x)
	var dy := absi(local.y - mid.y)
	match shape:
		1: return local.x <= mid.x + 1 or local.y >= mid.y - 1 # L
		2: return dx <= 4 or dy <= 4 # cross
		3: return float(dx) / (r.size.x * 0.5) + float(dy) / (r.size.y * 0.5) < 1.35 # bevelled
		4: return dy <= 3 or local.x < 6 or local.x >= r.size.x - 6 # two chambers
	return true


func connect_rooms(game, a: int, b: int) -> void:
	var p: Vector2i = game.rooms[a].get_center()
	var goal: Vector2i = game.rooms[b].get_center()
	while p != goal:
		for dy in range(-1, 2):
			for dx in range(-1, 2):
				game.corridor_cells[p + Vector2i(dx,dy)] = true
				if not game.cells.has(p + Vector2i(dx, dy)):
					game.cells[p + Vector2i(dx, dy)] = -1
		if p.x != goal.x: p.x += 1 if goal.x > p.x else -1
		else: p.y += 1 if goal.y > p.y else -1
