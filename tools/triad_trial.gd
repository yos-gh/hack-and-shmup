extends SceneTree
## Synthetic avoidance trial; does not replace a human difficulty assessment.
const Fixture = preload("res://tools/balance_fixture.gd")
var steering := Vector2.ZERO
func _initialize() -> void: call_deferred("run")

func steer(game, e: Dictionary) -> Vector2:
	var nearby: Array = []
	for b in game.bullets:
		if b.hostile and b.p.distance_squared_to(game.player) < 390*390: nearby.append(b)
	var best_score := -INF
	var chosen := Vector2.ZERO
	var radial: Vector2 = e.p.direction_to(game.player)
	var tangent := Vector2(-radial.y,radial.x)
	if not game.boss.lasers.is_empty():
		if angle_difference(game.boss.lasers[0].heading.angle(),radial.angle()) < 0: tangent = -tangent
	for index in range(25):
		var direction := Vector2.ZERO if index == 24 else Vector2.from_angle(index*TAU/24)
		var velocity: Vector2 = direction*(game.SPEED+game.move_bonus)
		var finish: Vector2 = game.player+velocity*0.8
		var margin := 65.0
		for t in [0.2,0.5,0.8]:
			var point: Vector2 = game.player+velocity*t
			if not game.walkable(point,10) or point.distance_to(e.p) < 337: margin = -150
		for b in nearby:
			var relative: Vector2 = b.p-game.player
			var travel: Vector2 = b.v-velocity
			var t: float = clampf(-relative.dot(travel)/maxf(travel.length_squared(),1),0,0.8)
			margin = minf(margin,(relative+travel*t).length()-10)
		for beam in game.boss.lasers:
			for t in [0.2,0.5,0.8]:
				if beam.warning > t or beam.duration+beam.warning < t: continue
				var point: Vector2 = game.player+velocity*t
				var desired: Vector2 = e.p.direction_to(point)
				var turn: float = beam.turn_rate*maxf(0,t-beam.warning)
				var heading: Vector2 = beam.heading.rotated(clampf(angle_difference(beam.heading.angle(),desired.angle()),-turn,turn))
				var a: Vector2 = e.p+heading*82
				var b: Vector2 = game.attack_end(a,heading,1600)
				margin = minf(margin,Geometry2D.get_closest_point_to_segment(point,a,b).distance_to(point)-beam.width*0.5-8)
		for strike in e.evictions:
			if strike.timer > 0 and strike.timer <= 0.8:
				margin = minf(margin,(game.player+velocity*strike.timer).distance_to(strike.p)-73)
		var score: float = minf(margin,45)*4-absf(finish.distance_to(e.p)-435)*0.1+direction.dot(tangent)*18+direction.dot(steering)*2
		if score > best_score: best_score = score; chosen = direction
	return chosen

func run() -> void:
	var game = load("res://main.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	game.depth_view.set_process(false)
	for depth in [5,25,50]:
		Fixture.new().configure(game,depth,"standard",2,1)
		var e: Dictionary = game.enemies[0]
		game.player = e.p+Vector2(-410,40)
		game.grace = 0
		game.build_flow()
		var elapsed := 0.0
		var maximum := 0
		var outcome := "timeout"
		for frame in range(4500):
			if frame%4 == 0: steering = steer(game,e)
			var danger: bool = game.bullets.any(func(b: Dictionary) -> bool: return b.hostile and b.p.distance_squared_to(game.player) < 95*95)
			game.replay_input = {"movement":steering,"aim":game.player.direction_to(e.p),"primary":frame%180 > 0 and frame%180 <= 45,"secondary":danger}
			game._physics_process(1.0/60.0)
			maximum = maxi(maximum,game.bullets.size())
			elapsed = (frame+1)/60.0
			if game.pending_respawn: outcome = "death"; break
			if game.stairs_unlocked: outcome = "clear"; break
		print("TRIAD LIVE: floor=%d outcome=%s seconds=%.2f hp=%.1f%% max_bullets=%d" % [depth,outcome,elapsed,maxf(0,e.hp/e.max_hp*100),maximum])
		if outcome == "death":
			var nearest := INF
			for b in game.bullets:
				if b.hostile: nearest = minf(nearest,b.p.distance_to(game.player))
			var laser_distance := INF
			for beam in game.boss.lasers:
				if beam.warning <= 0: laser_distance = minf(laser_distance,Geometry2D.get_closest_point_to_segment(game.player,beam.a,beam.b).distance_to(game.player))
			print("THREAT: bullet=%.1f beam=%.1f core=%.1f player=%s" % [nearest,laser_distance,game.player.distance_to(e.p),game.player])
	game.free()
	quit()
