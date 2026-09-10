extends RefCounted

# Traverse tile boundaries until a wall or unopened room, independent of camera
# and weapon range. Finite floor geometry provides the termination bound.
static func endpoint(game, origin: Vector2, direction: Vector2) -> Vector2:
	if not game.attack_open(origin) or direction.is_zero_approx(): return origin
	var cell: Vector2i = game.tile(origin)
	var step := Vector2i(int(signf(direction.x)), int(signf(direction.y)))
	var stride := Vector2(INF, INF)
	var crossing := Vector2(INF, INF)
	for axis in range(2):
		if step[axis] == 0: continue
		stride[axis] = game.TILE/absf(direction[axis])
		var boundary: float = (cell[axis]+(1 if step[axis] > 0 else 0))*game.TILE
		crossing[axis] = (boundary-origin[axis])/direction[axis]
	for _i in range(game.cells.size()+1):
		var distance := minf(crossing.x,crossing.y)
		var cross_x := crossing.x <= crossing.y+0.00001
		var cross_y := crossing.y <= crossing.x+0.00001
		# Do not leak diagonally through the corner of blocked tiles.
		for axis in range(2):
			if (axis == 0 and cross_x) or (axis == 1 and cross_y):
				var adjacent := cell
				adjacent[axis] += step[axis]
				if not game.attack_open(game.center(adjacent)):
					return origin+direction*maxf(0,distance-0.001)
		if cross_x:
			cell.x += step.x
			crossing.x += stride.x
		if cross_y:
			cell.y += step.y
			crossing.y += stride.y
		if not game.attack_open(game.center(cell)):
			return origin+direction*maxf(0,distance-0.001)
	return origin

static func lanes(game, origin: Vector2, aim: Vector2) -> Array:
	var result: Array = []
	var direction := aim.normalized()
	var side := direction.orthogonal()
	var count := maxi(1,ceili(game.LANCE_WIDTH))
	var width: float = game.LANCE_WIDTH/count
	for i in range(count):
		var start: Vector2 = origin+side*((i+0.5)*width-game.LANCE_WIDTH*0.5)
		# The muzzle cannot originate across a wall beside the player.
		var end: Vector2 = endpoint(game,start,direction) if game.attack_reaches(origin,start) else start
		result.append({"p":start,"end":end,"width":width})
	return result

static func hits(game, enemy: Dictionary, rays: Array, direction: Vector2) -> bool:
	if not game.attack_open(enemy.p): return false
	for ray in rays:
		var distance: float = (enemy.p-ray.p).dot(direction)
		if distance < 0 or distance > ray.p.distance_to(ray.end): continue
		var point: Vector2 = ray.p+direction*distance
		if point.distance_to(enemy.p) <= game.enemy_bullet_radius(enemy)-1.5+ray.width*0.5 and game.attack_reaches(point,enemy.p): return true
	return false
