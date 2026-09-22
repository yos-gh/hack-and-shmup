extends RefCounted
## Heavy chassis locomotion, independent of the weapon choreography.
const MODES := ["cross_x","hunt","cross_y","flank","ram_warning","ram","retreat"]
const CLEARANCE := 220.0
const TURN_RATE := 1.8

func setup(e: Dictionary) -> void:
	e["move_step"] = 0
	e["move_mode"] = "cross_x"
	e["move_time"] = 4.5
	e["move_target"] = e.home+Vector2(320,0)
	e["move_cycle"] = 0
	e["ram_start"] = e.p
	e["ram_end"] = e.p
	e["ram_direction"] = Vector2.RIGHT
	e["player_velocity"] = Vector2.ZERO
	e["last_player"] = Vector2.INF

func clear_at(game, point: Vector2) -> bool:
	# Test every blocked tile touching the bounding disk, including interior holes.
	var low: Vector2i = game.tile(point-Vector2.ONE*CLEARANCE)
	var high: Vector2i = game.tile(point+Vector2.ONE*CLEARANCE)
	for y in range(low.y,high.y+1):
		for x in range(low.x,high.x+1):
			var cell := Vector2i(x,y)
			if game.cells.get(cell,-1) == 1: continue
			var corner: Vector2 = Vector2(cell)*game.TILE
			if point.distance_to(point.clamp(corner,corner+Vector2.ONE*game.TILE)) < CLEARANCE: return false
	return true

func tactical_target(e: Dictionary, target: Vector2) -> Vector2:
	# Preserve outer refuge lanes. The tank may charge out of this inner zone,
	# but ordinary pursuit cannot pin the player against the arena walls.
	return target.clamp(e.home-Vector2(320,180),e.home+Vector2(320,180))

func enter(game, e: Dictionary, step: int) -> void:
	e.move_step = step%MODES.size()
	e.move_mode = MODES[e.move_step]
	var side: float = 1.0 if e.move_cycle%2 == 0 else -1.0
	match e.move_mode:
		"cross_x":
			e.move_target = e.home+Vector2(-320 if e.p.x > e.home.x else 320,clampf(e.p.y-e.home.y,-180,180))
			e.move_time = 4.5
		"cross_y":
			e.move_target = e.home+Vector2(clampf(e.p.x-e.home.x,-280,280),-180 if e.p.y > e.home.y else 180)
			e.move_time = 3.5
		"hunt": e.move_time = 2.8 if not e.expert else 3.2
		"flank":
			e.move_target = tactical_target(e,game.player+e.p.direction_to(game.player).orthogonal()*side*280)
			e.move_time = 2.6
		"ram_warning":
			var aim: Vector2 = game.player+(e.player_velocity*0.28 if e.expert else Vector2.ZERO)
			e.ram_start = e.p
			e.ram_direction = e.p.direction_to(aim)
			if e.ram_direction.is_zero_approx(): e.ram_direction = Vector2.from_angle(e.heading)
			e.ram_end = e.p
			for distance in range(16,721 if e.expert else 609,16):
				var next: Vector2 = e.p+e.ram_direction*distance
				if not clear_at(game,next): break
				e.ram_end = next
			if e.p.distance_to(e.ram_end) < 128:
				enter(game,e,6)
				return
			e.move_time = maxf(1.0 if e.expert else 1.15,absf(angle_difference(e.heading,e.ram_direction.angle()))/TURN_RATE+0.12)
			# A moving laser cannot suddenly sweep sideways at charge speed.
			for beam in game.boss.lasers:
				if beam.owner == e: beam.duration = 0
		"ram": e.move_time = e.p.distance_to(e.ram_end)/(410.0 if e.expert else 340.0)+0.03
		"retreat":
			e.move_target = tactical_target(e,e.home+(e.home-game.player).normalized()*230)
			e.move_time = 3.0
			e.move_cycle += 1

func advance(game, e: Dictionary, delta: float, rage: bool) -> Vector2:
	if delta <= 0: return Vector2.ZERO
	if e.last_player != Vector2.INF: e.player_velocity = ((game.player-e.last_player)/delta).limit_length(450)
	e.last_player = game.player
	e.move_time -= delta
	if e.move_time <= 0: enter(game,e,e.move_step+1)
	var motion := Vector2.ZERO
	if e.move_mode == "ram_warning":
		e.heading = rotate_toward(e.heading,e.ram_direction.angle(),delta*TURN_RATE)
		e.dir = Vector2.from_angle(e.heading)
		return Vector2.ZERO
	if e.move_mode == "ram":
		motion = e.ram_direction*minf((410.0 if e.expert else 340.0)*delta,e.p.distance_to(e.ram_end))
		if e.p.distance_to(e.ram_end) < 2: enter(game,e,e.move_step+1)
	else:
		if e.move_mode == "hunt": e.move_target = tactical_target(e,game.player)
		var offset: Vector2 = e.move_target-e.p
		if offset.length() < 20:
			enter(game,e,e.move_step+1)
			return Vector2.ZERO
		var angle := offset.angle()
		var turn: float = absf(angle_difference(e.heading,angle))
		e.heading = rotate_toward(e.heading,angle,delta*TURN_RATE)
		var speed: float = (165 if rage else 140)+(15 if e.expert else 0)
		if e.move_mode == "hunt": speed += 20
		# Slow into a turn, retaining the same smooth tracked-vehicle presentation.
		speed *= lerpf(0.15,1.0,clampf(1-turn/1.6,0,1))
		motion = Vector2.from_angle(e.heading)*minf(speed*delta,offset.length())
	if not clear_at(game,e.p+motion):
		enter(game,e,6 if e.move_mode == "ram" else (e.move_step+1))
		return Vector2.ZERO
	e.dir = Vector2.from_angle(e.heading)
	e.tread = fposmod(e.tread+motion.length(),32.0)
	return motion/delta

func draw(game, e: Dictionary) -> void:
	if not e.move_mode in ["ram_warning","ram"]: return
	var side: Vector2 = e.ram_direction.orthogonal()*215
	var ink := Color("ff496a")
	var start: Vector2 = e.ram_start-e.ram_direction*215
	var end: Vector2 = e.ram_end+e.ram_direction*215
	game.draw_colored_polygon(PackedVector2Array([start-side,end-side,end+side,start+side]),Color(1,0.2,0.3,0.08))
	for sign_value in [-1,1]: game.draw_line(start+side*sign_value,end+side*sign_value,ink,2,true)
	var length: float = e.ram_start.distance_to(e.ram_end)
	for distance in range(100,int(length),90):
		var point: Vector2 = e.ram_start+e.ram_direction*distance
		game.draw_polyline(PackedVector2Array([point-e.ram_direction*18-side.normalized()*16,point,point-e.ram_direction*18+side.normalized()*16]),ink,3,true)
