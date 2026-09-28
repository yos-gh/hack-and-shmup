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
	for depth in [25,50,100]:
		game.practice.variant = 0
		game.practice.depth = depth
		game.practice.start(game)
		game.discovered[1] = true
		var e: Dictionary = game.enemies[0]
		game.player = e.home+Vector2(370,120)
		for rage in [false,true]:
			for pattern in ["laser","scissor"]:
				game.boss.reset()
				e.p = e.home
				e.heading = 0
				e.move_mode = "cross_y"
				e.move_time = 10
				e.move_target = e.home+Vector2(0,180)
				fortress.pattern(game.boss,game,e,pattern,rage)
				var before: float = e.heading
				fortress.drive(game,e,0.1,rage)
				check(absf(angle_difference(before,e.heading)) <= 0.091,"warning already reduces chassis rotation")
				var beam: Dictionary = game.boss.lasers[0]
				for active in game.boss.lasers: active.warning = 0
				var total_rotation := 0.0
				var muzzle_speed := 0.0
				for frame in range(20):
					before = e.heading
					var mount: Vector2 = fortress.gun_position(e,beam.gun)
					var velocity: Vector2 = fortress.drive(game,e,1.0/60,rage)
					e.p += velocity/60
					var turn: float = absf(angle_difference(before,e.heading))
					total_rotation += turn
					muzzle_speed = maxf(muzzle_speed,mount.distance_to(fortress.gun_position(e,beam.gun))*60)
					check(turn <= 0.00751 and velocity.length() <= 60.01,"firing bounds chassis turn and translation even when enraged")
					game.grace = 2
					game.boss.advance_lasers(game,1.0/60)
					check(beam.a.distance_to(fortress.gun_position(e,beam.gun)) < 0.001,"stabilized laser remains attached to its real muzzle")
					check(beam.b == game.attack_end(beam.a,beam.heading,1800),"cover still clips the moving laser")
				check(total_rotation > 0.05 and muzzle_speed < 124,"laser risk remains mobile but has bounded lateral motion")
				game.boss.reset()
				e.heading = 0
				e.move_target = e.p+Vector2(0,180)
				fortress.drive(game,e,0.1,rage)
				check(e.heading > 0.17,"ordinary maneuvering resumes when beams end")
		# Check extended tracking through the actual projectile simulation.
		game.bullets.clear()
		game.boss.emit_salvo(game,{"owner":e,"aim":Vector2.RIGHT,"offsets":PackedFloat32Array([0]),"speed":165.0,"guided":true})
		var shot: Dictionary = game.bullets[-1]
		var launch_speed: float = shot.v.length()
		game.boss_floor = false
		game.time_left = 999
		game.enemies.clear()
		game.cells.clear()
		for x in range(60):
			for y in range(-30,31): game.cells[Vector2i(x,y)] = 1
		game.player = shot.p+Vector2(600,0)
		game.replay_input = {"movement":Vector2.ZERO,"aim":Vector2.RIGHT,"primary":false,"secondary":false}
		game.grace = 999
		for frame in range(78): game._physics_process(1.0/60)
		game.player = shot.p+Vector2(0,300)
		var before: float = shot.v.angle()
		game._physics_process(0.1)
		check(shot.homing_time > 0.9 and angle_difference(before,shot.v.angle()) > 0.1,"seeker still turns toward a new target after 1.3 seconds")
		check(is_equal_approx(shot.v.length(),launch_speed),"stronger tracking preserves the floor-scaled travel speed")
		for frame in range(75): game._physics_process(1.0/60)
		before = shot.v.angle()
		game.player = shot.p+Vector2(0,-300)
		game._physics_process(0.1)
		check(game.bullets.has(shot) and shot.homing_time == 0 and is_equal_approx(before,shot.v.angle()),"seeker eventually commits to a straight escapeable path")
	game.free()
	if failures == 0: print("PASS: bounded Citadel laser motion and persistent finite seeker tracking at 25/50/100F")
	quit(1 if failures else 0)
