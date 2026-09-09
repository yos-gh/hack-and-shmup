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
	if DisplayServer.get_name() == "headless":
		printerr("Sniper warning test requires a display renderer")
		quit(2)
		return
	DirAccess.make_dir_recursive_absolute("res://docs/validation/sniper-warning")
	var game = load("res://main.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	game.set_process_unhandled_input(false)
	Scenario.configure(game, "normal19", 19045, 2)
	var sniper: Dictionary = game.enemies.filter(func(enemy: Dictionary) -> bool: return enemy.kind == 1)[0]
	game.enemies.assign([sniper])
	sniper.active = true
	sniper.charge = 0.0
	sniper.stun = 0.0
	game.discovered[sniper.room] = true
	game.camera_pos = sniper.p
	game.player = sniper.p-Vector2(200,0)
	game.replay_input = {"aim": Vector2.LEFT, "cursor": Vector2(1100,700)}
	game.banner = 0
	game.set_depth_view(true)
	var samples: Array[float] = []
	var center := Vector2i(game.get_viewport_rect().size*0.5)
	var outside := Color.BLACK
	for phase in range(5):
		sniper.cd = [0.45, 0.225, 0.0, game.ENEMY_SHOT_INTERVAL, 0.0][phase]
		sniper.stun = 0.2 if phase == 4 else 0.0
		var before: String = Scenario.digest(game)
		game.depth_view.sync(game)
		check(is_equal_approx(game.depth_view.batches.sniper.get_instance_custom_data(0).r, game.attack_warning(sniper)), "shader receives the shared warning value")
		await process_frame
		await process_frame
		await RenderingServer.frame_post_draw
		check(Scenario.digest(game) == before, "iris animation does not change combat")
		var picture: Image = game.depth_view.viewport.get_texture().get_image()
		samples.append(picture.get_pixelv(center+Vector2i(3,0)).get_luminance())
		check(picture.get_pixelv(center).get_luminance() < 0.2, "central opening remains dark")
		if phase == 0: outside = picture.get_pixelv(center+Vector2i(14,0))
		else: check(picture.get_pixelv(center+Vector2i(14,0)).is_equal_approx(outside), "outer silhouette does not expand")
		check(root.get_texture().get_image().save_png("res://docs/validation/sniper-warning/phase-%d.png" % phase) == OK, "save actual rendered warning frame")
	check(samples[2] > samples[0]+0.2, "the actual 3D hole visibly closes before firing")
	check(is_equal_approx(samples[3],samples[0]), "opening resets after firing")
	check(is_equal_approx(samples[4],samples[0]), "stun cancels the closing warning")
	print("Iris pixel luminance (idle, half, ready, fired, stunned): ", samples)
	game.free()
	if failures == 0: print("PASS: 3D sniper iris closes, resets, respects stun and preserves silhouette/gameplay")
	quit(1 if failures else 0)
