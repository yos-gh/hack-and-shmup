extends RefCounted

# Traverse tile boundaries until a wall or unopened room, independent of camera
# and weapon range. Finite floor geometry provides the termination bound.
# Cell openness is read directly (equivalent to Game.attack_open on the cell
# centre): a wide lance traces one lane per unit of width every frame.
static func endpoint(game, origin: Vector2, direction: Vector2) -> Vector2:
	var cells: Dictionary = game.cells
	var discovered: Dictionary = game.discovered
	var size: float = game.TILE
	var cell := Vector2i(floori(origin.x/size), floori(origin.y/size))
	var room = cells.get(cell)
	if room == null or not (room == -1 or discovered.has(room)) or direction.is_zero_approx(): return origin
	var step := Vector2i(int(signf(direction.x)), int(signf(direction.y)))
	var stride := Vector2(INF, INF)
	var crossing := Vector2(INF, INF)
	for axis in range(2):
		if step[axis] == 0: continue
		stride[axis] = size/absf(direction[axis])
		var boundary: float = (cell[axis]+(1 if step[axis] > 0 else 0))*size
		crossing[axis] = (boundary-origin[axis])/direction[axis]
	for _i in range(cells.size()+1):
		var distance := minf(crossing.x,crossing.y)
		var cross_x := crossing.x <= crossing.y+0.00001
		var cross_y := crossing.y <= crossing.x+0.00001
		# Do not leak diagonally through the corner of blocked tiles.
		if cross_x:
			room = cells.get(Vector2i(cell.x+step.x,cell.y))
			if room == null or not (room == -1 or discovered.has(room)): return origin+direction*maxf(0,distance-0.001)
		if cross_y:
			room = cells.get(Vector2i(cell.x,cell.y+step.y))
			if room == null or not (room == -1 or discovered.has(room)): return origin+direction*maxf(0,distance-0.001)
		if cross_x:
			cell.x += step.x
			crossing.x += stride.x
		if cross_y:
			cell.y += step.y
			crossing.y += stride.y
		room = cells.get(cell)
		if room == null or not (room == -1 or discovered.has(room)): return origin+direction*maxf(0,distance-0.001)
	return origin

# The beam leaves the hull slightly narrowed and reaches full width almost at
# once: lateral offsets and lane widths scale by this factor near the muzzle.
const TAPER_START := 0.5
const TAPER_LENGTH := 26.0

static func taper(distance: float) -> float:
	var k := clampf(distance/TAPER_LENGTH,0.0,1.0)
	return 1.0-(1.0-TAPER_START)*pow(1.0-k,2.0)

# Lane centre at a distance along the beam, measured from the lane start.
static func lane_point(ray: Dictionary, direction: Vector2, distance: float) -> Vector2:
	return ray.origin+(ray.p-ray.origin)*taper(distance)+direction*distance

static func lanes(game, origin: Vector2, aim: Vector2) -> Array:
	var result: Array = []
	var direction := aim.normalized()
	var side := direction.orthogonal()
	var total: float = game.LANCE_WIDTH
	var count := maxi(1,ceili(total))
	var width: float = total/count
	# Game.attack_reaches(origin,start) samples every 4 units from the hull toward
	# the lane start. Lanes on one side share those samples, so find the first
	# blocked sample once per side instead of once per lane.
	var blocked := {-1:INF, 1:INF}
	for sign_value in [-1,1]:
		var k := 1
		while k*4.0 < total*0.5:
			if not game.attack_open(origin+side*(sign_value*k*4.0)):
				blocked[sign_value] = k*4.0
				break
			k += 1
	for i in range(count):
		var offset: float = (i+0.5)*width-total*0.5
		var start: Vector2 = origin+side*offset
		var reach := absf(offset)
		# The muzzle cannot originate across a wall beside the player.
		var open_path: bool = (ceilf(reach/4.0)-1.0)*4.0 < blocked[-1 if offset < 0 else 1] and (reach == 0 or game.attack_open(start))
		var end: Vector2 = endpoint(game,start,direction) if open_path else start
		result.append({"p":start,"end":end,"width":width,"origin":origin})
	return result

static func hits(game, enemy: Dictionary, rays: Array, direction: Vector2) -> bool:
	if rays.is_empty() or not game.attack_open(enemy.p): return false
	var reach: float = game.enemy_bullet_radius(enemy)-1.5
	# Lanes are evenly spaced across the beam, so only those whose tapered band
	# can touch the target's lateral position need the exact test.
	var origin: Vector2 = rays[0].origin
	var width: float = rays[0].width
	var total: float = width*rays.size()
	var scale := taper(maxf(0,(enemy.p-origin).dot(direction)))
	var lateral: float = (enemy.p-origin).dot(direction.orthogonal())
	var first := maxi(0,floori(((lateral-reach)/scale+total*0.5)/width-1.5))
	var last := mini(rays.size()-1,ceili(((lateral+reach)/scale+total*0.5)/width+0.5))
	for index in range(first,last+1):
		var ray: Dictionary = rays[index]
		var distance: float = (enemy.p-ray.p).dot(direction)
		if distance < 0 or distance > ray.p.distance_to(ray.end): continue
		var point: Vector2 = lane_point(ray,direction,distance)
		if point.distance_to(enemy.p) <= reach+ray.width*0.5*taper(distance) and game.attack_reaches(point,enemy.p): return true
	return false
