extends SceneTree
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, message: String) -> void:
	if not ok:
		push_error("FAIL: "+message)
		failures += 1
func run() -> void:
	var game = load("res://main.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	game.depth_view.set_process(false)
	var fortress = game.boss.fortress
	var gap_sizes := []
	for depth in [25,50]:
		game.practice.variant = 3
		game.practice.depth = depth
		game.practice.start(game)
		game.discovered[1] = true
		var e: Dictionary = game.enemies[0]
		game.player = e.p+Vector2(-300,0)
		game.build_flow()
		var kinds := {}
		var sweep_seen := false
		var modes := {}
		var peak := 0
		for frame in range(1800):
			game.grace = 2
			game.replay_input = {"movement":Vector2.ZERO,"aim":Vector2.RIGHT,"primary":false,"secondary":false}
			if frame == 900: e.hp = e.max_hp*0.4
			game._physics_process(1.0/60)
			modes[e.move_mode] = true
			for bullet in game.bullets:
				if bullet.has("pattern"): kinds[bullet.pattern] = true
			for beam in game.boss.lasers: sweep_seen = sweep_seen or beam.has("sweep")
			peak = maxi(peak,game.bullets.size())
			check(fortress.motion.clear_at(game,e.p),"tank footprint avoids walls and pillars")
		check(kinds.has("weave") == (depth == 50) and kinds.has("crossfire") == (depth == 50) and kinds.has("intercept") == (depth == 50),"exclusive floor 50 patterns")
		check(sweep_seen == (depth == 50),"floor 50 sweeping pincer laser")
		check(modes.has("ram") and modes.has("hunt") and modes.has("cross_y"),"all depths use tactical movement")
		check(peak < 500,"upper-depth projectile budget")
		var angles: Array[float] = []
		for i in range(40): angles.append(fposmod(fortress.radial_angle(i,40,lerpf(54.0,36.0,e.low)-16.0*e.mid),TAU))
		angles.sort()
		var max_gap := 0.0
		for i in range(40): max_gap = maxf(max_gap,fposmod(angles[(i+1)%40]-angles[i],TAU))
		gap_sizes.append(max_gap)
		print("TACTICS: floor %d patterns=%s sweep=%s peak=%d gap=%.1f deg" % [depth,kinds.keys(),sweep_seen,peak,rad_to_deg(max_gap)])
		game.boss.reset()
		e.p = e.home
		e.heading = 0
		game.player = e.home+Vector2(400,80)
		fortress.motion.enter(game,e,1)
		fortress.drive(game,e,0.1,false)
		var target: Vector2 = e.move_target
		game.player = e.home+Vector2(-300,100)
		fortress.drive(game,e,0.1,false)
		check(e.move_target.x < target.x-400,"pursuit reacts to player repositioning")
		# Charge is announced, clipped and locked; subsequent player movement
		# cannot steer it. It moves faster than ordinary pursuit.
		e.p = e.home
		e.heading = 0
		e.player_velocity = Vector2.ZERO
		game.player = e.home+Vector2(350,0)
		fortress.motion.enter(game,e,4)
		check(e.move_mode == "ram_warning" and e.move_time >= 1,"charge has a full warning")
		var end: Vector2 = e.ram_end
		var direction: Vector2 = e.ram_direction
		game.player = e.home+Vector2(0,300)
		var warning_move: Vector2 = fortress.drive(game,e,0.2,false)
		check(warning_move == Vector2.ZERO and e.ram_end == end,"warning holds locked route")
		fortress.motion.enter(game,e,5)
		var velocity: Vector2 = fortress.drive(game,e,1.0/60,false)
		check(velocity.length() >= 330 and velocity.normalized().dot(direction) > 0.999,"ram is fast and never re-tracks")
		check(fortress.motion.clear_at(game,end),"charge stops before terrain")
		if depth == 50:
			game.boss.reset()
			fortress.pattern(game.boss,game,e,"scissor",false)
			var beam: Dictionary = game.boss.lasers[0]
			var initial_heading: Vector2 = beam.heading
			game.boss.advance_lasers(game,0.3)
			check(beam.heading == initial_heading,"scissor direction holds during warning")
			beam.warning = 0
			game.boss.advance_lasers(game,0.2)
			check(absf(beam.heading.angle_to(initial_heading)) > 0.1,"active scissor sweeps")
	check(gap_sizes[1] < gap_sizes[0]*0.65 and gap_sizes[1] > deg_to_rad(18),"50 narrows escape gaps while retaining traversable lanes")
	game.free()
	if failures == 0: print("PASS: tactical movement, telegraphed ram, terrain safety and structural 25/50 difficulty difference")
	quit(1 if failures else 0)
