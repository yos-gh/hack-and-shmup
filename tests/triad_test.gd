extends SceneTree
const Fixture = preload("res://tools/balance_fixture.gd")
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, message: String) -> void:
	if not ok:
		push_error("FAIL: "+message)
		failures += 1
# Every contact part corner must exist on the ground footprint of its 3D mesh.
func check_footprint(mesh: ArrayMesh, shapes: Array) -> void:
	var vertices: PackedVector3Array = mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	var ground := PackedVector2Array()
	for vertex in vertices:
		if is_zero_approx(vertex.z): ground.append(Vector2(vertex.x,-vertex.y))
	for shape in shapes:
		for corner in shape:
			var matched := false
			for point in ground:
				if point.distance_to(corner) < 0.001: matched = true; break
			check(matched,"3D battery footprint agrees with its contact hull")

func check_projectile_batch(game) -> void:
	var renderer = game.world_view.field_projectiles
	var boss = game.boss.triad
	game.bullets.clear()
	game.player = Vector2(260,48)
	game.discovered[1] = true
	boss.emit_pearl(game,Vector2(256,48),Vector2.RIGHT,112,0,"ribbon")
	boss.emit_pearl(game,Vector2(270,58),Vector2.LEFT,112,1,"ribbon")
	boss.emit_pearl(game,Vector2(700,48),Vector2.RIGHT,112,0,"ribbon")
	var before: int = hash(game.bullets)
	var bounds := Rect2(200,0,100,100)
	renderer.sync(game,bounds)
	check(renderer.visible_counts == PackedInt32Array([1,1,0]),"only on-screen pearls enter their color batches")
	check(renderer.batches[0].get_instance_transform_2d(0).origin == Vector2(256,48),"batched pearl stays at its collision position")
	check(hash(game.bullets) == before,"render culling leaves all simulation bullets unchanged")
	game.discovered.erase(1)
	renderer.sync(game,bounds)
	check(renderer.visible_counts == PackedInt32Array([0,0,0]),"hidden rooms cannot leak batched projectiles")
	game.discovered[1] = true
	game.sub_weapon = 1
	game.fire_sub(Vector2.RIGHT)
	renderer.sync(game,bounds)
	check(renderer.visible_counts == PackedInt32Array([0,0,0]) and game.bullets.size() == 1,"shockwave clears visible pearls without ghost instances")
	game.bullets.clear()
	for i in range(1030): boss.emit_pearl(game,Vector2(260,48),Vector2.RIGHT,112,0,"ribbon")
	renderer.sync(game,bounds)
	check(renderer.visible_counts[0] == 1030 and renderer.batches[0].get_instance_transform_2d(0).origin == Vector2(260,48),"batch growth retains every transform without a bullet cap")
	game.bullets.clear()
	renderer.sync(game,bounds)
	check(renderer.batches[0].visible_instance_count == 0,"empty/retried battle clears old draw instances")
	game.emit_shot(Vector2(260,48),Vector2.RIGHT,165,1,true)
	game.bullets[-1]["field"] = true
	renderer.sync(game,bounds)
	check(renderer.visible_counts == PackedInt32Array([0,0,1]),"other bosses use the shared amber field batch")
	game.bullets[-1]["guided"] = true
	renderer.sync(game,bounds)
	check(renderer.visible_counts == PackedInt32Array([0,0,0]),"guided shape takes precedence over field metadata")

func check_pressure(game, boss, e: Dictionary) -> void:
	game.player = e.p+Vector2(-390,0)
	e.player_velocity = Vector2(0,240)
	boss.prepare_needles(game,e,false)
	var heading: Vector2 = e.needle_volleys[0].heading
	var target: Vector2 = e.needle_volleys[0].target
	game.bullets.clear()
	e.needle_cd = 10
	boss.advance_needles(game,e,0.5,false)
	check(game.bullets.is_empty(),"needle salvo cannot fire through its warning")
	game.player += Vector2(0,-200)
	boss.advance_needles(game,e,0.49,false)
	check(not game.bullets.is_empty(),"warned gun fires after its warning")
	check(e.needle_volleys[0].heading == heading and e.needle_volleys[0].target == target,"warning locks aim before the player dodges")
	for bullet in game.bullets:
		var source_matches := false
		for volley in e.needle_volleys:
			if bullet.source == boss.needle_position(e,volley.gun): source_matches = true
		check(source_matches,"needles fire from the visible port")
	e.needle_volleys.clear()
	game.bullets.clear()
func run() -> void:
	var game = load("res://main.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	game.depth_view.set_process(false)
	for depth in [5,50]:
		Fixture.new().configure(game,depth,"standard",2,0)
		var e: Dictionary = game.enemies[0]
		var boss = game.boss.triad
		check_pressure(game,boss,e)
		check_footprint(boss.Visual.gantry_mesh(),boss.Visual.GANTRY_HULL)
		check_footprint(boss.Visual.carriage_mesh(),[boss.Visual.CARRIAGE_HULL])
		check(game.time_limit == 0 and e.cover_points.size() == 4,"untimed arena with four shelters")
		for point in e.cover_points: check(not game.attack_open(point),"shelter has physical cover")
		check(boss.touches(e,e.p+Vector2(130,0),5),"carapace matches contact boundary")
		for i in range(6):
			check(boss.touches(e,boss.mouth_position(e,i),5),"turret muzzle sits on a solid carriage")
			check(boss.touches(e,boss.needle_position(e,i),5),"needle pod sits on a solid rail")
		check(not boss.touches(e,e.p+Vector2(-370,0),5),"open outer route stays traversable")
		for pair in range(3):
			var gap := Vector2.from_angle(boss.gantry_angle(e,pair)+PI/3)
			for radius in [170.0,230.0,300.0]:
				check(not boss.touches(e,e.p+gap*radius,5),"lanes between gantries reach the core")
		boss.fire_streams(game,e)
		var reference: Array = game.bullets.duplicate(true)
		game.bullets.clear()
		game.player = e.p+Vector2(0,400)
		boss.fire_streams(game,e)
		for i in range(reference.size()):
			check(reference[i].p == game.bullets[i].p and reference[i].v == game.bullets[i].v,"ribbons are a fixed pattern, independent of player aim")
			check(reference[i].p == reference[i].source,"ribbons start at a visible mouth")
		game.bullets.clear()
		game.player = e.p+Vector2(-420,0)
		boss.start_laser(game.boss,game,e,false)
		var beam: Dictionary = game.boss.lasers[-1]
		check(beam.warning >= 1,"beam is telegraphed")
		beam.warning = 0
		game.player = e.p+Vector2(0,420)
		var old_angle: float = beam.heading.angle()
		game.grace = 2
		game.boss.advance_lasers(game,0.1)
		check(absf(angle_difference(old_angle,beam.heading.angle())) <= 0.04,"tracking is bounded")
		check(beam.b == game.attack_end(beam.a,beam.heading,1600),"cover clips beam")
		game.boss.lasers.clear()
		e.eviction_cd = 0
		game.player = e.cover_points[0]+Vector2(-65,0)
		boss.advance(game.boss,game,e,0.016,Vector2.ZERO)
		check(e.evictions.size() == 1 and e.evictions[0].timer > 1,"cover eviction gives time to move")
		var target: Vector2 = e.evictions[0].p
		game.player += Vector2(0,100)
		boss.advance(game.boss,game,e,0.4,Vector2.ZERO)
		check(e.evictions[0].p == target,"eviction target locks instead of following")
		game.restart_attempt()
		check(game.boss_variant == 2 and game.enemies[0].motif == 0,"retry rebuilds encounter")
	check_projectile_batch(game)
	game.free()
	if failures == 0: print("PASS: Triad Battery contact hull, cover, telegraphs, retry and batched projectile rendering")
	quit(1 if failures else 0)
