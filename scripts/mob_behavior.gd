extends RefCounted

const Catalog = preload("res://scripts/combat_catalog.gd")
const FLANK_DISTANCE := 100.0
const FLANK_ANGLE := PI / 3.0
const ESCAPE_DISTANCE := 192.0
const ESCAPE_TIME := 0.35
const WARP_AHEAD := 240.0
const WARP_WARNING := 0.45
const WARP_RECOVERY := 0.6
const WARP_INTERVAL := 5.0
const WARP_CLEARANCE := 96.0
const WARP_RETRY := 0.3
var warp_owner: Dictionary = {}

func reset() -> void:
	warp_owner = {}

func begin_frame() -> void:
	if not warp_owner.is_empty() and warp_owner.hp <= 0: warp_owner = {}

func chase(game, e: Dictionary, speed: float) -> Vector2:
	var cell: Vector2i = game.tile(e.p)
	var target: Vector2 = game.player if cell == game.tile(game.player) else game.center(game.flow.get(cell, cell))
	return (target - e.p).normalized() * speed

func velocity(game, e: Dictionary, delta: float, player_motion: Vector2) -> Vector2:
	var definition = Catalog.ENEMIES[e.kind]
	var toward: Vector2 = e.p.direction_to(game.player)
	match e.kind:
		Catalog.Enemy.SNIPER:
			if e.cd <= 0:
				game.emit_shot(e.p, toward, definition.bullet_speed, 1, true)
				game.enemy_attack_cue("sniper_fire",e.p)
				e.cd = definition.shot_interval
			return Vector2.ZERO
		Catalog.Enemy.SHIELD:
			return shield_velocity(game,e,delta,toward)
		Catalog.Enemy.FLANKER:
			if e.p.distance_to(game.player) > FLANK_DISTANCE and game.attack_reaches(e.p,game.player):
				var flank: Vector2 = toward.rotated(FLANK_ANGLE * e.get("flank_side",1))
				# A bounded lookahead keeps the local turn out of walls and narrow passages.
				var target: Vector2 = e.p + flank * 64.0
				if game.walkable(target) and game.attack_reaches(e.p,target):
					e.dir = flank
					return flank * definition.move_speed
			var motion := chase(game,e,definition.move_speed)
			if not motion.is_zero_approx(): e.dir = motion.normalized()
			return motion
		Catalog.Enemy.INTERCEPTOR:
			return interceptor(game,e,delta,player_motion)
	return chase(game,e,definition.move_speed)

func shield_velocity(game, e: Dictionary, delta: float, toward: Vector2) -> Vector2:
	var definition = Catalog.ENEMIES[Catalog.Enemy.SHIELD]
	if e.get("stun", 0.0) > 0:
		e.stun = maxf(0.0, e.stun - delta)
		return Vector2.ZERO
	if e.charge > 0:
		e.charge = maxf(0.0, e.charge - delta)
		var motion: Vector2 = e.dir * definition.charge_speed
		var hit_wall: bool = not game.walkable(e.p + motion * delta)
		if e.charge <= 0 or hit_wall:
			if hit_wall: e.cd = definition.wall_recovery
			game.combat_events.charge_changed.emit(e.p,e.dir,false)
			e.charge = 0.0
			e.stun = definition.stun_duration
			return Vector2.ZERO
		return motion
	if e.cd <= 0:
		e.dir = toward
		e.charge = definition.charge_duration
		game.combat_events.charge_changed.emit(e.p,e.dir,true)
		e.cd = definition.charge_recovery
	return Vector2.ZERO

func landing_valid(game, target: Vector2) -> bool:
	var room: int = game.cells.get(game.tile(game.player), -2)
	var destination: int = game.cells.get(game.tile(target), -2)
	if room == -2 or destination == -2: return false
	# Reserve ambushes for corridors, never the starting room or an unopened room.
	if destination != -1: return false
	if not game.walkable(target,14): return false
	if target.distance_to(game.player) < WARP_CLEARANCE: return false
	# Exclude HUD-covered space, not just offscreen positions.
	var screen: Vector2 = game.get_viewport_rect().size
	var point: Vector2 = game.world_to_screen(target)
	var map: Rect2 = game.hud.hud_layout(screen).map
	return Rect2(Vector2(24,100),screen-Vector2(48,164)).has_point(point) and not map.grow(24).has_point(point)

func intercept_target(game, movement: Vector2) -> Vector2:
	# Search only a small forward neighborhood of the actual walkable route.
	# Following connected tiles also works around L-shaped corridor bends.
	var speed: float = game.SPEED + game.move_bonus
	var ahead: float = maxf(WARP_AHEAD,speed*WARP_WARNING+WARP_CLEARANCE+32.0)
	var start: Vector2i = game.tile(game.player)
	var room: int = game.cells.get(start,-2)
	var distances := {start:0.0}
	var queue: Array[Vector2i] = [start]
	var heading := movement.normalized()
	var limit := ceili(ahead/game.TILE)+3
	var best := Vector2.INF
	var best_score := INF
	var index := 0
	while index < queue.size() and index < 1024:
		var cell := queue[index]
		index += 1
		var distance: float = distances[cell]
		var point: Vector2 = game.center(cell)
		# Reserve the warp for travel pressure, rather than spending its cooldown
		# on another position inside the room the player is about to leave.
		if game.cells.get(cell,-2) == -1 and distance >= speed*WARP_WARNING+WARP_CLEARANCE+16 and (point-game.player).dot(heading) > 32 and landing_valid(game,point):
			var score: float = absf(distance-ahead) + absf((point-game.player).cross(heading))*2.0
			if score < best_score:
				best_score = score
				best = point
		if distance >= limit*game.TILE: continue
		for direction in [Vector2i.RIGHT,Vector2i.DOWN,Vector2i.LEFT,Vector2i.UP]:
			var next: Vector2i = cell+direction
			if distances.has(next): continue
			# The first step must be forward, but later steps may follow a bend.
			if cell == start and Vector2(direction).dot(heading) <= 0.25: continue
			var owner: int = game.cells.get(next,-2)
			if owner == -2 or (owner >= 0 and owner != room): continue
			if not game.walkable(game.center(next),14): continue
			distances[next] = distance+game.TILE
			queue.append(next)
	return best

func interceptor(game, e: Dictionary, delta: float, player_motion: Vector2) -> Vector2:
	e.warp_cd = maxf(0.0,e.get("warp_cd",0.0)-delta)
	if e.get("arrival",0.0) > 0:
		e.arrival = maxf(0.0,e.arrival-delta)
		return Vector2.ZERO
	if e.get("warp_warning",0.0) > 0:
		e.warp_warning = maxf(0.0,e.warp_warning-delta)
		if e.warp_warning <= 0.000001:
			e.warp_warning = 0.0
			if landing_valid(game,e.warp_target) and (e.warp_target-game.player).dot(player_motion) >= 0:
				e.p = e.warp_target
				e.push = Vector2.ZERO
				e.arrival = WARP_RECOVERY
				e.dir = e.p.direction_to(game.player)
			e.warp_cd = WARP_INTERVAL if e.get("arrival",0.0) > 0 else WARP_RETRY
			e.escape_time = 0.0
			warp_owner = {}
		return Vector2.ZERO
	var away: Vector2 = game.player-e.p
	var left_room: bool = game.cells.get(game.tile(game.player),-1) != e.room
	var moving: bool = player_motion.length_squared() > 0.0001
	var escaping: bool = moving and away.length() >= ESCAPE_DISTANCE and (left_room or player_motion.dot(away.normalized()) > 0.01)
	e.escape_time = e.get("escape_time",0.0)+delta if escaping else 0.0
	if e.escape_time >= ESCAPE_TIME and e.warp_cd <= 0 and warp_owner.is_empty():
		var target := intercept_target(game,player_motion)
		if target.is_finite():
			e.warp_target = target
			e.warp_warning = WARP_WARNING
			e.escape_time = 0.0
			warp_owner = e
			return Vector2.ZERO
		# Failed attempts are bounded even when no landing is available.
		e.warp_cd = WARP_RETRY
		e.escape_time = 0.0
	return chase(game,e,Catalog.ENEMIES[Catalog.Enemy.INTERCEPTOR].move_speed)
