extends RefCounted

# Shared geometry queries for live Game and standalone FloorData.

static func tile(model, p: Vector2) -> Vector2i:
	return Vector2i(floor(p.x / model.TILE), floor(p.y / model.TILE))

static func center(model, p: Vector2i) -> Vector2:
	return Vector2(p) * model.TILE + Vector2.ONE * model.TILE * 0.5

static func walkable(model, p: Vector2, radius: float = 10.0) -> bool:
	for offset in [Vector2(-radius,-radius), Vector2(radius,-radius), Vector2(-radius,radius), Vector2(radius,radius)]:
		if not model.cells.has(model.tile(p + offset)): return false
	return true

static func entry_safe(model, p: Vector2, room_id: int) -> bool:
	if model.cells.get(model.tile(p), -1) != room_id: return false
	for entrance in model.entrances.get(room_id, []):
		if p.distance_to(entrance) < model.ENTRY_CLEARANCE: return false
	return model.walkable(p)

static func build_flow(model) -> void:
	model.flow.clear()
	var start: Vector2i = model.tile(model.player)
	model.flow[start] = start
	var queue: Array[Vector2i] = [start]
	var index := 0
	while index < queue.size():
		var c := queue[index]
		index += 1
		for d in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			var n: Vector2i = c + d
			if model.cells.has(n) and not model.flow.has(n):
				model.flow[n] = c
				queue.append(n)

static func enemy_health(_model, kind: int, depth: int) -> float:
	if kind == 2: return 1.0
	# Preserve floor-one HP and interpolate to the requested floor-15 targets.
	return lerpf(2.3, 4.0, (depth - 1) / 14.0) if kind == 0 else 1.0 + (depth - 1) / 14.0

static func room_contains(_model, p: Vector2i, r: Rect2i, shape: int) -> bool:
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

static func connect_rooms(model, a: int, b: int) -> void:
	var p: Vector2i = model.rooms[a].get_center()
	var goal: Vector2i = model.rooms[b].get_center()
	while p != goal:
		for dy in range(-1, 2):
			for dx in range(-1, 2):
				model.corridor_cells[p + Vector2i(dx,dy)] = true
				if not model.cells.has(p + Vector2i(dx, dy)):
					model.cells[p + Vector2i(dx, dy)] = -1
		if p.x != goal.x: p.x += 1 if goal.x > p.x else -1
		else: p.y += 1 if goal.y > p.y else -1
