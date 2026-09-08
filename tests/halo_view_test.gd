extends SceneTree

const Scenario = preload("res://tools/dev_scenario.gd")
var failures := 0
func _initialize() -> void:
	call_deferred("run")
func check(ok: bool, message: String) -> void:
	if not ok:
		push_error("FAIL: " + message)
		failures += 1
func run() -> void:
	var game = load("res://main.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	game.set_process_unhandled_input(false)
	Scenario.configure(game,"halo45",19045,1)
	game.set_depth_view(true)
	var boss: Dictionary = game.enemies[0]
	boss.active = true
	boss.charge = 0.0
	game.camera_pos = boss.p
	game.player = boss.p+Vector2(180,80)
	game.banner = 0
	game.boss.deploy_options(game,boss,0)
	DirAccess.make_dir_recursive_absolute("res://docs/validation/halo-view")
	var samples: Array[float] = []
	for phase in range(3):
		boss.cd = [0.8,0.0,2.5][phase]
		boss.stun = 0.0
		for salvo in game.boss.salvos: salvo.delay = [0.7,0.0,0.7][phase]
		var before := var_to_bytes([Scenario.digest(game),game.boss.salvos,game.boss.options,game.effects_rng.state])
		game.depth_view.sync(game)
		check(game.depth_view.batches.halo_ring.visible_instance_count == game.boss.options.size()+1,"body and all live options uploaded")
		await process_frame
		await process_frame
		await RenderingServer.frame_post_draw
		check(before == var_to_bytes([Scenario.digest(game),game.boss.salvos,game.boss.options,game.effects_rng.state]),"render leaves attacks and RNG untouched")
		var picture: Image = game.depth_view.viewport.get_texture().get_image()
		var center := Vector2i(game.get_viewport_rect().size*0.5)
		samples.append(picture.get_pixelv(center+Vector2i(9,0)).get_luminance())
		check(picture.get_pixelv(center+Vector2i(27,0)).get_luminance() > 0.15,"outer ring actually rendered")
		check(root.get_texture().get_image().save_png("res://docs/validation/halo-view/phase-%d.png" % phase) == OK,"capture rendered frame")
	check(samples[0] > samples[1]+0.1 and is_equal_approx(samples[0],samples[2]),"actual core contracts before fire then resets")
	boss.hp = 0
	game.depth_view.sync(game)
	check(game.depth_view.batches.halo_ring.visible_instance_count == 0,"dead owner removes body and options immediately")
	game.restart_attempt()
	game.depth_view.sync(game)
	check(game.depth_view.batches.halo_ring.visible_instance_count == 0,"retry keeps undiscovered boss hidden")
	game.discovered[1] = true
	game.depth_view.sync(game)
	check(game.depth_view.batches.halo_ring.visible_instance_count == 1,"retry restores body without stale options")
	Scenario.configure(game,"normal19",19045,1)
	game.depth_view.sync(game)
	check(game.depth_view.batches.halo_ring.visible_instance_count == 0,"normal floor clears HALO geometry")
	game.free()
	if failures == 0: print("PASS: HALO rendered contraction/reset, live options, state isolation, death/retry/floor cleanup")
	quit(1 if failures else 0)
