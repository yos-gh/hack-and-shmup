extends SceneTree
## Iron Citadel rules: armour, core exposure, cover, telegraphs, bounded attacks and retry.
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, message: String) -> void:
	if not ok:
		push_error("FAIL: "+message)
		failures += 1

func start(game, depth: int) -> Dictionary:
	game.practice.variant = 0
	game.practice.depth = depth
	game.practice.start(game)
	game.set_physics_process(false)
	game.discovered[1] = true
	return game.enemies[0]

func run() -> void:
	var game = load("res://main.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	game.depth_view.set_process(false)
	var fortress = game.boss.fortress
	var e: Dictionary = start(game,25)
	check(not game.walkable(game.center(Vector2i(7,-11))),"pillars are solid cover")
	check(fortress.touches(e,e.p+Vector2(140,128).rotated(e.heading),game.PLAYER_HIT_RADIUS),"tracks have contact collision")
	check(not fortress.touches(e,e.p+Vector2(150,0).rotated(e.heading),game.PLAYER_HIT_RADIUS),"recess beside hull stays traversable")
	# Every contact corner exists on the ground footprint of the 3D tracks or frame.
	var vertices: PackedVector3Array = fortress.CitadelVisual.chassis_mesh().surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	vertices.append_array(fortress.CitadelVisual.frame_mesh().surface_get_arrays(0)[Mesh.ARRAY_VERTEX])
	var ground := PackedVector2Array()
	for vertex in vertices:
		if is_zero_approx(vertex.z): ground.append(Vector2(vertex.x,-vertex.y))
	var local := Transform2D(e.heading,e.p).affine_inverse()
	for polygon in fortress.CitadelVisual.contact_parts(e):
		for corner in polygon:
			var matched := false
			for point in ground:
				if point.distance_to(local*corner) < 0.01: matched = true; break
			check(matched,"3D chassis footprint agrees with its contact hull")

	# Armour: a plate absorbs hits until broken, then that side exposes the core.
	var hp: float = e.hp
	game.hurt_enemy(e,1,Vector2.RIGHT)
	check(e.hp == hp and e.plates[6].hp < e.plates[6].max_hp,"armor protects core")
	fortress.damage_plate(game,e,6,e.plates[6].max_hp)
	game.hurt_enemy(e,1,Vector2.RIGHT)
	check(e.hp == hp-1 and e.plates[5].hp > 0,"local opening exposes core")
	e.cd = 100
	fortress.advance(game.boss,game,e,fortress.REBUILD-0.1,Vector2.LEFT)
	check(e.plates[6].hp == 0,"gap persists until rebuild time")
	fortress.advance(game.boss,game,e,0.2,Vector2.LEFT)
	check(e.plates[6].hp > 0,"plate regenerates")
	game.player = e.p+Vector2(-270,0)
	for weapon in [1,2]:
		game.sub_weapon = weapon
		game.fire_sub(Vector2.RIGHT)
		check(e.hp == hp-1,"sub weapons cannot bypass intact armor")
	game.player = e.p+Vector2(-300,80)
	var before: float = e.plates[5].hp
	fortress.lance(game,e,game.LanceTrace.lanes(game,game.player,Vector2.RIGHT),Vector2.RIGHT,1)
	check(e.plates[5].hp < before,"off-center lance damages the panel it crosses")

	# The hammer is lobbed over cover: a pillar between core and player does not block it.
	var pillar: Vector2 = game.center(Vector2i(7,-11))
	game.player = pillar+e.p.direction_to(pillar)*60
	check(not game.attack_reaches(e.p,game.player),"player is shielded from direct fire by the pillar")
	game.grace = 0
	var deaths: int = game.deaths
	e.cd = 100
	fortress.pattern(game.boss,game,e,"slam",false)
	check(e.slam[-1].source == e.p,"hammer launches from the core")
	fortress.advance(game.boss,game,e,e.slam[-1].time-fortress.HAMMER_LANDING_LEAD+0.01,Vector2.LEFT)
	check(e.slam[-1].get("cued",false) and not e.slam[-1].fired,"impact clip starts before landing so its hit lines up")
	fortress.advance(game.boss,game,e,e.slam[-1].time+0.01,Vector2.LEFT)
	check(game.deaths == deaths+1,"lobbed hammer clears the pillar and hits")
	game.pending_respawn = false
	e.slam.clear()

	# Enrage adds volume; retry restores the armour snapshot.
	game.boss.reset()
	e.slam.clear()
	e.step = 0
	e.cd = 0
	fortress.advance(game.boss,game,e,0,Vector2.LEFT)
	var normal: int = game.boss.salvos[0].offsets.size()
	game.boss.reset()
	e.hp = e.max_hp*0.4
	e.step = 0
	e.cd = 0
	fortress.advance(game.boss,game,e,0,Vector2.LEFT)
	check(game.boss.salvos[0].offsets.size() > normal,"enrage adds volleys")
	game.restart_attempt()
	check(game.enemies[0].plates[6].hp == game.enemies[0].plates[6].max_hp and game.enemies[0].hp == game.enemies[0].max_hp,"retry restores core and shields")

	# A queued gun fires from its current mount, not where it was when queued.
	e = game.enemies[0]
	game.boss.reset()
	var salvo: Dictionary = fortress.queue_gun(game.boss,e,1,0,1,0,200,Vector2.ZERO,"machine")
	e.p += Vector2(20,10)
	e.heading += 0.3
	game.boss.emit_salvo(game,salvo)
	check(game.bullets[-1].p.distance_to(fortress.gun_position(e,1)) < 0.001,"delayed muzzle follows translation and rotation")
	game.restart_attempt()

	# Live encounters: terrain safety, mounted clipped lasers, bounded load and
	# expert-only patterns at floor 50.
	for depth in [25,50]:
		e = start(game,depth)
		game.player = e.p+Vector2(-300,0)
		game.build_flow()
		var kinds := {}
		var sweep_seen := false
		var peak := 0
		for frame in range(1800):
			game.grace = 2
			game.replay_input = {"movement":Vector2.ZERO,"aim":Vector2.RIGHT,"primary":false,"secondary":false}
			if frame == 900: e.hp = e.max_hp*0.4
			game._physics_process(1.0/60)
			check(fortress.motion.clear_at(game,e.p),"tank footprint avoids walls and pillars")
			peak = maxi(peak,game.bullets.size())
			for bullet in game.bullets:
				if bullet.has("pattern"): kinds[bullet.pattern] = true
				if bullet.get("guided",false): check(bullet.homing_time <= 2.4,"seekers home for a bounded time")
			for beam in game.boss.lasers:
				sweep_seen = sweep_seen or beam.has("sweep")
				check(beam.a.distance_to(fortress.gun_position(e,beam.gun)) < 0.01,"laser stays mounted while moving")
				check(game.attack_reaches(beam.a,beam.b),"cover clips lasers")
		check(peak < 500,"bounded projectile load at floor %d" % depth)
		var expert: bool = depth >= 50
		check(kinds.has("weave") == expert and kinds.has("crossfire") == expert and sweep_seen == expert,"expert patterns appear only from floor 50")

		# Ram: announced, locked during warning, never re-tracks, stops before terrain.
		game.boss.reset()
		e.p = e.home
		e.heading = 0
		e.player_velocity = Vector2.ZERO
		game.player = e.home+Vector2(350,0)
		fortress.motion.enter(game,e,4)
		check(e.move_mode == "ram_warning" and e.move_time >= 1,"ram has a full warning")
		var end: Vector2 = e.ram_end
		var direction: Vector2 = e.ram_direction
		game.player = e.home+Vector2(0,300)
		check(fortress.drive(game,e,0.2,false) == Vector2.ZERO and e.ram_end == end,"warning holds the locked route")
		fortress.motion.enter(game,e,5)
		check(fortress.drive(game,e,1.0/60,false).normalized().dot(direction) > 0.999,"ram never re-tracks")
		check(fortress.motion.clear_at(game,end),"ram stops before terrain")
		if expert:
			game.boss.reset()
			fortress.pattern(game.boss,game,e,"scissor",false)
			var beam: Dictionary = game.boss.lasers[0]
			var heading: Vector2 = beam.heading
			game.boss.advance_lasers(game,0.3)
			check(beam.heading == heading,"sweeping laser holds its direction during warning")
	game.free()
	if failures == 0: print("PASS: Citadel armour, cover, telegraphs, bounded attacks and retry")
	quit(1 if failures else 0)
