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
	game.start_run()
	for depth in [5,20,25,30,50,75,100]:
		game.floor_number = depth
		game.new_floor()
		check((game.boss_variant == 3) == (depth%25 == 0),"25-floor replacement")
	game.practice.variant = 3
	game.practice.depth = 25
	game.practice.start(game)
	game.set_physics_process(false)
	game.discovered[1] = true
	var e: Dictionary = game.enemies[0]
	var fortress = game.boss.fortress
	check(game.boss_variant == 3 and game.rooms[1].size == Vector2i(48,36),"practice and arena")
	check(not game.walkable(game.center(Vector2i(7,-11))),"solid cover")
	check(fortress.touches(e,e.p+Vector2(140,128).rotated(e.heading),game.PLAYER_HIT_RADIUS),"tracks have contact collision")
	check(not fortress.touches(e,e.p+Vector2(150,0).rotated(e.heading),game.PLAYER_HIT_RADIUS),"recess beside hull stays traversable")
	var hp: float = e.hp
	game.hurt_enemy(e,1,Vector2.RIGHT)
	check(e.hp == hp and e.plates[6].hp < e.plates[6].max_hp,"armor protects core")
	fortress.damage_plate(game,e,6,e.plates[6].max_hp)
	game.hurt_enemy(e,1,Vector2.RIGHT)
	check(e.hp == hp-1 and e.plates[5].hp > 0,"local opening exposes core")
	e.cd = 100
	fortress.advance(game.boss,game,e,7.9,Vector2.LEFT)
	check(e.plates[6].hp == 0,"gap persists")
	fortress.advance(game.boss,game,e,0.2,Vector2.LEFT)
	check(e.plates[6].hp > 0,"plate regenerates")
	game.player = e.p+Vector2(-270,0)
	for weapon in [1,2]:
		game.sub_weapon = weapon
		game.fire_sub(Vector2.RIGHT)
		check(e.hp == hp-1,"sub cannot bypass intact armor")
	for step in range(12):
		e.cd = 0
		fortress.advance(game.boss,game,e,0,Vector2.LEFT)
	check(not game.boss.salvos.is_empty() and not game.boss.lasers.is_empty() and not e.slam.is_empty(),"mixed twelve-stage routine")
	for beam in game.boss.lasers:
		check(game.attack_reaches(beam.a,beam.b),"lasers clip to terrain")
	# A lance aimed at armor outside the core still damages that individual panel.
	game.player = e.p+Vector2(-300,80)
	var before: float = e.plates[5].hp
	var rays: Array = game.LanceTrace.lanes(game,game.player,Vector2.RIGHT)
	fortress.lance(game,e,rays,Vector2.RIGHT,1)
	check(e.plates[5].hp < before,"off-center lance damages armor")
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
	check(game.boss.salvos[0].offsets.size() > normal,"enraged additional volleys")
	# Pillars interrupt both rays and travelling hostile projectiles.
	var pillar: Vector2 = game.center(Vector2i(7,-11))
	var ray_start := pillar+Vector2(-120,0)
	var ray_end: Vector2 = game.attack_end(ray_start,Vector2.RIGHT,300)
	check(ray_end.x < pillar.x,"pillar clips laser before hiding player")
	game.restart_attempt()
	check(game.enemies[0].plates[6].hp == game.enemies[0].plates[6].max_hp,"retry restores shield snapshot")
	if DisplayServer.get_name() != "headless":
		game.discovered[1] = true
		e = game.enemies[0]
		game.player = e.p+Vector2(-270,30)
		game.camera_pos = e.p+Vector2(-100,0)
		game.banner = 0
		game.set_depth_view(true)
		game.depth_view.sync(game)
		game.queue_redraw()
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://docs/validation/fortress.png")
		e.active = true
		e.hp = e.max_hp*0.4
		e.cd = 0
		e.step = 2
		fortress.advance(game.boss,game,e,0,Vector2.LEFT)
		e.cd = 0
		e.step = 5
		fortress.advance(game.boss,game,e,0,Vector2.LEFT)
		fortress.damage_plate(game,e,6,e.plates[6].max_hp)
		game.depth_view.sync(game)
		game.queue_redraw()
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://docs/validation/fortress-enraged.png")
		game.practice.open(game)
		game.menus.sync()
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://docs/validation/fortress-menu.png")
	game.free()
	if failures == 0: print("PASS: fortress routing, armor, regeneration, weapons, cover, phases and retry")
	quit(1 if failures else 0)
