extends RefCounted

# Only the player uses corner assistance. Keep the existing collision footprint.
const CORNER_REACH := 6.0
const SAMPLE_STEP := 1.0

static func clear_segment(game, start: Vector2, end: Vector2, radius: float) -> bool:
	var samples := maxi(1,ceili(start.distance_to(end)/SAMPLE_STEP))
	for i in range(1,samples+1):
		if not game.walkable(start.lerp(end,float(i)/samples),radius): return false
	return true

static func move(game, position: Vector2, motion: Vector2, radius: float) -> Vector2:
	if motion.is_zero_approx(): return position
	var steps := maxi(1,ceili(motion.length()/2.0))
	var step := motion/steps
	for i in range(steps): position = advance(game,position,step,radius)
	return position

static func advance(game, position: Vector2, motion: Vector2, radius: float) -> Vector2:
	var normal: Vector2 = game.slide(position,motion,radius)
	# Ordinary wall sliding already gives the player a way out.
	if normal.distance_squared_to(position)>0.0001: return normal
	var forward := Vector2(signf(motion.x),0) if absf(motion.x)>=absf(motion.y) else Vector2(0,signf(motion.y))
	var side := forward.orthogonal()
	if side.dot(motion)<0: side = -side
	for distance in range(1,int(CORNER_REACH)+1):
		for sign_value in [1.0,-1.0]:
			var offset: Vector2 = side*distance*sign_value
			var edge: Vector2 = position+offset
			if not clear_segment(game,position,edge,radius): continue
			if not clear_segment(game,edge,edge+forward*(radius+2.0),radius): continue
			var adjusted: Vector2 = (motion+offset).normalized()*motion.length()
			if adjusted.dot(motion)<0: continue
			return game.slide(position,adjusted,radius)
	return normal
