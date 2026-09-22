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
	game.practice.variant = 3
	game.practice.depth = 25
	game.practice.start(game)
	game.discovered[1] = true
	var e: Dictionary = game.enemies[0]
	var fortress = game.boss.fortress
	game.player = e.p+Vector2(-300,0)
	game.build_flow()
	var start: Vector2 = e.p
	var min_position: Vector2 = e.p
	var max_position: Vector2 = e.p
	var kinds := {}
	var modes := {}
	var max_bullets := 0
	var max_queue := 0
	var longest_gap := 0.0
	var gap := 0.0
	var heading_start: float = e.heading
	for frame in range(1800):
		game.grace = 2
		game.replay_input = {"movement":Vector2.ZERO,"aim":Vector2.RIGHT,"primary":false,"secondary":false}
		if frame == 900: e.hp = e.max_hp*0.4
		game._physics_process(1.0/60.0)
		modes[e.move_mode] = true
		min_position = min_position.min(e.p)
		max_position = max_position.max(e.p)
		max_bullets = maxi(max_bullets,game.bullets.size())
		max_queue = maxi(max_queue,game.boss.salvos.size())
		var emitted := false
		for bullet in game.bullets:
			if bullet.has("pattern"):
				kinds[bullet.pattern] = true
				# Newly born bullets have not travelled yet this frame.
				if is_equal_approx(bullet.life,1200.0/bullet.v.length()): emitted = true
			if bullet.get("guided",false):
				check(bullet.homing_time <= 1.15 and bullet.turn_rate == 1.25,"bounded homing")
		if frame > 90:
			gap = 0 if emitted else gap+1.0/60.0
			longest_gap = maxf(longest_gap,gap)
		for beam in game.boss.lasers:
			check(beam.a.distance_to(fortress.gun_position(e,beam.gun)) < 0.01,"laser stays mounted while moving")
			check(game.attack_reaches(beam.a,beam.b),"moving beam respects pillars")
		for offset in [Vector2(220,0),Vector2(-220,0),Vector2(0,220),Vector2(0,-220)]:
			check(game.cells.get(game.tile(e.p+offset),-1) == 1,"whole chassis stays inside arena")
	check(max_position.x-min_position.x > 350 and max_position.y-min_position.y > 180,"tank uses varied routes across the arena")
	check(absf(e.heading-heading_start) > 0.3,"chassis turns with travel")
	for mode in ["cross_x","cross_y","hunt","flank","ram_warning","ram","retreat"]: check(modes.has(mode),"movement reaches "+mode)
	for kind in ["machine","radial","fan","missile"]: check(kinds.has(kind),"emits "+kind)
	check(longest_gap < 0.8,"no long firing rest")
	check(max_bullets < 450 and max_queue < 50,"bounded overlapping attacks")
	# A queued gun uses its current mount; no ghost firing from old positions.
	game.boss.reset()
	var salvo: Dictionary = fortress.queue_gun(game.boss,e,1,0,1,0,200,Vector2.ZERO,"machine")
	e.p += Vector2(20,10)
	e.heading += 0.3
	game.boss.emit_salvo(game,salvo)
	check(game.bullets[-1].p.distance_to(fortress.gun_position(e,1)) < 0.001,"delayed muzzle follows translation and rotation")
	check(game.bullets[-1].v.normalized().dot(game.bullets[-1].p.direction_to(game.player)) > 0.999,"machinegun re-aims each round")
	# Radial lobes preserve four readable gaps regardless of density.
	for count in [28,40]:
		var angles: Array[float] = []
		for i in range(count): angles.append(fposmod(game.boss.radial_angle(i,count),TAU))
		angles.sort()
		var gaps := 0
		for i in range(count):
			if fposmod(angles[(i+1)%count]-angles[i],TAU) > 0.6: gaps += 1
		check(gaps == 4,"radial has four escape corridors")
	game.restart_attempt()
	e = game.enemies[0]
	check(e.p == start and e.move_step == 0 and e.move_mode == "cross_x" and e.machine_cycle == 0,"retry restores movement and independent guns")
	print("METRICS: peak bullets=%d queue=%d longest firing gap=%.2fs travel=%s" % [max_bullets,max_queue,longest_gap,max_position-min_position])
	game.free()
	if failures == 0: print("PASS: moving fortress, rotating hull, mounted guns, layered patterns, gaps and bounded queues")
	quit(1 if failures else 0)
